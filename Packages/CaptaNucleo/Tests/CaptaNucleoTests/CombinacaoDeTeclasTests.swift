import Testing

@testable import CaptaNucleo

@Suite("CombinacaoDeTeclas")
struct CombinacaoDeTeclasTests {
    @Test func capturaLivreEControleOpcaoC() {
        #expect(CombinacaoDeTeclas.capturaLivre.codigoDaTecla == 8)
        #expect(CombinacaoDeTeclas.capturaLivre.modificadores == [.controle, .opcao])
    }

    @Test func capturaLivreDifereDaTelaInteira() {
        #expect(CombinacaoDeTeclas.capturaLivre != CombinacaoDeTeclas.capturarTelaInteira)
    }
}
