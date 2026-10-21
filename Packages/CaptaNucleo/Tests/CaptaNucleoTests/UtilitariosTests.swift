import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

@Suite("Utilitários do renderizador")
struct UtilitariosTests {
    @Test func retanguloUtilDescartaSemAreaNaoFinitoEPadronizaNegativo() {
        #expect(retanguloUtil(CGRect(x: 1, y: 2, width: 0, height: 5)) == nil)
        #expect(retanguloUtil(CGRect(x: 1, y: 2, width: 5, height: 0)) == nil)
        #expect(retanguloUtil(CGRect(x: CGFloat.nan, y: 2, width: 5, height: 5)) == nil)
        #expect(retanguloUtil(CGRect(x: 1, y: CGFloat.infinity, width: 5, height: 5)) == nil)
        #expect(retanguloUtil(CGRect(x: 1, y: 2, width: CGFloat.infinity, height: 5)) == nil)
        #expect(retanguloUtil(CGRect(x: 1, y: 2, width: 5, height: CGFloat.nan)) == nil)
        #expect(
            retanguloUtil(CGRect(x: 50, y: 40, width: -20, height: -10))
                == CGRect(x: 30, y: 30, width: 20, height: 10)
        )
        #expect(
            retanguloUtil(CGRect(x: 1, y: 2, width: 3, height: 4))
                == CGRect(x: 1, y: 2, width: 3, height: 4)
        )
    }

    @Test func corDoModeloViraCGColorSRGBComOsMesmosComponentes() throws {
        let cor = cgCor(CorRGBA(r: 0.25, g: 0.5, b: 0.75, a: 0.5))
        #expect(cor.colorSpace?.name == CGColorSpace.sRGB)
        let c = try #require(cor.components)
        #expect(c.count == 4)
        #expect(abs(c[0] - 0.25) < 0.001 && abs(c[1] - 0.5) < 0.001)
        #expect(abs(c[2] - 0.75) < 0.001 && abs(c[3] - 0.5) < 0.001)
    }
}
