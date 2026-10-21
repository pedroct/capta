import CoreGraphics

/// Como a imagem se acomoda na janela de captura.
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
}
