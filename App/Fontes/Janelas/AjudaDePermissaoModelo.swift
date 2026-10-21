import Observation

/// Estado da janela de ajuda de permissão.
///
/// O botão de reiniciar só aparece depois de um "Tentar de novo" que ainda falha por permissão:
/// o sistema às vezes só reconhece a permissão depois que o app reinicia. Um novo teste que
/// termina em outro erro não conta, e uma captura que dá certo volta tudo ao estado inicial,
/// para uma revogação futura abrir a ajuda sem o botão.
@MainActor
@Observable
final class AjudaDePermissaoModelo {
    private(set) var mostraReiniciar = false
    /// Um "Tentar de novo" foi pedido e o desfecho ainda não chegou.
    private(set) var aguardandoNovoTeste = false

    /// A pessoa pediu "Tentar de novo"; o desfecho chega por um dos métodos abaixo.
    func tentouDeNovo() {
        aguardandoNovoTeste = true
    }

    /// A ajuda vai abrir porque falta permissão. Se for o desfecho de um novo teste, mostra
    /// o botão de reiniciar.
    func permissaoSegueNegada() {
        guard aguardandoNovoTeste else { return }
        aguardandoNovoTeste = false
        mostraReiniciar = true
    }

    /// O novo teste falhou por outro erro, que não diz nada sobre a permissão.
    func novoTesteFalhouPorOutroMotivo() {
        aguardandoNovoTeste = false
    }

    /// Uma captura deu certo: volta ao estado inicial.
    func reiniciarEstado() {
        aguardandoNovoTeste = false
        mostraReiniciar = false
    }
}
