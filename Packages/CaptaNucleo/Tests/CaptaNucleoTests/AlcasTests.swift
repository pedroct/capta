import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private func forma(_ r: CGRect, rotacao: Double = 0) -> Anotacao {
    Anotacao(geometria: .forma(.retangulo, r), rotacao: rotacao)
}

private func retangulo(_ a: Anotacao) -> CGRect? {
    switch a.geometria {
    case .forma(_, let r), .texto(let r, _, _, _, _), .carimbo(let r, _), .realce(let r),
        .desfoque(let r, _, _):
        return r
    default: return nil
    }
}

private func perto(_ a: CGPoint?, _ b: CGPoint, _ tol: Double = 1e-9) -> Bool {
    guard let a else { return false }
    return abs(a.x - b.x) < tol && abs(a.y - b.y) < tol
}

private func igual(_ a: CGRect?, _ b: CGRect, _ tol: Double = 1e-9) -> Bool {
    guard let a else { return false }
    return abs(a.minX - b.minX) < tol && abs(a.minY - b.minY) < tol
        && abs(a.width - b.width) < tol && abs(a.height - b.height) < tol
}

@Test func alcasDaLinhaSaoOsDoisPontos() {
    let linha = Anotacao(geometria: .linha(inicio: CGPoint(x: 1, y: 2), fim: CGPoint(x: 3, y: 4)))
    #expect(linha.alcas() == [.inicio: CGPoint(x: 1, y: 2), .fim: CGPoint(x: 3, y: 4)])
    let seta = Anotacao(geometria: .seta(inicio: CGPoint(x: 1, y: 2), fim: CGPoint(x: 3, y: 4)))
    #expect(seta.alcas().count == 2)
}

@Test func alcasDoRetanguloSaoOito() {
    let alcas = forma(CGRect(x: 0, y: 0, width: 100, height: 20)).alcas()
    #expect(alcas.count == 8)
    #expect(alcas[.canto(.inferiorDireito)] == CGPoint(x: 100, y: 20))
    #expect(alcas[.borda(.superior)] == CGPoint(x: 50, y: 0))
    #expect(alcas[.borda(.esquerda)] == CGPoint(x: 0, y: 10))
}

@Test func alcasDaFormaGiradaGiramJunto() {
    let alcas = forma(CGRect(x: 0, y: 0, width: 100, height: 20), rotacao: .pi / 2).alcas()
    #expect(perto(alcas[.canto(.superiorEsquerdo)], CGPoint(x: 60, y: -40)))
}

@Test func alcasDaEtapaSaoOsCantosDoQuadrado() {
    let etapa = Anotacao(
        geometria: .etapa(centro: CGPoint(x: 10, y: 10), diametro: 20, reiniciaSequencia: false)
    )
    let alcas = etapa.alcas()
    #expect(alcas.count == 4)
    #expect(alcas[.canto(.superiorEsquerdo)] == CGPoint(x: 0, y: 0))
    #expect(alcas[.canto(.inferiorDireito)] == CGPoint(x: 20, y: 20))
}

@Test func arrastarCantoMantemOpostoParado() {
    let a = forma(CGRect(x: 10, y: 10, width: 100, height: 50))
        .arrastando(.canto(.inferiorDireito), ate: CGPoint(x: 200, y: 100), restrito: false)
    #expect(igual(retangulo(a), CGRect(x: 10, y: 10, width: 190, height: 90)))
}

@Test func arrastarCantoDeFormaGiradaMantemOpostoNoMundo() {
    let original = forma(CGRect(x: 0, y: 0, width: 100, height: 20), rotacao: .pi / 2)
    let antes = original.alcas()[.canto(.inferiorDireito)]
    let depois = original.arrastando(
        .canto(.superiorEsquerdo),
        ate: CGPoint(x: 70, y: -80),
        restrito: false
    )
    #expect(perto(depois.alcas()[.canto(.inferiorDireito)], antes ?? .zero))
    #expect(perto(depois.alcas()[.canto(.superiorEsquerdo)], CGPoint(x: 70, y: -80)))
    #expect(depois.rotacao == .pi / 2)
}

@Test func arrastarBordaDeFormaGiradaMantemBordaOpostaNoMundo() {
    let original = forma(CGRect(x: 0, y: 0, width: 100, height: 20), rotacao: 0.7)
    let antes = original.alcas()[.borda(.esquerda)]
    let depois = original.arrastando(.borda(.direita), ate: CGPoint(x: 150, y: 60), restrito: false)
    #expect(perto(depois.alcas()[.borda(.esquerda)], antes ?? .zero))
}

