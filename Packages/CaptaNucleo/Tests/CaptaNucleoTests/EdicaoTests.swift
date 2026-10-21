import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private func retangulo(_ x: Double) -> Anotacao {
    Anotacao(geometria: .realce(CGRect(x: x, y: 0, width: 10, height: 10)))
}

private func vazio() -> Documento {
    .novo(tamanhoBase: CGSize(width: 100, height: 100), escala: 1)
}

private func sessao(com objetos: [Anotacao]) throws -> SessaoEdicao {
    var s = SessaoEdicao(documento: vazio())
    for objeto in objetos { try s.aplicar(.adicionar(objeto)) }
    return s
}

@Test func adicionarMoverRemoverAplicamNaOrdem() throws {
    let a = retangulo(0)
    var s = SessaoEdicao(documento: vazio())
    try s.aplicar(.adicionar(a))
    try s.aplicar(.mover([a.id], deslocamento: CGVector(dx: 5, dy: 7)))
    #expect(
        s.documento.objetos.first?.geometria == .realce(CGRect(x: 5, y: 7, width: 10, height: 10))
    )
    try s.aplicar(.remover([a.id]))
    #expect(s.documento.objetos.isEmpty)
}

@Test func desfazerRefazerRestauraCadaPasso() throws {
    let a = retangulo(0)
    var s = SessaoEdicao(documento: vazio())
    var instantes = [s.documento]
    try s.aplicar(.adicionar(a))
    instantes.append(s.documento)
    try s.aplicar(.mover([a.id], deslocamento: CGVector(dx: 1, dy: 1)))
    instantes.append(s.documento)
    try s.aplicar(.remover([a.id]))
    instantes.append(s.documento)

    for indice in stride(from: 2, through: 0, by: -1) {
        let resultadoDesfazer = s.desfazer()
        #expect(resultadoDesfazer)
        #expect(s.documento == instantes[indice])
    }
    let semDesfazer = s.desfazer()
    #expect(!semDesfazer)
    for indice in 1...3 {
        let resultadoRefazer = s.refazer()
        #expect(resultadoRefazer)
        #expect(s.documento == instantes[indice])
    }
    let semRefazer = s.refazer()
    #expect(!semRefazer)
}

@Test func aplicarDepoisDeDesfazerLimpaORefazer() throws {
    var s = try sessao(com: [retangulo(0), retangulo(1)])
    s.desfazer()
    #expect(s.podeRefazer)
    try s.aplicar(.adicionar(retangulo(2)))
    #expect(!s.podeRefazer)
}

@Test func edicaoInvalidaNaoMudaNada() throws {
    var s = try sessao(com: [retangulo(0)])
    let antes = s.documento
    let id = UUID()
    #expect(throws: ErroDocumento.objetoInexistente(id)) { try s.aplicar(.remover([id])) }
    #expect(throws: ErroDocumento.objetoInexistente(id)) {
        try s.aplicar(.reordenar(id, .paraFrente))
    }
    #expect(throws: ErroDocumento.objetoInexistente(id)) {
        try s.aplicar(.mover([id], deslocamento: .zero))
    }
    var fantasma = retangulo(3)
    fantasma.id = id
    #expect(throws: ErroDocumento.objetoInexistente(id)) { try s.aplicar(.substituir(fantasma)) }
    #expect(s.documento == antes)
    #expect(s.podeDesfazer)
    s.desfazer()
    #expect(s.documento.objetos.isEmpty)
    #expect(!s.podeDesfazer)
}

@Test func moverComDeslocamentoNaoFinitoELancado() throws {
    var s = try sessao(com: [retangulo(0)])
    let antes = s.documento
    let id = try #require(antes.objetos.first?.id)
    #expect(throws: ErroDocumento.valorNaoFinito) {
        try s.aplicar(.mover([id], deslocamento: CGVector(dx: Double.infinity, dy: 0)))
    }
    #expect(s.documento == antes)
}

@Test func substituirTrocaOObjetoMantendoAPosicao() throws {
    let a = retangulo(0)
    let b = retangulo(1)
    var s = try sessao(com: [a, b])
    var novo = a
    novo.geometria = .realce(CGRect(x: 50, y: 50, width: 5, height: 5))
    try s.aplicar(.substituir(novo))
    #expect(s.documento.objetos == [novo, b])
}

@Test func reordenarMudaAPosicaoNoArray() throws {
    let o = (0..<4).map { retangulo(Double($0)) }
    let ids = o.map(\.id)
    func ordem(_ s: SessaoEdicao) -> [UUID] { s.documento.objetos.map(\.id) }

    var s = try sessao(com: o)
    try s.aplicar(.reordenar(ids[0], .paraFrente))
    #expect(ordem(s) == [ids[1], ids[2], ids[3], ids[0]])

    s = try sessao(com: o)
    try s.aplicar(.reordenar(ids[3], .paraTras))
    #expect(ordem(s) == [ids[3], ids[0], ids[1], ids[2]])

    s = try sessao(com: o)
    try s.aplicar(.reordenar(ids[1], .umNivelAcima))
    #expect(ordem(s) == [ids[0], ids[2], ids[1], ids[3]])

    s = try sessao(com: o)
    try s.aplicar(.reordenar(ids[2], .umNivelAbaixo))
    #expect(ordem(s) == [ids[0], ids[2], ids[1], ids[3]])

    // Bordas: no-op sem erro e sem entrada de histórico.
    s = try sessao(com: o)
    let antes = s.documento
    try s.aplicar(.reordenar(ids[3], .paraFrente))
    try s.aplicar(.reordenar(ids[3], .umNivelAcima))
    try s.aplicar(.reordenar(ids[0], .paraTras))
    try s.aplicar(.reordenar(ids[0], .umNivelAbaixo))
    #expect(s.documento == antes)
    s.desfazer()
    #expect(s.documento.objetos.count == 3)
}

