import CoreGraphics

/// Uma tela conectada, independente do ScreenCaptureKit para dar para testar a escolha.
public struct DescricaoDeTela: Equatable, Sendable {
    /// `CGDirectDisplayID` da tela.
    public let id: UInt32
    /// Quadro em pontos no espaço global do CoreGraphics: origem no canto superior esquerdo
    /// da tela principal, Y para baixo; telas acima ou à esquerda têm coordenadas negativas.
    public let quadro: CGRect
    /// Pixels por ponto (`2` em Retina).
    public let escala: Double
    public let principal: Bool

    public init(id: UInt32, quadro: CGRect, escala: Double, principal: Bool) {
        self.id = id
        self.quadro = quadro
        self.escala = escala
        self.principal = principal
    }

    /// Tamanho da tela em pixels nativos (pontos × escala, arredondado), ou `nil` se o
    /// quadro ou a escala não renderem ao menos um pixel representável em cada lado.
    public var tamanhoEmPixels: (largura: Int, altura: Int)? {
        guard
            let largura = Self.pixels(quadro.width * escala),
            let altura = Self.pixels(quadro.height * escala)
        else { return nil }
        return (largura, altura)
    }

    private static func pixels(_ valor: Double) -> Int? {
        // `Int(exactly:)` recusa NaN, infinito e o que não cabe em `Int`.
        guard let inteiro = Int(exactly: valor.rounded()), inteiro >= 1 else { return nil }
        return inteiro
    }
}

extension DescricaoDeTela {
    /// Tamanho da tela em pixels nativos como `CGSize`, ou `nil` se `tamanhoEmPixels` for `nil`.
    public var limitesEmPixels: CGSize? {
        tamanhoEmPixels.map { CGSize(width: $0.largura, height: $0.altura) }
    }

    /// Ponto global em pontos para pixel local da tela (origem no canto superior esquerdo
    /// da própria tela): `(ponto - quadro.origin) * escala`, sem arredondar.
    public func pixelLocal(dePonto ponto: CGPoint) -> CGPoint {
        CGPoint(x: (ponto.x - quadro.minX) * escala, y: (ponto.y - quadro.minY) * escala)
    }

    /// Retângulo global em pontos para pixels locais da tela. Cada lado vai ao pixel mais
    /// próximo (meio pixel arredonda para o par) e a largura e a altura saem da diferença
    /// dos lados já arredondados, então retângulos vizinhos não deixam fresta nem se sobrepõem.
    public func pixels(dePontos retangulo: CGRect) -> CGRect {
        let minimo = pixelLocal(dePonto: CGPoint(x: retangulo.minX, y: retangulo.minY))
        let maximo = pixelLocal(dePonto: CGPoint(x: retangulo.maxX, y: retangulo.maxY))
        let esquerda = minimo.x.rounded(.toNearestOrEven)
        let topo = minimo.y.rounded(.toNearestOrEven)
        return CGRect(
            x: esquerda,
            y: topo,
            width: maximo.x.rounded(.toNearestOrEven) - esquerda,
            height: maximo.y.rounded(.toNearestOrEven) - topo
        )
    }

    /// Inverso de `pixels(dePontos:)`: pixels locais da tela para o quadro global em pontos.
    public func quadroEmPontos(dePixels pixels: CGRect) -> CGRect {
        CGRect(
            x: quadro.minX + pixels.minX / escala,
            y: quadro.minY + pixels.minY / escala,
            width: pixels.width / escala,
            height: pixels.height / escala
        )
    }
}

/// Escolha da tela a capturar a partir do ponto do cursor.
public enum SelecaoDeTela {
    /// A primeira tela cujo quadro contém o ponto. A borda esquerda e a superior são
    /// inclusivas e a direita e a inferior exclusivas, então a divisa entre duas telas é
    /// da tela à direita ou abaixo. Ponto fora de todas ou não finito usa a principal
    /// (ou a primeira, se nenhuma estiver marcada); lista vazia devolve `nil`.
    public static func escolher(
        entre telas: [DescricaoDeTela],
        sob ponto: CGPoint
    ) -> DescricaoDeTela? {
        if ponto.x.isFinite, ponto.y.isFinite,
            let sob = telas.first(where: { contem($0.quadro, ponto) })
        {
            return sob
        }
        return telas.first(where: \.principal) ?? telas.first
    }

    private static func contem(_ quadro: CGRect, _ ponto: CGPoint) -> Bool {
        ponto.x >= quadro.minX && ponto.x < quadro.maxX
            && ponto.y >= quadro.minY && ponto.y < quadro.maxY
    }
}
