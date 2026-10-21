import CoreGraphics
import Testing

@testable import CaptaNucleo

@Suite("Conversão entre pontos e pixels da tela")
struct ConversaoDeTelaTests {
    private let esquerda = DescricaoDeTela(
        id: 1,
        quadro: CGRect(x: -1440, y: 0, width: 1440, height: 900),
        escala: 2,
        principal: false
    )

    @Test func pixelLocalDePontoEmTelaComOrigemNegativa() {
        let local = esquerda.pixelLocal(dePonto: CGPoint(x: -1439.5, y: 10.25))
        #expect(local == CGPoint(x: 1, y: 20.5))
    }

    @Test(arguments: [1.0, 1.5, 2.0, 3.0])
    func quadroEmPontosEPixelsSaoInversosEmEscalasComunsDeTodoRetanguloInteiro(escala: Double) {
        let tela = DescricaoDeTela(
            id: 1,
            quadro: CGRect(x: -1440, y: -900, width: 1440, height: 900),
            escala: escala,
            principal: false
        )
        for x in 0...20 {
            for y in 0...20 {
                for largura in 1...20 {
                    for altura in 1...20 {
                        let r = CGRect(x: x, y: y, width: largura, height: altura)
                        #expect(tela.pixels(dePontos: tela.quadroEmPontos(dePixels: r)) == r)
                    }
                }
            }
        }
    }

    @Test func meioPontoArredondaParaOPixelMaisProximo() {
        let tela = DescricaoDeTela(
            id: 1,
            quadro: CGRect(x: 0, y: 0, width: 1440, height: 900),
            escala: 2,
            principal: true
        )
        let pixels = tela.pixels(dePontos: CGRect(x: 10.25, y: 10.25, width: 5, height: 5))
        #expect(pixels == CGRect(x: 20, y: 20, width: 10, height: 10))
    }

    @Test func pixelsSaoRelativosAOrigemDaTela() {
        let pixels = esquerda.pixels(dePontos: CGRect(x: -1430, y: 5, width: 10, height: 10))
        #expect(pixels == CGRect(x: 20, y: 10, width: 20, height: 20))
    }

    @Test func limitesEmPixelsDevolveNilParaQuadroInvalido() throws {
        let limites = try #require(esquerda.limitesEmPixels)
        #expect(limites == CGSize(width: 2880, height: 1800))
        let invalida = DescricaoDeTela(
            id: 2,
            quadro: CGRect(x: 0, y: 0, width: 0, height: 900),
            escala: 2,
            principal: false
        )
        #expect(invalida.limitesEmPixels == nil)
    }
}
