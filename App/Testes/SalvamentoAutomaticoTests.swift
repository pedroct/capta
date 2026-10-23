import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

@Suite("Salvamento automático")
@MainActor
struct SalvamentoAutomaticoTests {
    let relogio = RelogioFalso()
    let gravador = GravadorDeDocumentoFalso()
    let url = URL(fileURLWithPath: "/rascunho.capta")

    private func salvamento(
        _ gravador: GravadorDeDocumentoFalso? = nil,
        atraso: Duration = .seconds(2)
    ) -> SalvamentoAutomatico {
        let relogio = relogio
        let gravador = gravador ?? self.gravador
        return SalvamentoAutomatico(
            atraso: atraso,
            dormir: { try await relogio.dormir($0) },
            gravar: { try await gravador.gravar($0, $1) }
        )
    }

    private func documento(_ largura: CGFloat) throws -> Documento {
        try documentoComRecorte(largura: largura)
    }

    @Test func agendarVariasVezesGravaSoOUltimo() async throws {
        let salvamento = salvamento()
        let ultimo = try documento(4)

        salvamento.agendar(try documento(2), em: url)
        await relogio.aguardarEsperas(1)
        salvamento.agendar(try documento(3), em: url)
        salvamento.agendar(ultimo, em: url)
        #expect(salvamento.estado == .pendente)

        await relogio.aguardarEsperas(1)
        await relogio.avancar()
        await salvamento.salvarAgora()

        #expect(await gravador.concluidas == [ultimo])
        #expect(await gravador.urls == [url])
        #expect(salvamento.estado == .salvo)
    }

    @Test func esperaOAtrasoAntesDeGravar() async throws {
        let salvamento = salvamento(atraso: .seconds(5))

        salvamento.agendar(try documento(2), em: url)
        await relogio.aguardarEsperas(1)

        #expect(await relogio.pedidos.contains(.seconds(5)))
        #expect(await gravador.iniciadas.isEmpty)
        #expect(salvamento.estado == .pendente)

        await relogio.avancar()
        await gravador.aguardarInicio()
        await salvamento.salvarAgora()

        #expect(await gravador.concluidas.count == 1)
        #expect(salvamento.estado == .salvo)
    }

    @Test func salvarAgoraGravaOPendenteSemEsperar() async throws {
        let salvamento = salvamento()
        let doc = try documento(2)
        salvamento.agendar(doc, em: url)
        await relogio.aguardarEsperas(1)

        await salvamento.salvarAgora()

        #expect(await gravador.concluidas == [doc])
        #expect(salvamento.estado == .salvo)
        // A espera cancelada não grava de novo, nem se o relógio andar depois.
        await relogio.avancar()
        await salvamento.salvarAgora()
        #expect(await gravador.iniciadas.count == 1)
    }

    @Test func salvarAgoraSemNadaPendenteNaoGrava() async {
        let salvamento = salvamento()

        await salvamento.salvarAgora()

        #expect(await gravador.iniciadas.isEmpty)
        #expect(salvamento.estado == .salvo)
    }

    @Test func salvarAgoraEsperaAGravacaoEmCurso() async throws {
        let portao = Portao()
        let preso = GravadorDeDocumentoFalso(portao: portao)
        let salvamento = salvamento(preso)
        salvamento.agendar(try documento(2), em: url)
        await relogio.aguardarEsperas(1)
        await relogio.avancar()
        await preso.aguardarInicio()
        #expect(salvamento.estado == .salvando)

        var terminou = false
        let espera = Task { @MainActor in
            await salvamento.salvarAgora()
            terminou = true
        }
        for _ in 0..<200 { await Task.yield() }
        #expect(!terminou)

        await portao.abrir()
        await espera.value

        #expect(terminou)
        #expect(await preso.concluidas.count == 1)
        #expect(salvamento.estado == .salvo)
    }

    @Test func gravacoesNuncaSeSobrepoem() async throws {
        let portao = Portao()
        let preso = GravadorDeDocumentoFalso(portao: portao)
        let salvamento = salvamento(preso)
        let segundo = try documento(4)
        salvamento.agendar(try documento(2), em: url)
        await relogio.aguardarEsperas(1)
        await relogio.avancar()
        await preso.aguardarInicio()

        // Edição nova durante a gravação: a nova espera termina e a gravação segue na fila.
        salvamento.agendar(segundo, em: url)
        await relogio.aguardarEsperas(1)
        await relogio.avancar()
        for _ in 0..<200 { await Task.yield() }
        #expect(await preso.iniciadas.count == 1)

        await portao.abrir()
        await salvamento.salvarAgora()

        #expect(await preso.concluidas.last == segundo)
        #expect(await preso.concluidas.count == 2)
        #expect(await preso.maximoSimultaneo == 1)
    }

    @Test func falhaMudaOEstadoEOProximoAgendarTentaDeNovo() async throws {
        let falho = GravadorDeDocumentoFalso(falhar: true)
        let salvamento = salvamento(falho)
        salvamento.agendar(try documento(2), em: url)
        await relogio.aguardarEsperas(1)

        await salvamento.salvarAgora()
        #expect(salvamento.estado == .falhou)

        await falho.mudar(falhar: false)
        let novo = try documento(4)
        salvamento.agendar(novo, em: url)
        await salvamento.salvarAgora()

        #expect(await falho.concluidas == [novo])
        #expect(salvamento.estado == .salvo)
    }

    @Test func salvarAgoraDepoisDeFalhaTentaOMesmoDocumentoDeNovo() async throws {
        let falho = GravadorDeDocumentoFalso(falhar: true)
        let salvamento = salvamento(falho)
        let doc = try documento(2)
        salvamento.agendar(doc, em: url)
        await salvamento.salvarAgora()
        #expect(salvamento.estado == .falhou)

        await falho.mudar(falhar: false)
        await salvamento.salvarAgora()

        #expect(await falho.concluidas == [doc])
        #expect(salvamento.estado == .salvo)
    }
}
