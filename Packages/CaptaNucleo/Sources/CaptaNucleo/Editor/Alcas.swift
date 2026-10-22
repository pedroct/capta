import CoreGraphics
import Foundation

// Mesma convenção de rotação de `Limites.swift`: em torno do centro do retângulo do objeto
// (da etapa, em torno de `centro`), eixo Y para baixo, ângulo positivo = sentido horário.

/// Alça de edição de um objeto selecionado.
public enum AlcaDeObjeto: Hashable, Sendable {
    case inicio, fim
    case canto(CantoDoObjeto)
    case borda(BordaDoObjeto)
}

public enum CantoDoObjeto: Hashable, Sendable {
    case superiorEsquerdo, superiorDireito, inferiorEsquerdo, inferiorDireito

    /// Sinal de cada eixo do canto no referencial local (-1 esquerda/cima, +1 direita/baixo).
    fileprivate var sinais: (x: CGFloat, y: CGFloat) {
        switch self {
        case .superiorEsquerdo: (-1, -1)
        case .superiorDireito: (1, -1)
        case .inferiorEsquerdo: (-1, 1)
        case .inferiorDireito: (1, 1)
        }
    }
}

public enum BordaDoObjeto: Hashable, Sendable {
    case superior, inferior, esquerda, direita

    fileprivate var sinais: (x: CGFloat, y: CGFloat) {
        switch self {
        case .superior: (0, -1)
        case .inferior: (0, 1)
        case .esquerda: (-1, 0)
        case .direita: (1, 0)
        }
    }
}

extension CGPoint {
    /// Gira o vetor `self` pelo ângulo (horário na tela, Y para baixo).
    fileprivate func girado(por angulo: Double) -> CGPoint {
        let c = CGFloat(cos(angulo))
        let s = CGFloat(sin(angulo))
        return CGPoint(x: x * c - y * s, y: x * s + y * c)
    }

    fileprivate func somado(a outro: CGPoint) -> CGPoint {
        CGPoint(x: x + outro.x, y: y + outro.y)
    }
}

extension Anotacao {
    /// Retângulo (não girado) que as alças de redimensionar descrevem; `nil` para seta e linha.
    private var retanguloDeAlcas: CGRect? {
        switch geometria {
        case .seta, .linha: nil
        case .etapa(let centro, let diametro, _):
            CGRect(
                x: centro.x - diametro / 2,
                y: centro.y - diametro / 2,
                width: diametro,
                height: diametro
            )
        case .forma(_, let r), .texto(let r, _, _, _, _), .carimbo(let r, _), .realce(let r),
            .desfoque(let r, _, _):
            r.standardized
        }
    }

    private var ehEtapa: Bool {
        if case .etapa = geometria { return true }
        return false
    }

    private var ehCarimbo: Bool {
        if case .carimbo = geometria { return true }
        return false
    }

    public var aceitaRotacao: Bool {
        switch geometria {
        case .forma, .texto, .carimbo, .realce, .etapa: true
        case .seta, .linha, .desfoque: false
        }
    }

    /// Pontos das alças, em pixels do documento, já girados com o objeto.
    public func alcas() -> [AlcaDeObjeto: CGPoint] {
        switch geometria {
        case .seta(let inicio, let fim), .linha(let inicio, let fim):
            return [.inicio: inicio, .fim: fim]
        default: break
        }
        guard let r = retanguloDeAlcas else { return [:] }
        let centro = CGPoint(x: r.midX, y: r.midY)
        func mundo(_ sx: CGFloat, _ sy: CGFloat) -> CGPoint {
            CGPoint(x: sx * r.width / 2, y: sy * r.height / 2).girado(por: rotacao)
                .somado(a: centro)
        }
        var alcas: [AlcaDeObjeto: CGPoint] = [:]
        for canto in [
            CantoDoObjeto.superiorEsquerdo, .superiorDireito, .inferiorEsquerdo, .inferiorDireito,
        ] {
            alcas[.canto(canto)] = mundo(canto.sinais.x, canto.sinais.y)
        }
        guard !ehEtapa else { return alcas }
        for borda in [BordaDoObjeto.superior, .inferior, .esquerda, .direita] {
            alcas[.borda(borda)] = mundo(borda.sinais.x, borda.sinais.y)
        }
        return alcas
    }

    /// Meio da borda superior, afastado `distancia` para fora e girado; `nil` sem rotação.
    public func pontoDeGiro(distancia: CGFloat) -> CGPoint? {
        guard aceitaRotacao, let r = retanguloDeAlcas else { return nil }
        let centro = CGPoint(x: r.midX, y: r.midY)
        return CGPoint(x: 0, y: -(r.height / 2 + distancia)).girado(por: rotacao).somado(a: centro)
    }

    /// Move a alça até `ponto`; o canto ou a borda oposta fica parado no mundo.
    public func arrastando(
        _ alca: AlcaDeObjeto,
        ate ponto: CGPoint,
        restrito: Bool
    ) -> Anotacao {
        var copia = self
        switch (geometria, alca) {
        case (.seta(_, let fim), .inicio):
            copia.geometria = .seta(inicio: Self.prender(ponto, em: fim, restrito), fim: fim)
        case (.seta(let inicio, _), .fim):
            copia.geometria = .seta(inicio: inicio, fim: Self.prender(ponto, em: inicio, restrito))
        case (.linha(_, let fim), .inicio):
            copia.geometria = .linha(inicio: Self.prender(ponto, em: fim, restrito), fim: fim)
        case (.linha(let inicio, _), .fim):
            copia.geometria = .linha(inicio: inicio, fim: Self.prender(ponto, em: inicio, restrito))
        case (_, .canto(let canto)):
            copia.redimensionar(sinais: canto.sinais, ate: ponto, restrito: restrito)
        case (_, .borda(let borda)):
            copia.redimensionar(sinais: borda.sinais, ate: ponto, restrito: restrito)
        default: break
        }
        return copia
    }