@Test func recorteForaDosLimitesELancado() throws {
    var s = SessaoEdicao(documento: vazio())
    for ruim in [
        CGRect(x: -5, y: 0, width: 10, height: 10),
        CGRect(x: 0, y: 0, width: 0, height: 10),
        CGRect(x: 0, y: 0, width: 10, height: -10),
    ] {
        #expect(throws: ErroDocumento.recorteInvalido) { try s.aplicar(.definirRecorte(ruim)) }
    }
    #expect(s.documento.recorte == nil)
    #expect(!s.podeDesfazer)

    // Invertidos, mas inteiramente dentro da base: só o tamanho cru os denuncia.
    for invertido in [
        CGRect(x: 0, y: 50, width: 10, height: -10),
        CGRect(x: 50, y: 0, width: -10, height: 10),
        CGRect(x: 50, y: 50, width: -10, height: -10),
    ] {
        #expect(throws: ErroDocumento.recorteInvalido) { try s.aplicar(.definirRecorte(invertido)) }
    }
    #expect(!s.podeDesfazer)

    let valido = CGRect(x: 10, y: 10, width: 20, height: 20)
    try s.aplicar(.definirRecorte(valido))
    #expect(s.documento.recorte == valido)
    try s.aplicar(.definirRecorte(nil))
    #expect(s.documento.recorte == nil)
    s.desfazer()
    #expect(s.documento.recorte == valido)
}

@Test func adicionarIdDuplicadoELancadoESemEfeito() throws {
    let a = retangulo(0)
    var s = try sessao(com: [a])
    let antes = s.documento
    #expect(throws: ErroDocumento.idDuplicado(a.id)) { try s.aplicar(.adicionar(a)) }
    #expect(s.documento == antes)
    s.desfazer()
    #expect(s.documento.objetos.isEmpty)
    #expect(!s.podeDesfazer)
}

@Test func conjuntosVaziosSaoNoOpSemHistorico() throws {
    var s = SessaoEdicao(documento: vazio())
    try s.aplicar(.remover([]))
    try s.aplicar(.mover([], deslocamento: CGVector(dx: 1, dy: 1)))
    #expect(!s.podeDesfazer)
    #expect(s.documento == vazio())
}

private func deslocar(_ geometria: Geometria, por d: CGVector) throws -> Geometria? {
    let objeto = Anotacao(geometria: geometria)
    var s = try sessao(com: [objeto])
    try s.aplicar(.mover([objeto.id], deslocamento: d))
    return s.documento.objetos.first?.geometria
}

@Test func deslocarMoveTextoEPreservaConteudoEFonte() throws {
    let original = Geometria.texto(
        CGRect(x: 10, y: 20, width: 30, height: 40),
        conteudo: "Olá",
        tamanhoFonte: 18,
        negrito: true,
        italico: false
    )
    let movido = try deslocar(original, por: CGVector(dx: 5, dy: -7))
    #expect(
        movido
            == .texto(
                CGRect(x: 15, y: 13, width: 30, height: 40),
                conteudo: "Olá",
                tamanhoFonte: 18,
                negrito: true,
                italico: false
            )
    )
}

@Test func deslocarMoveCentroDaEtapaEPreservaDiametroEReinicio() throws {
    let original = Geometria.etapa(
        centro: CGPoint(x: 10, y: 20),
        diametro: 32,
        reiniciaSequencia: true
    )
    let movido = try deslocar(original, por: CGVector(dx: 3, dy: 4))
    #expect(
        movido == .etapa(centro: CGPoint(x: 13, y: 24), diametro: 32, reiniciaSequencia: true)
    )
}

@Test func deslocarMoveRetanguloDoDesfoquePreservandoTipoEIntensidade() throws {
    let original = Geometria.desfoque(
        CGRect(x: 10, y: 20, width: 30, height: 40),
        .pixelizar,
        intensidade: 0.6
    )
    let movido = try deslocar(original, por: CGVector(dx: -2, dy: 9))
    #expect(
        movido
            == .desfoque(
                CGRect(x: 8, y: 29, width: 30, height: 40),
                .pixelizar,
                intensidade: 0.6
            )
    )
}

@Test func variosIdsInexistentesFalhamComOMenorIdEDocumentoIntacto() throws {
    var s = try sessao(com: [retangulo(0)])
    let antes = s.documento
    let ids = (0..<5).map { _ in UUID() }
    let menor = ids.min { $0.uuidString < $1.uuidString }
    let esperado = try #require(menor)
    #expect(throws: ErroDocumento.objetoInexistente(esperado)) {
        try s.aplicar(.remover(Set(ids)))
    }
    #expect(s.documento == antes)
}
