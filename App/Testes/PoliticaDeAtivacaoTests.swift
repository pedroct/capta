import AppKit
import Testing

@testable import Capta

@Suite("Política de ativação do app")
struct PoliticaDeAtivacaoTests {
    @Test func semJanelasVoltaParaAccessory() {
        #expect(PoliticaDeAtivacao.para(janelasAbertas: 0) == .accessory)
    }

    @Test func comJanelasUsaRegular() {
        #expect(PoliticaDeAtivacao.para(janelasAbertas: 1) == .regular)
        #expect(PoliticaDeAtivacao.para(janelasAbertas: 3) == .regular)
    }
}
