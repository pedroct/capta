import CoreGraphics

/// Fonte de imagens de símbolos (por exemplo SF Symbols) para os carimbos.
///
/// O núcleo não conhece AppKit: quem tem acesso a símbolos do sistema (camada de sistema ou app)
/// implementa este protocolo e o entrega ao ``Renderizador``.
public protocol ProvedorDeSimbolos: Sendable {
    /// Imagem quadrada do símbolo, com `lado` em pixels e `cor` aplicada; `nil` se não existir.
    func imagem(simbolo: String, lado: Double, cor: CorRGBA) -> CGImage?
}
