import CaptaNucleo
import CoreGraphics
import Foundation
import Testing
import os

@testable import Capta

/// Erro qualquer, que não é do domínio.
struct ErroDeTeste: Error {}

/// Imagem sólida de `largura` x `altura` pixels, com a cor RGB dada (0 a 1).
func imagemDeTeste(
    largura: Int = 8,
    altura: Int = 6,
    vermelho: CGFloat = 1,
    verde: CGFloat = 0,
    azul: CGFloat = 0
) throws -> CGImage {
    let espaco = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let contexto = try #require(
        CGContext(
            data: nil,
            width: largura,
            height: altura,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: espaco,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    contexto.setFillColor(CGColor(srgbRed: vermelho, green: verde, blue: azul, alpha: 1))
    contexto.fill(CGRect(x: 0, y: 0, width: largura, height: altura))
    return try #require(contexto.makeImage())
}

/// Pasta temporária única; o teste a remove com `remover()` no fim.
struct PastaTemporaria {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func conteudo() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.path)
    }

    func remover() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// `UserDefaults` isolado por teste; `remover()` apaga o domínio no fim.
struct DefaultsTemporarios {
    let nome = "com.pedroct.capta.testes.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: nome))
    }

    func remover() {
        defaults.removePersistentDomain(forName: nome)
    }
}

/// Portão: quem chama `esperar()` fica preso até alguém chamar `abrir()`.
actor Portao {
    private var aberto = false
    private var presos: [CheckedContinuation<Void, Never>] = []
    private var observadores: [CheckedContinuation<Void, Never>] = []

    func esperar() async {
        if aberto { return }
        await withCheckedContinuation { continuacao in
            presos.append(continuacao)
            let avisar = observadores
            observadores = []
            avisar.forEach { $0.resume() }
        }
    }

    /// Volta quando alguém já está preso no portão.
    func aguardarAlguemPreso() async {
        if !presos.isEmpty { return }
        await withCheckedContinuation { observadores.append($0) }
    }

    func abrir() {
        aberto = true
        let soltar = presos
        presos = []
        soltar.forEach { $0.resume() }
    }
}

/// Chamada registrada de `capturarRegiao`.
struct ChamadaDeRegiao: Equatable {
    let tela: DescricaoDeTela
    let pixels: CGRect
    let incluirCursor: Bool
}

/// Chamada registrada de `capturarJanela`.
struct ChamadaDeJanela: Equatable {
    let id: UInt32
    let incluirCursor: Bool
}

/// Capturador que devolve resultados fixos, opcionalmente preso num portão, e registra as chamadas.
/// Os métodos novos falham com `.falhou` até receberem um resultado programado.
actor CapturadorFalso: Capturador {
    private let resultado: Result<ImagemCapturada, ErroCaptura>
    private let portao: Portao?
    private(set) var pontos: [CGPoint] = []

    var resultadoDeCongelar: Result<[TelaCongelada], ErroCaptura> = .failure(.falhou)
    var resultadoDeJanelas: Result<[JanelaDeTela], ErroCaptura> = .failure(.falhou)
    var resultadoDeRegiao: Result<ImagemCapturada, ErroCaptura> = .failure(.falhou)
    var resultadoDeJanela: Result<ImagemCapturada, ErroCaptura> = .failure(.falhou)
    private(set) var congelamentos = 0
    private(set) var listagensDeJanelas = 0
    private(set) var chamadasDeRegiao: [ChamadaDeRegiao] = []
    private(set) var chamadasDeJanela: [ChamadaDeJanela] = []

    init(_ resultado: Result<ImagemCapturada, ErroCaptura>, portao: Portao? = nil) {
        self.resultado = resultado
        self.portao = portao
    }

    func programar(
        congelar: Result<[TelaCongelada], ErroCaptura>? = nil,
        janelas: Result<[JanelaDeTela], ErroCaptura>? = nil,
        regiao: Result<ImagemCapturada, ErroCaptura>? = nil,
        janela: Result<ImagemCapturada, ErroCaptura>? = nil
    ) {
        if let congelar { resultadoDeCongelar = congelar }
        if let janelas { resultadoDeJanelas = janelas }
        if let regiao { resultadoDeRegiao = regiao }
        if let janela { resultadoDeJanela = janela }
    }

    func capturarTela(sobCursor ponto: CGPoint) async throws -> ImagemCapturada {
        pontos.append(ponto)
        await portao?.esperar()
        return try resultado.get()
    }

    func congelarTelas() async throws -> [TelaCongelada] {
        congelamentos += 1
        await portao?.esperar()
        return try resultadoDeCongelar.get()
    }

    func listarJanelas() async throws -> [JanelaDeTela] {
        listagensDeJanelas += 1
        await portao?.esperar()
        return try resultadoDeJanelas.get()
    }

    func capturarRegiao(
        em tela: DescricaoDeTela,
        pixels: CGRect,
        incluirCursor: Bool
    ) async throws -> ImagemCapturada {
        chamadasDeRegiao.append(
            ChamadaDeRegiao(tela: tela, pixels: pixels, incluirCursor: incluirCursor)
        )
        await portao?.esperar()
        return try resultadoDeRegiao.get()
    }

    func capturarJanela(id: UInt32, incluirCursor: Bool) async throws -> ImagemCapturada {
        chamadasDeJanela.append(ChamadaDeJanela(id: id, incluirCursor: incluirCursor))
        await portao?.esperar()
        return try resultadoDeJanela.get()
    }
}

/// Permissão com resposta fixa que conta os pedidos.
final class PermissaoFalsa: PermissaoDeGravacaoDeTela {
    private struct Estado {
        var concedida: Bool
        var solicitacoes = 0
    }

    private let estado: OSAllocatedUnfairLock<Estado>

    init(concedida: Bool) {
        estado = OSAllocatedUnfairLock(initialState: Estado(concedida: concedida))
    }

    var solicitacoes: Int { estado.withLock { $0.solicitacoes } }

    func consultar() -> Bool { estado.withLock { $0.concedida } }

    func solicitar() { estado.withLock { $0.solicitacoes += 1 } }
}

/// Apresentador que só registra o que foi pedido.
@MainActor
final class ApresentadorFalso: Apresentador {
    private(set) var ajudas = 0
    private(set) var capturas: [CapturaAberta] = []
    private(set) var alertas: [MensagemDeErro] = []

    func mostrarAjudaDePermissao() { ajudas += 1 }

    func mostrarCaptura(_ captura: CapturaAberta) { capturas.append(captura) }

    func mostrarAlerta(_ mensagem: MensagemDeErro) { alertas.append(mensagem) }
}

/// Área de transferência que guarda o último PNG ou falha.
final class AreaDeTransferenciaFalsa: AreaDeTransferencia {
    private let falhar: Bool
    private let copiado = OSAllocatedUnfairLock<Data?>(initialState: nil)

    init(falhar: Bool = false) {
        self.falhar = falhar
    }

    var dados: Data? { copiado.withLock { $0 } }

    func copiarPNG(_ dados: Data) throws {
        if falhar { throw ErroExportacao.falhaAoCopiar }
        copiado.withLock { $0 = dados }
    }
}

/// Painel que devolve um destino fixo (`nil` = cancelado) e registra o pedido.
@MainActor
final class PainelFalso: PainelDeArquivos {
    private let destino: URL?
    private(set) var pedidos: [(nomeSugerido: String, extensao: String)] = []

    init(destino: URL?) {
        self.destino = destino
    }

    func escolherDestino(nomeSugerido: String, extensao: String) async -> URL? {
        pedidos.append((nomeSugerido, extensao))
        return destino
    }
}
