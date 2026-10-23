import CoreGraphics
import Foundation

/// Como a imagem se acomoda na área do canvas.
enum ModoDeExibicao {
    case ajustar
    case tamanhoReal
}

/// Escala de exibição da imagem na área disponível.
enum Enquadramento {
    /// `tamanhoReal` é sempre 1. `ajustar` é o menor entre 1 e a razão que cabe na área: reduz
    /// quando não cabe e nunca amplia. Com lado zero na imagem ou na área, devolve 1.
    /// `imagem` está em pontos (pixels ÷ escala da captura).
    static func escala(imagem: CGSize, area: CGSize, modo: ModoDeExibicao) -> CGFloat {
        guard modo == .ajustar else { return 1 }
        guard imagem.width > 0, imagem.height > 0, area.width > 0, area.height > 0 else {
            return 1
        }
        return min(1, area.width / imagem.width, area.height / imagem.height)
    }

    /// Altura da barra de ferramentas.
    static let alturaDasFerramentas = 52.0
    /// Altura do rodapé (zoom, tamanho e salvamento).
    static let alturaDoRodape = 28.0
    /// Largura do painel de propriedades, à direita do canvas.
    static let larguraDoPainel = 232.0
    /// Altura da barra de ferramentas somada à do rodapé: o que a janela gasta além do canvas.
    static let alturaDaBarra = alturaDasFerramentas + alturaDoRodape
    /// Menor conteúdo da janela do editor: a barra de ferramentas ainda cabe inteira.
    static let tamanhoMinimo = CGSize(width: 640, height: 320 + alturaDaBarra)

    /// Tamanho inicial do conteúdo da janela: o canvas com a imagem em pontos (mínimo 480 x 320),
    /// mais o painel e as barras. O conjunto sem as barras fica em 80 % da área visível da tela,
    /// quando a imagem é maior. Sem tela, vale 1280 x 800.
    static func tamanhoInicial(imagem: CGSize, telaVisivel: CGSize?) -> CGSize {
        let tela = telaVisivel ?? CGSize(width: 1280, height: 800)
        let largura = min(imagem.width, tela.width * 0.8 - larguraDoPainel)
        let altura = min(imagem.height, tela.height * 0.8)
        return CGSize(
            width: max(largura, 480) + larguraDoPainel,
            height: max(altura, 320) + alturaDaBarra
        )
    }

    /// Origem (canto inferior esquerdo, coordenadas do AppKit) que centraliza um quadro de
    /// `tamanho` em `area`. Se não couber, encosta à esquerda e no topo, para a barra de título
    /// ficar na tela.
    static func origemCentralizada(_ tamanho: CGSize, em area: CGRect) -> CGPoint {
        CGPoint(
            x: max(area.minX, area.midX - tamanho.width / 2),
            y: min(area.maxY - tamanho.height, area.midY - tamanho.height / 2)
        )
    }
    /// Tamanho em pontos de uma imagem de `larguraEmPixels` x `alturaEmPixels` capturada em `escala`.
    static func pontos(larguraEmPixels: Int, alturaEmPixels: Int, escala: Double) -> CGSize {
        CGSize(
            width: Double(larguraEmPixels) / escala,
            height: Double(alturaEmPixels) / escala
        )
    }

    /// A tela sob o `cursor` (coordenadas do AppKit), ou `padrao` se nenhuma o contém.
    ///
    /// Segue a regra do `NSMouseInRect` sem inversão: a borda de cima e a da esquerda são da
    /// tela; a de baixo e a da direita, da vizinha. É assim porque o cursor no pixel mais alto
    /// tem y igual a `maxY`, o que o `CGRect.contains`, semiaberto em cima, deixaria de fora.
    static func tela<Tela>(
        sob cursor: CGPoint,
        entre telas: [Tela],
        quadro: (Tela) -> CGRect,
        padrao: Tela?
    ) -> Tela? {
        telas.first { tela in
            let area = quadro(tela)
            return cursor.x >= area.minX && cursor.x < area.maxX
                && cursor.y > area.minY && cursor.y <= area.maxY
        } ?? padrao
    }
}
