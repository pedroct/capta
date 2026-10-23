import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private let a = anotacaoA
private let b = anotacaoB

/// Começa um arraste de `a` com prévia na tela e devolve o estado no meio do gesto.
private func movendoComPrevia() throws -> (EstadoDoEditor, ContextoDoEditor) {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(170, 150), []), contexto: ctx)
    return (estado, ctx)
}

// MARK: - Comandos de teclado no meio do gesto

@Test func excluirNoMeioDoArrasteDescartaAPreviaESoltarNaoAplicaNada() throws {
    var (estado, ctx) = try movendoComPrevia()
    #expect(estado.reduzir(.excluir, contexto: ctx) == .aplicar(.remover([a.id])))
    #expect(estado.reduzir(.soltar(pontoDoEditor(190, 150), []), contexto: ctx) == nil)
}

@Test func deslocarNoMeioDoArrasteAplicaSoOComandoESoltarNaoAplicaMover() throws {
    var (estado, ctx) = try movendoComPrevia()
    let vetor = CGVector(dx: 1, dy: 0)
    #expect(
        estado.reduzir(.deslocar(vetor), contexto: ctx)
            == .aplicar(.mover([a.id], deslocamento: vetor))
    )
    #expect(estado.reduzir(.soltar(pontoDoEditor(190, 150), []), contexto: ctx) == nil)
}

@Test func duplicarNoMeioDoArrasteEncerraOGesto() throws {
    var (estado, ctx) = try movendoComPrevia()
    let acao = estado.reduzir(.duplicar, contexto: ctx)
    guard case .aplicar(.lote) = acao else {
        Issue.record("esperava um lote, veio \(String(describing: acao))")
        return
    }
    #expect(estado.reduzir(.soltar(pontoDoEditor(190, 150), []), contexto: ctx) == nil)
}

@Test func comandoSemEfeitoNoMeioDoArrasteAindaCancelaAPrevia() throws {
    // Seleção vazia dentro do gesto de retângulo não tem prévia; já `.selecionarTudo` com
    // prévia de mover precisa cancelá-la.
    var (estado, ctx) = try movendoComPrevia()
    #expect(estado.reduzir(.selecionarTudo, contexto: ctx) == .cancelarPrevia)
    #expect(estado.selecao == [a.id, b.id])
    #expect(estado.reduzir(.soltar(pontoDoEditor(190, 150), []), contexto: ctx) == nil)
}

@Test func selecionarTudoNoMeioDoRetanguloDeSelecaoApagaORetangulo() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom()
    _ = estado.reduzir(.pressionar(pontoDoEditor(50, 50), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(80, 80), []), contexto: ctx)
    #expect(estado.reduzir(.selecionarTudo, contexto: ctx) == nil)
    #expect(estado.retanguloDeSelecao == nil)
    #expect(estado.reduzir(.soltar(pontoDoEditor(80, 80), []), contexto: ctx) == nil)
    #expect(estado.selecao == [a.id, b.id])
}

// MARK: - Prévia de mover rastreada à parte

@Test func arrastarSemSairDoLugarNaoEmitePrevia() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    #expect(estado.reduzir(.arrastar(pontoDoEditor(150, 150), []), contexto: ctx) == nil)
    // Sem prévia na tela, o Esc é o único que avisa; soltar não tem o que cancelar.
    #expect(estado.reduzir(.soltar(pontoDoEditor(150, 150), []), contexto: ctx) == nil)
}

@Test func voltarAoPontoInicialDuranteOArrasteCancelaAPreviaNaHora() throws {
    var (estado, ctx) = try movendoComPrevia()
    #expect(
        estado.reduzir(.arrastar(pontoDoEditor(150, 150), []), contexto: ctx) == .cancelarPrevia
    )
    // Já cancelada: soltar no mesmo ponto e comandos seguintes não repetem o aviso.
    #expect(estado.reduzir(.soltar(pontoDoEditor(150, 150), []), contexto: ctx) == nil)
}

@Test func shiftQueZeraOEixoNaoDeixaPreviaOrfa() throws {
    // Com ⇧ o delta fica no eixo dominante: (20, 0) -> depois (0, 0) nos dois eixos.
    var (estado, ctx) = try movendoComPrevia()
    #expect(
        estado.reduzir(.arrastar(pontoDoEditor(150, 150), .shift), contexto: ctx) == .cancelarPrevia
    )
    #expect(estado.reduzir(.excluir, contexto: ctx) == .aplicar(.remover([a.id])))
}

// MARK: - Soltar decide pelo deslocamento da soltura

@Test func soltarComShiftQueTravaNoEixoSemDeslocamentoNaoAplicaMover() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(170, 150), []), contexto: ctx)
    // Soltar no mesmo ponto: delta zero, mesmo com ⇧, cancela a prévia em vez de aplicar.
    #expect(
        estado.reduzir(.soltar(pontoDoEditor(150, 150), .shift), contexto: ctx) == .cancelarPrevia
    )
}
