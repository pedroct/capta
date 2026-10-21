import Testing

@testable import Capta

@Suite("Onde o alerta aparece")
struct DestinoDoAlertaTests {
    @Test func semJanelaOAlertaEModal() {
        #expect(DestinoDoAlerta.para(nil) == .modal)
    }

    @Test func janelaVisivelELivreRecebeAFolha() {
        #expect(DestinoDoAlerta.para((visivel: true, comFolhaAberta: false)) == .folha)
    }

    @Test func janelaFechadaOuOcultaNaoRecebeFolha() {
        #expect(DestinoDoAlerta.para((visivel: false, comFolhaAberta: false)) == .modal)
    }

    @Test func janelaComOutraFolhaAbertaNaoRecebeOutra() {
        // Uma janela só aceita uma folha por vez; a segunda iria para a fila e ficaria escondida.
        #expect(DestinoDoAlerta.para((visivel: true, comFolhaAberta: true)) == .modal)
    }
}
