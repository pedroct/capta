import AppKit
import CaptaNucleo
import CaptaSistema
import Foundation
import Testing

@testable import Capta

@Suite("Gerenciador de janelas: trazer para a frente", .serialized)
@MainActor
struct GerenciadorDeJanelasTrazerTests {
    private func captura(rascunho: CapturaAberta.EstadoRascunho) throws -> CapturaAberta {
        let imagem = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        return CapturaAberta(
            nome: "Captura de teste",
            documento: try Documento.novo(de: imagem),
            base: imagem.imagem,
            escala: imagem.escala,
            rascunho: rascunho,
            renderizador: Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF()),
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa()
        )
    }

    private func fecharTudo(_ gerenciador: GerenciadorDeJanelas) {
        for janela in gerenciador.janelasDeCaptura { janela.close() }
    }

    @Test func trazerParaFrenteReconheceAJanelaDoPacoteAberto() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        gerenciador.mostrarCaptura(
            try captura(rascunho: .gravado(URL(fileURLWithPath: "/rascunho.capta")))
        )
        gerenciador.mostrarCaptura(try captura(rascunho: .gravando))
        let janela = try #require(gerenciador.janelasDeCaptura.first)
        janela.miniaturize(nil)

        let trouxe = gerenciador.trazerParaFrente(URL(fileURLWithPath: "/rascunho.capta"))

        #expect(trouxe)
        #expect(!janela.isMiniaturized)
        #expect(gerenciador.janelasDeCaptura.count == 2)
    }

    @Test func trazerParaFrenteIgnoraPacoteSemJanela() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        // Rascunho ainda gravando: não tem endereço para casar.
        gerenciador.mostrarCaptura(try captura(rascunho: .gravando))
        gerenciador.mostrarCaptura(
            try captura(rascunho: .gravado(URL(fileURLWithPath: "/rascunho.capta")))
        )

        #expect(!gerenciador.trazerParaFrente(URL(fileURLWithPath: "/outro.capta")))
        #expect(gerenciador.janelasDeCaptura.count == 2)
    }

    @Test func trazerParaFrenteDepoisDeFecharAJanelaNaoReconhece() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        gerenciador.mostrarCaptura(
            try captura(rascunho: .gravado(URL(fileURLWithPath: "/rascunho.capta")))
        )
        try #require(gerenciador.janelasDeCaptura.first).close()

        #expect(!gerenciador.trazerParaFrente(URL(fileURLWithPath: "/rascunho.capta")))
    }
}
