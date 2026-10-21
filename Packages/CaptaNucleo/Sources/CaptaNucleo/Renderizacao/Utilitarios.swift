import CoreGraphics

/// Cor do modelo como `CGColor` sRGB.
func cgCor(_ cor: CorRGBA) -> CGColor {
    CGColor(
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        components: [CGFloat(cor.r), CGFloat(cor.g), CGFloat(cor.b), CGFloat(cor.a)]
    )
        ?? CGColor(gray: 0, alpha: 1)
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

/// Falhas internas do renderizador (distintas de documento inválido).
public enum ErroRenderizacao: Error, Equatable, Sendable {
    /// O `CGContext` de composição não pôde ser criado.
    case falhaAoCriarContexto
    /// A imagem final não pôde ser gerada.
    case falhaAoGerarImagem
}
