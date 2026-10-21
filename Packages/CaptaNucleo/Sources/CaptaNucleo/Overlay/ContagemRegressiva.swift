import Foundation

/// Atraso opcional entre o fim da seleção e a captura, em segundos.
public enum Atraso: Int, CaseIterable, Sendable {
    case nenhum = 0
    case tres = 3
    case cinco = 5
    case dez = 10
}

/// Contagem regressiva de segundos inteiros, com o relógio injetado para os testes.
public struct ContagemRegressiva: Sendable {
    private let segundos: Int
    private let pausa: @Sendable (Duration) async throws -> Void

    /// - Parameters:
    ///   - segundos: ponto de partida; zero ou negativo conta como nenhum segundo.
    ///   - pausa: espera de uma duração; deve lançar se a `Task` for cancelada.
    public init(
        segundos: Int,
        pausa: @escaping @Sendable (Duration) async throws -> Void = {
            try await Task.sleep(for: $0)
        }
    ) {
        self.segundos = segundos
        self.pausa = pausa
    }

    /// Chama `aCadaSegundo(n)` de `segundos` até `1`, pausando 1 s depois de cada chamada.
    ///
    /// - Returns: `true` ao chegar ao fim; `false` se a `Task` for cancelada, sem chamar
    ///   mais nada a partir daí.
    public func executar(aCadaSegundo: @escaping @Sendable (Int) -> Void) async -> Bool {
        var n = segundos
        while n >= 1 {
            if Task.isCancelled { return false }
            aCadaSegundo(n)
            do {
                try await pausa(.seconds(1))
            } catch {
                return false
            }
            n -= 1
        }
        return true
    }
}
