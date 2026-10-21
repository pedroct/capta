import CoreGraphics
import Foundation

/// Posição de um elemento flutuante (lupa, texto das dimensões, ajuda) junto a um ponto.
public enum Posicionamento {
    /// Origem do elemento de `tamanho`, preferindo o canto inferior direito do `ponto`
    /// (a `afastamento` de distância em cada eixo).
    ///
    /// Se não couber à direita (ou embaixo), troca para a esquerda (ou para cima). O
    /// resultado nunca sai de `limites`; se o elemento for maior que o espaço, fica
    /// encostado na origem dos limites. Ponto não finito vale a origem dos limites.
    public static func origem(
        junto ponto: CGPoint,
        tamanho: CGSize,
        dentro limites: CGRect,
        afastamento: CGFloat
    ) -> CGPoint {
        let x = eixo(
            ponto.x.isFinite ? ponto.x : limites.minX,
            tamanho: tamanho.width,
            minimo: limites.minX,
            maximo: limites.maxX,
            afastamento: afastamento
        )
        let y = eixo(
            ponto.y.isFinite ? ponto.y : limites.minY,
            tamanho: tamanho.height,
            minimo: limites.minY,
            maximo: limites.maxY,
            afastamento: afastamento
        )
        return CGPoint(x: x, y: y)
    }

    private static func eixo(
        _ ponto: CGFloat,
        tamanho: CGFloat,
        minimo: CGFloat,
        maximo: CGFloat,
        afastamento: CGFloat
    ) -> CGFloat {
        var origem = ponto + afastamento
        if origem + tamanho > maximo { origem = ponto - afastamento - tamanho }
        return max(minimo, min(origem, maximo - tamanho))
    }
}
