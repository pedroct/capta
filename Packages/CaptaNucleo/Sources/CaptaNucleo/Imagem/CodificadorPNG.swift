import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Erros dos utilitários de imagem.
public enum ErroImagem: Error, Equatable, Sendable {
    /// A escala não é um número finito maior que zero.
    case escalaInvalida
    /// O ImageIO não conseguiu produzir os dados do PNG.
    case falhaAoCodificar
}

/// Codifica um `CGImage` em PNG com ImageIO.
public enum CodificadorPNG {
    /// DPI de uma imagem em escala 1x.
    private static let dpiBase = 72.0

    /// Codifica `imagem` em PNG gravando o DPI `72 × escala`.
    /// - Throws: ``ErroImagem/escalaInvalida`` se `escala` não for finita ou for `<= 0`;
    ///   ``ErroImagem/falhaAoCodificar`` se o ImageIO falhar.
    public static func codificar(_ imagem: CGImage, escala: Double) throws -> Data {
        guard escala.isFinite, escala > 0 else { throw ErroImagem.escalaInvalida }
        let dados = NSMutableData()
        guard
            let destino = CGImageDestinationCreateWithData(
                dados,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else { throw ErroImagem.falhaAoCodificar }
        let dpi = dpiBase * escala
        let propriedades: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
        ]
        CGImageDestinationAddImage(destino, imagem, propriedades as CFDictionary)
        guard CGImageDestinationFinalize(destino) else { throw ErroImagem.falhaAoCodificar }
        return dados as Data
    }
}
