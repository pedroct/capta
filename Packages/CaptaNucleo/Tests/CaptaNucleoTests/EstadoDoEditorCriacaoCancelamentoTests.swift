import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

/// Seta em criação, com prévia na tela.
private func criandoComPrevia() throws -> (EstadoDoEditor, ContextoDoEditor) {
    let ctx = contextoDoEditor(
        try documentoDoEditor([anotacaoA]),
        novosIds: [idDoEditor(20)]
    )
    var estado = editorCom()
    _ = estado.reduzir(.escolher(.seta), contexto: ctx)
    _ = estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(560, 520), []), contexto: ctx)
    return (estado, ctx)
}

@Test func sincronizarNoMeioDaCriacaoCancelaAPreviaESoltarNaoAplicaNada() throws {
    var (estado, ctx) = try criandoComPrevia()
    #expect(estado.reduzir(.sincronizar, contexto: ctx) == .cancelarPrevia)
    #expect(estado.reduzir(.soltar(pontoDoEditor(560, 520), []), contexto: ctx) == nil)
}

@Test func escolherNoMeioDaCriacaoCancelaAPreviaESoltarNaoAplicaNada() throws {
    var (estado, ctx) = try criandoComPrevia()
    #expect(estado.reduzir(.escolher(.linha), contexto: ctx) == .cancelarPrevia)
    #expect(estado.reduzir(.soltar(pontoDoEditor(560, 520), []), contexto: ctx) == nil)
}
