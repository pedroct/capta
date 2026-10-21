import Testing

@testable import Capta

@Suite("Modelo da ajuda de permissão")
@MainActor
struct AjudaDePermissaoModeloTests {
    @Test func reiniciarSoApareceDepoisDeTentarDeNovoSemSucesso() {
        let modelo = AjudaDePermissaoModelo()
        // A primeira abertura da ajuda não é desfecho de um novo teste.
        modelo.permissaoSegueNegada()
        #expect(!modelo.mostraReiniciar)

        modelo.tentouDeNovo()
        #expect(modelo.aguardandoNovoTeste)
        modelo.permissaoSegueNegada()
        #expect(modelo.mostraReiniciar)
        #expect(!modelo.aguardandoNovoTeste)
    }

    @Test func novoTesteQueFalhaPorOutroMotivoNaoFicaPendurado() {
        let modelo = AjudaDePermissaoModelo()
        modelo.tentouDeNovo()

        modelo.novoTesteFalhouPorOutroMotivo()

        #expect(!modelo.aguardandoNovoTeste)
        // Uma revogação futura abre a ajuda sem o botão de reiniciar.
        modelo.permissaoSegueNegada()
        #expect(!modelo.mostraReiniciar)
    }

    @Test func capturaQueDaCertoVoltaAoEstadoInicial() {
        let modelo = AjudaDePermissaoModelo()
        modelo.tentouDeNovo()
        modelo.permissaoSegueNegada()
        modelo.tentouDeNovo()

        modelo.reiniciarEstado()

        #expect(!modelo.mostraReiniciar)
        #expect(!modelo.aguardandoNovoTeste)
        modelo.permissaoSegueNegada()
        #expect(!modelo.mostraReiniciar)
    }
}
