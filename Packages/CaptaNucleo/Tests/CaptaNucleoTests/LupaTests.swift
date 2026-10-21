import CoreGraphics
import Testing

@testable import CaptaNucleo

@Suite("Lupa")
struct LupaTests {
    private let imagem = CGSize(width: 100, height: 100)

    @Test func amostraNoMeioFicaCentrada() {
        let r = Lupa.amostra(em: CGPoint(x: 50, y: 50), lado: 15, imagem: imagem)
        #expect(r == CGRect(x: 43, y: 43, width: 15, height: 15))
    }

    @Test func amostraNosQuatroCantosFicaDentro() {
        let casos: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0)),
            (CGPoint(x: 99, y: 99), CGPoint(x: 85, y: 85)),
            (CGPoint(x: 0, y: 99), CGPoint(x: 0, y: 85)),
            (CGPoint(x: 99, y: 0), CGPoint(x: 85, y: 0)),
        ]
        for (centro, origem) in casos {
            let r = Lupa.amostra(em: centro, lado: 15, imagem: imagem)
            #expect(r == CGRect(origin: origem, size: CGSize(width: 15, height: 15)))
        }
    }

    @Test func imagemMenorQueOLadoDevolveAImagemInteira() {
        let r = Lupa.amostra(
            em: CGPoint(x: 5, y: 5),
            lado: 15,
            imagem: CGSize(width: 10, height: 10)
        )
        #expect(r == CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    @Test func centroFracionarioUsaOPisoELadoParTemOCentroNaMetade() {
        let r = Lupa.amostra(em: CGPoint(x: 50.9, y: 50.2), lado: 16, imagem: imagem)
        #expect(r == CGRect(x: 42, y: 42, width: 16, height: 16))
    }

    @Test func entradasInvalidasNaoQuebram() {
        let nan = Lupa.amostra(
            em: CGPoint(x: CGFloat.nan, y: CGFloat.infinity),
            lado: 15,
            imagem: imagem
        )
        #expect(CGRect(origin: .zero, size: imagem).contains(nan))
        #expect(Lupa.amostra(em: .zero, lado: 0, imagem: imagem) == .zero)
        #expect(Lupa.amostra(em: .zero, lado: 5, imagem: .zero) == .zero)
        let fora = Lupa.amostra(em: CGPoint(x: -500, y: 900), lado: 15, imagem: imagem)
        #expect(fora == CGRect(x: 0, y: 85, width: 15, height: 15))
    }
}
