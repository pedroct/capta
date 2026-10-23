import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private let a = anotacaoA
private let novo = idDoEditor(20)

private func criador(_ ferramenta: Ferramenta, selecao: Set<UUID> = []) throws
    -> (EstadoDoEditor, ContextoDoEditor)
{
    let ctx = contextoDoEditor(try documentoDoEditor([a]), novosIds: [novo, idDoEditor(21)])
    var estado = editorCom(selecao: selecao)
    _ = estado.reduzir(.escolher(ferramenta), contexto: ctx)
    estado.selecao = selecao
    return (estado, ctx)
}

private func anotacaoDe(_ acao: AcaoDoEditor?) -> Anotacao? {
    switch acao {
    case .previa(.adicionar(let anotacao)), .aplicar(.adicionar(let anotacao)): anotacao
    default: nil
    }
}

// MARK: - Criação

@Test func setaArrastadaMostraPreviaComEstiloLembradoEAplicaAoSoltar() throws {
    var (estado, ctx) = try criador(.seta)
    #expect(estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx) == nil)
    let previa = estado.reduzir(.arrastar(pontoDoEditor(560, 520), []), contexto: ctx)
    let esperada = Anotacao(
        id: novo,
        geometria: .seta(inicio: pontoDoEditor(500, 500), fim: pontoDoEditor(560, 520)),
        estilo: MemoriaDeEstilos.padrao[.seta]
    )
    #expect(previa == .previa(.adicionar(esperada)))
    #expect(
        estado.reduzir(.soltar(pontoDoEditor(560, 520), []), contexto: ctx)
            == .aplicar(.adicionar(esperada))
    )
    #expect(estado.selecao == [novo])
    #expect(estado.ferramenta == .seta)
}

@Test func novoIdEChamadoUmaVezPorGesto() throws {
    var (estado, ctx) = try criador(.linha)
    _ = estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx)
    let p1 = anotacaoDe(estado.reduzir(.arrastar(pontoDoEditor(540, 500), []), contexto: ctx))
    let p2 = anotacaoDe(estado.reduzir(.arrastar(pontoDoEditor(580, 500), []), contexto: ctx))
    let fim = anotacaoDe(estado.reduzir(.soltar(pontoDoEditor(580, 500), []), contexto: ctx))
    #expect([p1?.id, p2?.id, fim?.id] == [novo, novo, novo])
}

@Test func shiftPrendeALinhaEm45Graus() throws {
    var (estado, ctx) = try criador(.linha)
    _ = estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx)
    let previa = anotacaoDe(
        estado.reduzir(.arrastar(pontoDoEditor(600, 590), .shift), contexto: ctx)
    )
    guard case .linha(_, let fim)? = previa?.geometria else {
        Issue.record("esperava uma linha")
        return
    }
    // 45° exatos: os dois deslocamentos têm o mesmo módulo.
    #expect(abs((fim.x - 500) - (fim.y - 500)) < 1e-6)
}

@Test func formaUsaOTipoEscolhidoEShiftFazQuadrado() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]), novosIds: [novo])
    var estado = editorCom()
    _ = estado.reduzir(.escolherForma(.elipse), contexto: ctx)
    _ = estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx)
    let livre = anotacaoDe(estado.reduzir(.arrastar(pontoDoEditor(600, 540), []), contexto: ctx))
    #expect(livre?.geometria == .forma(.elipse, CGRect(x: 500, y: 500, width: 100, height: 40)))
    let quadrada = anotacaoDe(
        estado.reduzir(.arrastar(pontoDoEditor(600, 440), .shift), contexto: ctx)
    )
    #expect(quadrada?.geometria == .forma(.elipse, CGRect(x: 500, y: 400, width: 100, height: 100)))
    #expect(quadrada?.estilo == MemoriaDeEstilos.padrao[.forma])
}

@Test func realceECriadoComoRetangulo() throws {
    var (estado, ctx) = try criador(.realce)
    _ = estado.reduzir(.pressionar(pontoDoEditor(600, 600), []), contexto: ctx)
    let previa = anotacaoDe(estado.reduzir(.arrastar(pontoDoEditor(500, 550), []), contexto: ctx))
    #expect(previa?.geometria == .realce(CGRect(x: 500, y: 550, width: 100, height: 50)))
    #expect(previa?.estilo == MemoriaDeEstilos.padrao[.realce])
}

