import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private let a = anotacaoA
private let b = anotacaoB

// MARK: - Esc, sincronizar, escolher

@Test func escComGestoCancelaAPreviaENadaMais() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(170, 150), []), contexto: ctx)
    #expect(estado.reduzir(.esc, contexto: ctx) == .cancelarPrevia)
    #expect(estado.selecao == [a.id])
    // O gesto acabou: arrastar e soltar depois do Esc são ignorados.
    #expect(estado.reduzir(.arrastar(pontoDoEditor(190, 150), []), contexto: ctx) == nil)
    #expect(estado.reduzir(.soltar(pontoDoEditor(190, 150), []), contexto: ctx) == nil)
}

@Test func escDuranteORetanguloDeSelecaoApagaOdesenho() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom()
    _ = estado.reduzir(.pressionar(pontoDoEditor(50, 50), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(150, 150), []), contexto: ctx)
    #expect(estado.reduzir(.esc, contexto: ctx) == .cancelarPrevia)
    #expect(estado.retanguloDeSelecao == nil)
    #expect(estado.selecao.isEmpty)
}

@Test func escSemGestoLimpaASelecao() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    #expect(estado.reduzir(.esc, contexto: ctx) == nil)
    #expect(estado.selecao.isEmpty)
}

@Test func sincronizarTiraDaSelecaoOQueNaoExisteMais() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id, b.id])
    #expect(estado.reduzir(.sincronizar, contexto: ctx) == nil)
    #expect(estado.selecao == [a.id])
}

@Test func sincronizarCancelaOGestoEAPreviaSeHouver() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    #expect(estado.reduzir(.sincronizar, contexto: ctx) == nil)
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(160, 150), []), contexto: ctx)
    #expect(estado.reduzir(.sincronizar, contexto: ctx) == .cancelarPrevia)
    #expect(estado.reduzir(.soltar(pontoDoEditor(160, 150), []), contexto: ctx) == nil)
}

@Test func sincronizarApagaORetanguloDeSelecao() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom()
    _ = estado.reduzir(.pressionar(pontoDoEditor(50, 50), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(80, 80), []), contexto: ctx)
    #expect(estado.reduzir(.sincronizar, contexto: ctx) == nil)
    #expect(estado.retanguloDeSelecao == nil)
}

@Test func escolherCancelaOGestoELimpaSelecaoSoParaFerramentasDeCriacao() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(160, 150), []), contexto: ctx)
    #expect(estado.reduzir(.escolher(.selecao), contexto: ctx) == .cancelarPrevia)
    #expect(estado.selecao == [a.id])
    #expect(estado.reduzir(.escolher(.seta), contexto: ctx) == nil)
    #expect(estado.ferramenta == .seta)
    #expect(estado.selecao.isEmpty)
}

@Test func escolherFormaGuardaOTipoELimpaASelecao() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    #expect(estado.tipoForma == .retangulo)
    #expect(estado.reduzir(.escolherForma(.elipse), contexto: ctx) == nil)
    #expect(estado.ferramenta == .forma)
    #expect(estado.tipoForma == .elipse)
    #expect(estado.selecao.isEmpty)
}

@Test func pressionarNovamenteComGestoAbertoCancelaAPrevia() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(160, 150), []), contexto: ctx)
    #expect(
        estado.reduzir(.pressionar(pontoDoEditor(350, 150), []), contexto: ctx) == .cancelarPrevia
    )
    #expect(estado.selecao == [b.id])
}

// MARK: - Comandos

@Test func excluirRemoveASelecaoEEsvazia() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id])
    #expect(estado.reduzir(.excluir, contexto: ctx) == .aplicar(.remover([a.id])))
    #expect(estado.selecao.isEmpty)
    #expect(estado.reduzir(.excluir, contexto: ctx) == nil)
}

@Test func duplicarCopiaComDeslocamentoEPassaASelecaoParaAsCopias() throws {
    let novo1 = idDoEditor(10)
    let novo2 = idDoEditor(11)
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]), novosIds: [novo1, novo2])
    var estado = editorCom(selecao: [a.id, b.id])
    let copias = ctx.documento.copias(de: [a.id, b.id], deslocamento: CGVector(dx: 10, dy: 10)) {
        UUID()
    }
    let acao = estado.reduzir(.duplicar, contexto: ctx)
    guard case .aplicar(.lote(let itens)) = acao else {
        Issue.record("esperava um lote, veio \(String(describing: acao))")
        return
    }
    #expect(itens.count == 2)
    let adicionadas = itens.compactMap { item -> Anotacao? in
        if case .adicionar(let anotacao) = item { return anotacao }
        return nil
    }
    #expect(adicionadas.map(\.id) == [novo1, novo2])
    #expect(adicionadas.map(\.geometria) == copias.map(\.geometria))
    #expect(estado.selecao == [novo1, novo2])
}

@Test func duplicarSemSelecaoNaoFazNada() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom()
    #expect(estado.reduzir(.duplicar, contexto: ctx) == nil)
}

@Test func deslocarMoveASelecao() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    let v = CGVector(dx: -1, dy: 0)
    #expect(
        estado.reduzir(.deslocar(v), contexto: ctx) == .aplicar(.mover([a.id], deslocamento: v))
    )
    estado.selecao = []
    #expect(estado.reduzir(.deslocar(v), contexto: ctx) == nil)
}

@Test func selecionarTudoSelecionaTodosOsIds() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom()
    #expect(estado.reduzir(.selecionarTudo, contexto: ctx) == nil)
    #expect(estado.selecao == [a.id, b.id])
}

// MARK: - Eventos ignorados

@Test func arrastarESoltarSemPressionarSaoIgnorados() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    let antes = estado
    #expect(estado.reduzir(.arrastar(pontoDoEditor(150, 150), []), contexto: ctx) == nil)
    #expect(estado.reduzir(.soltar(pontoDoEditor(150, 150), []), contexto: ctx) == nil)
    #expect(estado == antes)
}

@Test func eventosDeMouseForaDaSelecaoEAlteracaoDeEstiloFicamParaAProximaTarefa() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.escolher(.seta), contexto: ctx)
    let antes = estado
    #expect(estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx) == nil)
    #expect(estado.reduzir(.alterarEstilo(.largura(8)), contexto: ctx) == nil)
    #expect(estado == antes)
}

@Test func padroesDoEstado() {
    let estado = EstadoDoEditor(memoria: MemoriaDeEstilos())
    #expect(estado.ferramenta == .selecao)
    #expect(estado.tipoForma == .retangulo)
    #expect(estado.selecao.isEmpty)
    #expect(estado.retanguloDeSelecao == nil)
    #expect(Ferramenta.allCases.count == 5)
}
