import CoreGraphics
import Foundation

extension Renderizador {
    /// Desenha o símbolo do carimbo dentro de `retangulo`, centralizado e sem distorcer.
    ///
    /// O lado pedido ao provedor é o menor lado do retângulo. Sem provedor, sem imagem ou com
    /// retângulo sem área: não desenha nada.
    func desenharCarimbo(
        simbolo: String,
        em retangulo: CGRect,
        cor: CorRGBA,
        contexto: CGContext
    ) {
        guard let r = retanguloUtil(retangulo),
            let imagem = provedorDeSimbolos?.imagem(
                simbolo: simbolo,
                lado: Double(min(r.width, r.height)),
                cor: cor
            ),
            imagem.width > 0, imagem.height > 0
        else { return }

        let escala = min(r.width / CGFloat(imagem.width), r.height / CGFloat(imagem.height))
        let tamanho = CGSize(
            width: CGFloat(imagem.width) * escala,
            height: CGFloat(imagem.height) * escala
        )
        let destino = CGRect(
            x: r.midX - tamanho.width / 2,
            y: r.midY - tamanho.height / 2,
            width: tamanho.width,
            height: tamanho.height
        )
        contexto.saveGState()
        // O contexto tem o Y invertido: desvira localmente para a imagem ficar de pé.
        contexto.translateBy(x: destino.minX, y: destino.maxY)
        contexto.scaleBy(x: 1, y: -1)
        contexto.draw(imagem, in: CGRect(origin: .zero, size: destino.size))
        contexto.restoreGState()
    }
}