@Test func criacaoUsaOEstiloDaMemoria() throws {
    var (estado, ctx) = try criador(.seta)
    estado.memoria[.seta] = Estilo(cor: .azul, largura: 9)
    _ = estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx)
    let previa = anotacaoDe(estado.reduzir(.arrastar(pontoDoEditor(560, 500), []), contexto: ctx))
    #expect(previa?.estilo == Estilo(cor: .azul, largura: 9))
}

@Test func soltarPertoDoInicioCancelaESemCriarNada() throws {
    var (estado, ctx) = try criador(.seta)
    _ = estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(502, 501), []), contexto: ctx)
    #expect(estado.reduzir(.soltar(pontoDoEditor(502, 501), []), contexto: ctx) == .cancelarPrevia)
    #expect(estado.selecao.isEmpty)
}

@Test func cliqueSemArrastarNaoCriaNada() throws {
    var (estado, ctx) = try criador(.forma)
    _ = estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx)
    #expect(estado.reduzir(.soltar(pontoDoEditor(500, 500), []), contexto: ctx) == .cancelarPrevia)
}

@Test func distanciaIgualAToleranciaiaCria() throws {
    var (estado, ctx) = try criador(.linha)
    _ = estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx)
    let acao = estado.reduzir(.soltar(pontoDoEditor(504, 500), []), contexto: ctx)
    #expect(anotacaoDe(acao)?.id == novo)
}

@Test func escDuranteACriacaoCancelaAPrevia() throws {
    var (estado, ctx) = try criador(.seta)
    _ = estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(560, 500), []), contexto: ctx)
    #expect(estado.reduzir(.esc, contexto: ctx) == .cancelarPrevia)
    #expect(estado.reduzir(.soltar(pontoDoEditor(560, 500), []), contexto: ctx) == nil)
}

@Test func criarSobreUmObjetoNaoOSeleciona() throws {
    var (estado, ctx) = try criador(.seta)
    _ = estado.reduzir(.pressionar(pontoDoEditor(150, 150), []), contexto: ctx)
    let acao = estado.reduzir(.soltar(pontoDoEditor(250, 250), []), contexto: ctx)
    #expect(anotacaoDe(acao)?.id == novo)
    #expect(estado.selecao == [novo])
}

@Test func ferramentaDeCriacaoPressionandoNumaAlcaArrastaAAlca() throws {
    // O objeto criado fica selecionado; pegar a alça dele edita em vez de criar outro.
    let criado = Anotacao(
        id: novo,
        geometria: .seta(inicio: pontoDoEditor(500, 500), fim: pontoDoEditor(600, 500)),
        estilo: MemoriaDeEstilos.padrao[.seta]
    )
    let ctx = contextoDoEditor(try documentoDoEditor([a, criado]), novosIds: [idDoEditor(99)])
    var estado = editorCom()
    _ = estado.reduzir(.escolher(.seta), contexto: ctx)
    estado.selecao = [novo]
    _ = estado.reduzir(.pressionar(pontoDoEditor(600, 500), []), contexto: ctx)
    let previa = estado.reduzir(.arrastar(pontoDoEditor(600, 560), []), contexto: ctx)
    var editado = try #require(ctx.documento.objetos.first { $0.id == novo })
    editado.geometria = .seta(inicio: pontoDoEditor(500, 500), fim: pontoDoEditor(600, 560))
    #expect(previa == .previa(.substituir(editado)))
    #expect(
        estado.reduzir(.soltar(pontoDoEditor(600, 560), []), contexto: ctx)
            == .aplicar(.substituir(editado))
    )
}

// MARK: - Estilos

@Test func alterarEstiloComSelecaoSubstituiSoOCampoEAtualizaAMemoriaDoTipo() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    var esperado = try #require(ctx.documento.objetos.first)
    esperado.estilo.largura = 8
    #expect(
        estado.reduzir(.alterarEstilo(.largura(8)), contexto: ctx)
            == .aplicar(.lote([.substituir(esperado)]))
    )
    #expect(estado.memoria[.realce].largura == 8)
    #expect(estado.memoria[.seta] == MemoriaDeEstilos.padrao[.seta])
}

