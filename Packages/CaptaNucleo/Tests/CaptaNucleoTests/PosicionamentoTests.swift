import CoreGraphics
import Testing

@testable import CaptaNucleo

@Suite("Posicionamento")
struct PosicionamentoTests {
    private let limites = CGRect(x: 0, y: 0, width: 200, height: 100)
    private let tamanho = CGSize(width: 40, height: 20)

    @Test func preferePerToDoPontoAbaixoEADireita() {
        let o = Posicionamento.origem(
            junto: CGPoint(x: 50, y: 30),
            tamanho: tamanho,
            dentro: limites,
            afastamento: 10
        )
        #expect(o == CGPoint(x: 60, y: 40))
    }

    @Test func trocaParaEsquerdaNaBordaDireita() {
        let o = Posicionamento.origem(
            junto: CGPoint(x: 180, y: 30),
            tamanho: tamanho,
            dentro: limites,
            afastamento: 10
        )
        #expect(o == CGPoint(x: 130, y: 40))
    }

    @Test func trocaParaCimaNaBordaInferior() {
        let o = Posicionamento.origem(
            junto: CGPoint(x: 50, y: 90),
            tamanho: tamanho,
            dentro: limites,
            afastamento: 10
        )
        #expect(o == CGPoint(x: 60, y: 60))
    }

    @Test func naoSaiDosLimitesComTamanhoMaiorQueOEspaco() {
        let grande = CGSize(width: 300, height: 150)
        let o = Posicionamento.origem(
            junto: CGPoint(x: 100, y: 50),
            tamanho: grande,
            dentro: limites,
            afastamento: 10
        )
        #expect(o == CGPoint(x: 0, y: 0))
    }

    @Test func respeitaLimitesComOrigemDiferenteDeZero() {
        let l = CGRect(x: 1000, y: 200, width: 200, height: 100)
        let o = Posicionamento.origem(
            junto: CGPoint(x: 1199, y: 299),
            tamanho: tamanho,
            dentro: l,
            afastamento: 10
        )
        #expect(o == CGPoint(x: 1149, y: 269))
        let fora = Posicionamento.origem(
            junto: CGPoint(x: -5000, y: -5000),
            tamanho: tamanho,
            dentro: l,
            afastamento: 10
        )
        #expect(fora == CGPoint(x: 1000, y: 200))
    }

    @Test func pontoNaoFinitoCaiNoCantoDosLimites() {
        let o = Posicionamento.origem(
            junto: CGPoint(x: CGFloat.nan, y: CGFloat.infinity),
            tamanho: tamanho,
            dentro: limites,
            afastamento: 10
        )
        #expect(limites.contains(o))
    }
}
