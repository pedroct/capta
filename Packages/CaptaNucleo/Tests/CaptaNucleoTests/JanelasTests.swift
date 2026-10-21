import CoreGraphics
import Testing

@testable import CaptaNucleo

@Suite("Janelas selecionáveis")
struct JanelasTests {
    private func janela(
        _ id: UInt32,
        _ quadro: CGRect,
        camada: Int = 0,
        naTela: Bool = true
    ) -> JanelaDeTela {
        JanelaDeTela(id: id, quadro: quadro, camada: camada, naTela: naTela)
    }

    private func tela(_ id: UInt32, _ quadro: CGRect) -> DescricaoDeTela {
        DescricaoDeTela(id: id, quadro: quadro, escala: 2, principal: id == 1)
    }

    private let quadroGrande = CGRect(x: 0, y: 0, width: 300, height: 200)

    @Test func selecionaveisDescartaCamadaDeSistemaForaDaTelaEPequenas() {
        let janelas = [
            janela(1, quadroGrande),
            janela(2, quadroGrande, camada: 25),
            janela(3, quadroGrande, naTela: false),
            janela(4, CGRect(x: 0, y: 0, width: 30, height: 500)),
            janela(5, CGRect(x: 0, y: 0, width: 500, height: 30)),
        ]
        let resultado = ListaDeJanelas.selecionaveis(janelas, tamanhoMinimo: 40)
        #expect(resultado == [janelas[0]])
    }

    @Test func selecionaveisMantemJanelaNoTamanhoMinimoExato() {
        let janelas = [janela(1, CGRect(x: 0, y: 0, width: 40, height: 40))]
        #expect(ListaDeJanelas.selecionaveis(janelas, tamanhoMinimo: 40) == janelas)
    }

    @Test func selecionaveisPreservaAOrdemDeEmpilhamento() {
        let janelas = [
            janela(9, quadroGrande),
            janela(3, quadroGrande),
            janela(7, quadroGrande),
        ]
        let resultado = ListaDeJanelas.selecionaveis(janelas, tamanhoMinimo: 40)
        #expect(resultado.map(\.id) == [9, 3, 7])
    }

    @Test func sobDevolveAJanelaMaisAFrenteEmSobreposicao() {
        let frente = janela(1, CGRect(x: 0, y: 0, width: 100, height: 100))
        let fundo = janela(2, CGRect(x: 50, y: 50, width: 100, height: 100))
        let janelas = [frente, fundo]
        #expect(ListaDeJanelas.sob(CGPoint(x: 70, y: 70), em: janelas) == frente)
        #expect(ListaDeJanelas.sob(CGPoint(x: 140, y: 140), em: janelas) == fundo)
    }

    @Test func sobSemJanelaDevolveNil() {
        let janelas = [janela(1, CGRect(x: 0, y: 0, width: 100, height: 100))]
        #expect(ListaDeJanelas.sob(CGPoint(x: 500, y: 500), em: janelas) == nil)
        #expect(ListaDeJanelas.sob(CGPoint(x: 5, y: 5), em: []) == nil)
    }

    @Test func sobComPontoNaoFinitoDevolveNil() {
        let janelas = [janela(1, CGRect(x: 0, y: 0, width: 100, height: 100))]
        #expect(ListaDeJanelas.sob(CGPoint(x: CGFloat.nan, y: 5), em: janelas) == nil)
        #expect(ListaDeJanelas.sob(CGPoint(x: 5, y: CGFloat.infinity), em: janelas) == nil)
    }

    @Test func sobNaBordaDireitaNaoContem() {
        let alvo = janela(1, CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(ListaDeJanelas.sob(CGPoint(x: 100, y: 50), em: [alvo]) == nil)
        #expect(ListaDeJanelas.sob(CGPoint(x: 50, y: 100), em: [alvo]) == nil)
        #expect(ListaDeJanelas.sob(CGPoint(x: 0, y: 0), em: [alvo]) == alvo)
        #expect(ListaDeJanelas.sob(CGPoint(x: 99.9, y: 99.9), em: [alvo]) == alvo)
    }

    @Test func telaDaJanelaEscolheAMaiorInterseccao() {
        let a = tela(1, CGRect(x: 0, y: 0, width: 1000, height: 800))
        let b = tela(2, CGRect(x: 1000, y: 0, width: 1000, height: 800))
        let alvo = janela(1, CGRect(x: 700, y: 100, width: 1000, height: 300))
        #expect(ListaDeJanelas.tela(de: alvo, entre: [a, b]) == b)
    }

    @Test func empateUsaACantoSuperiorEsquerdo() {
        let a = tela(1, CGRect(x: 0, y: 0, width: 1000, height: 800))
        let b = tela(2, CGRect(x: 1000, y: 0, width: 1000, height: 800))
        let alvo = janela(1, CGRect(x: 900, y: 100, width: 200, height: 300))
        #expect(ListaDeJanelas.tela(de: alvo, entre: [b, a]) == a)
        let alvoDireita = janela(2, CGRect(x: 1000 - 100, y: 100, width: 200, height: 300))
        #expect(ListaDeJanelas.tela(de: alvoDireita, entre: [a, b]) == a)
    }

    @Test func empateSemTelaNoCantoUsaAPrimeiraDaLista() {
        // O canto superior esquerdo (y = -50) fica acima das duas telas.
        let a = tela(1, CGRect(x: 0, y: 0, width: 1000, height: 800))
        let b = tela(2, CGRect(x: 1000, y: 0, width: 1000, height: 800))
        let alvo = janela(1, CGRect(x: 900, y: -50, width: 200, height: 100))
        #expect(ListaDeJanelas.tela(de: alvo, entre: [b, a]) == b)
    }

    @Test func janelaForaDeTodasDevolveNil() {
        let a = tela(1, CGRect(x: 0, y: 0, width: 1000, height: 800))
        let longe = janela(1, CGRect(x: 5000, y: 5000, width: 100, height: 100))
        #expect(ListaDeJanelas.tela(de: longe, entre: [a]) == nil)
        #expect(ListaDeJanelas.tela(de: longe, entre: []) == nil)
        // Encostar na borda não é interseção.
        let vizinha = janela(2, CGRect(x: 1000, y: 0, width: 100, height: 100))
        #expect(ListaDeJanelas.tela(de: vizinha, entre: [a]) == nil)
    }

    @Test func telaComOrigemNegativa() {
        let principal = tela(1, CGRect(x: 0, y: 0, width: 1440, height: 900))
        let acima = tela(2, CGRect(x: -200, y: -1080, width: 1920, height: 1080))
        let alvo = janela(1, CGRect(x: 100, y: -800, width: 400, height: 300))
        #expect(ListaDeJanelas.tela(de: alvo, entre: [principal, acima]) == acima)
    }

    @Test func janelaComQuadroNaoFinitoNaoTemTela() {
        let a = tela(1, CGRect(x: 0, y: 0, width: 1000, height: 800))
        let ruim = janela(1, CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100))
        #expect(ListaDeJanelas.tela(de: ruim, entre: [a]) == nil)
    }
}
