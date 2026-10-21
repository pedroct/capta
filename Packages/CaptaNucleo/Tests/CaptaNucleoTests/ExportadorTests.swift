import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import CaptaNucleo

private func documento(recorte: CGRect? = nil, escala: Double = 1) -> Documento {
    Documento(
        versaoEsquema: Esquema.versaoAtual,
        tamanhoBase: CGSize(width: 40, height: 30),
        escala: escala,
        recorte: recorte,
        objetos: []
    )
}

private func decodificar(_ dados: Data) throws -> (CGImage, [CFString: Any]) {
    let fonte = try #require(CGImageSourceCreateWithData(dados as CFData, nil))
    let imagem = try #require(CGImageSourceCreateImageAtIndex(fonte, 0, nil))
    let props = try #require(CGImageSourceCopyPropertiesAtIndex(fonte, 0, nil) as? [CFString: Any])
    return (imagem, props)
}

@Suite("Exportador")
struct ExportadorTests {
    let base = imagemSolida(CGSize(width: 40, height: 30), cor: CorRGBA(r: 1, g: 0, b: 0, a: 1))

    @Test func exportadorSemAnotacaoDevolvePngDoTamanhoDaBase() throws {
        let dados = try Exportador.png(documento(), base: base, renderizador: Renderizador())
        let (imagem, _) = try decodificar(dados)
        #expect(imagem.width == 40)
        #expect(imagem.height == 30)
        #expect(proximos(pixel(imagem, x: 5, y: 5), 255, 0, 0))
    }

    @Test func exportadorRespeitaORecorte() throws {
        let recorte = CGRect(x: 4, y: 3, width: 20, height: 10)
        let dados = try Exportador.png(
            documento(recorte: recorte),
            base: base,
            renderizador: Renderizador()
        )
        let (imagem, _) = try decodificar(dados)
        #expect(imagem.width == 20)
        #expect(imagem.height == 10)
    }

    @Test func exportadorGravaDpiDaEscala() throws {
        let dados = try Exportador.png(
            documento(escala: 2),
            base: base,
            renderizador: Renderizador()
        )
        let (_, props) = try decodificar(dados)
        let dpi = try #require(props[kCGImagePropertyDPIWidth] as? Double)
        #expect(abs(dpi - 144) < 0.5)
    }
}

@Test func combinacaoPadraoEControleOpcaoF() {
    let combinacao = CombinacaoDeTeclas.capturarTelaInteira
    #expect(combinacao.codigoDaTecla == 3)
    #expect(combinacao.modificadores == [.controle, .opcao])
    #expect(!combinacao.modificadores.contains(.comando))
    #expect(!combinacao.modificadores.contains(.shift))
}
