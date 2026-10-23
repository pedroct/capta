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
    private let aoMudarRecentes: @MainActor () -> Void
    private let renderizador = Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF())

    /// Há captura, overlay ou contagem em andamento.
    private var capturando = false
    /// A contagem que está correndo, para `cancelarContagem` a interromper.
    private var tarefaDaContagem: Task<Bool, Never>?
    /// `Esc` ou clique pediram o cancelamento desta contagem.
    ///
    /// Sozinho, `tarefaDaContagem?.cancel()` corre uma corrida estreita: se o cancelamento chega
    /// bem quando a última pausa de 1 s já terminou, `ContagemRegressiva.executar` não torna a
    /// checar `Task.isCancelled` antes de devolver `true`, e a captura ao vivo aconteceria mesmo
    /// cancelada. Esta marca é conferida à parte do valor devolvido pela contagem.
    private var contagemCancelada = false
    /// Gravação do rascunho da última captura (os testes a aguardam).
    private(set) var gravacaoDoRascunho: Task<Void, Never>?
    /// Pacotes recentes que estão sendo lidos, para um segundo clique não abrir outra janela.
    private var abrindoRecentes: Set<URL> = []

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
        pausa: @escaping Pausa = { try await Task.sleep(for: $0) },
        aoMudarRecentes: @escaping @MainActor () -> Void = {}
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
        self.aoMudarRecentes = aoMudarRecentes
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
                contagemCancelada = false
                let terminou = await contar(atraso.rawValue, naTela: escolha.telaDaContagem)
                guard terminou && !contagemCancelada else { return }
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
        contagemCancelada = true
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

    // MARK: - Capturas recentes

    /// Reabre um pacote `.capta` da lista de recentes (spec §4.8).
    ///
    /// Se o pacote já tem janela, ela vem para a frente. Senão lê e decodifica fora da *main
    /// actor* e abre o editor com o próprio pacote como rascunho. Pacote corrompido, de versão
    /// mais nova ou apagado vira o alerta ``MensagemDeErro/naoFoiPossivelAbrir``; a leitura
    /// nunca escreve no pacote.
    func abrirRecente(_ url: URL) async {
        if apresentador.trazerParaFrente(url) { return }
        guard abrindoRecentes.insert(url).inserted else { return }
        defer { abrindoRecentes.remove(url) }
        // Uma janela recém-fechada deste pacote ainda pode estar gravando a última edição.
        await apresentador.aguardarFechamentos()
        do {
            let imagem = try await Self.lerPacote(url)
            let captura = montarCaptura(
                nome: url.deletingPathExtension().lastPathComponent,
                documento: imagem.documento,
                imagem: imagem.base,
                rascunho: .gravado(url)
            )
            apresentador.mostrarCaptura(captura)
        } catch {
            RegistroDeCaptura.falha("abrirRecente", error)
            apresentador.mostrarAlerta(.naoFoiPossivelAbrir)
            // A lista do menu estava velha (pacote apagado ou estragado): relê.
            aoMudarRecentes()
        }
    }

    /// Lê o pacote e decodifica a base fora da *main actor*. A base tem de ter o tamanho que o
    /// documento declara; senão as coordenadas das anotações não casariam com a imagem.
    nonisolated private static func lerPacote(
        _ url: URL
    ) async throws -> (documento: Documento, base: ImagemCapturada) {
        try await Task.detached(priority: .userInitiated) {
            let conteudo = try PacoteCapta.ler(de: url)
            let imagem = try CodificadorPNG.decodificar(conteudo.baseDados)
            let tamanho = conteudo.documento.tamanhoBase
            guard CGFloat(imagem.width) == tamanho.width, CGFloat(imagem.height) == tamanho.height
            else { throw ErroImagem.falhaAoDecodificar }
            return (
                conteudo.documento,
                ImagemCapturada(imagem: imagem, escala: conteudo.documento.escala)
            )
        }.value
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
        let captura = montarCaptura(
            nome: nome,
            documento: documento,
            imagem: imagem,
            rascunho: .gravando
        )
        apresentador.mostrarCaptura(captura)
        aoMostrar()
        gravarRascunho(imagem, documento: documento, nome: nome, em: captura)
    }

    private func montarCaptura(
        nome: String,
        documento: Documento,
        imagem: ImagemCapturada,
        rascunho: CapturaAberta.EstadoRascunho
    ) -> CapturaAberta {
        CapturaAberta(
            nome: nome,
            documento: documento,
            base: imagem.imagem,
            escala: imagem.escala,
            rascunho: rascunho,
            renderizador: renderizador,
            painel: painel,
            areaDeTransferencia: areaDeTransferencia,
            pastaDeRascunhos: pastaDeRascunhos,
            gravadorDeRascunho: gravadorDeRascunho,
            aoPersistir: aoMudarRecentes
        )
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