@Test func arrastarBordaSoMexeUmLado() {
    let a = forma(CGRect(x: 10, y: 10, width: 100, height: 50))
        .arrastando(.borda(.direita), ate: CGPoint(x: 200, y: 999), restrito: false)
    #expect(igual(retangulo(a), CGRect(x: 10, y: 10, width: 190, height: 50)))
    let b = forma(CGRect(x: 10, y: 10, width: 100, height: 50))
        .arrastando(.borda(.superior), ate: CGPoint(x: 999, y: 0), restrito: false)
    #expect(igual(retangulo(b), CGRect(x: 10, y: 0, width: 100, height: 60)))
    let c = forma(CGRect(x: 10, y: 10, width: 100, height: 50))
        .arrastando(.borda(.esquerda), ate: CGPoint(x: 0, y: 999), restrito: false)
    #expect(igual(retangulo(c), CGRect(x: 0, y: 10, width: 110, height: 50)))
    let d = forma(CGRect(x: 10, y: 10, width: 100, height: 50))
        .arrastando(.borda(.inferior), ate: CGPoint(x: 999, y: 100), restrito: false)
    #expect(igual(retangulo(d), CGRect(x: 10, y: 10, width: 100, height: 90)))
}

@Test func arrastarAlemDoOpostoInverte() {
    let a = forma(CGRect(x: 10, y: 10, width: 100, height: 50))
        .arrastando(.canto(.inferiorDireito), ate: CGPoint(x: 0, y: 0), restrito: false)
    #expect(igual(retangulo(a)?.standardized, CGRect(x: 0, y: 0, width: 10, height: 10)))
}

@Test func cantoRestritoMantemProporcao() {
    let a = forma(CGRect(x: 0, y: 0, width: 100, height: 50))
        .arrastando(.canto(.inferiorDireito), ate: CGPoint(x: 300, y: 60), restrito: true)
    #expect(igual(retangulo(a), CGRect(x: 0, y: 0, width: 300, height: 150)))
    let b = forma(CGRect(x: 0, y: 0, width: 100, height: 50))
        .arrastando(.canto(.inferiorDireito), ate: CGPoint(x: 120, y: 200), restrito: true)
    #expect(igual(retangulo(b), CGRect(x: 0, y: 0, width: 400, height: 200)))
    let c = forma(CGRect(x: 0, y: 0, width: 0, height: 50))
        .arrastando(.canto(.inferiorDireito), ate: CGPoint(x: 30, y: 70), restrito: true)
    #expect(igual(retangulo(c), CGRect(x: 0, y: 0, width: 30, height: 70)))
}

@Test func setaRestritaPrendeEm45Graus() {
    let seta = Anotacao(geometria: .seta(inicio: .zero, fim: CGPoint(x: 50, y: 50)))
    let a = seta.arrastando(.fim, ate: CGPoint(x: 100, y: 10), restrito: true)
    guard case .seta(_, let fim) = a.geometria else {
        Issue.record("não é seta")
        return
    }
    #expect(perto(fim, CGPoint(x: Foundation.hypot(100.0, 10.0), y: 0)))
    let livre = seta.arrastando(.fim, ate: CGPoint(x: 100, y: 10), restrito: false)
    guard case .seta(_, let fimLivre) = livre.geometria else {
        Issue.record("não é seta")
        return
    }
    #expect(fimLivre == CGPoint(x: 100, y: 10))
}

@Test func linhaMoveOInicio() {
    let linha = Anotacao(geometria: .linha(inicio: .zero, fim: CGPoint(x: 10, y: 0)))
    let a = linha.arrastando(.inicio, ate: CGPoint(x: 10, y: 10), restrito: true)
    guard case .linha(let inicio, let fim) = a.geometria else {
        Issue.record("não é linha")
        return
    }
    #expect(fim == CGPoint(x: 10, y: 0))
    #expect(perto(inicio, CGPoint(x: 10, y: 10)))
}

@Test func alcaQueNaoExisteNaoMudaNada() {
    let f = forma(CGRect(x: 0, y: 0, width: 10, height: 10))
    #expect(f.arrastando(.inicio, ate: CGPoint(x: 5, y: 5), restrito: false) == f)
    let seta = Anotacao(geometria: .seta(inicio: .zero, fim: CGPoint(x: 10, y: 0)))
    #expect(seta.arrastando(.canto(.superiorDireito), ate: .zero, restrito: false) == seta)
}

@Test func etapaRedimensionaPeloDiametro() {
    let etapa = Anotacao(
        geometria: .etapa(centro: CGPoint(x: 10, y: 10), diametro: 20, reiniciaSequencia: true)
    )
    let a = etapa.arrastando(.canto(.inferiorDireito), ate: CGPoint(x: 60, y: 40), restrito: false)
    guard case .etapa(let centro, let diametro, let reinicia) = a.geometria else {
        Issue.record("não é etapa")
        return
    }
    #expect(abs(diametro - 60) < 1e-9)
    #expect(perto(centro, CGPoint(x: 30, y: 30)))
    #expect(reinicia)
    #expect(etapa.arrastando(.borda(.superior), ate: .zero, restrito: false) == etapa)
}

