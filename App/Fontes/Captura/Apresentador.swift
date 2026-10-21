/// Erros que a interface mostra; a view troca cada caso pelo texto do String Catalog.
enum MensagemDeErro: Equatable {
    case capturaFalhou
    case naoFoiPossivelCopiar
    case naoFoiPossivelSalvar
    case rascunhoNaoGuardado
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
    func mostrarAlerta(_ mensagem: MensagemDeErro)
}
