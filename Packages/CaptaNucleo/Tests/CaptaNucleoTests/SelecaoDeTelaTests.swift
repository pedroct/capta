import CoreGraphics
import Testing

@testable import CaptaNucleo

@Suite("Seleção da tela sob o cursor")
struct SelecaoDeTelaTests {
    private let principal = DescricaoDeTela(
        id: 1,
        quadro: CGRect(x: 0, y: 0, width: 1440, height: 900),
        escala: 2,
        principal: true
    )

    private func tela(_ id: UInt32, _ quadro: CGRect, escala: Double = 1) -> DescricaoDeTela {
        DescricaoDeTela(id: id, quadro: quadro, escala: escala, principal: false)
    }

    @Test func escolheATelaQueContemOPonto() {
        let direita = tela(2, CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        let telas = [principal, direita]
        #expect(SelecaoDeTela.escolher(entre: telas, sob: CGPoint(x: 2000, y: 500)) == direita)
        #expect(SelecaoDeTela.escolher(entre: telas, sob: CGPoint(x: 700, y: 450)) == principal)
    }

    @Test func telaAcimaDaPrincipalTemCoordenadasNegativas() {
        let acima = tela(2, CGRect(x: 0, y: -1080, width: 1920, height: 1080))
        let escolhida = SelecaoDeTela.escolher(
            entre: [principal, acima],
            sob: CGPoint(x: 100, y: -10)
        )
        #expect(escolhida == acima)
    }

    @Test func telaAEsquerdaTemXNegativo() {
        let esquerda = tela(2, CGRect(x: -1920, y: -100, width: 1920, height: 1080))
        let escolhida = SelecaoDeTela.escolher(
            entre: [principal, esquerda],
            sob: CGPoint(x: -1, y: 0)
        )
        #expect(escolhida == esquerda)
    }

    @Test func divisaPertenceAProximaTela() {
        let direita = tela(2, CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        let abaixo = tela(3, CGRect(x: 0, y: 900, width: 1440, height: 900))
        let telas = [principal, direita, abaixo]
        #expect(SelecaoDeTela.escolher(entre: telas, sob: CGPoint(x: 1440, y: 10)) == direita)
        #expect(SelecaoDeTela.escolher(entre: telas, sob: CGPoint(x: 10, y: 900)) == abaixo)
        // A borda esquerda e a superior são da própria tela.
        #expect(SelecaoDeTela.escolher(entre: telas, sob: CGPoint(x: 0, y: 0)) == principal)
    }

    @Test func pontoForaDeTodasAsTelasUsaAPrincipal() {
        let direita = tela(2, CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        // A principal fora da primeira posição: o padrão é pela marca, não pela ordem.
        let telas = [direita, principal]
        #expect(SelecaoDeTela.escolher(entre: telas, sob: CGPoint(x: 5000, y: 5000)) == principal)
        // Borda inferior da tela da direita é exclusiva: o ponto fica fora de todas.
        #expect(SelecaoDeTela.escolher(entre: telas, sob: CGPoint(x: 1440, y: 1080)) == principal)
    }

    @Test(arguments: [
        CGPoint(x: Double.nan, y: 10),
        CGPoint(x: 10, y: Double.infinity),
        CGPoint(x: -Double.infinity, y: Double.nan),
    ])
    func pontoNaoFinitoUsaAPrincipal(ponto: CGPoint) {
        let direita = tela(2, CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        #expect(SelecaoDeTela.escolher(entre: [direita, principal], sob: ponto) == principal)
    }

    @Test func semTelasDevolveNil() {
        #expect(SelecaoDeTela.escolher(entre: [], sob: CGPoint(x: 10, y: 10)) == nil)
    }

    @Test func semPrincipalMarcadaPontoForaDevolveAPrimeira() {
        let unica = tela(2, CGRect(x: 0, y: 0, width: 800, height: 600))
        #expect(SelecaoDeTela.escolher(entre: [unica], sob: CGPoint(x: -50, y: -50)) == unica)
    }

    @Test func tamanhoEmPixelsMultiplicaOQuadroPelaEscala() throws {
        let tamanho = try #require(principal.tamanhoEmPixels)
        #expect(tamanho.largura == 2880 && tamanho.altura == 1800)
        let fracionaria = tela(2, CGRect(x: 0, y: 0, width: 1365, height: 767), escala: 1.5)
        let arredondado = try #require(fracionaria.tamanhoEmPixels)
        #expect(arredondado.largura == 2048 && arredondado.altura == 1151)
    }

    @Test(
        arguments: [
            (CGRect(x: 0, y: 0, width: 1440, height: 900), Double.nan),
            (CGRect(x: 0, y: 0, width: 1440, height: 900), Double.infinity),
            (CGRect(x: 0, y: 0, width: 1440, height: 900), 0),
            (CGRect(x: 0, y: 0, width: 1440, height: 900), -2),
            (CGRect(x: 0, y: 0, width: 0, height: 900), 2),
            (CGRect(x: 0, y: 0, width: 1440, height: 0.1), 2),
            (CGRect(x: 0, y: 0, width: 1e300, height: 900), 2),
        ] as [(CGRect, Double)]
    )
    func tamanhoEmPixelsInvalidoDevolveNil(quadro: CGRect, escala: Double) {
        #expect(tela(2, quadro, escala: escala).tamanhoEmPixels == nil)
    }
}
