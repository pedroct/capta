import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private func estilo(largura: Double = 0, preenchimento: CorRGBA? = nil) -> Estilo {
    var e = Estilo()
    e.largura = largura
    e.preenchimento = preenchimento
    return e
}

private func documento(_ anotacoes: [Anotacao]) throws -> Documento {
    var s = SessaoEdicao(
        documento: .novo(tamanhoBase: CGSize(width: 500, height: 500), escala: 1)
    )
    for a in anotacoes { try s.aplicar(.adicionar(a)) }
    return s.documento
}

private func forma(
    _ tipo: TipoForma,
    _ r: CGRect,
    largura: Double = 0,
    cheia: Bool = false,
    rotacao: Double = 0
) -> Anotacao {
    Anotacao(
        geometria: .forma(tipo, r),
        estilo: estilo(largura: largura, preenchimento: cheia ? .branco : nil),
        rotacao: rotacao
    )
}

@Test func acertoPegaOObjetoDeCima() throws {
    let r = CGRect(x: 0, y: 0, width: 50, height: 50)
    let a = forma(.retangulo, r, cheia: true)
    let b = forma(.retangulo, r, cheia: true)
    let doc = try documento([a, b])
    #expect(doc.objeto(em: CGPoint(x: 25, y: 25), tolerancia: 2) == b.id)
    #expect(doc.objeto(em: CGPoint(x: 200, y: 200), tolerancia: 2) == nil)
}

@Test func formaSemPreenchimentoSoAcertaNoContorno() throws {
    let f = forma(.retangulo, CGRect(x: 0, y: 0, width: 100, height: 100), largura: 2)
    let doc = try documento([f])
    #expect(doc.objeto(em: CGPoint(x: 50, y: 50), tolerancia: 4) == nil)
    #expect(doc.objeto(em: CGPoint(x: 2, y: 50), tolerancia: 4) == f.id)
    #expect(doc.objeto(em: CGPoint(x: 106, y: 50), tolerancia: 4) == nil)
}

@Test func elipseEArredondadoSemPreenchimentoAcertamNoContorno() throws {
    let e = forma(.elipse, CGRect(x: 0, y: 0, width: 100, height: 60), largura: 2)
    let r = forma(.retanguloArredondado, CGRect(x: 200, y: 0, width: 100, height: 60), largura: 2)
    let doc = try documento([e, r])
    #expect(doc.objeto(em: CGPoint(x: 0, y: 30), tolerancia: 2) == e.id)
    #expect(doc.objeto(em: CGPoint(x: 50, y: 30), tolerancia: 2) == nil)
    #expect(doc.objeto(em: CGPoint(x: 50, y: 0), tolerancia: 2) == e.id)
    #expect(doc.objeto(em: CGPoint(x: 250, y: 0), tolerancia: 2) == r.id)
    #expect(doc.objeto(em: CGPoint(x: 250, y: 30), tolerancia: 2) == nil)
}

@Test func formasPreenchidasAcertamPorDentroComTolerancia() throws {
    let e = forma(.elipse, CGRect(x: 0, y: 0, width: 100, height: 60), cheia: true)
    let r = forma(.retanguloArredondado, CGRect(x: 200, y: 0, width: 100, height: 60), cheia: true)
    let doc = try documento([e, r])
    #expect(doc.objeto(em: CGPoint(x: 50, y: 30), tolerancia: 2) == e.id)
    #expect(doc.objeto(em: CGPoint(x: 102, y: 30), tolerancia: 3) == e.id)
    #expect(doc.objeto(em: CGPoint(x: 0, y: 0), tolerancia: 2) == nil)
    #expect(doc.objeto(em: CGPoint(x: 250, y: 30), tolerancia: 2) == r.id)
    #expect(doc.objeto(em: CGPoint(x: 200, y: 0), tolerancia: 2) == nil)
}

