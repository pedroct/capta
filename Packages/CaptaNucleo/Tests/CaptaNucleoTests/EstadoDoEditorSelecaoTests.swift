import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private let a = anotacaoA
private let b = anotacaoB

// MARK: - Alças

@Test func pressionarEmAlcaArrastaEAplicaOQueMostrouNaPrevia() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id])
    #expect(estado.reduzir(.pressionar(pontoDoEditor(200, 200), []), contexto: ctx) == nil)
    let esperado = a.arrastando(
        .canto(.inferiorDireito),
        ate: pontoDoEditor(250, 230),
        restrito: false
    )
    #expect(
        estado.reduzir(.arrastar(pontoDoEditor(250, 230), []), contexto: ctx)
            == .previa(.substituir(esperado))
    )
    #expect(
        estado.reduzir(.soltar(pontoDoEditor(250, 230), []), contexto: ctx)
            == .aplicar(.substituir(esperado))
    )
    #expect(estado.selecao == [a.id])
}

@Test func soltarNaAlcaSemMudarNaoFazNada() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(201, 199), []), contexto: ctx)
    #expect(estado.reduzir(.soltar(pontoDoEditor(201, 199), []), contexto: ctx) == nil)
}

@Test func alcaNaoPulaAteOCursorQuandoOCliqueFoiPertoDela() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(203, 198), []), contexto: ctx)
    // A alça fica 3 px à esquerda e 2 abaixo do clique, e mantém essa distância ao arrastar.
    let esperado = a.arrastando(
        .canto(.inferiorDireito),
        ate: pontoDoEditor(247, 232),
        restrito: false
    )
    #expect(
        estado.reduzir(.arrastar(pontoDoEditor(250, 230), []), contexto: ctx)
            == .previa(.substituir(esperado))
    )
}

@Test func voltarAoPontoInicialDaAlcaCancelaAPrevia() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(200, 200), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(250, 250), []), contexto: ctx)
    #expect(estado.reduzir(.soltar(pontoDoEditor(200, 200), []), contexto: ctx) == .cancelarPrevia)
}

@Test func pontoDeGiroGiraOObjetoERespeitaOShift() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 80), []), contexto: ctx)
    let livre = a.girando(ate: pontoDoEditor(250, 130), restrito: false)
    #expect(
        estado.reduzir(.arrastar(pontoDoEditor(250, 130), []), contexto: ctx)
            == .previa(.substituir(livre))
    )
    let preso = a.girando(ate: pontoDoEditor(250, 130), restrito: true)
    #expect(
        estado.reduzir(.arrastar(pontoDoEditor(250, 130), .shift), contexto: ctx)
            == .previa(.substituir(preso))
    )
    #expect(
        estado.reduzir(.soltar(pontoDoEditor(250, 130), .shift), contexto: ctx)
            == .aplicar(.substituir(preso))
    )
}

@Test func pressionarEmAlcaTemPrioridadeSobreOutroObjeto() throws {
    // B cobre o canto inferior direito de A e está acima dele.
    let cobre = realceDoEditor(2, CGRect(x: 150, y: 150, width: 100, height: 100))
    let ctx = contextoDoEditor(try documentoDoEditor([a, cobre]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(200, 200), []), contexto: ctx)
    #expect(estado.selecao == [a.id])
    let esperado = a.arrastando(
        .canto(.inferiorDireito),
        ate: pontoDoEditor(220, 220),
        restrito: false
    )
    #expect(
        estado.reduzir(.arrastar(pontoDoEditor(220, 220), []), contexto: ctx)
            == .previa(.substituir(esperado))
    )
}

@Test func alcasSoValemParaOUnicoObjetoSelecionado() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id, b.id])
    // (200, 200) é só a quina de A: com dois selecionados, é um clique no objeto A.
    _ = estado.reduzir(.pressionar(pontoDoEditor(199, 199), []), contexto: ctx)
    #expect(
        estado.reduzir(.arrastar(pontoDoEditor(209, 199), []), contexto: ctx)
            == .previa(.mover([a.id, b.id], deslocamento: CGVector(dx: 10, dy: 0)))
    )
}

// MARK: - Objetos

@Test func pressionarEmObjetoNaoSelecionadoViraASelecaoUnica() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [b.id])
    #expect(estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx) == nil)
    #expect(estado.selecao == [a.id])
}

@Test func shiftAlternaOObjetoNaSelecao() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(350, 150), .shift), contexto: ctx)
    _ = estado.reduzir(.soltar(pontoDoEditor(350, 150), .shift), contexto: ctx)
    #expect(estado.selecao == [a.id, b.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(350, 150), .shift), contexto: ctx)
    #expect(estado.selecao == [a.id])
    // Tirado da seleção, o arraste seguinte não move nada.
    #expect(estado.reduzir(.arrastar(pontoDoEditor(400, 150), .shift), contexto: ctx) == nil)
    #expect(estado.reduzir(.soltar(pontoDoEditor(400, 150), .shift), contexto: ctx) == nil)
}

