import AppKit
import CaptaNucleo

extension TeclaDoOverlay {
    /// Códigos de tecla (`kVK_*`) que não dependem do layout.
    private static let porCodigo: [UInt16: TeclaDoOverlay] = [
        53: .esc,
        36: .enter,
        76: .enter,  // Enter do teclado numérico
        49: .espaco,
    ]
    private static let setas: [UInt16: Direcao] = [
        123: .esquerda,
        124: .direita,
        125: .baixo,
        126: .cima,
    ]
    /// Posição ANSI das letras, só para layouts sem letras latinas.
    private static let letrasANSI: [UInt16: TeclaDoOverlay] = [3: .f, 46: .m, 4: .h]
    private static let letras: [Character: TeclaDoOverlay] = ["f": .f, "m": .m, "h": .h]

    /// A tecla do overlay para um `keyDown`, ou `nil` se não for dele.
    ///
    /// Letras valem pelo caractere do layout (`F` no Dvorak é a tecla marcada F); só num
    /// layout sem letras latinas caem na posição ANSI. Com `⌘`, `⌃` ou `⌥` nada é do overlay;
    /// `⇧` nas setas pede o passo grande.
    static func de(
        codigo: UInt16,
        caracteres: String?,
        modificadores: NSEvent.ModifierFlags
    ) -> TeclaDoOverlay? {
        guard modificadores.isDisjoint(with: [.command, .control, .option]) else { return nil }
        if let tecla = porCodigo[codigo] { return tecla }
        if let direcao = setas[codigo] {
            return .seta(direcao, grande: modificadores.contains(.shift))
        }
        let texto = (caracteres ?? "").lowercased()
        if let caractere = texto.first, texto.count == 1, caractere.isASCII {
            return letras[caractere]
        }
        return letrasANSI[codigo]
    }

    /// Com o overlay aberto toda tecla é engolida (sem bipe), menos as com `⌘`.
    static func deixaPassar(modificadores: NSEvent.ModifierFlags) -> Bool {
        modificadores.contains(.command)
    }
}
