import AppKit
import CaptaNucleo
import CaptaSistema
import Foundation
import Testing

@testable import Capta

@Suite("Gerenciador de janelas: aguardar fechamentos", .serialized)
@MainActor
struct GerenciadorDeJanelasFechamentoTests {
    @Test func aguardarFechamentosSoVoltaDepoisDaGravacaoDaJanelaFechada() async throws {
        let gerenciador = GerenciadorDeJanelas()
        let portao = Portao()
        let gravador = GravadorDeDocumentoFalso(portao: portao)
        let imagem = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        let captura = CapturaAberta(
            nome: "Captura de teste",
            documento: try Documento.novo(de: imagem),
            base: imagem.imagem,
            escala: imagem.escala,
            rascunho: .gravado(URL(fileURLWithPath: "/rascunho.capta")),
            renderizador: Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF()),
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa(),
            salvamento: SalvamentoAutomatico(
                dormir: { _ in try await Task.sleep(for: .seconds(60)) },
                gravar: { documento, url in try await gravador.gravar(documento, url) }
            )
        )
        gerenciador.mostrarCaptura(captura)
        captura.aplicar(.definirRecorte(CGRect(x: 0, y: 0, width: 4, height: 3)))
        try #require(gerenciador.janelasDeCaptura.first).close()
        await portao.aguardarAlguemPreso()

        var terminou = false
        let espera = Task {
            await gerenciador.aguardarFechamentos()
            terminou = true
        }
        try await Task.sleep(for: .milliseconds(200))
        #expect(!terminou)

        await portao.abrir()
        await espera.value
        #expect(terminou)
        #expect(await gravador.concluidas.count == 1)
    }

    @Test func aguardarFechamentosSemJanelaFechandoVoltaNaHora() async {
        await GerenciadorDeJanelas().aguardarFechamentos()
    }
}
