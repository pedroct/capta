import CoreGraphics

/// Níveis de zoom do canvas. 100 % é a imagem em pontos (pixels ÷ escala da captura), como o
/// `Enquadramento` da janela de captura.
enum Zoom {
    static let niveis: [Double] = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4]

    private static let folga = 1e-9

    /// O próximo nível acima de `atual`; no topo, fica no topo.
    static func acima(de atual: Double) -> Double {
        niveis.first { $0 > atual + folga } ?? niveis[niveis.count - 1]
    }

    /// O próximo nível abaixo de `atual`. Já no piso (ou abaixo dele, como acontece no "ajustar"
    /// de uma imagem enorme), não muda: diminuir nunca aumenta o zoom.
    static func abaixo(de atual: Double) -> Double {
        niveis.last { $0 < atual - folga } ?? min(atual, niveis[0])
    }

    /// Prende `valor` entre o menor e o maior nível.
    static func limitado(_ valor: Double) -> Double {
        min(max(valor, niveis[0]), niveis[niveis.count - 1])
    }

    /// Como ``limitado(_:)``, para a pinça: o piso é o menor entre o nível mais baixo e o zoom de
    /// onde o gesto parte. Assim o "ajustar" de uma imagem enorme (abaixo de 25 %) não salta para
    /// 25 % no primeiro toque, e a pinça nunca zera o zoom.
    static func limitado(_ valor: Double, partindoDe atual: Double) -> Double {
        min(max(valor, min(niveis[0], atual)), niveis[niveis.count - 1])
    }
}

/// Converte entre pixels do documento e pontos da vista, no zoom atual.
///
/// Um ponto da vista vale `escala / zoom` pixels. `origem` é o canto do recorte, em pixels (zero
/// nesta fatia; o recorte da 5b o usa).
struct ConversaoDoCanvas: Equatable {
    let zoom: Double
    let escala: Double
    let origem: CGPoint

    init(zoom: Double, escala: Double, origem: CGPoint = .zero) {
        self.zoom = zoom
        self.escala = escala
        self.origem = origem
    }

    private var pontosPorPixel: CGFloat { CGFloat(zoom / escala) }

    /// Do ponto da vista para o pixel do documento.
    func pixel(de ponto: CGPoint) -> CGPoint {
        CGPoint(
            x: ponto.x / pontosPorPixel + origem.x,
            y: ponto.y / pontosPorPixel + origem.y
        )
    }

    /// Do pixel do documento para o ponto da vista.
    func ponto(de pixel: CGPoint) -> CGPoint {
        CGPoint(
            x: (pixel.x - origem.x) * pontosPorPixel,
            y: (pixel.y - origem.y) * pontosPorPixel
        )
    }

    /// Uma distância na tela, em pontos, expressa em pixels do documento. É o que mantém a
    /// tolerância de clique igual na tela em qualquer zoom.
    func pixels(dePontos pontos: CGFloat) -> CGFloat {
        pontos / pontosPorPixel
    }
}
