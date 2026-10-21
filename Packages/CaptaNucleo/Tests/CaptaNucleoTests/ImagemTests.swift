import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import CaptaNucleo

@Suite("Imagem: PNG e miniatura")
struct ImagemTests {
    private let vermelho = CorRGBA(r: 1, g: 0, b: 0, a: 1)

    @Test func pngFazIdaEVoltaComOMesmoTamanhoEPixels() throws {
        let original = imagemXadrez(CGSize(width: 8, height: 6))
        let dados = try CodificadorPNG.codificar(original, escala: 1)
        let fonte = try #require(CGImageSourceCreateWithData(dados as CFData, nil))
        let volta = try #require(CGImageSourceCreateImageAtIndex(fonte, 0, nil))
        #expect(volta.width == 8)
        #expect(volta.height == 6)
        #expect(todosOsPixels(volta) == todosOsPixels(original))
    }

    @Test func pngGravaDpiConformeAEscala() throws {
        let dados = try CodificadorPNG.codificar(
            imagemSolida(CGSize(width: 4, height: 4), cor: vermelho),
            escala: 2
        )
        let fonte = try #require(CGImageSourceCreateWithData(dados as CFData, nil))
        let props = try #require(
            CGImageSourceCopyPropertiesAtIndex(fonte, 0, nil) as? [CFString: Any]
        )
        let largura = try #require(props[kCGImagePropertyDPIWidth] as? Double)
        let altura = try #require(props[kCGImagePropertyDPIHeight] as? Double)
        #expect(abs(largura - 144) < 0.5)
        #expect(abs(altura - 144) < 0.5)
    }

    @Test(arguments: [0, -1, Double.nan, Double.infinity])
    func escalaInvalidaLanca(escala: Double) {
        let imagem = imagemSolida(CGSize(width: 2, height: 2), cor: vermelho)
        #expect(throws: ErroImagem.escalaInvalida) {
            try CodificadorPNG.codificar(imagem, escala: escala)
        }
    }

    @Test func miniaturaReduzMantendoProporcao() throws {
        let m = try Miniatura.gerar(
            de: imagemSolida(CGSize(width: 2000, height: 1000), cor: vermelho)
        )
        #expect(m.width == 512)
        #expect(m.height == 256)
        #expect(proximos(pixel(m, x: 10, y: 10), 255, 0, 0))
    }

    @Test func miniaturaNaoAmpliaImagemPequena() throws {
        let m = try Miniatura.gerar(de: imagemSolida(CGSize(width: 100, height: 50), cor: vermelho))
        #expect(m.width == 100)
        #expect(m.height == 50)
    }

    @Test func miniaturaDeUmPixelFunciona() throws {
        let m = try Miniatura.gerar(de: imagemSolida(CGSize(width: 1, height: 1), cor: vermelho))
        #expect(m.width == 1)
        #expect(m.height == 1)
    }

    @Test func miniaturaMuitoLargaNaoViraZeroPixel() throws {
        let m = try Miniatura.gerar(de: imagemSolida(CGSize(width: 4000, height: 1), cor: vermelho))
        #expect(m.width == 512)
        #expect(m.height == 1)
    }
}
