import CaptaNucleo
import CoreGraphics
import Foundation
import Observation

/// Uma captura aberta numa janela: a imagem em memória, a sessão de edição e o rascunho.
///
/// Toda mudança do documento agenda o salvamento automático no rascunho; não há estado "não
/// salvo" para a pessoa (spec §4.8).
///
/// Copiar e salvar PNG funcionam desde o primeiro instante; salvar como Capta espera o rascunho.
/// O trabalho pesado (renderizar, codificar, gravar) roda fora da *main actor*.
@MainActor
@Observable
final class CapturaAberta {
    /// Situação do pacote de rascunho, que é gravado em paralelo à abertura da janela.
    enum EstadoRascunho: Equatable {
        case gravando
        case gravado(URL)
        case falhou
    }

    let nome: String
    private(set) var sessao: SessaoEdicao
    let base: CGImage
    let escala: Double
    var rascunho: EstadoRascunho {
        didSet { rascunhoMudou() }
    }

    var documento: Documento { sessao.documento }
    var podeDesfazer: Bool { sessao.podeDesfazer }
    var podeRefazer: Bool { sessao.podeRefazer }
    var estadoDoSalvamento: EstadoDoSalvamento { salvamento.estado }

    /// Enquanto o rascunho grava, salvar como Capta fica indisponível.
    var podeSalvarCapta: Bool { rascunho != .gravando }

    /// Aviso discreto que a janela mostra na barra (spec §4.5): só quando o rascunho falhou.
    var aviso: MensagemDeErro? { rascunho == .falhou ? .rascunhoNaoGuardado : nil }

    /// O único renderizador da captura: o canvas, copiar e salvar PNG desenham com ele.
    let renderizador: Renderizador
    private let painel: any PainelDeArquivos
    private let areaDeTransferencia: any AreaDeTransferencia
    private let pastaDeRascunhos: URL
    private let gravadorDeRascunho: FluxoDeCaptura.GravadorDeRascunho
    private let salvamento: SalvamentoAutomatico
    /// Avisa que o rascunho passou a existir ou foi regravado (o menu relê os recentes).
    private let aoPersistir: @MainActor () -> Void
    /// Há edição que o rascunho ainda não recebeu porque ele estava gravando ou sendo refeito.
    private var edicaoEsperaORascunho = false
    private var recriacao: Task<Void, Never>?
    /// Quem espera o rascunho sair de `.gravando` (``salvarAgora()``).
    private var esperasDoRascunho: [CheckedContinuation<Void, Never>] = []

    init(
        nome: String,
        documento: Documento,
        base: CGImage,
        escala: Double,
        rascunho: EstadoRascunho,
        renderizador: Renderizador,
        painel: any PainelDeArquivos,
        areaDeTransferencia: any AreaDeTransferencia,
        pastaDeRascunhos: URL = FileManager.default.temporaryDirectory,
        gravadorDeRascunho: @escaping FluxoDeCaptura.GravadorDeRascunho =
            FluxoDeCaptura.gravadorPadrao,
        salvamento: SalvamentoAutomatico? = nil,
        aoPersistir: @escaping @MainActor () -> Void = {}
    ) {
        self.nome = nome
        self.sessao = SessaoEdicao(documento: documento)
        self.base = base
        self.escala = escala
        self.rascunho = rascunho
        self.renderizador = renderizador
        self.painel = painel
        self.areaDeTransferencia = areaDeTransferencia
        self.pastaDeRascunhos = pastaDeRascunhos
        self.gravadorDeRascunho = gravadorDeRascunho
        self.aoPersistir = aoPersistir
        self.salvamento =
            salvamento
            ?? SalvamentoAutomatico(
                dormir: { try await Task.sleep(for: $0) },
                gravar: Self.gravadorPadrao(
                    base: ImagemCapturada(imagem: base, escala: escala),
                    renderizador: renderizador
                )
            )
        self.salvamento.aoGravar = aoPersistir
    }

    // MARK: Edição

    /// Aplica a edição à sessão e agenda o salvamento. Edição inválida é registrada, devolve
    /// `false` e não muda nada.
    @discardableResult
    func aplicar(_ edicao: Edicao) -> Bool {
        let antes = documento
        do {
            try sessao.aplicar(edicao)
        } catch {
            RegistroDeCaptura.falha("aplicarEdicao", error)
            return false
        }
        if documento != antes { documentoMudou() }
        return true
    }

    func desfazer() {
        if sessao.desfazer() { documentoMudou() }
    }

    func refazer() {
        if sessao.refazer() { documentoMudou() }
    }

    /// Grava já o que estiver pendente (fechar a janela, encerrar o app) e espera terminar.
    ///
    /// Com o rascunho ainda `.gravando`, espera ele terminar: a edição feita nesse intervalo só
    /// tem onde ser gravada depois (no rascunho novo, ou num refeito se ele falhar).
    func salvarAgora() async {
        while rascunho == .gravando {
            await withCheckedContinuation { esperasDoRascunho.append($0) }
        }
        await recriacao?.value
        await salvamento.salvarAgora()
    }

    /// Espera a recriação do rascunho em curso, se houver. Serve aos testes.
    func aguardarRascunho() async {
        await recriacao?.value
    }

    /// Gravador padrão do rascunho: renderiza, gera a miniatura e atualiza o pacote, tudo fora
    /// da *main actor*.
    nonisolated static func gravadorPadrao(
        base: ImagemCapturada,
        renderizador: Renderizador
    ) -> SalvamentoAutomatico.Gravador {
        { documento, url in
            try await Task.detached(priority: .utility) {
                let renderizada = try renderizador.renderizar(documento, base: base.imagem)
                let miniatura = try Miniatura.gerar(de: renderizada)
                let miniaturaDados = try CodificadorPNG.codificar(miniatura, escala: 1)
                try PacoteCapta.atualizar(documento, miniaturaDados: miniaturaDados, em: url)
            }.value
        }
    }