    /// Com restrição, leva o ângulo de `ancora` até `ponto` ao múltiplo de 45° mais próximo,
    /// mantendo o comprimento.
    private static func prender(_ ponto: CGPoint, em ancora: CGPoint, _ restrito: Bool) -> CGPoint {
        guard restrito else { return ponto }
        let dx = ponto.x - ancora.x
        let dy = ponto.y - ancora.y
        let passo = Double.pi / 4
        let angulo = (atan2(dy, dx) / passo).rounded() * passo
        let comprimento = hypot(dx, dy)
        return CGPoint(
            x: ancora.x + comprimento * CGFloat(cos(angulo)),
            y: ancora.y + comprimento * CGFloat(sin(angulo))
        )
    }

    /// Redimensiona no referencial local e recalcula o centro, para que o lado oposto à alça
    /// (canto ou meio da borda) volte ao mesmo ponto do mundo. `sinais` é a direção da alça
    /// a partir do centro: (±1, ±1) num canto, um eixo zero numa borda.
    private mutating func redimensionar(
        sinais: (x: CGFloat, y: CGFloat),
        ate ponto: CGPoint,
        restrito: Bool
    ) {
        guard let r = retanguloDeAlcas, sinais.x != 0 || sinais.y != 0 else { return }
        let centro = CGPoint(x: r.midX, y: r.midY)
        let ancora = CGPoint(x: -sinais.x * r.width / 2, y: -sinais.y * r.height / 2)
            .girado(por: rotacao).somado(a: centro)
        // Vetor da âncora ao cursor, nos eixos locais do objeto.
        var u = CGPoint(x: ponto.x - ancora.x, y: ponto.y - ancora.y).girado(por: -rotacao)
        if sinais.x == 0 { u.x = 0 }
        if sinais.y == 0 { u.y = 0 }
        var largura = abs(u.x)
        var altura = abs(u.y)
        var direcao = (
            x: u.x < 0 ? CGFloat(-1) : (u.x > 0 ? 1 : sinais.x),
            y: u.y < 0 ? CGFloat(-1) : (u.y > 0 ? 1 : sinais.y)
        )
        let proporcional = ehEtapa || ehCarimbo || (restrito && sinais.x != 0 && sinais.y != 0)
        if proporcional, r.width > 0, r.height > 0 {
            let k: CGFloat
            switch (sinais.x != 0, sinais.y != 0) {
            case (true, true): k = max(largura / r.width, altura / r.height)
            case (true, false): k = largura / r.width
            default: k = altura / r.height
            }
            largura = k * r.width
            altura = k * r.height
            if sinais.x == 0 { direcao.x = 0 }
            if sinais.y == 0 { direcao.y = 0 }
        } else {
            if sinais.x == 0 { largura = r.width }
            if sinais.y == 0 { altura = r.height }
        }
        // Centro novo: da âncora, metade da extensão na direção do arrasto (eixo livre: zero).
        let deslocamento = CGPoint(x: direcao.x * largura / 2, y: direcao.y * altura / 2)
            .girado(por: rotacao)
        let novoCentro = ancora.somado(a: deslocamento)
        aplicar(centro: novoCentro, largura: largura, altura: altura)
    }

    private mutating func aplicar(centro: CGPoint, largura: CGFloat, altura: CGFloat) {
        let novo = CGRect(
            x: centro.x - largura / 2,
            y: centro.y - altura / 2,
            width: largura,
            height: altura
        )
        switch geometria {
        case .etapa(_, _, let reinicia):
            geometria = .etapa(
                centro: centro,
                diametro: Double(largura),
                reiniciaSequencia: reinicia
            )
        case .forma(let tipo, _): geometria = .forma(tipo, novo)
        case .texto(_, let c, let t, let n, let i):
            geometria = .texto(novo, conteudo: c, tamanhoFonte: t, negrito: n, italico: i)
        case .carimbo(_, let simbolo): geometria = .carimbo(novo, simbolo: simbolo)
        case .realce: geometria = .realce(novo)
        case .desfoque(_, let tipo, let intensidade):
            geometria = .desfoque(novo, tipo, intensidade: intensidade)
        case .seta, .linha: break
        }
    }

    /// Gira o objeto para que o ponto de giro fique na direção do cursor; com `restrito`, em
    /// múltiplos de 15°. Sem efeito em quem não aceita rotação.
    public func girando(ate ponto: CGPoint, restrito: Bool) -> Anotacao {
        guard aceitaRotacao, let r = retanguloDeAlcas else { return self }
        let dx = ponto.x - r.midX
        let dy = ponto.y - r.midY
        guard dx != 0 || dy != 0 else { return self }
        // O ponto de giro nasce "para cima" (0, -1); o ângulo horário que o leva a (dx, dy).
        var angulo = atan2(dx, -dy)
        if restrito {
            angulo = (angulo / (Double.pi / 12)).rounded() * 15 * Double.pi / 180
        }
        var copia = self
        copia.rotacao = angulo
        return copia
    }
}
