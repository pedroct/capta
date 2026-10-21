import CaptaNucleo
import Foundation

/// O que o usuário escolheu da última vez: atraso, "incluir cursor" e a ajuda do overlay.
///
/// Guarda em `UserDefaults` (só preferências do próprio app, sem rede nem conta). O "incluir
/// cursor" continua guardado mesmo com `atraso == .nenhum`: o controle fica desabilitado, mas a
/// escolha volta quando o atraso voltar.
struct OpcoesLembradas {
    private enum Chave {
        static let atraso = "atraso"
        static let incluirCursor = "incluirCursor"
        static let ajudaVisivel = "ajudaVisivel"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Sem nada gravado, ou com um atraso que não existe mais: sem atraso e sem cursor.
    var opcoes: OpcoesDeCaptura {
        get {
            let atraso = Atraso(rawValue: defaults.integer(forKey: Chave.atraso)) ?? .nenhum
            return OpcoesDeCaptura(
                atraso: atraso,
                incluirCursor: defaults.bool(forKey: Chave.incluirCursor)
            )
        }
        nonmutating set {
            defaults.set(newValue.atraso.rawValue, forKey: Chave.atraso)
            defaults.set(newValue.incluirCursor, forKey: Chave.incluirCursor)
        }
    }

    /// A ajuda do overlay começa visível.
    var ajudaVisivel: Bool {
        get { defaults.object(forKey: Chave.ajudaVisivel) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Chave.ajudaVisivel) }
    }
}
