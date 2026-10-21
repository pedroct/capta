import AppKit

/// Abre e fecha o overlay: uma `JanelaDeOverlay` escura por tela.
///
/// Provisório (Tarefa 1): só prova que o teclado chega ao overlay. `Esc` fecha, perder a ativação
/// do app fecha e clicar em qualquer janela do overlay devolve o foco a ela.
@MainActor
final class GerenciadorDoOverlay {
    private var janelas: [JanelaDeOverlay] = []
    private var aoFechar: (@MainActor () -> Void)?
    private var monitorDeTeclas: Any?
    private var monitorDeCliques: Any?
    private var observadorDeAtivacao: NSObjectProtocol?

    var aberto: Bool { !janelas.isEmpty }

    func abrir(aoFechar: @escaping @MainActor () -> Void) {
        guard !aberto else { return }
        self.aoFechar = aoFechar
        janelas = NSScreen.screens.map { JanelaDeOverlay(tela: $0) }

        NSApp.activate()
        for janela in janelas { janela.orderFrontRegardless() }
        janelas.first(where: { $0.screen == NSScreen.main })?.makeKey()
            ?? janelas.first?.makeKey()

        monitorDeTeclas = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] evento in
            guard evento.keyCode == 53 else { return evento }  // kVK_Escape
            MainActor.assumeIsolated { self?.fechar() }
            return nil
        }
        monitorDeCliques = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { evento in
            if let janela = evento.window as? JanelaDeOverlay, !janela.isKeyWindow {
                MainActor.assumeIsolated { janela.makeKey() }
            }
            return evento
        }
        observadorDeAtivacao = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fechar() }
        }
    }

    func fechar() {
        guard aberto else { return }
        if let monitorDeTeclas { NSEvent.removeMonitor(monitorDeTeclas) }
        if let monitorDeCliques { NSEvent.removeMonitor(monitorDeCliques) }
        if let observadorDeAtivacao {
            NotificationCenter.default.removeObserver(observadorDeAtivacao)
        }
        monitorDeTeclas = nil
        monitorDeCliques = nil
        observadorDeAtivacao = nil
        for janela in janelas { janela.orderOut(nil) }
        janelas = []
        let retorno = aoFechar
        aoFechar = nil
        retorno?()
    }
}
