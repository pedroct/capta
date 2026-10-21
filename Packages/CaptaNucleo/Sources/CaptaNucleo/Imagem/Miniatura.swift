import CoreGraphics
import Foundation

/// Gera miniaturas sRGB de uma imagem.
public enum Miniatura {
    /// Lado maior padrão, em pixels.
    public static let ladoMaiorPadrao = 512

    /// Reduz `imagem` para que o lado maior tenha no máximo `ladoMaior` pixels, mantendo a proporção.
    ///
    /// Não amplia: imagem menor que o limite mantém o tamanho. Nenhum lado fica menor que 1 pixel.
    /// A saída é sempre sRGB, 8 bits por componente, `premultipliedLast`.
    /// - Throws: ``ErroRenderizacao/falhaAoCriarContexto`` ou ``ErroRenderizacao/falhaAoGerarImagem``
    ///   se o contexto ou a imagem não puderam ser criados.
    public static func gerar(de imagem: CGImage, ladoMaior: Int = ladoMaiorPadrao) throws -> CGImage
    {
        let maior = max(imagem.width, imagem.height)
        let fator = min(1, Double(max(1, ladoMaior)) / Double(max(1, maior)))
        let largura = max(1, Int((Double(imagem.width) * fator).rounded()))
        let altura = max(1, Int((Double(imagem.height) * fator).rounded()))

        guard let espaco = CGColorSpace(name: CGColorSpace.sRGB),
            let contexto = CGContext(
                data: nil,
                width: largura,
                height: altura,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: espaco,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { throw ErroRenderizacao.falhaAoCriarContexto }

        contexto.interpolationQuality = .high
        contexto.draw(imagem, in: CGRect(x: 0, y: 0, width: largura, height: altura))
        guard let saida = contexto.makeImage() else { throw ErroRenderizacao.falhaAoGerarImagem }
        return saida
    }
}
