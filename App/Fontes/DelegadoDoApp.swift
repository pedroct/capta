import AppKit

/// Delegado do `NSApplication`: segura o encerramento até o rascunho de cada janela estar no
/// disco. O app não pergunta nada à pessoa (spec §4.8); só espera gravar e então sai.
@MainActor
final class DelegadoDoApp: NSObject, NSApplicationDelegate {
    /// O `@NSApplicationDelegateAdaptor` cria o delegado sozinho, sem receber argumentos; o
    /// `CaptaApp` entrega o gerenciador por aqui antes de o app começar a rodar.
    static weak var janelas: GerenciadorDeJanelas?

    /// Grava tudo o que estiver pendente; padrão: as janelas do gerenciador.
    var salvarTodas: @MainActor () async -> Void = {
        await DelegadoDoApp.janelas?.salvarTodas()
    }

    /// Responde ao `.terminateLater`; padrão: libera o encerramento no `NSApp`.
    var responder: @MainActor (Bool) -> Void = {
        NSApp.reply(toApplicationShouldTerminate: $0)
    }

    /// A espera em curso, para os testes aguardarem.
    private(set) var encerramento: Task<Void, Never>?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        encerramento = Task {
            await salvarTodas()
            responder(true)
        }
        return .terminateLater
    }
}
