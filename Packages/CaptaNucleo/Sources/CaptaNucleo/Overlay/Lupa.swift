import CoreGraphics
import Foundation

/// Escolha da área de pixels que a lupa do overlay amostra.
///
/// A ampliação (8×) é assunto da view; aqui só sai o retângulo, em pixels nativos
/// da imagem congelada (origem no canto superior esquerdo, Y para baixo).
public enum Lupa {
    /// Retângulo `lado × lado` centrado em `floor(centro)`, deslocado para caber na imagem.
    ///
    /// Com `lado` par, o pixel central fica em `lado / 2` a partir da origem. Se a imagem
    /// for menor que `lado` num eixo, a amostra ocupa a imagem inteira nesse eixo.
    /// `lado` menor que 1, imagem vazia ou não finita devolvem `.zero`; centro não finito
    /// vale 0 no eixo afetado.
    public static func amostra(em centro: CGPoint, lado: Int, imagem: CGSize) -> CGRect {
        guard lado >= 1, imagem.width.isFinite, imagem.height.isFinite,
            imagem.width >= 1, imagem.height >= 1
        else { return .zero }
        let largura = min(lado, Int(imagem.width))
        let altura = min(lado, Int(imagem.height))
        let x = origem(centro.x, lado: lado, tamanho: largura, limite: Int(imagem.width))
        let y = origem(centro.y, lado: lado, tamanho: altura, limite: Int(imagem.height))
        return CGRect(x: x, y: y, width: largura, height: altura)
    }

    private static func origem(_ centro: CGFloat, lado: Int, tamanho: Int, limite: Int) -> Int {
        // Satura antes de converter para Int, para não estourar com valores enormes.
        let piso = centro.isFinite ? Int(max(-1e9, min(1e9, centro.rounded(.down)))) : 0
        return max(0, min(piso - lado / 2, limite - tamanho))
    }
}
