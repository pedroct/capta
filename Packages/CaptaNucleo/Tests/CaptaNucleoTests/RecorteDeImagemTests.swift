import CoreGraphics
import Testing

@testable import CaptaNucleo

@Suite("Recorte da imagem congelada")
struct RecorteDeImagemTests {
    private let base = imagemXadrez(CGSize(width: 100, height: 100), quadrado: 2)

    @Test func recorteTemOTamanhoPedidoEPixelCorrespondente() throws {
        let recorte = try #require(
            RecorteDeImagem.recortar(base, pixels: CGRect(x: 10, y: 10, width: 30, height: 20))
        )
        #expect(recorte.width == 30)
        #expect(recorte.height == 20)
        for (dx, dy) in [(0, 0), (1, 0), (2, 2), (29, 19)] {
            let a = pixel(recorte, x: dx, y: dy)
            let b = pixel(base, x: 10 + dx, y: 10 + dy)
            #expect(a.r == b.r && a.g == b.g && a.b == b.b)
        }
    }

    @Test func recorteForaOuVazioDevolveNil() {
        #expect(
            RecorteDeImagem.recortar(base, pixels: CGRect(x: 200, y: 200, width: 5, height: 5))
                == nil
        )
        #expect(
            RecorteDeImagem.recortar(base, pixels: CGRect(x: 10, y: 10, width: 0, height: 5)) == nil
        )
        #expect(RecorteDeImagem.recortar(base, pixels: .zero) == nil)
        #expect(
            RecorteDeImagem.recortar(
                base,
                pixels: CGRect(x: CGFloat.nan, y: 0, width: 5, height: 5)
            )
                == nil
        )
    }

    @Test func recorteParcialmenteForaDevolveNil() {
        #expect(
            RecorteDeImagem.recortar(base, pixels: CGRect(x: 90, y: 90, width: 20, height: 20))
                == nil
        )
        #expect(
            RecorteDeImagem.recortar(base, pixels: CGRect(x: -1, y: 0, width: 10, height: 10))
                == nil
        )
    }

    @Test func recorteDaImagemInteiraFunciona() {
        let r = RecorteDeImagem.recortar(base, pixels: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(r?.width == 100 && r?.height == 100)
    }
}
