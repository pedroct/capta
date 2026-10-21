import CaptaNucleo
import ScreenCaptureKit

/// Traduz o erro do ScreenCaptureKit para o ``ErroCaptura`` do núcleo.
public enum MapeadorDeErroDeCaptura {
    /// `userDeclined` do `SCStreamErrorDomain` (permissão negada ou revogada no meio da
    /// sessão) vira ``ErroCaptura/semPermissao``; qualquer outro erro vira ``ErroCaptura/falhou``.
    public static func mapear(dominio: String, codigo: Int) -> ErroCaptura {
        if dominio == SCStreamErrorDomain, codigo == SCStreamError.Code.userDeclined.rawValue {
            return .semPermissao
        }
        return .falhou
    }

    /// Mapeia um erro qualquer: ``ErroCaptura`` passa sem mudar; os demais vão pelo
    /// domínio e código do `NSError` em ``mapear(dominio:codigo:)``.
    public static func mapear(_ erro: any Error) -> ErroCaptura {
        if let erro = erro as? ErroCaptura { return erro }
        let ns = erro as NSError
        return mapear(dominio: ns.domain, codigo: ns.code)
    }
}
