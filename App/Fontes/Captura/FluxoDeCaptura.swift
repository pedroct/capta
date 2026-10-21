import CaptaNucleo
import CaptaSistema
import CoreGraphics
import Foundation

/// Coordena uma captura: disparo → permissão → captura → janela → rascunho em paralelo.
///
/// Dois caminhos chegam à mesma janela: a tela inteira sob o cursor (fatia 3) e a captura livre,
/// que passa pelo overlay e, com atraso, pela contagem (spec §4.1). Só um disparo corre por vez:
/// enquanto há captura, overlay ou contagem, outro disparo é ignorado. A janela abre sobre a
/// imagem em memória sem esperar o rascunho.
///
/// Guarda o `apresentador`, o `seletor` e a `contagem` com referência forte: quem os implementa
/// não deve guardar este fluxo com referência forte de volta.
@MainActor
final class FluxoDeCaptura {
    typealias GravadorDeRascunho =
        @Sendable (ImagemCapturada, Documento, URL, String) async throws -> URL
    /// Espera da contagem regressiva; deve lançar se a `Task` for cancelada.
    typealias Pausa = @Sendable (Duration) async throws -> Void

    /// Marca, nos ajustes, que o pedido de permissão do sistema já foi feito uma vez.
    static let chavePermissaoJaSolicitada = "permissaoJaSolicitada"

