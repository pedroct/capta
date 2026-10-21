import AppKit

/// Janela sem borda que cobre uma tela inteira, acima da barra de menus e do Dock.
///
/// Precisa ser `key` para receber o teclado num app de barra de menus.
final class JanelaDeOverlay: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// - Parameter quadro: quadro da tela no espaço do AppKit (ver `quadroNoAppKit`).
    init(quadro: NSRect) {
        super.init(
            contentRect: quadro,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // A vista cobre tudo com a imagem congelada.
        isOpaque = true
        backgroundColor = Tema.Overlay.fundoDaJanela
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        setFrame(quadro, display: false)
    }

    /// O quadro fica exatamente sobre a tela, inclusive sobre a barra de menus.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// Quadro global do núcleo (pontos, origem no canto superior esquerdo da tela principal,
    /// Y para baixo) para o espaço do AppKit (origem no canto inferior esquerdo da principal,
    /// Y para cima).
    static func quadroNoAppKit(de quadro: CGRect, alturaDaPrincipal: CGFloat) -> NSRect {
        NSRect(
            x: quadro.minX,
            y: alturaDaPrincipal - quadro.maxY,
            width: quadro.width,
            height: quadro.height
        )
    }
}
