import CaptaNucleo
import Foundation
import Observation

/// O que o menu precisa saber do registro de cada atalho global: uma flag por atalho, para o
/// aviso aparecer ao lado do item afetado.
@MainActor
@Observable
final class EstadoDoMenu {
    var atalhoDeTelaInteiraIndisponivel = false
    var atalhoDeCapturaLivreIndisponivel = false
    /// Capturas do submenu "Capturas recentes", da mais nova para a mais antiga.
    private(set) var recentes: [CapturaRecente] = []

    /// Relê as capturas recentes de `pasta`. Pasta que não pode ser lida deixa a lista vazia.
    func atualizarRecentes(em pasta: URL) {
        do {
            recentes = try CapturasRecentes.listar(em: pasta)
        } catch {
            RegistroDeCaptura.falha("listarRecentes", error)
            recentes = []
        }
    }
}

extension OpcoesLembradas {
    /// Fechamento que o `GerenciadorDoOverlay` chama quando a ajuda muda (tecla `H`): grava a
    /// escolha para a próxima captura.
    @MainActor var gravarAjuda: @MainActor (Bool) -> Void {
        { [self] visivel in self.ajudaVisivel = visivel }
    }
}
