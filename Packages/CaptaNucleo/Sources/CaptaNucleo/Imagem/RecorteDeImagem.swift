import CoreGraphics
import Foundation

/// Recorte da imagem congelada pelo retângulo escolhido no overlay.
public enum RecorteDeImagem {
    /// Recorta `pixels` (pixels nativos, origem no canto superior esquerdo).
    ///
    /// Devolve `nil` se o retângulo for vazio, não finito ou não estiver inteiro dentro da
    /// imagem. O pixel `(0, 0)` da saída é o pixel `(x, y)` da base.
    public static func recortar(_ imagem: CGImage, pixels: CGRect) -> CGImage? {
        let limites = CGRect(x: 0, y: 0, width: imagem.width, height: imagem.height)
        guard !pixels.isEmpty, !pixels.isNull, limites.contains(pixels) else { return nil }
        return imagem.cropping(to: pixels)
    }
}
