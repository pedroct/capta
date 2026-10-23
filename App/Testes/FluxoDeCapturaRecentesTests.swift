import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

@Suite("Fluxo de captura: abrir capturas recentes")
@MainActor
struct FluxoDeCapturaRecentesTests: PacotesRecentesDeTeste {
    private static let recorte = Edicao.definirRecorte(CGRect(x: 0, y: 0, width: 4, height: 3))

    @Test func abrirRecenteMostraOEditorComORascunhoGravado() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let url = try pacote(em: pasta.url)
        let defaults = try DefaultsTemporarios()
        defer { defaults.remover() }
        let apresentador = ApresentadorFalso()

        await fluxo(apresentador: apresentador, defaults: defaults.defaults, pasta: pasta.url)
            .abrirRecente(url)

        let captura = try #require(apresentador.capturas.first)
        #expect(apresentador.capturas.count == 1)
        #expect(apresentador.alertas.isEmpty)
        #expect(captura.rascunho == .gravado(url))
        #expect(captura.nome == "Captura antiga")
        #expect(captura.escala == 2)
        #expect(captura.base.width == 8 && captura.base.height == 6)
        #expect(captura.documento == (try PacoteCapta.ler(de: url)).documento)
    }

    @Test func abrirRecenteJaAbertoTrazParaAFrenteSemOutraJanela() async throws {
        let defaults = try DefaultsTemporarios()
        defer { defaults.remover() }
        let apresentador = ApresentadorFalso()
        // O pacote nem existe: se o fluxo tentasse ler, haveria alerta.
        let url = URL(fileURLWithPath: "/nao/existe/Aberta.capta", isDirectory: true)
        apresentador.pacotesAbertos = [url]

        await fluxo(
            apresentador: apresentador,
            defaults: defaults.defaults,
            pasta: URL(fileURLWithPath: "/rascunhos")
        ).abrirRecente(url)

        #expect(apresentador.trazidos == [url])
        #expect(apresentador.capturas.isEmpty)
        #expect(apresentador.alertas.isEmpty)
    }

    @Test func abrirRecenteV1MigraEOProximoSalvamentoGravaV2() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let url = try pacote(em: pasta.url)
        try reescrever(url) {
            $0.replacingOccurrences(
                of: "\"versaoEsquema\" : \(Esquema.versaoAtual)",
                with: "\"versaoEsquema\" : 1"
            )
        }
        let antes = try String(
            contentsOf: url.appendingPathComponent("documento.json"),
            encoding: .utf8
        )
        #expect(antes.contains("\"versaoEsquema\" : 1"))
        let defaults = try DefaultsTemporarios()
        defer { defaults.remover() }
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(apresentador: apresentador, defaults: defaults.defaults, pasta: pasta.url)

        await fluxo.abrirRecente(url)

        let captura = try #require(apresentador.capturas.first)
        #expect(captura.documento.versaoEsquema == Esquema.versaoAtual)
        // Abrir não grava nada: o pacote segue em v1 até a primeira edição.
        let aposAbrir = try String(
            contentsOf: url.appendingPathComponent("documento.json"),
            encoding: .utf8
        )
        #expect(aposAbrir == antes)

        captura.aplicar(Self.recorte)
        await captura.salvarAgora()

        let depois = try String(
            contentsOf: url.appendingPathComponent("documento.json"),
            encoding: .utf8
        )
        #expect(depois.contains("\"versaoEsquema\" : \(Esquema.versaoAtual)"))
        #expect(try PacoteCapta.ler(de: url).documento == captura.documento)
    }

    @Test func salvamentoDaCapturaReabertaAvisaOMenu() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let url = try pacote(em: pasta.url)
        let defaults = try DefaultsTemporarios()
        defer { defaults.remover() }
        let apresentador = ApresentadorFalso()
        let avisos = Contador()
        let fluxo = fluxo(
            apresentador: apresentador,
            defaults: defaults.defaults,
            pasta: pasta.url,
            aoMudarRecentes: { avisos.vezes += 1 }
        )
        await fluxo.abrirRecente(url)
        let captura = try #require(apresentador.capturas.first)
        #expect(avisos.vezes == 0)

        captura.aplicar(Self.recorte)
        await captura.salvarAgora()

        #expect(avisos.vezes == 1)
    }

    @Test func rascunhoGravadoDeUmaCapturaNovaAvisaOMenu() async throws {
        let defaults = try DefaultsTemporarios()
        defer { defaults.remover() }
        let apresentador = ApresentadorFalso()
        let imagem = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        let avisos = Contador()
        let fluxo = FluxoDeCaptura(
            capturador: CapturadorFalso(.success(imagem)),
            permissao: PermissaoFalsa(concedida: true),
            apresentador: apresentador,
            seletor: SeletorFalso(),
            contagem: ContagemFalsa(),
            opcoes: OpcoesLembradas(defaults: defaults.defaults),
            pastaDeRascunhos: URL(fileURLWithPath: "/rascunhos"),
            agora: { Date(timeIntervalSince1970: 1_800_000_000) },
            defaults: defaults.defaults,
            gravadorDeRascunho: { _, _, pasta, nome in
                pasta.appendingPathComponent("\(nome).capta", isDirectory: true)
            },
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa(),
            aoMudarRecentes: { avisos.vezes += 1 }
        )

        await fluxo.capturarTelaInteira()
        await fluxo.gravacaoDoRascunho?.value

        #expect(avisos.vezes == 1)
    }

    @Test func abrirOMesmoRecenteDuasVezesSeguidasAbreUmaJanela() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let url = try pacote(em: pasta.url)
        let defaults = try DefaultsTemporarios()
        defer { defaults.remover() }
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(apresentador: apresentador, defaults: defaults.defaults, pasta: pasta.url)

        async let primeira: Void = fluxo.abrirRecente(url)
        async let segunda: Void = fluxo.abrirRecente(url)
        _ = await (primeira, segunda)

        #expect(apresentador.capturas.count == 1)
    }
}
