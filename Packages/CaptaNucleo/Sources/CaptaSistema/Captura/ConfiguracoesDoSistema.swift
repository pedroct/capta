import Foundation

/// Endereços que abrem painéis das Configurações do Sistema.
public enum ConfiguracoesDoSistema {
    /// Painel Privacidade e Segurança > Gravação de Tela.
    public static let urlGravacaoDeTela: URL = {
        let endereco =
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        // Constante válida: o `else` nunca roda (o teste confere o endereço).
        guard let url = URL(string: endereco) else { preconditionFailure("URL do painel") }
        return url
    }()
}