    private func documentoMudou() {
        switch rascunho {
        case .gravado(let url):
            salvamento.agendar(documento, em: url)
        case .gravando:
            edicaoEsperaORascunho = true
        case .falhou:
            edicaoEsperaORascunho = true
            recriarRascunho()
        }
    }

    private func rascunhoMudou() {
        if case .gravado = rascunho { aoPersistir() }
        switch rascunho {
        case .gravado(let url) where edicaoEsperaORascunho:
            edicaoEsperaORascunho = false
            salvamento.agendar(documento, em: url)
        case .falhou where edicaoEsperaORascunho:
            // A edição que esperava o rascunho não pode esperar uma próxima: refaz já.
            recriarRascunho()
        default:
            break
        }
        if rascunho != .gravando {
            let esperas = esperasDoRascunho
            esperasDoRascunho = []
            esperas.forEach { $0.resume() }
        }
    }

    /// Spec §4.8: o rascunho que falhou é refeito com o documento atual no primeiro salvamento.
    /// O aviso continua se falhar de novo; a próxima edição tenta outra vez.
    private func recriarRascunho() {
        guard recriacao == nil else { return }
        // O rascunho refeito já leva o documento atual: o que chegar depois fica marcado.
        edicaoEsperaORascunho = false
        let imagem = ImagemCapturada(imagem: base, escala: escala)
        let atual = documento
        let gravador = gravadorDeRascunho
        let pasta = pastaDeRascunhos
        let nome = nome
        recriacao = Task {
            do {
                let url = try await gravador(imagem, atual, pasta, nome)
                recriacao = nil
                rascunho = .gravado(url)
            } catch {
                RegistroDeCaptura.falha("recriarRascunho", error)
                recriacao = nil
            }
        }
    }

    /// Põe a imagem renderizada, em PNG, na área de transferência.
    ///
    /// Renderiza e codifica fora da *main actor*, como `salvarPNG`; só a escrita na área de
    /// transferência, que é rápida, volta para ela.
    func copiar() async -> ResultadoDeAcao {
        let documento = documento
        let base = imagemEnviavel
        let renderizador = renderizador
        do {
            let dados = try await Task.detached(priority: .userInitiated) {
                try Exportador.png(documento, base: base.imagem, renderizador: renderizador)
            }.value
            try areaDeTransferencia.copiarPNG(dados)
            return .concluido
        } catch {
            RegistroDeCaptura.falha("copiar", error)
            return .falhou(.naoFoiPossivelCopiar)
        }
    }

    /// Grava a imagem renderizada, em PNG, no destino escolhido no painel.
    func salvarPNG() async -> ResultadoDeAcao {
        guard let destino = await painel.escolherDestino(nomeSugerido: nome, extensao: "png")
        else { return .cancelado }
        let documento = documento
        let base = imagemEnviavel
        let renderizador = renderizador
        return await salvar("salvarPNG") {
            let dados = try Exportador.png(documento, base: base.imagem, renderizador: renderizador)
            try dados.write(to: destino, options: .atomic)
        }
    }

    /// Exporta uma cópia `.capta`: do rascunho, se já foi gravado; senão, da imagem em memória.
    func salvarCapta() async -> ResultadoDeAcao {
        guard
            let destino = await painel.escolherDestino(
                nomeSugerido: nome,
                extensao: PacoteCapta.extensao
            )
        else { return .cancelado }
        if case .gravado(let origem) = rascunho {
            // A cópia sai do rascunho: o pendente tem de estar nele antes.
            await salvamento.salvarAgora()
            // Se o rascunho não recebeu o pendente, copiá-lo exportaria um documento velho.
            if estadoDoSalvamento != .falhou {
                return await salvar("salvarCapta") {
                    try PacoteCapta.copiar(de: origem, para: destino)
                }
            }
        }
        return await salvarCaptaDaMemoria(em: destino)
    }

    /// Exporta o `.capta` da imagem e do documento em memória, sem passar pelo rascunho.
    private func salvarCaptaDaMemoria(em destino: URL) async -> ResultadoDeAcao {
        let documento = documento
        let base = imagemEnviavel
        return await salvar("salvarCapta") {
            let baseDados = try CodificadorPNG.codificar(base.imagem, escala: base.escala)
            let miniatura = try Miniatura.gerar(de: base.imagem)
            let miniaturaDados = try CodificadorPNG.codificar(miniatura, escala: 1)
            try PacoteCapta.gravar(
                documento,
                baseDados: baseDados,
                miniaturaDados: miniaturaDados,
                em: destino
            )
        }
    }

    /// A base empacotada para atravessar para fora da *main actor* (a `CGImage` é imutável).
    private var imagemEnviavel: ImagemCapturada {
        ImagemCapturada(imagem: base, escala: escala)
    }

    /// Roda a gravação fora da *main actor*, para codificar e escrever sem travar a janela.
    private func salvar(
        _ acao: String,
        _ trabalho: @escaping @Sendable () throws -> Void
    ) async -> ResultadoDeAcao {
        do {
            try await Task.detached(priority: .userInitiated, operation: trabalho).value
            return .concluido
        } catch {
            RegistroDeCaptura.falha(acao, error)
            return .falhou(.naoFoiPossivelSalvar)
        }
    }
}
