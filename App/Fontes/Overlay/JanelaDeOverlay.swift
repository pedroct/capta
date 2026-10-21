import AppKit

/// Janela sem borda que cobre uma tela inteira, acima da barra de menus e do Dock.
///
/// Precisa ser `key` para receber o teclado (`Esc`) num app de barra de menus.
final class JanelaDeOverlay: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(tela: NSScreen) {
        super.init(
            contentRect: tela.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: tela
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(0.35)
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        setFrame(tela.frame, display: false)
    }
}
