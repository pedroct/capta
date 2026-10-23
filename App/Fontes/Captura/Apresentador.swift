import Foundation

/// Erros que a interface mostra; a view troca cada caso pelo texto do String Catalog.
///
/// `rascunhoNaoGuardado` não vira alerta: é o aviso da barra (``CapturaAberta/aviso``).
enum MensagemDeErro: Equatable {
    case capturaFalhou
    case naoFoiPossivelCopiar
    case naoFoiPossivelSalvar
    case rascunhoNaoGuardado
    case naoFoiPossivelAbrir
}

extension MensagemDeErro {
    /// Texto do alerta ou do aviso, pelo String Catalog.
    var texto: String {
        switch self {
        case .capturaFalhou:
            String(localized: "Não foi possível capturar a tela.")
        case .naoFoiPossivelCopiar:
            String(localized: "Não foi possível copiar a imagem.")
        case .naoFoiPossivelSalvar:
            String(localized: "Não foi possível salvar o arquivo.")
        case .rascunhoNaoGuardado:
            String(localized: "A captura não foi guardada. Copiar e salvar continuam funcionando.")
        case .naoFoiPossivelAbrir:
            String(localized: "Não foi possível abrir a captura.")
        }
    }
}

/// Desfecho de uma ação da janela de captura. Cancelar no painel não é erro.
enum ResultadoDeAcao: Equatable {
    case concluido
    case cancelado
    case falhou(MensagemDeErro)
}

/// Quem mostra janelas e alertas ao fluxo de captura; a implementação real é das views.
@MainActor
protocol Apresentador {
    func mostrarAjudaDePermissao()
    func mostrarCaptura(_ captura: CapturaAberta)
    /// Traz para a frente a janela do pacote em `url`, se houver; `true` quando havia.
    func trazerParaFrente(_ url: URL) -> Bool
    func mostrarAlerta(_ mensagem: MensagemDeErro)
}
