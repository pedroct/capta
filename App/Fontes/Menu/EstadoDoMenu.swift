import Observation

/// O que o menu precisa saber do registro de cada atalho global: uma flag por atalho, para o
/// aviso aparecer ao lado do item afetado.
@MainActor
@Observable
final class EstadoDoMenu {
    var atalhoDeTelaInteiraIndisponivel = false
    var atalhoDeCapturaLivreIndisponivel = false
}

extension OpcoesLembradas {
    /// Fechamento que o `GerenciadorDoOverlay` chama quando a ajuda muda (tecla `H`): grava a
    /// escolha para a próxima captura.
    @MainActor var gravarAjuda: @MainActor (Bool) -> Void {
        { [self] visivel in self.ajudaVisivel = visivel }
    }
}
