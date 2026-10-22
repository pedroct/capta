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

private func igual(_ a: CGRect, _ b: CGRect, tolerancia: Double = 1e-9) -> Bool {
    abs(a.minX - b.minX) < tolerancia && abs(a.minY - b.minY) < tolerancia
        && abs(a.width - b.width) < tolerancia && abs(a.height - b.height) < tolerancia
}

private func documento(_ anotacoes: [Anotacao]) throws -> Documento {
    var s = SessaoEdicao(
        documento: .novo(tamanhoBase: CGSize(width: 500, height: 500), escala: 1)
    )
    for a in anotacoes { try s.aplicar(.adicionar(a)) }
    return s.documento
}

@Test func limitesDaSetaIncluemACabeca() {
    let seta = Anotacao(
        geometria: .seta(inicio: .zero, fim: CGPoint(x: 100, y: 0)),
        estilo: estilo(largura: 4)
    )
    #expect(igual(seta.limites, CGRect(x: -8, y: -8, width: 116, height: 16)))
}

@Test func limitesDaLinhaSomamMeioTraco() {
    let linha = Anotacao(
        geometria: .linha(inicio: CGPoint(x: 10, y: 10), fim: CGPoint(x: 0, y: 30)),
        estilo: estilo(largura: 4)
    )
    #expect(igual(linha.limites, CGRect(x: -2, y: 8, width: 14, height: 24)))
}

@Test func limitesDaFormaSomamMeioTraco() {
    let forma = Anotacao(
        geometria: .forma(.elipse, CGRect(x: 10, y: 10, width: 20, height: 20)),
        estilo: estilo(largura: 4)
    )
    #expect(igual(forma.limites, CGRect(x: 8, y: 8, width: 24, height: 24)))
}

@Test func limitesDaFormaGirada90GrausTrocamOsLados() {
    let forma = Anotacao(
        geometria: .forma(.retangulo, CGRect(x: 0, y: 0, width: 100, height: 20)),
        estilo: estilo(),
        rotacao: .pi / 2
    )
    #expect(igual(forma.limites, CGRect(x: 40, y: -40, width: 20, height: 100)))
}

@Test func limitesDaEtapaSomamMeioTraco() {
    let etapa = Anotacao(
        geometria: .etapa(centro: CGPoint(x: 50, y: 50), diametro: 20, reiniciaSequencia: false),
        estilo: estilo(largura: 2)
    )
    #expect(igual(etapa.limites, CGRect(x: 39, y: 39, width: 22, height: 22)))
}

@Test func limitesDeRetanguloInvertidoSaemPadronizados() {
    let realce = Anotacao(geometria: .realce(CGRect(x: 30, y: 30, width: -20, height: -10)))
    #expect(igual(realce.limites, CGRect(x: 10, y: 20, width: 20, height: 10)))
}

@Test func limitesDeTextoCarimboEDesfoqueSaoORetangulo() {
    let r = CGRect(x: 1, y: 2, width: 30, height: 40)
    let texto = Anotacao(
        geometria: .texto(r, conteudo: "a", tamanhoFonte: 12, negrito: false, italico: false)
    )
    let carimbo = Anotacao(geometria: .carimbo(r, simbolo: "star"))
    let desfoque = Anotacao(geometria: .desfoque(r, .borrar, intensidade: 5))
    #expect(texto.limites == r)
    #expect(carimbo.limites == r)
    #expect(desfoque.limites == r)
}

@Test func limitesDeIdsSomamEVazioENil() throws {
    let a = Anotacao(geometria: .realce(CGRect(x: 0, y: 0, width: 10, height: 10)))
    let b = Anotacao(geometria: .realce(CGRect(x: 50, y: 20, width: 10, height: 10)))
    let doc = try documento([a, b])
    #expect(doc.limites(de: [a.id, b.id]) == CGRect(x: 0, y: 0, width: 60, height: 30))
    #expect(doc.limites(de: [b.id]) == b.limites)
    #expect(doc.limites(de: []) == nil)
    #expect(doc.limites(de: [UUID()]) == nil)
}

@Test func objetosTocandoDevolveNaOrdemDasCamadas() throws {
    let a = Anotacao(geometria: .realce(CGRect(x: 0, y: 0, width: 10, height: 10)))
    let b = Anotacao(geometria: .realce(CGRect(x: 100, y: 0, width: 10, height: 10)))
    let c = Anotacao(geometria: .realce(CGRect(x: 5, y: 5, width: 10, height: 10)))
    let doc = try documento([a, b, c])
    #expect(doc.objetos(tocando: CGRect(x: 8, y: 8, width: -10, height: -10)) == [a.id, c.id])
    #expect(doc.objetos(tocando: CGRect(x: 300, y: 300, width: 5, height: 5)).isEmpty)
}
