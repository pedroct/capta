import CoreGraphics

/// Cor do modelo como `CGColor` sRGB.
func cgCor(_ cor: CorRGBA) -> CGColor {
    CGColor(
        srgbRed: CGFloat(cor.r),
        green: CGFloat(cor.g),
        blue: CGFloat(cor.b),
        alpha: CGFloat(cor.a)
    )
}

/// Retângulo padronizado; `nil` se sem área (tamanho zero) ou com números não finitos.
///
/// `Documento.validar()` só confere finitude, então tamanhos zero ou negativos podem chegar
/// ao renderizador: negativos são padronizados e os sem área são descartados.
func retanguloUtil(_ retangulo: CGRect) -> CGRect? {
    let r = retangulo.standardized
    guard r.origin.x.isFinite, r.origin.y.isFinite, r.width.isFinite, r.height.isFinite,
        r.width > 0, r.height > 0
    else { return nil }
    return r
}

/// Bitmap transparente sRGB, 8 bits por componente, `premultipliedLast`, com o tamanho dado em
/// pixels (inteiro e positivo).
/// - Throws: ``ErroRenderizacao/falhaAoCriarContexto`` se o contexto não pôde ser criado.
func contextoTransparente(_ tamanho: CGSize) throws -> CGContext {
    guard let espaco = CGColorSpace(name: CGColorSpace.sRGB),
        let contexto = CGContext(
            data: nil,
            width: Int(tamanho.width),
            height: Int(tamanho.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: espaco,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else { throw ErroRenderizacao.falhaAoCriarContexto }
    return contexto
}

/// Falhas internas do renderizador (distintas de documento inválido).
public enum ErroRenderizacao: Error, Equatable, Sendable {
    /// O `CGContext` de composição não pôde ser criado.
    case falhaAoCriarContexto
    /// A imagem final não pôde ser gerada.
    case falhaAoGerarImagem
    /// O contexto recebido por `compor` não tem o tamanho em pixels da base.
    case contextoIncompativel
}
