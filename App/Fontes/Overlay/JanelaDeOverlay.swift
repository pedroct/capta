import AppKit

/// Janela sem borda que cobre uma tela inteira, acima da barra de menus e do Dock.
///
/// Precisa ser `key` para receber o teclado num app de barra de menus.
final class JanelaDeOverlay: NSPanel {
    /// Nível do overlay e da janelinha da contagem.
    ///
    /// Valores do `CGWindowLevel.h` do SDK: Dock 20, barra de menus 24, barra de status 25,
    /// menu pop-up 101, overlay 102, ajuda 200, arrasto 500, protetor de tela 1000. O
    /// `.popUpMenu` (101) fica acima do Dock, da barra de menus e dos itens de status, que o
    /// overlay precisa cobrir (spec §4.3). Com o nível anterior, `.screenSaver` (1000), o HUD do
    /// alternador de apps (⌘Tab) não aparecia no teste em tela real enquanto o overlay ou a
    /// contagem estavam abertos (a troca de app ainda acontecia, às cegas); o mais provável é
    /// que ficasse atrás das janelas do Capta.
    ///
    /// É uma escolha pelos níveis documentados do CoreGraphics: a Apple não publica o nível do
    /// alternador do sistema. Precisa ser confirmada de novo em tela real: barra de menus e Dock
    /// ainda cobertos, e o HUD do ⌘Tab visível com o overlay ou a contagem abertos.
    static let nivel: NSWindow.Level = .popUpMenu

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
        // `.popUpMenu` (101), não `.screenSaver` (1000), para não esconder o ⌘Tab (ver `nivel`).
        level = Self.nivel
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
