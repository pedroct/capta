import AppKit
import CaptaNucleo
import Testing

@testable import Capta

@MainActor
@Suite("Painéis do overlay")
struct PaineisDoOverlayTests: BancadaDaVista {
    @Test func paineisSoNaTelaDoCursor() throws {
        let vistaA = try vista()
        let vistaB = try vista(Self.telaB)
        let atual = estado(eventos: [.cursorMoveu(CGPoint(x: 50, y: 50))])
        vistaA.mostrar(atual)
        vistaB.mostrar(atual)
        #expect(!vistaA.paineis.isHidden)
        #expect(vistaB.paineis.isHidden)
    }

    @Test func ajudaOcultaDeixaABarraComADicaDoH() throws {
        let vista = try vista()
        vista.mostrar(estado(ajudaVisivel: false, eventos: [.cursorMoveu(CGPoint(x: 50, y: 50))]))
        #expect(vista.paineis.ajuda.isHidden)
        #expect(!vista.paineis.barra.isHidden)
        #expect(!vista.paineis.barra.dicaDaAjuda.isHidden)
        vista.mostrar(estado(ajudaVisivel: true, eventos: [.cursorMoveu(CGPoint(x: 50, y: 50))]))
        #expect(!vista.paineis.ajuda.isHidden)
        #expect(vista.paineis.barra.dicaDaAjuda.isHidden)
    }

    @Test func ajudaMostraOModoAtual() throws {
        let janela = JanelaDeTela(
            id: 9,
            quadro: CGRect(x: 200, y: 20, width: 100, height: 60),
            camada: 0,
            naTela: true
        )
        let vista = try vista()
        vista.mostrar(estado(eventos: [.cursorMoveu(CGPoint(x: 50, y: 50))]))
        #expect(vista.paineis.ajuda.titulo.stringValue == "Modo: região")
        vista.mostrar(
            estado(janelas: [janela], modo: .janela, eventos: [.cursorMoveu(CGPoint(x: 50, y: 50))])
        )
        #expect(vista.paineis.ajuda.titulo.stringValue == "Modo: janela")
    }

    @Test func semAtrasoOCursorFicaDesabilitadoMostrandoOValorLembrado() throws {
        let vista = try vista()
        vista.mostrar(
            estado(
                opcoes: OpcoesDeCaptura(atraso: .nenhum, incluirCursor: true),
                eventos: [.cursorMoveu(CGPoint(x: 50, y: 50))]
            )
        )
        let barra = vista.paineis.barra
        #expect(!barra.incluirCursor.isEnabled)
        #expect(barra.incluirCursor.state == .on)
        #expect(!barra.explicacao.isHidden)
        #expect(barra.atraso.selectedSegment == 0)
    }

    @Test func comAtrasoOCursorFicaHabilitado() throws {
        let vista = try vista()
        vista.mostrar(
            estado(
                opcoes: OpcoesDeCaptura(atraso: .dez, incluirCursor: false),
                eventos: [.cursorMoveu(CGPoint(x: 50, y: 50))]
            )
        )
        let barra = vista.paineis.barra
        #expect(barra.incluirCursor.isEnabled)
        #expect(barra.incluirCursor.state == .off)
        #expect(barra.explicacao.isHidden)
        #expect(barra.atraso.selectedSegment == 3)
    }

    @Test func mudarAsOpcoesViraEvento() throws {
        let vista = try vista()
        var recebidos: [EventoDoOverlay] = []
        vista.aoEvento = { recebidos.append($0) }
        vista.mostrar(
            estado(
                opcoes: OpcoesDeCaptura(atraso: .tres, incluirCursor: true),
                eventos: [.cursorMoveu(CGPoint(x: 50, y: 50))]
            )
        )
        let barra = vista.paineis.barra
        barra.atraso.selectedSegment = 2
        barra.atraso.sendAction(barra.atraso.action, to: barra.atraso.target)
        barra.incluirCursor.state = .off
        barra.incluirCursor.sendAction(barra.incluirCursor.action, to: barra.incluirCursor.target)
        #expect(
            recebidos == [
                .opcoesMudaram(OpcoesDeCaptura(atraso: .cinco, incluirCursor: true)),
                .opcoesMudaram(OpcoesDeCaptura(atraso: .tres, incluirCursor: false)),
            ]
        )
    }

    @Test func cliqueNoPainelNaoComecaSelecao() throws {
        let vista = try vista()
        var recebidos: [EventoDoOverlay] = []
        vista.aoEvento = { recebidos.append($0) }
        let evento = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        vista.paineis.ajuda.mouseDown(with: evento)
        vista.paineis.ajuda.mouseDragged(with: evento)
        vista.paineis.ajuda.mouseUp(with: evento)
        #expect(recebidos.isEmpty)
    }

    @Test func cliqueNoVaoEntreOsPaineisNaoComecaSelecao() throws {
        let vista = try vista()
        var recebidos: [EventoDoOverlay] = []
        vista.aoEvento = { recebidos.append($0) }
        let evento = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        // No vão entre `ajuda` e `barra`, nenhuma das duas vistas recebe o clique: cai na pilha.
        vista.paineis.mouseDown(with: evento)
        vista.paineis.mouseDragged(with: evento)
        vista.paineis.mouseUp(with: evento)
        #expect(recebidos.isEmpty)
    }

    @Test func paineisSaoDesenhados() throws {
        let vista = try vista()
        vista.mostrar(estado(eventos: [.cursorMoveu(CGPoint(x: 50, y: 50))]))
        vista.layoutSubtreeIfNeeded()
        let quadro = vista.paineis.ajuda.convert(vista.paineis.ajuda.bounds, to: vista)
        #expect(quadro.width > 0)
        // O fundo do painel é opaco: perto do canto interno não aparece o vermelho da imagem.
        let fundo = try cor(de: vista, em: CGPoint(x: quadro.minX + 6, y: quadro.minY + 6))
        #expect(abs(fundo.redComponent - fundo.blueComponent) < 0.2)
    }
}
