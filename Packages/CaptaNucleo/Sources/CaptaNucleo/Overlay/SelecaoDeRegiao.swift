import CoreGraphics
import Foundation

/// Ponto de pegada de uma seleção: quatro lados e quatro cantos.
public enum Alca: Equatable, Sendable {
    case cima, baixo, esquerda, direita
    case cantoSuperiorEsquerdo, cantoSuperiorDireito
    case cantoInferiorEsquerdo, cantoInferiorDireito
}

/// Resultado do teste de acerto de um ponto contra a seleção.
public enum Acerto: Equatable, Sendable {
    case fora
    case dentro
    case borda(Alca)
}

/// Região escolhida no overlay, em pixels nativos inteiros da tela.
///
/// Origem no canto superior esquerdo da tela, Y para baixo. `pixels` é sempre
/// inteiro, fica dentro de `(0, 0, limites)` e tem lados de pelo menos 1.
/// Pontos fracionários chegam em pixels locais (ver `DescricaoDeTela.pixelLocal(dePonto:)`).
public struct SelecaoDeRegiao: Equatable, Sendable {
    public let telaId: UInt32
    public let pixels: CGRect
    public let limites: CGSize

    /// Limites inteiros usados nas contas (sempre pelo menos 1 em cada eixo).
    private var largura: Int { Self.limiteInteiro(limites.width) }
    private var altura: Int { Self.limiteInteiro(limites.height) }

    private init(
        telaId: UInt32,
        limites: CGSize,
        esquerda: Int,
        cima: Int,
        direita: Int,
        baixo: Int
    ) {
        self.telaId = telaId
        self.limites = limites
        self.pixels = CGRect(x: esquerda, y: cima, width: direita - esquerda, height: baixo - cima)
    }

    /// Seleção por arrasto de `de` até `ate`, em qualquer direção.
    /// Aplica `floor` nas duas pontas, limita à tela e devolve `nil` se a largura ou a altura ficar 0.
    public static func arrasto(
        telaId: UInt32,
        limites: CGSize,
        de: CGPoint,
        ate: CGPoint
    ) -> SelecaoDeRegiao? {
        let larg = limiteInteiro(limites.width)
        let alt = limiteInteiro(limites.height)
        let x0 = coordenada(de.x, maximo: larg)
        let x1 = coordenada(ate.x, maximo: larg)
        let y0 = coordenada(de.y, maximo: alt)
        let y1 = coordenada(ate.y, maximo: alt)
        guard x0 != x1, y0 != y1 else { return nil }
        return SelecaoDeRegiao(
            telaId: telaId,
            limites: limites,
            esquerda: min(x0, x1),
            cima: min(y0, y1),
            direita: max(x0, x1),
            baixo: max(y0, y1)
        )
    }

    /// Seleção que cobre a tela toda.
    public static func telaInteira(telaId: UInt32, limites: CGSize) -> SelecaoDeRegiao {
        SelecaoDeRegiao(
            telaId: telaId,
            limites: limites,
            esquerda: 0,
            cima: 0,
            direita: limiteInteiro(limites.width),
            baixo: limiteInteiro(limites.height)
        )
    }

    /// Desloca a seleção; o tamanho se mantém e ela fica presa à tela.
    public func movida(dx: Int, dy: Int) -> SelecaoDeRegiao {
        let l = Int(pixels.width)
        let a = Int(pixels.height)
        let x = min(max(Int(pixels.minX) + dx, 0), largura - l)
        let y = min(max(Int(pixels.minY) + dy, 0), altura - a)
        return SelecaoDeRegiao(
            telaId: telaId,
            limites: limites,
            esquerda: x,
            cima: y,
            direita: x + l,
            baixo: y + a
        )
    }

