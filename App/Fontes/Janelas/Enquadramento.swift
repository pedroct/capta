import CoreGraphics
import Foundation

/// Como a imagem se acomoda na janela de captura.
enum ModoDeExibicao {
    case ajustar
    case tamanhoReal

    /// O outro modo: o botão da barra alterna entre os dois.
    var alternado: ModoDeExibicao {
        self == .ajustar ? .tamanhoReal : .ajustar
    }

    /// Rótulo do botão da barra, que nomeia o modo para onde ele leva.
    var rotuloDaAlternancia: String {
        switch self {
        case .ajustar: String(localized: "Tamanho real")
        case .tamanhoReal: String(localized: "Ajustar à janela")
        }
    }
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

    /// Altura da barra de ações, somada à da imagem no conteúdo da janela.
    static let alturaDaBarra = 52.0

    /// Tamanho inicial do conteúdo da janela: a imagem em pontos, limitada a 80 % da área
    /// visível da tela e com mínimo de 480 x 320, mais a barra. Sem tela, vale 1280 x 800.
    static func tamanhoInicial(imagem: CGSize, telaVisivel: CGSize?) -> CGSize {
        let tela = telaVisivel ?? CGSize(width: 1280, height: 800)
        let largura = min(imagem.width, tela.width * 0.8)
        let altura = min(imagem.height, tela.height * 0.8)
        return CGSize(width: max(largura, 480), height: max(altura, 320) + alturaDaBarra)
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
