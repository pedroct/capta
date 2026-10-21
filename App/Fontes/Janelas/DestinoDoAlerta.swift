/// Onde aparece um alerta do app: em folha sobre uma janela, ou modal do app.
enum DestinoDoAlerta: Equatable {
    case folha
    case modal

    /// Em folha só sobre uma janela que existe, está na tela e não tem outra folha aberta;
    /// `janela` é `nil` quando não há janela de referência.
    static func para(_ janela: (visivel: Bool, comFolhaAberta: Bool)?) -> DestinoDoAlerta {
        guard let janela, janela.visivel, !janela.comFolhaAberta else { return .modal }
        return .folha
    }
}
