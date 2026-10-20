import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private func em255(_ cor: CorRGBA) -> [Int] {
    [cor.r, cor.g, cor.b].map { Int(($0 * 255).rounded()) }
}

private func anotacao(
    _ geometria: Geometria,
    opacidade: Double = 1,
    largura: Double = 4
) -> Anotacao {
    Anotacao(
        geometria: geometria,
        estilo: Estilo(
            cor: .vermelho,
            largura: largura,
            opacidade: opacidade,
            preenchimento: nil,
            tracejado: false
        )
    )
}

private func documento(com objeto: Anotacao) -> Documento {
    Documento(
        versaoEsquema: Esquema.versaoAtual,
        tamanhoBase: CGSize(width: 200, height: 100),
        escala: 2,
        recorte: nil,
        objetos: [objeto]
    )
}

private let retangulo = CGRect(x: 10, y: 20, width: 30, height: 40)

@Test func coresPadraoConferemComOsTokensDeAnotacao() {
    #expect(em255(.vermelho) == [255, 59, 48])
    #expect(em255(.amarelo) == [255, 204, 0])
    #expect(em255(.preto) == [28, 28, 30])
    #expect(em255(.branco) == [255, 255, 255])
    for cor in [CorRGBA.vermelho, .amarelo, .preto, .branco] {
        #expect(cor.a == 1)
    }
}

@Test func documentoNovoComecaVazio() {
    let doc = Documento.novo(tamanhoBase: .init(width: 200, height: 100), escala: 2)
    #expect(doc.versaoEsquema == Esquema.versaoAtual)
    #expect(doc.objetos.isEmpty)
    #expect(doc.recorte == nil)
}

@Test(
    arguments: [
        Geometria.seta(inicio: .init(x: 1, y: 2), fim: .init(x: 3, y: 4)),
        .linha(inicio: .init(x: 1, y: 2), fim: .init(x: 3, y: 4)),
        .forma(.retanguloArredondado, retangulo),
        .texto(retangulo, conteudo: "Olá", tamanhoFonte: 14, negrito: true, italico: false),
        .etapa(centro: .init(x: 5, y: 6), diametro: 24, reiniciaSequencia: true),
        .carimbo(retangulo, simbolo: "checkmark"),
        .realce(retangulo),
        .desfoque(retangulo, .pixelizar, intensidade: 0.5),
    ])
func ciclaJSONParaCadaGeometria(geometria: Geometria) throws {
    let original = anotacao(geometria)
    let dados = try JSONEncoder().encode(original)
    #expect(try JSONDecoder().decode(Anotacao.self, from: dados) == original)
}

@Test func rejeitaValoresNaoFinitos() {
    let nan = anotacao(.seta(inicio: CGPoint(x: CGFloat.nan, y: 0), fim: .zero))
    let infinito = anotacao(.linha(inicio: .zero, fim: CGPoint(x: 0, y: CGFloat.infinity)))
    for objeto in [nan, infinito] {
        #expect(throws: ErroDocumento.valorNaoFinito) {
            try documento(com: objeto).validar()
        }
    }
}

@Test func rejeitaOpacidadeForaDeFaixa() {
    for opacidade in [1.5, -0.1] {
        let objeto = anotacao(.realce(retangulo), opacidade: opacidade)
        #expect(throws: ErroDocumento.valorForaDeFaixa("opacidade")) {
            try documento(com: objeto).validar()
        }
    }
}

@Test func rejeitaTamanhoBaseNaoPositivo() {
    let casos: [(CGSize, Double)] = [
        (CGSize(width: 0, height: 100), 2),
        (CGSize(width: -5, height: 100), 2),
        (CGSize(width: 200, height: 100), 0),
    ]
    for (tamanho, escala) in casos {
        #expect(throws: ErroDocumento.tamanhoInvalido) {
            try Documento.novo(tamanhoBase: tamanho, escala: escala).validar()
        }
    }
}

@Test func decodificacaoValidaDocumento() throws {
    let valido = documento(com: anotacao(.realce(retangulo), opacidade: 0.5))
    let codificador = JSONEncoder()
    codificador.outputFormatting = [.sortedKeys]
    let texto = try #require(String(data: codificador.encode(valido), encoding: .utf8))
    #expect(texto.contains("\"opacidade\":0.5"))
    #expect(throws: Never.self) {
        try JSONDecoder().decode(Documento.self, from: Data(texto.utf8))
    }
    for invalido in ["7", "1e999"] {
        let adulterado = texto.replacingOccurrences(
            of: "\"opacidade\":0.5",
            with: "\"opacidade\":\(invalido)"
        )
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Documento.self, from: Data(adulterado.utf8))
        }
    }
}

@Test func validarRecorteDoDocumento() throws {
    var doc = Documento.novo(tamanhoBase: CGSize(width: 100, height: 100), escala: 1)
    // Exatamente igual à base é válido.
    doc.recorte = CGRect(x: 0, y: 0, width: 100, height: 100)
    #expect(throws: Never.self) { try doc.validar() }
    let invalidos = [
        CGRect(x: 0, y: 0, width: 0, height: 10),
        CGRect(x: 0, y: 0, width: 10, height: 0),
        CGRect(x: 90, y: 0, width: 20, height: 10),
        CGRect(x: -1, y: 0, width: 10, height: 10),
        // Invertidos, mas inteiramente dentro da base.
        CGRect(x: 0, y: 50, width: 10, height: -10),
        CGRect(x: 50, y: 0, width: -10, height: 10),
        CGRect(x: 50, y: 50, width: -10, height: -10),
    ]
    for recorte in invalidos {
        doc.recorte = recorte
        #expect(throws: ErroDocumento.recorteInvalido) { try doc.validar() }
    }
}

@Test func validarRejeitaIdDuplicado() throws {
    let a = anotacao(.realce(retangulo))
    var doc = documento(com: a)
    doc.objetos.append(Anotacao(id: a.id, geometria: .realce(retangulo)))
    #expect(throws: ErroDocumento.idDuplicado(a.id)) { try doc.validar() }
}

@Test func decodificacaoComIdDuplicadoLanca() throws {
    let a = anotacao(.realce(retangulo))
    var doc = documento(com: a)
    doc.objetos.append(Anotacao(id: a.id, geometria: .realce(retangulo)))
    let dados = try JSONEncoder().encode(doc)
    #expect(throws: ErroDocumento.idDuplicado(a.id)) {
        try JSONDecoder().decode(Documento.self, from: dados)
    }
}
