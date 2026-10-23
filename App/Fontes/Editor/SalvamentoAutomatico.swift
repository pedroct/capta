import CaptaNucleo
import Foundation
import Observation

/// Situação do salvamento automático do rascunho. O app não tem estado "não salvo" para a
/// pessoa: isto só serve à interface e aos testes.
enum EstadoDoSalvamento: Equatable {
    case salvo
    case pendente
    case salvando
    case falhou
}

/// Grava o documento no rascunho sozinho, um pouco depois da última edição.
///
/// Cada ``agendar(_:em:)`` reinicia a espera; passado o atraso grava o **último** documento
/// agendado. Nunca há duas gravações ao mesmo tempo: a que chega durante outra espera a vez.
/// ``salvarAgora()`` serve ao fechar a janela e ao encerrar o app: cancela a espera, grava o
/// que estiver pendente e só volta com o disco em dia.
@MainActor
@Observable
final class SalvamentoAutomatico {
    /// Grava `documento` no pacote em `url`; roda fora da *main actor*.
    typealias Gravador = @Sendable (Documento, URL) async throws -> Void

    private(set) var estado: EstadoDoSalvamento = .salvo

    /// Roda depois de cada gravação que deu certo (o menu relê as capturas recentes).
    @ObservationIgnored var aoGravar: (@MainActor () -> Void)?

    @ObservationIgnored private let atraso: Duration
    @ObservationIgnored private let dormir: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private let gravar: Gravador
    @ObservationIgnored private var pendente: (documento: Documento, url: URL)?
    @ObservationIgnored private var espera: Task<Void, Never>?
    @ObservationIgnored private var geracao = 0
    @ObservationIgnored private var gravacao: Task<Void, Never>?

    init(
        atraso: Duration = .seconds(2),
        dormir: @escaping @Sendable (Duration) async throws -> Void,
        gravar: @escaping Gravador
    ) {
        self.atraso = atraso
        self.dormir = dormir
        self.gravar = gravar
    }

    /// Guarda `documento` como o próximo a gravar e reinicia a espera.
    func agendar(_ documento: Documento, em url: URL) {
        pendente = (documento, url)
        estado = gravacao == nil ? .pendente : .salvando
        espera?.cancel()
        geracao += 1
        let minha = geracao
        let dormir = dormir
        let atraso = atraso
        espera = Task {
            do {
                try await dormir(atraso)
            } catch {
                return
            }
            guard geracao == minha else { return }
            espera = nil
            await gravarPendente()
        }
    }

    /// Cancela a espera e grava o pendente, se houver; volta quando nada mais está em curso.
    func salvarAgora() async {
        espera?.cancel()
        espera = nil
        geracao += 1
        await gravarPendente()
    }

    // MARK: Privado

    /// Espera a gravação em curso, pega o pendente e grava. Cada chamada só volta depois de a
    /// sua própria gravação (ou a que já estava em curso) terminar.
    private func gravarPendente() async {
        while let emCurso = gravacao { await emCurso.value }
        guard let alvo = pendente else { return }
        pendente = nil
        estado = .salvando
        let gravar = gravar
        let tarefa = Task {
            do {
                try await gravar(alvo.documento, alvo.url)
                estado = pendente == nil ? .salvo : .pendente
                aoGravar?()
            } catch {
                RegistroDeCaptura.falha("salvarRascunho", error)
                // Sem edição mais nova, o mesmo documento fica na fila para a próxima tentativa.
                if pendente == nil { pendente = alvo }
                estado = .falhou
            }
            gravacao = nil
        }
        gravacao = tarefa
        await tarefa.value
    }
}
