import Testing

@testable import CaptaNucleo

@Test func versaoAtualDoEsquemaEDois() {
    #expect(Esquema.versaoAtual == 2)
    #expect(Esquema.versaoMinimaLegivel == 1)
}
