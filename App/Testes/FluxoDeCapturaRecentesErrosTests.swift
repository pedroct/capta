import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

@Suite("Fluxo de captura: capturas recentes que não abrem")
@MainActor
struct FluxoDeCapturaRecentesErrosTests: PacotesRecentesDeTeste {

    @Test func abrirRecenteCorrompidoAlertaENaoTocaOPacote() async throws {
        let resultado = try await abrirComPacote { pasta in
            let url = try pacote(em: pasta)
            try Data("isto não é json".utf8).write(
                to: url.appendingPathComponent("documento.json")
            )
            try fixarDatas(url)
            return url
        }
        defer { resultado.pasta.remover() }

        #expect(resultado.apresentador.alertas == [.naoFoiPossivelAbrir])
        #expect(resultado.apresentador.capturas.isEmpty)
        #expect(try marcas(resultado.pacote) == resultado.antes)
    }

    @Test func abrirRecenteComBaseCorrompidaAlertaENaoTocaOPacote() async throws {
        let resultado = try await abrirComPacote { pasta in
            let url = try pacote(em: pasta)
            try Data("não é PNG".utf8).write(to: url.appendingPathComponent("base.png"))
            try fixarDatas(url)
            return url
        }
        defer { resultado.pasta.remover() }

        #expect(resultado.apresentador.alertas == [.naoFoiPossivelAbrir])
        #expect(try marcas(resultado.pacote) == resultado.antes)
    }

    @Test func abrirRecenteComBaseDeOutroTamanhoAlertaENaoTocaOPacote() async throws {
        let resultado = try await abrirComPacote { pasta in
            let url = try pacote(em: pasta)
            let outra = try CodificadorPNG.codificar(
                try imagemDeTeste(largura: 4, altura: 4),
                escala: 2
            )
            try outra.write(to: url.appendingPathComponent("base.png"))
            try fixarDatas(url)
            return url
        }
        defer { resultado.pasta.remover() }

        #expect(resultado.apresentador.alertas == [.naoFoiPossivelAbrir])
        #expect(resultado.apresentador.capturas.isEmpty)
        #expect(try marcas(resultado.pacote) == resultado.antes)
    }

    @Test func abrirRecenteDeVersaoMaisNovaAlertaENaoTocaOPacote() async throws {
        let resultado = try await abrirComPacote { pasta in
            let url = try pacote(em: pasta)
            try reescrever(url) {
                $0.replacingOccurrences(
                    of: "\"versaoEsquema\" : \(Esquema.versaoAtual)",
                    with: "\"versaoEsquema\" : 99"
                )
            }
            return url
        }
        defer { resultado.pasta.remover() }

        #expect(resultado.apresentador.alertas == [.naoFoiPossivelAbrir])
        #expect(resultado.apresentador.capturas.isEmpty)
        #expect(try marcas(resultado.pacote) == resultado.antes)
    }

    @Test func abrirRecenteApagadoAlertaEAvisaOMenu() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let url = try pacote(em: pasta.url)
        try FileManager.default.removeItem(at: url)
        let defaults = try DefaultsTemporarios()
        defer { defaults.remover() }
        let apresentador = ApresentadorFalso()
        let avisos = Contador()

        await fluxo(
            apresentador: apresentador,
            defaults: defaults.defaults,
            pasta: pasta.url,
            aoMudarRecentes: { avisos.vezes += 1 }
        ).abrirRecente(url)

        #expect(apresentador.alertas == [.naoFoiPossivelAbrir])
        #expect(apresentador.capturas.isEmpty)
        // A lista do menu estava velha: relê.
        #expect(avisos.vezes == 1)
    }
}
