import Testing

@testable import Capta

@Suite("Modelo da ajuda de permissão")
@MainActor
struct AjudaDePermissaoModeloTests {
    @Test func reiniciarSoApareceDepoisDeTentarDeNovoSemSucesso() {
        let modelo = AjudaDePermissaoModelo()
        #expect(!modelo.mostraReiniciar)
        modelo.tentouDeNovoSemSucesso()
        #expect(modelo.mostraReiniciar)
    }
}