@Test func alterarEstiloEmVariosMudaCadaUmNaOrdemDasCamadas() throws {
    let seta = Anotacao(
        id: idDoEditor(5),
        geometria: .seta(inicio: .zero, fim: pontoDoEditor(50, 50))
    )
    let ctx = contextoDoEditor(try documentoDoEditor([a, seta]))
    var estado = editorCom(selecao: [seta.id, a.id])
    let acao = estado.reduzir(.alterarEstilo(.tracejado(true)), contexto: ctx)
    var a2 = try #require(ctx.documento.objetos.first { $0.id == a.id })
    a2.estilo.tracejado = true
    var s2 = try #require(ctx.documento.objetos.first { $0.id == seta.id })
    s2.estilo.tracejado = true
    #expect(acao == .aplicar(.lote([.substituir(a2), .substituir(s2)])))
    #expect(estado.memoria[.seta].tracejado)
    #expect(estado.memoria[.realce].tracejado)
    #expect(!estado.memoria[.linha].tracejado)
}

@Test func alterarEstiloSemSelecaoMudaSoAMemoriaDaFerramenta() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom()
    _ = estado.reduzir(.escolher(.forma), contexto: ctx)
    #expect(estado.reduzir(.alterarEstilo(.preenchimento(.verde)), contexto: ctx) == nil)
    #expect(estado.memoria[.forma].preenchimento == .verde)
    #expect(estado.memoria[.seta] == MemoriaDeEstilos.padrao[.seta])
}

@Test func alterarEstiloNaSelecaoSemSelecionadosNaoFazNada() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom()
    let antes = estado
    #expect(estado.reduzir(.alterarEstilo(.largura(8)), contexto: ctx) == nil)
    #expect(estado == antes)
}

@Test func opacidadeELarguraSaoLimitadasSemLancar() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom()
    _ = estado.reduzir(.escolher(.linha), contexto: ctx)
    _ = estado.reduzir(.alterarEstilo(.opacidade(3)), contexto: ctx)
    _ = estado.reduzir(.alterarEstilo(.largura(-5)), contexto: ctx)
    #expect(estado.memoria[.linha].opacidade == 1)
    #expect(estado.memoria[.linha].largura == 0)
    _ = estado.reduzir(.alterarEstilo(.opacidade(-1)), contexto: ctx)
    #expect(estado.memoria[.linha].opacidade == 0)
}

@Test func corDoRealceMantemOAlfaDoToken() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom(selecao: [a.id])
    let acao = estado.reduzir(.alterarEstilo(.cor(.azul)), contexto: ctx)
    guard case .aplicar(.lote(let itens))? = acao, case .substituir(let nova)? = itens.first else {
        Issue.record("esperava um lote de substituição")
        return
    }
    #expect(
        nova.estilo.cor
            == CorRGBA(r: CorRGBA.azul.r, g: CorRGBA.azul.g, b: CorRGBA.azul.b, a: CorRGBA.realce.a)
    )
    #expect(estado.memoria[.realce].cor.a == CorRGBA.realce.a)
}

@Test func corDeSetaNaoMexeNoAlfa() throws {
    let ctx = contextoDoEditor(try documentoDoEditor([a]))
    var estado = editorCom()
    _ = estado.reduzir(.escolher(.seta), contexto: ctx)
    _ = estado.reduzir(.alterarEstilo(.cor(.azul)), contexto: ctx)
    #expect(estado.memoria[.seta].cor == .azul)
}

@Test func alterarEstiloNoMeioDeUmGestoEncerraOGesto() throws {
    var (estado, ctx) = try criador(.seta)
    _ = estado.reduzir(.pressionar(pontoDoEditor(500, 500), []), contexto: ctx)
    _ = estado.reduzir(.arrastar(pontoDoEditor(560, 500), []), contexto: ctx)
    #expect(estado.reduzir(.alterarEstilo(.largura(2)), contexto: ctx) == .cancelarPrevia)
    #expect(estado.reduzir(.soltar(pontoDoEditor(560, 500), []), contexto: ctx) == nil)
}

// MARK: - Estilo exibido

@Test func estiloExibidoSegueSelecaoOuFerramenta() throws {
    var diferente = a
    diferente.estilo.largura = 33
    let doc = try documentoDoEditor([anotacaoB, diferente])
    #expect(editorCom(selecao: [diferente.id]).estiloExibido(em: doc) == diferente.estilo)
    // Vários: o do primeiro na ordem das camadas (B vem antes).
    #expect(
        editorCom(selecao: [diferente.id, anotacaoB.id]).estiloExibido(em: doc) == anotacaoB.estilo
    )
    var criacao = editorCom()
    criacao.memoria[.linha].largura = 7
    _ = criacao.reduzir(.escolher(.linha), contexto: contextoDoEditor(doc))
    #expect(criacao.estiloExibido(em: doc)?.largura == 7)
    #expect(editorCom().estiloExibido(em: doc) == nil)
}
