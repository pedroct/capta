import CoreGraphics
import Foundation

// Rotação (convenção de todo o editor): em torno do centro do retângulo do objeto (da etapa,
// em torno de `centro`), eixo Y para baixo, ângulo positivo = sentido horário na tela.

extension CGRect {
    /// Os quatro cantos girados em torno do centro, e a caixa que os contém.
    fileprivate func caixaGirada(por angulo: Double) -> CGRect {
        guard angulo != 0 else { return self }
        let centro = CGPoint(x: midX, y: midY)
        let cos = Foundation.cos(angulo)
        let sen = Foundation.sin(angulo)
        let cantos = [
            CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: minY),
            CGPoint(x: maxX, y: maxY), CGPoint(x: minX, y: maxY),
        ].map { c -> CGPoint in
            let dx = c.x - centro.x
            let dy = c.y - centro.y
            return CGPoint(x: centro.x + dx * cos - dy * sen, y: centro.y + dx * sen + dy * cos)
        }
        let xs = cantos.map(\.x)
        let ys = cantos.map(\.y)
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else {
            return self
        }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}

extension Anotacao {
    /// Retângulo padronizado, alinhado aos eixos, em pixels do documento, que contém tudo o que
    /// o renderizador pinta do objeto (traço, cabeça da seta, rotação).
    public var limites: CGRect {
        let meioTraco = CGFloat(max(estilo.largura, 0)) / 2
        let base: CGRect
        switch geometria {
        case .seta(let inicio, let fim):
            let comprimento = hypot(fim.x - inicio.x, fim.y - inicio.y)
            let cabeca = tamanhoDaCabeca(largura: estilo.largura, comprimento: comprimento) / 2
            return Self.caixa(inicio, fim).insetBy(
                dx: -max(meioTraco, cabeca),
                dy: -max(meioTraco, cabeca)
            )
        case .linha(let inicio, let fim):
            return Self.caixa(inicio, fim).insetBy(dx: -meioTraco, dy: -meioTraco)
        case .forma(_, let r):
            base = r.standardized.insetBy(dx: -meioTraco, dy: -meioTraco)
        case .etapa(let centro, let diametro, _):
            let raio = CGFloat(diametro) / 2 + meioTraco
            base = CGRect(x: centro.x - raio, y: centro.y - raio, width: raio * 2, height: raio * 2)
        case .texto(let r, _, _, _, _), .carimbo(let r, _), .realce(let r), .desfoque(let r, _, _):
            base = r.standardized
        }
        return base.caixaGirada(por: rotacao)
    }

    private static func caixa(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }

    /// `true` se o ponto (em pixels do documento) acerta o objeto, com a tolerância dada.
    func acerta(_ ponto: CGPoint, tolerancia: CGFloat) -> Bool {
        let meioTraco = CGFloat(max(estilo.largura, 0)) / 2
        switch geometria {
        case .seta(let inicio, let fim), .linha(let inicio, let fim):
            return Self.distancia(de: ponto, ao: inicio, e: fim) <= meioTraco + tolerancia
        case .etapa(let centro, let diametro, _):
            return hypot(ponto.x - centro.x, ponto.y - centro.y)
                <= CGFloat(diametro) / 2 + tolerancia
        case .forma(let tipo, let r):
            let r = r.standardized
            let p = noReferencialDoObjeto(ponto, centro: CGPoint(x: r.midX, y: r.midY))
            if estilo.preenchimento != nil {
                return Self.distanciaComSinal(p, tipo, r) <= tolerancia
            }
            return abs(Self.distanciaComSinal(p, tipo, r)) <= meioTraco + tolerancia
        case .texto(let r, _, _, _, _), .carimbo(let r, _), .realce(let r), .desfoque(let r, _, _):
            let r = r.standardized
            let p = noReferencialDoObjeto(ponto, centro: CGPoint(x: r.midX, y: r.midY))
            return r.insetBy(dx: -tolerancia, dy: -tolerancia).contains(p)
        }
    }

    /// Desfaz a rotação do objeto no ponto (gira de volta, em torno do centro).
    private func noReferencialDoObjeto(_ ponto: CGPoint, centro: CGPoint) -> CGPoint {
        guard rotacao != 0 else { return ponto }
        let cos = Foundation.cos(-rotacao)
        let sen = Foundation.sin(-rotacao)
        let dx = ponto.x - centro.x
        let dy = ponto.y - centro.y
        return CGPoint(x: centro.x + dx * cos - dy * sen, y: centro.y + dx * sen + dy * cos)
    }

    private static func distancia(de p: CGPoint, ao a: CGPoint, e b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let quadrado = dx * dx + dy * dy
        guard quadrado > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = min(max(((p.x - a.x) * dx + (p.y - a.y) * dy) / quadrado, 0), 1)
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    /// Distância com sinal ao contorno da forma (negativa dentro). Para a elipse é a
    /// aproximação de primeira ordem, suficiente para acerto com tolerância.
    private static func distanciaComSinal(_ p: CGPoint, _ tipo: TipoForma, _ r: CGRect) -> CGFloat {
        let dx = p.x - r.midX
        let dy = p.y - r.midY
        let a = r.width / 2
        let b = r.height / 2
        switch tipo {
        case .retangulo, .retanguloArredondado:
            let raio = tipo == .retangulo ? 0 : min(r.width, r.height) * 0.2
            let qx = abs(dx) - (a - raio)
            let qy = abs(dy) - (b - raio)
            return hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - raio
        case .elipse:
            guard a > 0, b > 0 else { return hypot(dx, dy) }
            let f = (dx / a) * (dx / a) + (dy / b) * (dy / b) - 1
            let gradiente = hypot(2 * dx / (a * a), 2 * dy / (b * b))
            // No centro o gradiente some: a distância ao contorno é o menor semieixo.
            guard gradiente > 1e-12 else { return -min(a, b) }
            return f / gradiente
        }
    }
}

extension Documento {
    /// O objeto mais acima que o ponto acerta (de cima para baixo), ou `nil`.
    public func objeto(em ponto: CGPoint, tolerancia: CGFloat) -> UUID? {
        objetos.last { $0.acerta(ponto, tolerancia: tolerancia) }?.id
    }

    /// Ids, na ordem das camadas, dos objetos cujos limites intersectam o retângulo.
    public func objetos(tocando retangulo: CGRect) -> [UUID] {
        let alvo = retangulo.standardized
        return objetos.filter { $0.limites.intersects(alvo) }.map(\.id)
    }

    /// União dos limites dos objetos de `ids`; `nil` se nenhum existe.
    public func limites(de ids: Set<UUID>) -> CGRect? {
        objetos.filter { ids.contains($0.id) }.map(\.limites).reduce(nil) { total, r in
            total.map { $0.union(r) } ?? r
        }
    }
}
