import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private let a = anotacaoA

private func contexto(toleranciaDasAlcas: CGFloat?) throws -> ContextoDoEditor {
    var ctx = contextoDoEditor(try documentoDoEditor([a]))
    ctx.toleranciaDasAlcas = toleranciaDasAlcas
    return ctx
}

private func arrastarDoCanto(_ ctx: ContextoDoEditor) -> AcaoDoEditor? {
    var estado = editorCom(selecao: [a.id])
    // Alça superior esquerda em (100, 100); (104, 104) é o canto do quadrado desenhado.
    _ = estado.reduzir(.pressionar(pontoDoEditor(104, 104), []), contexto: ctx)
    return estado.reduzir(.arrastar(pontoDoEditor(84, 84), []), contexto: ctx)
}

private func ehRedimensionar(_ acao: AcaoDoEditor?) -> Bool {
    if case .previa(.substituir)? = acao { return true }
    return false
}

@Test func alcaAcertaOCantoDoQuadradoDesenhadoComFolgaPropria() throws {
    #expect(ehRedimensionar(arrastarDoCanto(try contexto(toleranciaDasAlcas: 6))))
}

@Test func semFolgaPropriaAAlcaUsaATolerancia() throws {
    // Com tolerância 4 o canto do quadrado (distância ~5,7) fica fora e o gesto vira mover.
    let acao = arrastarDoCanto(try contexto(toleranciaDasAlcas: nil))
    #expect(!ehRedimensionar(acao))
    guard case .previa(.mover)? = acao else {
        Issue.record("esperava mover, veio \(String(describing: acao))")
        return
    }
}

@Test func folgaDasAlcasNaoAmpliaOAcertoDeObjetos() throws {
    // A 5 pt da borda de A: com tolerância de objeto 4 não pega, mesmo com alças a 6.
    let ctx = try contexto(toleranciaDasAlcas: 6)
    var estado = editorCom()
    _ = estado.reduzir(.pressionar(pontoDoEditor(95, 150), []), contexto: ctx)
    #expect(estado.selecao.isEmpty)
}
