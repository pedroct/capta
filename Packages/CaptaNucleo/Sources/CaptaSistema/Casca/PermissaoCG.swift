import CaptaNucleo
import CoreGraphics

/// Permissão de Gravação de Tela pelo CoreGraphics.
///
/// Casca fina, fora do portão de cobertura: só chama a API do sistema.
public struct PermissaoCG: PermissaoDeGravacaoDeTela {
    public init() {}

    /// Consulta sem mostrar pedido ao usuário.
    public func consultar() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Pede ao sistema que mostre o pedido de permissão. O sistema só pergunta uma vez;
    /// depois de negada, a liberação é nas Configurações do Sistema.
    public func solicitar() {
        _ = CGRequestScreenCaptureAccess()
    }
}