@Test func linhaFinaAcertaComATolerancia() throws {
    let l = Anotacao(
        geometria: .linha(inicio: .zero, fim: CGPoint(x: 100, y: 0)),
        estilo: estilo(largura: 1)
    )
    let doc = try documento([l])
    #expect(doc.objeto(em: CGPoint(x: 50, y: 4.4), tolerancia: 4) == l.id)
    #expect(doc.objeto(em: CGPoint(x: 50, y: 4.6), tolerancia: 4) == nil)
    // Além das pontas: a distância é até a extremidade.
    #expect(doc.objeto(em: CGPoint(x: -4, y: 0), tolerancia: 4) == l.id)
    #expect(doc.objeto(em: CGPoint(x: -6, y: 0), tolerancia: 4) == nil)
}

@Test func setaDegeneradaAcertaPeloPonto() throws {
    let s = Anotacao(
        geometria: .seta(inicio: CGPoint(x: 5, y: 5), fim: CGPoint(x: 5, y: 5)),
        estilo: estilo(largura: 2)
    )
    let doc = try documento([s])
    #expect(doc.objeto(em: CGPoint(x: 6, y: 5), tolerancia: 1) == s.id)
    #expect(doc.objeto(em: CGPoint(x: 20, y: 5), tolerancia: 1) == nil)
}

@Test func acertoEmTextoGirado() throws {
    let t = Anotacao(
        geometria: .texto(
            CGRect(x: 0, y: 0, width: 100, height: 20),
            conteudo: "a",
            tamanhoFonte: 12,
            negrito: false,
            italico: false
        ),
        rotacao: .pi / 2
    )
    let doc = try documento([t])
    // Centro (50,10): girado 90°, o texto ocupa x em 40...60 e y em -40...60.
    #expect(doc.objeto(em: CGPoint(x: 50, y: 50), tolerancia: 0) == t.id)
    #expect(doc.objeto(em: CGPoint(x: 90, y: 10), tolerancia: 0) == nil)
}

@Test func acertoEmEtapaCarimboRealceEDesfoque() throws {
    let etapa = Anotacao(
        geometria: .etapa(centro: CGPoint(x: 50, y: 50), diametro: 20, reiniciaSequencia: false)
    )
    let carimbo = Anotacao(
        geometria: .carimbo(CGRect(x: 100, y: 0, width: 20, height: 20), simbolo: "x")
    )
    let realce = Anotacao(geometria: .realce(CGRect(x: 200, y: 0, width: 20, height: 20)))
    let desfoque = Anotacao(
        geometria: .desfoque(CGRect(x: 300, y: 0, width: 20, height: 20), .borrar, intensidade: 5)
    )
    let doc = try documento([etapa, carimbo, realce, desfoque])
    #expect(doc.objeto(em: CGPoint(x: 50, y: 59), tolerancia: 0) == etapa.id)
    #expect(doc.objeto(em: CGPoint(x: 59, y: 59), tolerancia: 0) == nil)
    #expect(doc.objeto(em: CGPoint(x: 110, y: 10), tolerancia: 0) == carimbo.id)
    #expect(doc.objeto(em: CGPoint(x: 210, y: 10), tolerancia: 0) == realce.id)
    #expect(doc.objeto(em: CGPoint(x: 310, y: 10), tolerancia: 0) == desfoque.id)
}

@Test func formaPreenchidaContaAMetadeDeForaDoTraco() throws {
    // Traço de 10: a metade de fora (5) é parte do desenho, mesmo com tolerância 0.
    let f = forma(.retangulo, CGRect(x: 0, y: 0, width: 100, height: 100), largura: 10, cheia: true)
    let doc = try documento([f])
    #expect(doc.objeto(em: CGPoint(x: 103, y: 50), tolerancia: 0) == f.id)
    #expect(doc.objeto(em: CGPoint(x: 105, y: 50), tolerancia: 0) == f.id)
    #expect(doc.objeto(em: CGPoint(x: 106, y: 50), tolerancia: 0) == nil)
    // A tolerância soma à metade do traço.
    #expect(doc.objeto(em: CGPoint(x: 108, y: 50), tolerancia: 4) == f.id)
    #expect(doc.objeto(em: CGPoint(x: 110, y: 50), tolerancia: 4) == nil)
}
