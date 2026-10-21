import CoreGraphics
import Testing

@testable import CaptaNucleo

@Suite("Seleção de região em pixels")
struct SelecaoDeRegiaoTests {
    private let limites = CGSize(width: 100, height: 80)

    private func arrasto(_ de: CGPoint, _ ate: CGPoint) -> SelecaoDeRegiao? {
        SelecaoDeRegiao.arrasto(telaId: 7, limites: limites, de: de, ate: ate)
    }

    private func selecao(
        _ x: CGFloat,
        _ y: CGFloat,
        _ l: CGFloat,
        _ a: CGFloat
    ) throws -> SelecaoDeRegiao {
        // Obtida por arrasto para que a invariante valha também nos testes.
        try #require(
            SelecaoDeRegiao.arrasto(
                telaId: 7,
                limites: limites,
                de: CGPoint(x: x, y: y),
                ate: CGPoint(x: x + l, y: y + a)
            )
        )
    }

    @Test func arrastoEmQualquerDirecaoDaOMesmoRetangulo() throws {
        let esperado = CGRect(x: 10, y: 10, width: 20, height: 10)
        #expect(arrasto(CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 20))?.pixels == esperado)
        #expect(arrasto(CGPoint(x: 30, y: 20), CGPoint(x: 10, y: 10))?.pixels == esperado)
        #expect(arrasto(CGPoint(x: 30, y: 10), CGPoint(x: 10, y: 20))?.pixels == esperado)
        #expect(arrasto(CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 10))?.pixels == esperado)
    }

    @Test func arrastoGuardaTelaELimites() throws {
        let resultado = arrasto(CGPoint(x: 1, y: 1), CGPoint(x: 5, y: 5))
        #expect(resultado?.telaId == 7)
        #expect(resultado?.limites == limites)
    }

    @Test func arrastoComPontoFracionarioUsaFloor() throws {
        let resultado = arrasto(CGPoint(x: 10.9, y: 10.9), CGPoint(x: 30.2, y: 20.7))
        #expect(resultado?.pixels == CGRect(x: 10, y: 10, width: 20, height: 10))
    }

    @Test func arrastoSaindoDaTelaFicaPresoNasBordas() throws {
        #expect(
            arrasto(CGPoint(x: 90, y: 70), CGPoint(x: 150, y: 200))?.pixels
                == CGRect(x: 90, y: 70, width: 10, height: 10)
        )
        #expect(
            arrasto(CGPoint(x: -5, y: -5), CGPoint(x: 10, y: 10))?.pixels
                == CGRect(x: 0, y: 0, width: 10, height: 10)
        )
    }

    @Test func arrastoSemAreaDevolveNil() throws {
        #expect(arrasto(CGPoint(x: 10, y: 10), CGPoint(x: 10, y: 30)) == nil)
        #expect(arrasto(CGPoint(x: 10, y: 10), CGPoint(x: 10, y: 10)) == nil)
        #expect(arrasto(CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 10)) == nil)
        #expect(arrasto(CGPoint(x: 200, y: 10), CGPoint(x: 300, y: 30)) == nil)
    }

    @Test func arrastoComPontoNaoFinitoFicaNosLimites() throws {
        let resultado = arrasto(
            CGPoint(x: CGFloat.nan, y: -CGFloat.infinity),
            CGPoint(x: CGFloat.infinity, y: 5)
        )
        #expect(resultado?.pixels == CGRect(x: 0, y: 0, width: 100, height: 5))
    }

    @Test func telaInteiraCobreTodaATela() throws {
        let inteira = SelecaoDeRegiao.telaInteira(telaId: 7, limites: limites)
        #expect(inteira.pixels == CGRect(x: 0, y: 0, width: 100, height: 80))
        #expect(inteira.telaId == 7)
        #expect(inteira.limites == limites)
    }

    @Test func telaInteiraDeLimitesDegeneradosTemLadoUm() throws {
        let inteira = SelecaoDeRegiao.telaInteira(telaId: 1, limites: .zero)
        #expect(inteira.pixels == CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    @Test func movidaFicaPresaNaTela() throws {
        let movida = try selecao(10, 10, 20, 20).movida(dx: -50, dy: 100)
        #expect(movida.pixels == CGRect(x: 0, y: 60, width: 20, height: 20))
        let outra = try selecao(10, 10, 20, 20).movida(dx: 500, dy: -500)
        #expect(outra.pixels == CGRect(x: 80, y: 0, width: 20, height: 20))
    }

    @Test func movidaDentroDaTelaSomaODeslocamento() throws {
        let movida = try selecao(10, 10, 20, 20).movida(dx: 5, dy: 3)
        #expect(movida.pixels == CGRect(x: 15, y: 13, width: 20, height: 20))
    }

    @Test func redimensionarMantemAOutraBordaFixa() throws {
        let nova = try selecao(10, 10, 20, 20).redimensionada(
            alca: .direita,
            para: CGPoint(x: 40.4, y: 0)
        )
        #expect(nova.pixels == CGRect(x: 10, y: 10, width: 30, height: 20))
    }

    @Test func redimensionarAlemDaBordaOpostaInverte() throws {
        let base = try selecao(10, 10, 20, 20)
        #expect(
            base.redimensionada(alca: .direita, para: CGPoint(x: 5, y: 0)).pixels
                == CGRect(x: 5, y: 10, width: 5, height: 20)
        )
        #expect(
            base.redimensionada(alca: .cantoSuperiorEsquerdo, para: CGPoint(x: 35, y: 35)).pixels
                == CGRect(x: 30, y: 30, width: 5, height: 5)
        )
    }

    @Test func redimensionarNuncaDaLadoMenorQueUm() throws {
        let base = try selecao(10, 10, 20, 20)
        #expect(base.redimensionada(alca: .direita, para: CGPoint(x: 10, y: 0)).pixels.width == 1)
        #expect(base.redimensionada(alca: .esquerda, para: CGPoint(x: 30, y: 0)).pixels.width == 1)
        #expect(base.redimensionada(alca: .baixo, para: CGPoint(x: 0, y: 10)).pixels.height == 1)
        #expect(base.redimensionada(alca: .cima, para: CGPoint(x: 0, y: 30)).pixels.height == 1)
    }

    @Test func ladoMinimoNaBordaDaTelaCresceParaOLadoLivre() throws {
        let base = try selecao(80, 60, 20, 20)
        let nova = base.redimensionada(alca: .esquerda, para: CGPoint(x: 100, y: 0))
        #expect(nova.pixels == CGRect(x: 99, y: 60, width: 1, height: 20))
        let abaixo = base.redimensionada(alca: .cima, para: CGPoint(x: 0, y: 80))
        #expect(abaixo.pixels == CGRect(x: 80, y: 79, width: 20, height: 1))
    }

    @Test func redimensionarForaDaTelaFicaPresoNaTela() throws {
        let base = try selecao(10, 10, 20, 20)
        #expect(
            base.redimensionada(alca: .cantoInferiorDireito, para: CGPoint(x: 500, y: 500)).pixels
                == CGRect(x: 10, y: 10, width: 90, height: 70)
        )
        #expect(
            base.redimensionada(alca: .cantoSuperiorEsquerdo, para: CGPoint(x: -9, y: -9)).pixels
                == CGRect(x: 0, y: 0, width: 30, height: 30)
        )
    }

    @Test func cadaAlcaMoveSomenteAsSuasBordas() throws {
        let base = try selecao(10, 10, 20, 20)
        let alvo = CGPoint(x: 50, y: 60)
        #expect(
            base.redimensionada(alca: .cima, para: alvo).pixels
                == CGRect(x: 10, y: 30, width: 20, height: 30)
        )
        #expect(
            base.redimensionada(alca: .baixo, para: alvo).pixels
                == CGRect(x: 10, y: 10, width: 20, height: 50)
        )
        #expect(
            base.redimensionada(alca: .esquerda, para: alvo).pixels
                == CGRect(x: 30, y: 10, width: 20, height: 20)
        )
        #expect(
            base.redimensionada(alca: .cantoSuperiorDireito, para: alvo).pixels
                == CGRect(x: 10, y: 30, width: 40, height: 30)
        )
        #expect(
            base.redimensionada(alca: .cantoInferiorEsquerdo, para: alvo).pixels
                == CGRect(x: 30, y: 10, width: 20, height: 50)
        )
        #expect(
            base.redimensionada(alca: .cantoInferiorDireito, para: alvo).pixels
                == CGRect(x: 10, y: 10, width: 40, height: 50)
        )
    }

    @Test func acertoPrefereCantoDepoisBordaDepoisDentro() throws {
        let base = try selecao(10, 10, 20, 20)
        func acerto(_ x: CGFloat, _ y: CGFloat) -> Acerto {
            base.acerto(em: CGPoint(x: x, y: y), tolerancia: 3)
        }
        #expect(acerto(10, 10) == .borda(.cantoSuperiorEsquerdo))
        #expect(acerto(10, 20) == .borda(.esquerda))
        #expect(acerto(12, 12) == .borda(.cantoSuperiorEsquerdo))
        #expect(acerto(20, 20) == .dentro)
        #expect(acerto(50, 50) == .fora)
    }

    @Test func acertoReconheceTodasAsAlcas() throws {
        let base = try selecao(10, 10, 20, 20)
        func acerto(_ x: CGFloat, _ y: CGFloat) -> Acerto {
            base.acerto(em: CGPoint(x: x, y: y), tolerancia: 3)
        }
        #expect(acerto(30, 10) == .borda(.cantoSuperiorDireito))
        #expect(acerto(10, 30) == .borda(.cantoInferiorEsquerdo))
        #expect(acerto(30, 30) == .borda(.cantoInferiorDireito))
        #expect(acerto(20, 9) == .borda(.cima))
        #expect(acerto(20, 31) == .borda(.baixo))
        #expect(acerto(31, 20) == .borda(.direita))
        #expect(acerto(8, 20) == .borda(.esquerda))
    }

    @Test func acertoEmSelecaoEstreitaEscolheABordaMaisProxima() throws {
        let fina = try selecao(10, 10, 2, 40)
        #expect(fina.acerto(em: CGPoint(x: 10.2, y: 30), tolerancia: 3) == .borda(.esquerda))
        #expect(fina.acerto(em: CGPoint(x: 11.8, y: 30), tolerancia: 3) == .borda(.direita))
        let achatada = try selecao(10, 10, 40, 2)
        #expect(achatada.acerto(em: CGPoint(x: 30, y: 10.2), tolerancia: 3) == .borda(.cima))
        #expect(achatada.acerto(em: CGPoint(x: 30, y: 11.8), tolerancia: 3) == .borda(.baixo))
    }
}