@Test func arrastarObjetoSelecionadoMoveASelecaoInteira() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id, b.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    let mover = Edicao.mover([a.id, b.id], deslocamento: CGVector(dx: 30, dy: 20))
    #expect(estado.reduzir(.arrastar(pontoDoEditor(180, 170), []), contexto: ctx) == .previa(mover))
    #expect(estado.reduzir(.soltar(pontoDoEditor(180, 170), []), contexto: ctx) == .aplicar(mover))
    #expect(estado.selecao == [a.id, b.id])
}

@Test func shiftTravaOMovimentoNoEixoDominante() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    #expect(
        estado.reduzir(.arrastar(pontoDoEditor(190, 160), .shift), contexto: ctx)
            == .previa(.mover([a.id], deslocamento: CGVector(dx: 40, dy: 0)))
    )
    #expect(
        estado.reduzir(.arrastar(pontoDoEditor(160, 200), .shift), contexto: ctx)
            == .previa(.mover([a.id], deslocamento: CGVector(dx: 0, dy: 50)))
    )
}

@Test func soltarSemMoverEmSelecaoMultiplaFicaSoComOObjeto() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id, b.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    #expect(estado.reduzir(.soltar(pontoDoEditor(150, 150), []), contexto: ctx) == nil)
    #expect(estado.selecao == [a.id])
}

@Test func soltarSemMoverComShiftMantemASelecao() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id, b.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), .shift), contexto: ctx)
    _ = estado.reduzir(.soltar(pontoDoEditor(150, 150), .shift), contexto: ctx)
    #expect(estado.selecao == [b.id])
}

@Test func soltarDepoisDeMoverNaoReduzAMultiplaESeVoltarAoInicioCancelaAPrevia() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id, b.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(170, 150), []), contexto: ctx)
    #expect(estado.reduzir(.soltar(pontoDoEditor(150, 150), []), contexto: ctx) == .cancelarPrevia)
    #expect(estado.selecao == [a.id, b.id])
}

// MARK: - Vazio e retângulo de seleção

@Test func pressionarNoVazioLimpaAArrastarDesenhaESoltarSeleciona() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id])
    #expect(estado.reduzir(.pressionar(pontoDoEditor(50, 50), []), contexto: ctx) == nil)
    #expect(estado.selecao.isEmpty)
    #expect(estado.reduzir(.arrastar(pontoDoEditor(350, 150), []), contexto: ctx) == nil)
    #expect(estado.retanguloDeSelecao == CGRect(x: 50, y: 50, width: 300, height: 100))
    #expect(estado.reduzir(.soltar(pontoDoEditor(350, 150), []), contexto: ctx) == nil)
    #expect(estado.selecao == [a.id, b.id])
    #expect(estado.retanguloDeSelecao == nil)
}

@Test func retanguloDeSelecaoArrastadoParaTrasEPadronizado() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom()
    _ = estado.reduzir(.pressionar(pontoDoEditor(250, 150), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(120, 120), []), contexto: ctx)
    #expect(estado.retanguloDeSelecao == CGRect(x: 120, y: 120, width: 130, height: 30))
    _ = estado.reduzir(.soltar(pontoDoEditor(120, 120), []), contexto: ctx)
    #expect(estado.selecao == [a.id])
}

@Test func shiftNoVazioUneAoQueJaEstavaSelecionado() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [a.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(280, 50), .shift), contexto: ctx)
    #expect(estado.selecao == [a.id])
    _ = estado.reduzir(.arrastar(pontoDoEditor(450, 250), .shift), contexto: ctx)
    _ = estado.reduzir(.soltar(pontoDoEditor(450, 250), .shift), contexto: ctx)
    #expect(estado.selecao == [a.id, b.id])
}

@Test func cliqueNoVazioSemArrastarLimpaSemSelecionarPorAcidente() throws {
    // Retângulo degenerado (área zero): `intersects` pode dar falso mesmo sobre um objeto.
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [b.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(250, 150), []), contexto: ctx)
    #expect(estado.reduzir(.soltar(pontoDoEditor(250, 150), []), contexto: ctx) == nil)
    #expect(estado.selecao.isEmpty)
    #expect(estado.retanguloDeSelecao == nil)
}

@Test func cliqueNoVazioComShiftMantemASelecao() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom(selecao: [b.id])
    _ = estado.reduzir(.pressionar(pontoDoEditor(250, 150), .shift), contexto: ctx)
    _ = estado.reduzir(.soltar(pontoDoEditor(250, 150), .shift), contexto: ctx)
    #expect(estado.selecao == [b.id])
}

@Test func retanguloSemAreaNaoSelecionaNada() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a, b]))
    var estado = editorCom()
    // Linha vertical de largura zero atravessando A.
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 50), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(150, 300), []), contexto: ctx)
    _ = estado.reduzir(.soltar(pontoDoEditor(150, 300), []), contexto: ctx)
    #expect(estado.selecao.isEmpty)
    #expect(estado.retanguloDeSelecao == nil)
}