    private let capturador: any Capturador
    private let permissao: any PermissaoDeGravacaoDeTela
    private let apresentador: any Apresentador
    private let livre: CapturaLivre
    private let contagem: any ApresentadorDaContagem
    private let pastaDeRascunhos: URL
    private let cursor: () -> CGPoint
    private let agora: () -> Date
    private let defaults: UserDefaults
    private let gravadorDeRascunho: GravadorDeRascunho
    private let painel: any PainelDeArquivos
    private let areaDeTransferencia: any AreaDeTransferencia
    private let pausa: Pausa
    private let renderizador = Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF())

    /// Há captura, overlay ou contagem em andamento.
    private var capturando = false
    /// A contagem que está correndo, para `cancelarContagem` a interromper.
    private var tarefaDaContagem: Task<Bool, Never>?
    /// Gravação do rascunho da última captura (os testes a aguardam).
    private(set) var gravacaoDoRascunho: Task<Void, Never>?

    init(
        capturador: any Capturador,
        permissao: any PermissaoDeGravacaoDeTela,
        apresentador: any Apresentador,
        seletor: any SeletorDeCaptura,
        contagem: any ApresentadorDaContagem,
        opcoes: OpcoesLembradas,
        pastaDeRascunhos: URL,
        cursor: @escaping () -> CGPoint = CapturadorSC.posicaoDoCursor,
        agora: @escaping () -> Date,
        defaults: UserDefaults,
        gravadorDeRascunho: @escaping GravadorDeRascunho = FluxoDeCaptura.gravadorPadrao,
        painel: any PainelDeArquivos,
        areaDeTransferencia: any AreaDeTransferencia,
        pausa: @escaping Pausa = { try await Task.sleep(for: $0) }
    ) {
        self.capturador = capturador
        self.permissao = permissao
        self.apresentador = apresentador
        self.livre = CapturaLivre(capturador: capturador, seletor: seletor, opcoes: opcoes)
        self.contagem = contagem
        self.pastaDeRascunhos = pastaDeRascunhos
        self.cursor = cursor
        self.agora = agora
        self.defaults = defaults
        self.gravadorDeRascunho = gravadorDeRascunho
        self.painel = painel
        self.areaDeTransferencia = areaDeTransferencia
        self.pausa = pausa
    }

    // MARK: - Tela inteira

    /// Captura a tela sob o cursor e abre a janela. Com uma captura em andamento, não faz nada.
    func capturarTelaInteira() async {
        guard !capturando else { return }
        capturando = true
        defer { capturando = false }
        let inicio = ContinuousClock.now

        guard temPermissao() else { return }
        do {
            let imagem = try await capturador.capturarTela(sobCursor: cursor())
            try abrir(imagem) { RegistroDeCaptura.janelaAberta(apos: inicio.duration(to: .now)) }
        } catch {
            falhou("capturar", error)
        }
    }

    // MARK: - Captura livre

    /// Congela as telas, abre o overlay e captura o que for escolhido (spec §4.1 e §4.4).
    ///
    /// Com uma captura, overlay ou contagem em andamento, não faz nada. Toda saída fecha a
    /// contagem, para o `Esc` global dela nunca sobreviver ao fluxo.
    func capturarLivre(modo: ModoDoOverlay) async {
        guard !capturando else { return }
        capturando = true
        defer {
            capturando = false
            contagem.fechar()
        }
        let inicio = ContinuousClock.now

        guard temPermissao() else { return }
        do {
            let escolha = try await livre.escolher(modo: modo) {
                RegistroDeCaptura.overlayAberto(apos: inicio.duration(to: .now))
            }
            guard let escolha else { return }
            let atraso = escolha.opcoes.atraso
            if atraso != .nenhum {
                guard await contar(atraso.rawValue, naTela: escolha.telaDaContagem) else { return }
                contagem.fechar()
            }
            // Com atraso, a partir do fim da contagem: o que interessa é o tempo da captura.
            let desde = ContinuousClock.now
            let imagem =
                atraso == .nenhum
                ? try await livre.capturarSemAtraso(escolha)
                : try await livre.capturarAoVivo(
                    escolha.selecao,
                    incluirCursor: escolha.opcoes.incluirCursor
                )
            try abrir(imagem) {
                RegistroDeCaptura.janelaAberta(aposSelecao: desde.duration(to: .now))
            }
        } catch {
            falhou("capturarLivre", error)
        }
    }

    /// Cancela a contagem em andamento (o `Esc` ou o clique na janelinha); nada é capturado.
    func cancelarContagem() {
        tarefaDaContagem?.cancel()
    }

    /// Mostra a contagem e espera o atraso. Devolve `false` se ela for cancelada: pelo `Esc` ou
    /// clique (``cancelarContagem()``) ou pela tarefa de quem chamou.
    ///
    /// A `ContagemRegressiva` corre fora da *main actor*; os segundos voltam por um `AsyncStream`
    /// para a janelinha ser atualizada em ordem.
    private func contar(_ segundos: Int, naTela tela: DescricaoDeTela) async -> Bool {
        contagem.mostrar(segundos: segundos, naTela: tela)
        let (restantes, continuacao) = AsyncStream.makeStream(of: Int.self)
        let regressiva = ContagemRegressiva(segundos: segundos, pausa: pausa)
        let tarefa = Task {
            let terminou = await regressiva.executar { _ = continuacao.yield($0) }
            continuacao.finish()
            return terminou
        }
        tarefaDaContagem = tarefa
        defer { tarefaDaContagem = nil }
        return await withTaskCancellationHandler {
            for await restante in restantes { contagem.atualizar(restante) }
            return await tarefa.value
        } onCancel: {
            tarefa.cancel()
        }
    }

    // MARK: - Comum aos dois caminhos

    /// Sem permissão, pede uma única vez ao sistema e mostra a ajuda.
    private func temPermissao() -> Bool {
        guard permissao.consultar() else {
            solicitarPermissaoNaPrimeiraVez()
            apresentador.mostrarAjudaDePermissao()
            return false
        }
        return true
    }

    /// O pedido do sistema aparece uma única vez; depois, só a consulta e a ajuda.
    private func solicitarPermissaoNaPrimeiraVez() {
        guard !defaults.bool(forKey: Self.chavePermissaoJaSolicitada) else { return }
        defaults.set(true, forKey: Self.chavePermissaoJaSolicitada)
        permissao.solicitar()
    }

    /// Permissão revogada no meio da sessão (a consulta disse sim, o sistema disse não) vira a
    /// ajuda; qualquer outra falha, o alerta curto. Nada é gravado.
    private func falhou(_ acao: String, _ erro: any Error) {
        RegistroDeCaptura.falha(acao, erro)
        if erro as? ErroCaptura == .semPermissao {
            apresentador.mostrarAjudaDePermissao()
        } else {
            apresentador.mostrarAlerta(.capturaFalhou)
        }
    }

    /// Do `Documento.novo(de:)` à janela e ao rascunho, igual nos dois caminhos.
    /// `aoMostrar` roda logo depois de a janela abrir (o registro de duração).
    private func abrir(_ imagem: ImagemCapturada, aoMostrar: () -> Void) throws {
        let documento = try Documento.novo(de: imagem)
        let nome = Rascunho.nome(para: agora())
        let captura = CapturaAberta(
            nome: nome,
            documento: documento,
            base: imagem.imagem,
            escala: imagem.escala,
            rascunho: .gravando,
            renderizador: renderizador,
            painel: painel,
            areaDeTransferencia: areaDeTransferencia
        )
        apresentador.mostrarCaptura(captura)
        aoMostrar()
        gravarRascunho(imagem, documento: documento, nome: nome, em: captura)
    }

    /// Grava o rascunho em paralelo e atualiza a captura ao terminar.
    ///
    /// A falha não abre alerta: a janela mostra o aviso na barra a partir de
    /// ``CapturaAberta/aviso``, e copiar e salvar continuam funcionando.
    private func gravarRascunho(
        _ imagem: ImagemCapturada,
        documento: Documento,
        nome: String,
        em captura: CapturaAberta
    ) {
        let gravador = gravadorDeRascunho
        let pasta = pastaDeRascunhos
        gravacaoDoRascunho = Task {
            do {
                let url = try await gravador(imagem, documento, pasta, nome)
                captura.rascunho = .gravado(url)
            } catch {
                RegistroDeCaptura.falha("gravarRascunho", error)
                captura.rascunho = .falhou
            }
        }
    }

    /// `Rascunho.gravar` fora da *main actor* (codifica PNG e escreve no disco).
    nonisolated static func gravadorPadrao(
        _ imagem: ImagemCapturada,
        _ documento: Documento,
        _ pasta: URL,
        _ nome: String
    ) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try Rascunho.gravar(imagem, documento: documento, em: pasta, nome: nome)
        }.value
    }
}
