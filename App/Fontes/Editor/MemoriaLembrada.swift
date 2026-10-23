import CaptaNucleo
import Foundation

/// Último estilo de cada ferramenta de desenho, guardado em `UserDefaults` (só preferência do
/// próprio app). Valor ausente ou ilegível volta ao padrão.
@MainActor
final class MemoriaLembrada {
    private static let chave = "editor.memoriaDeEstilos"
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var memoria: MemoriaDeEstilos {
        get {
            guard let dados = defaults.data(forKey: Self.chave),
                let lida = try? JSONDecoder().decode(MemoriaDeEstilos.self, from: dados)
            else { return .padrao }
            return lida
        }
        set {
            guard let dados = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(dados, forKey: Self.chave)
        }
    }
}
