import CaptaNucleo
import CoreGraphics
import Testing

@testable import CaptaSistema

@Suite("Provedor de símbolos do sistema")
struct ProvedorDeSimbolosSFTests {
    @Test func provedorDoSistemaDevolveImagemParaSimboloConhecido() {
        let provedor = ProvedorDeSimbolosSF()
        let imagem = provedor.imagem(simbolo: "star.fill", lado: 24, cor: .preto)
        #expect(imagem != nil)
        #expect(imagem?.width == 24 && imagem?.height == 24)
        #expect(provedor.imagem(simbolo: "nao.existe.xyz", lado: 24, cor: .preto) == nil)
    }
}
