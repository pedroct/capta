import CoreGraphics

/// Uma janela de outro app, independente do ScreenCaptureKit para dar para testar a escolha.
public struct JanelaDeTela: Equatable, Sendable {
    /// `CGWindowID` da janela.
    public let id: UInt32
    /// Quadro em pontos no espaço global do CoreGraphics: origem no canto superior esquerdo
    /// da tela principal, Y para baixo; telas acima ou à esquerda têm coordenadas negativas.
    public let quadro: CGRect
    /// Camada da janela; `0` é a das janelas comuns de app.
    public let camada: Int
    /// Se a janela está visível na tela.
    public let naTela: Bool

    public init(id: UInt32, quadro: CGRect, camada: Int, naTela: Bool) {
        self.id = id
        self.quadro = quadro
        self.camada = camada
        self.naTela = naTela
    }
}

/// Filtro e consultas sobre as janelas que o modo janela do overlay oferece.
public enum ListaDeJanelas {
    /// Fica quem tem `camada == 0`, está na tela e tem os dois lados ao menos
    /// `tamanhoMinimo`. A ordem de entrada é preservada: a primeira é a mais à frente.
    public static func selecionaveis(
        _ janelas: [JanelaDeTela],
        tamanhoMinimo: CGFloat
    ) -> [JanelaDeTela] {
        janelas.filter {
            $0.camada == 0 && $0.naTela
                && $0.quadro.width >= tamanhoMinimo && $0.quadro.height >= tamanhoMinimo
        }
    }

    /// A primeira janela da lista que contém o ponto, ou seja, a mais à frente. A borda
    /// esquerda e a superior são inclusivas e a direita e a inferior exclusivas, como em
    /// `SelecaoDeTela`. Ponto não finito não está em nenhuma janela.
    public static func sob(_ ponto: CGPoint, em janelas: [JanelaDeTela]) -> JanelaDeTela? {
        guard ponto.x.isFinite, ponto.y.isFinite else { return nil }
        return janelas.first { contem($0.quadro, ponto) }
    }

    /// A tela com a maior área de interseção com a janela. No empate vale a tela que contém o
    /// canto superior esquerdo da janela; se nenhuma empatada o contém, a primeira da lista.
    /// Sem interseção com área (ou com quadro não finito) devolve `nil`.
    public static func tela(
        de janela: JanelaDeTela,
        entre telas: [DescricaoDeTela]
    ) -> DescricaoDeTela? {
        let quadro = janela.quadro
        guard
            quadro.origin.x.isFinite, quadro.origin.y.isFinite,
            quadro.width.isFinite, quadro.height.isFinite
        else { return nil }
        let areas = telas.map { area(da: quadro, em: $0.quadro) }
        guard let maior = areas.max(), maior > 0 else { return nil }
        let empatadas = zip(telas, areas).filter { $0.1 == maior }.map(\.0)
        let canto = CGPoint(x: quadro.minX, y: quadro.minY)
        return empatadas.first { contem($0.quadro, canto) } ?? empatadas.first
    }

    private static func area(da janela: CGRect, em tela: CGRect) -> Double {
        let comum = janela.intersection(tela)
        guard !comum.isNull, comum.width.isFinite, comum.height.isFinite else { return 0 }
        return comum.width * comum.height
    }

    private static func contem(_ quadro: CGRect, _ ponto: CGPoint) -> Bool {
        ponto.x >= quadro.minX && ponto.x < quadro.maxX
            && ponto.y >= quadro.minY && ponto.y < quadro.maxY
    }
}