@Test func carimboSempreProporcional() {
    let c = Anotacao(geometria: .carimbo(CGRect(x: 0, y: 0, width: 40, height: 20), simbolo: "x"))
    let a = c.arrastando(.canto(.inferiorDireito), ate: CGPoint(x: 80, y: 30), restrito: false)
    #expect(igual(retangulo(a), CGRect(x: 0, y: 0, width: 80, height: 40)))
    let b = c.arrastando(.borda(.direita), ate: CGPoint(x: 80, y: 0), restrito: false)
    #expect(igual(retangulo(b), CGRect(x: 0, y: -10, width: 80, height: 40)))
    let d = c.arrastando(.borda(.inferior), ate: CGPoint(x: 0, y: 40), restrito: false)
    #expect(igual(retangulo(d), CGRect(x: -20, y: 0, width: 80, height: 40)))
}

@Test func pontoDeGiroFicaAcimaDaBordaSuperior() {
    let f = forma(CGRect(x: 0, y: 0, width: 100, height: 20))
    #expect(perto(f.pontoDeGiro(distancia: 30), CGPoint(x: 50, y: -30)))
    let g = forma(CGRect(x: 0, y: 0, width: 100, height: 20), rotacao: .pi / 2)
    #expect(perto(g.pontoDeGiro(distancia: 30), CGPoint(x: 90, y: 10)))
    let etapa = Anotacao(
        geometria: .etapa(centro: CGPoint(x: 10, y: 10), diametro: 20, reiniciaSequencia: false)
    )
    #expect(perto(etapa.pontoDeGiro(distancia: 5), CGPoint(x: 10, y: -5)))
}

@Test func pontoDeGiroDaLinhaENil() {
    let linha = Anotacao(geometria: .linha(inicio: .zero, fim: CGPoint(x: 10, y: 0)))
    #expect(linha.pontoDeGiro(distancia: 10) == nil)
    #expect(!linha.aceitaRotacao)
    #expect(!Anotacao(geometria: .desfoque(.zero, .borrar, intensidade: 1)).aceitaRotacao)
    #expect(forma(.zero).aceitaRotacao)
}

@Test func girarPoeOPontoDeGiroNaDirecaoDoCursor() {
    let f = forma(CGRect(x: -50, y: -10, width: 100, height: 20))
    let a = f.girando(ate: CGPoint(x: 100, y: 0), restrito: false)
    #expect(a.rotacao == .pi / 2)
    let giro = a.pontoDeGiro(distancia: 30)
    #expect(perto(giro, CGPoint(x: 40, y: 0)))
}

@Test func girarPrendeEm15Graus() {
    let f = forma(CGRect(x: -50, y: -10, width: 100, height: 20))
    let alvo = 50 * Double.pi / 180
    let cursor = CGPoint(x: 100 * sin(alvo), y: -100 * cos(alvo))
    #expect(f.girando(ate: cursor, restrito: true).rotacao == 45 * .pi / 180)
    #expect(abs(f.girando(ate: cursor, restrito: false).rotacao - alvo) < 1e-12)
}

@Test func girarEtapaUsaOCentro() {
    let etapa = Anotacao(
        geometria: .etapa(centro: CGPoint(x: 10, y: 10), diametro: 20, reiniciaSequencia: false)
    )
    #expect(etapa.girando(ate: CGPoint(x: 10, y: 50), restrito: false).rotacao == .pi)
}

@Test func girarSetaNaoMudaNada() {
    let seta = Anotacao(geometria: .seta(inicio: .zero, fim: CGPoint(x: 10, y: 0)))
    #expect(seta.girando(ate: CGPoint(x: 5, y: 5), restrito: false) == seta)
    let f = forma(CGRect(x: -5, y: -5, width: 10, height: 10))
    #expect(f.girando(ate: .zero, restrito: false) == f)
}

@Test func arrastarCantoDeEtapaGiradaMantemOpostoNoMundo() {
    let etapa = Anotacao(
        geometria: .etapa(centro: CGPoint(x: 10, y: 10), diametro: 20, reiniciaSequencia: false),
        rotacao: 0.5
    )
    let antes = etapa.alcas()[.canto(.inferiorDireito)]
    let depois = etapa.arrastando(
        .canto(.superiorEsquerdo),
        ate: CGPoint(x: -30, y: -20),
        restrito: false
    )
    #expect(perto(depois.alcas()[.canto(.inferiorDireito)], antes ?? .zero))
}