    /// Arrasta uma alça até `ponto` (pixels locais). A borda oposta fica fixa; ao cruzá-la a
    /// seleção inverte. O ponto fora da tela é preso à tela; o lado mínimo é 1.
    public func redimensionada(alca: Alca, para ponto: CGPoint) -> SelecaoDeRegiao {
        var esquerda = Int(pixels.minX)
        var direita = Int(pixels.maxX)
        var cima = Int(pixels.minY)
        var baixo = Int(pixels.maxY)
        let x = Self.coordenada(ponto.x, maximo: largura)
        let y = Self.coordenada(ponto.y, maximo: altura)

        switch alca {
        case .esquerda, .cantoSuperiorEsquerdo, .cantoInferiorEsquerdo: esquerda = x
        case .direita, .cantoSuperiorDireito, .cantoInferiorDireito: direita = x
        case .cima, .baixo: break
        }
        switch alca {
        case .cima, .cantoSuperiorEsquerdo, .cantoSuperiorDireito: cima = y
        case .baixo, .cantoInferiorEsquerdo, .cantoInferiorDireito: baixo = y
        case .esquerda, .direita: break
        }

        let (e, d) = Self.normalizado(esquerda, direita, maximo: largura)
        let (c, b) = Self.normalizado(cima, baixo, maximo: altura)
        return SelecaoDeRegiao(
            telaId: telaId,
            limites: limites,
            esquerda: e,
            cima: c,
            direita: d,
            baixo: b
        )
    }

    /// Testa um ponto contra a seleção. Prioridade: cantos, depois bordas, depois dentro.
    /// A tolerância é a distância máxima (inclusive) até o canto ou a borda, nos dois sentidos.
    /// Com mais de uma alça ao alcance, vence a mais próxima (empate: ordem canto/lado do enum).
    public func acerto(em ponto: CGPoint, tolerancia: CGFloat) -> Acerto {
        let e = pixels.minX, d = pixels.maxX, c = pixels.minY, b = pixels.maxY

        let cantos: [(Alca, CGPoint)] = [
            (.cantoSuperiorEsquerdo, CGPoint(x: e, y: c)),
            (.cantoSuperiorDireito, CGPoint(x: d, y: c)),
            (.cantoInferiorEsquerdo, CGPoint(x: e, y: b)),
            (.cantoInferiorDireito, CGPoint(x: d, y: b)),
        ]
        if let canto = Self.maisProxima(
            cantos.compactMap { alca, p in
                let dx = abs(ponto.x - p.x), dy = abs(ponto.y - p.y)
                return dx <= tolerancia && dy <= tolerancia ? (alca, hypot(dx, dy)) : nil
            }
        ) {
            return .borda(canto)
        }

        let dentroDoVao = ponto.x >= e - tolerancia && ponto.x <= d + tolerancia
        let dentroDaAltura = ponto.y >= c - tolerancia && ponto.y <= b + tolerancia
        var lados: [(Alca, CGFloat)] = []
        if dentroDoVao {
            lados += [(.cima, abs(ponto.y - c)), (.baixo, abs(ponto.y - b))]
        }
        if dentroDaAltura {
            lados += [(.esquerda, abs(ponto.x - e)), (.direita, abs(ponto.x - d))]
        }
        if let lado = Self.maisProxima(lados.filter { $0.1 <= tolerancia }) {
            return .borda(lado)
        }

        return pixels.contains(ponto) ? .dentro : .fora
    }

    // MARK: - Aritmética inteira

    private static func limiteInteiro(_ valor: CGFloat) -> Int {
        guard valor.isFinite else { return 1 }
        return max(1, Int(min(valor.rounded(.down), CGFloat(Int32.max))))
    }

    /// `floor` preso a `0...maximo`; valores não finitos viram a borda mais próxima (NaN, 0).
    private static func coordenada(_ valor: CGFloat, maximo: Int) -> Int {
        guard !valor.isNaN else { return 0 }
        let preso = min(max(valor.rounded(.down), 0), CGFloat(maximo))
        return Int(preso)
    }

    /// Ordena as pontas e garante lado mínimo 1, crescendo para o lado livre da tela.
    private static func normalizado(_ a: Int, _ b: Int, maximo: Int) -> (Int, Int) {
        var menor = min(a, b)
        var maior = max(a, b)
        if menor == maior {
            if maior < maximo { maior += 1 } else { menor -= 1 }
        }
        return (menor, maior)
    }

    private static func maisProxima(_ candidatas: [(Alca, CGFloat)]) -> Alca? {
        var melhor: (Alca, CGFloat)?
        for candidata in candidatas where melhor.map({ candidata.1 < $0.1 }) ?? true {
            melhor = candidata
        }
        return melhor?.0
    }
}
