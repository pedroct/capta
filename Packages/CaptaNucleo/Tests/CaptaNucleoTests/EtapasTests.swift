import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private func etapa(reinicia: Bool = false) -> Anotacao {
    Anotacao(
        geometria: .etapa(centro: CGPoint(x: 10, y: 10), diametro: 20, reiniciaSequencia: reinicia)
    )
}

private func sessao(com objetos: [Anotacao]) throws -> SessaoEdicao {
    var s = SessaoEdicao(documento: .novo(tamanhoBase: CGSize(width: 100, height: 100), escala: 1))
    for objeto in objetos { try s.aplicar(.adicionar(objeto)) }
    return s
}

private func numeros(_ s: SessaoEdicao, _ etapas: [Anotacao]) -> [Int?] {
    etapas.map { s.documento.numeroDaEtapa($0.id) }
}

@Test func semEtapasNaoHaNumero() throws {
    let s = try sessao(com: [Anotacao(geometria: .realce(CGRect(x: 0, y: 0, width: 5, height: 5)))])
    #expect(s.documento.numeroDaEtapa(UUID()) == nil)
    #expect(s.documento.numeroDaEtapa(try #require(s.documento.objetos.first?.id)) == nil)
}

@Test func tresEtapasSaoNumeradasEmOrdem() throws {
    let e = [etapa(), etapa(), etapa()]
    let s = try sessao(com: e)
    #expect(numeros(s, e) == [1, 2, 3])
}

@Test func excluirASegundaRenumeraEDesfazerRestaura() throws {
    let e = [etapa(), etapa(), etapa()]
    var s = try sessao(com: e)
    try s.aplicar(.remover([e[1].id]))
    #expect(numeros(s, e) == [1, nil, 2])
    s.desfazer()
    #expect(numeros(s, e) == [1, 2, 3])
}

@Test func reinicioNaTerceiraDeQuatroDa1212() throws {
    let e = [etapa(), etapa(), etapa(), etapa()]
    var s = try sessao(com: e)
    try s.aplicar(.definirReinicioDeEtapa(e[2].id, true))
    #expect(numeros(s, e) == [1, 2, 1, 2])
    try s.aplicar(.definirReinicioDeEtapa(e[2].id, false))
    #expect(numeros(s, e) == [1, 2, 3, 4])
}

@Test func reinicioEmObjetoQueNaoEEtapaELancado() throws {
    let r = Anotacao(geometria: .realce(CGRect(x: 0, y: 0, width: 5, height: 5)))
    var s = try sessao(com: [r])
    #expect(throws: ErroDocumento.valorForaDeFaixa("etapa")) {
        try s.aplicar(.definirReinicioDeEtapa(r.id, true))
    }
    let id = UUID()
    #expect(throws: ErroDocumento.objetoInexistente(id)) {
        try s.aplicar(.definirReinicioDeEtapa(id, true))
    }
}
