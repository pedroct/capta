import Foundation
import Observation
import SwiftUI

/// As ações da barra que terminam com uma confirmação ("Copiado", "Salvo") ou um alerta.
///
/// A confirmação aparece na barra e some depois de 2 s; uma confirmação nova cancela a espera da
/// anterior, e fechar a janela cancela a espera pendente.
@MainActor
@Observable
final class AcoesDaBarra {
    private(set) var confirmacao: String?

    @ObservationIgnored private let mostrarAlerta: @MainActor (MensagemDeErro) -> Void
    @ObservationIgnored private let anunciar: @MainActor (String) -> Void
    @ObservationIgnored private let dormir: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var limpeza: Task<Void, Never>?

    init(
        mostrarAlerta: @escaping @MainActor (MensagemDeErro) -> Void,
        anunciar: @escaping @MainActor (String) -> Void = {
            AccessibilityNotification.Announcement($0).post()
        },
        dormir: @escaping @Sendable (Duration) async throws -> Void = {
            try await Task.sleep(for: $0)
        }
    ) {
        self.mostrarAlerta = mostrarAlerta
        self.anunciar = anunciar
        self.dormir = dormir
    }

    /// Roda a ação e trata o resultado. Devolve a tarefa para o teste esperar.
    @discardableResult
    func executar(
        confirmacao texto: String,
        _ acao: @escaping @MainActor () async -> ResultadoDeAcao
    ) -> Task<Void, Never> {
        Task { tratar(await acao(), confirmacao: texto) }
    }

    /// Cancela a espera pendente (a janela está fechando).
    func cancelar() {
        limpeza?.cancel()
    }

    /// Espera a limpeza da confirmação em curso, se houver. Serve aos testes.
    func aguardarLimpeza() async {
        await limpeza?.value
    }

    private func tratar(_ resultado: ResultadoDeAcao, confirmacao texto: String) {
        switch resultado {
        case .concluido:
            confirmacao = texto
            anunciar(texto)
            limpeza?.cancel()
            let dormir = dormir
            limpeza = Task {
                do {
                    try await dormir(.seconds(2))
                } catch {
                    return
                }
                if !Task.isCancelled, confirmacao == texto { confirmacao = nil }
            }
        case .cancelado:
            break
        case .falhou(let mensagem):
            mostrarAlerta(mensagem)
        }
    }
}
