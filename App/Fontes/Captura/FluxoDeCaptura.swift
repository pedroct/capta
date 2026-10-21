import CaptaNucleo
import CaptaSistema
import CoreGraphics
import Foundation
import os

/// Coordena uma captura: disparo → permissão → captura → janela → rascunho em paralelo.
///
/// A janela abre sobre a imagem em memória sem esperar o rascunho; só a captura em si bloqueia
/// novos disparos. Guarda o `apresentador` com referência forte: quem o implementa não deve
/// guardar este fluxo com referência forte de volta.
@MainActor
final class FluxoDeCaptura {
    typealias GravadorDeRascunho =
        @Sendable (ImagemCapturada, Documento, URL, String) async throws -> URL

    /// Marca, nos ajustes, que o pedido de permissão do sistema já foi feito uma vez.
    static let chavePermissaoJaSolicitada = "permissaoJaSolicitada"

    private let capturador: any Capturador
    private let permissao: any PermissaoDeGravacaoDeTela
    private let apresentador: any Apresentador
    private let pastaDeRascunhos: URL
    private let cursor: () -> CGPoint
    private let agora: () -> Date
    private let defaults: UserDefaults
    private let gravadorDeRascunho: GravadorDeRascunho
    private let painel: any PainelDeArquivos
    private let areaDeTransferencia: any AreaDeTransferencia
    private let renderizador = Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF())

    private var capturando = false
    /// Gravação do rascunho da última captura (os testes a aguardam).
    private(set) var gravacaoDoRascunho: Task<Void, Never>?

    init(
        capturador: any Capturador,
        permissao: any PermissaoDeGravacaoDeTela,
        apresentador: any Apresentador,
        pastaDeRascunhos: URL,
        cursor: @escaping () -> CGPoint = CapturadorSC.posicaoDoCursor,
        agora: @escaping () -> Date,
        defaults: UserDefaults,
        gravadorDeRascunho: @escaping GravadorDeRascunho = FluxoDeCaptura.gravadorPadrao,
        painel: any PainelDeArquivos,
        areaDeTransferencia: any AreaDeTransferencia
    ) {
        self.capturador = capturador
        self.permissao = permissao
        self.apresentador = apresentador
        self.pastaDeRascunhos = pastaDeRascunhos
        self.cursor = cursor
        self.agora = agora
        self.defaults = defaults
        self.gravadorDeRascunho = gravadorDeRascunho
        self.painel = painel
        self.areaDeTransferencia = areaDeTransferencia
    }

    /// Captura a tela sob o cursor e abre a janela. Com uma captura em andamento, não faz nada.
    func capturarTelaInteira() async {
        guard !capturando else { return }
        capturando = true
        defer { capturando = false }
        let inicio = ContinuousClock.now

        guard permissao.consultar() else {
            solicitarPermissaoNaPrimeiraVez()
            apresentador.mostrarAjudaDePermissao()
            return
        }

        let imagem: ImagemCapturada
        let documento: Documento
        do {
            imagem = try await capturador.capturarTela(sobCursor: cursor())
            documento = try Documento.novo(de: imagem)
        } catch ErroCaptura.semPermissao {
            // Revogada no meio da sessão: a consulta disse sim, o sistema disse não.
            RegistroDeCaptura.falha("capturar", ErroCaptura.semPermissao)
            apresentador.mostrarAjudaDePermissao()
            return
        } catch {
            RegistroDeCaptura.falha("capturar", error)
            apresentador.mostrarAlerta(.capturaFalhou)
            return
        }

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
        RegistroDeCaptura.janelaAberta(apos: inicio.duration(to: .now))
        gravarRascunho(imagem, documento: documento, nome: nome, em: captura)
    }

    /// O pedido do sistema aparece uma única vez; depois, só a consulta e a ajuda.
    private func solicitarPermissaoNaPrimeiraVez() {
        guard !defaults.bool(forKey: Self.chavePermissaoJaSolicitada) else { return }
        defaults.set(true, forKey: Self.chavePermissaoJaSolicitada)
        permissao.solicitar()
    }

    /// Grava o rascunho em paralelo e atualiza a captura ao terminar.
    private func gravarRascunho(
        _ imagem: ImagemCapturada,
        documento: Documento,
        nome: String,
        em captura: CapturaAberta
    ) {
        let gravador = gravadorDeRascunho
        let pasta = pastaDeRascunhos
        let apresentador = apresentador
        gravacaoDoRascunho = Task {
            do {
                let url = try await gravador(imagem, documento, pasta, nome)
                captura.rascunho = .gravado(url)
            } catch {
                RegistroDeCaptura.falha("gravarRascunho", error)
                captura.rascunho = .falhou
                apresentador.mostrarAlerta(.rascunhoNaoGuardado)
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

/// Registro local do fluxo de captura: só o tipo do erro e a duração, nunca conteúdo ou caminho.
enum RegistroDeCaptura {
    private static let registro = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedroct.capta",
        category: "captura"
    )

    static func falha(_ acao: String, _ erro: any Error) {
        registro.error("\(acao, privacy: .public) falhou: \(tipo(de: erro), privacy: .public)")
    }

    static func janelaAberta(apos duracao: Duration) {
        let (segundos, attossegundos) = duracao.components
        let milissegundos = segundos * 1000 + attossegundos / 1_000_000_000_000_000
        registro.notice("do disparo à janela: \(milissegundos, privacy: .public) ms")
    }

    /// `ErroCaptura` não carrega dados, então o caso vai junto; dos outros, só o tipo, porque
    /// a descrição pode trazer nome de arquivo ou caminho.
    static func tipo(de erro: any Error) -> String {
        if let erro = erro as? ErroCaptura { return "ErroCaptura.\(erro)" }
        return String(reflecting: type(of: erro))
    }
}
