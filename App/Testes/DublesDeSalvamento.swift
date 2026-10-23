import CaptaNucleo
import CoreGraphics
import Foundation

@testable import Capta

/// Relógio de mentira: cada `dormir` só retorna quando o teste chama `avancar()`; cancelar a
/// tarefa que dorme lança `CancellationError`, como o `Task.sleep` de verdade.
actor RelogioFalso {
    private var esperas: [Int: CheckedContinuation<Void, any Error>] = [:]
    private var cancelados: Set<Int> = []
    private var proximo = 0
    private(set) var pedidos: [Duration] = []

    var esperando: Int { esperas.count }

    func dormir(_ duracao: Duration) async throws {
        let id = proximo
        proximo += 1
        pedidos.append(duracao)
        try await withTaskCancellationHandler {
            try await esperar(id)
        } onCancel: {
            Task { await self.cancelar(id) }
        }
    }

    private func esperar(_ id: Int) async throws {
        try await withCheckedThrowingContinuation {
            (continuacao: CheckedContinuation<Void, any Error>) in
            if cancelados.contains(id) {
                continuacao.resume(throwing: CancellationError())
            } else {
                esperas[id] = continuacao
            }
        }
    }

    private func cancelar(_ id: Int) {
        cancelados.insert(id)
        esperas.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    /// Faz todas as esperas em curso retornarem (o tempo "passou").
    func avancar() {
        let soltar = esperas
        esperas = [:]
        soltar.values.forEach { $0.resume() }
    }

    /// Volta quando há `quantas` esperas registradas (cede a vez enquanto não há).
    func aguardarEsperas(_ quantas: Int = 1) async {
        var tentativas = 0
        while esperas.count < quantas, tentativas < 100_000 {
            tentativas += 1
            await Task.yield()
        }
    }
}

/// Gravador de documento de mentira: registra o que foi gravado, mede a sobreposição e pode
/// ficar preso num portão ou falhar.
actor GravadorDeDocumentoFalso {
    private(set) var iniciadas: [Documento] = []
    private(set) var concluidas: [Documento] = []
    private(set) var urls: [URL] = []
    private(set) var maximoSimultaneo = 0
    private var simultaneas = 0
    private var falhar: Bool
    private var portao: Portao?

    init(falhar: Bool = false, portao: Portao? = nil) {
        self.falhar = falhar
        self.portao = portao
    }

    func mudar(falhar: Bool) { self.falhar = falhar }
    func prender(em portao: Portao?) { self.portao = portao }

    func gravar(_ documento: Documento, _ url: URL) async throws {
        iniciadas.append(documento)
        urls.append(url)
        simultaneas += 1
        maximoSimultaneo = max(maximoSimultaneo, simultaneas)
        defer { simultaneas -= 1 }
        await portao?.esperar()
        if falhar { throw ErroDeTeste() }
        concluidas.append(documento)
    }

    /// Volta quando uma gravação já começou.
    func aguardarInicio(_ quantas: Int = 1) async {
        var tentativas = 0
        while iniciadas.count < quantas, tentativas < 100_000 {
            tentativas += 1
            await Task.yield()
        }
    }
}

/// Documento da base de teste (8 x 6 pixels, escala 2) com recorte de `largura` x 3: documentos
/// de larguras diferentes são diferentes entre si e todos válidos.
func documentoComRecorte(largura: CGFloat) throws -> Documento {
    var sessao = SessaoEdicao(
        documento: try Documento.novo(de: ImagemCapturada(imagem: imagemDeTeste(), escala: 2))
    )
    try sessao.aplicar(.definirRecorte(CGRect(x: 0, y: 0, width: largura, height: 3)))
    return sessao.documento
}
