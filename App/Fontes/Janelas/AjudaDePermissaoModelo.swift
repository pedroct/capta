import Observation

/// Estado da janela de ajuda de permissão.
///
/// O botão de reiniciar só aparece depois de um "Tentar de novo" que ainda falha por permissão:
/// o sistema às vezes só reconhece a permissão depois que o app reinicia.
@MainActor
@Observable
final class AjudaDePermissaoModelo {
    private(set) var mostraReiniciar = false

    func tentouDeNovoSemSucesso() {
        mostraReiniciar = true
    }
}
