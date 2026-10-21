import AppKit
import CaptaNucleo
import Testing

@testable import Capta

/// Imagem azul de `largura` x `altura` pixels com um bloco vermelho de `bloco` x `bloco` no
/// canto superior esquerdo, para conferir a orientação do desenho.
func imagemComCanto(largura: Int, altura: Int, bloco: Int) throws -> CGImage {
    let espaco = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let contexto = try #require(
        CGContext(
            data: nil,
            width: largura,
            height: altura,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: espaco,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    contexto.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
    contexto.fill(CGRect(x: 0, y: 0, width: largura, height: altura))
    contexto.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
    // O contexto de bitmap tem a origem embaixo: o bloco no topo fica em y = altura - bloco.
    contexto.fill(CGRect(x: 0, y: altura - bloco, width: bloco, height: bloco))
    return try #require(contexto.makeImage())
}

/// Telas falsas e ajudantes comuns às suítes da vista do overlay.
@MainActor
protocol BancadaDaVista {}

extension BancadaDaVista {
    static var telaA: DescricaoDeTela {
        DescricaoDeTela(
            id: 1,
            quadro: CGRect(x: 0, y: 0, width: 400, height: 300),
            escala: 1,
            principal: true
        )
    }
    /// À direita da A: com o cursor nela, a A fica sem painéis.
    static var telaB: DescricaoDeTela {
        DescricaoDeTela(
            id: 2,
            quadro: CGRect(x: 400, y: 0, width: 400, height: 300),
            escala: 1,
            principal: false
        )
    }
    static var longe: CGPoint { CGPoint(x: 600, y: 299.5) }

    func vista(_ descricao: DescricaoDeTela = Self.telaA) throws -> VistaDoOverlay {
        let imagem = try imagemComCanto(
            largura: Int(descricao.quadro.width * descricao.escala),
            altura: Int(descricao.quadro.height * descricao.escala),
            bloco: 100
        )
        return VistaDoOverlay(tela: TelaCongelada(descricao: descricao, imagem: imagem))
    }

    func estado(
        janelas: [JanelaDeTela] = [],
        modo: ModoDoOverlay = .regiao,
        opcoes: OpcoesDeCaptura = OpcoesDeCaptura(atraso: .nenhum, incluirCursor: false),
        ajudaVisivel: Bool = true,
        eventos: [EventoDoOverlay]
    ) -> EstadoDoOverlay {
        eventos.reduce(
            EstadoDoOverlay.inicial(
                modo: modo,
                telas: [Self.telaA, Self.telaB],
                janelas: janelas,
                opcoes: opcoes,
                ajudaVisivel: ajudaVisivel
            )
        ) { $0.reduzindo($1) }
    }

    /// Cor (sRGB) do ponto local `ponto` da vista renderizada fora da tela.
    func cor(de vista: NSView, em ponto: CGPoint) throws -> NSColor {
        let rep = try #require(vista.bitmapImageRepForCachingDisplay(in: vista.bounds))
        vista.cacheDisplay(in: vista.bounds, to: rep)
        let escala = CGFloat(rep.pixelsWide) / vista.bounds.width
        let cor = try #require(
            rep.colorAt(x: Int(ponto.x * escala), y: Int(ponto.y * escala))?.usingColorSpace(.sRGB)
        )
        return cor
    }
}

@MainActor
@Suite("Vista do overlay")
struct VistaDoOverlayTests: BancadaDaVista {
    // MARK: - Desenho

    @Test func imagemCongeladaNaOrientacaoCertaEEscurecida() throws {
        let vista = try vista()
        vista.mostrar(estado(eventos: [.cursorMoveu(Self.longe)]))
        let canto = try cor(de: vista, em: CGPoint(x: 50, y: 50))
        #expect(canto.redComponent > canto.blueComponent)
        #expect(canto.redComponent < 0.75)
        let resto = try cor(de: vista, em: CGPoint(x: 300, y: 50))
        #expect(resto.blueComponent > resto.redComponent)
        #expect(resto.blueComponent < 0.75)
    }

    /// Redesenhar só um pedaço (o caso de cada quadro) recorta a imagem no lugar certo.
    @Test func pedacoRedesenhadoMostraAParteCertaDaImagem() throws {
        let vista = try vista()
        vista.mostrar(estado(eventos: [.cursorMoveu(Self.longe)]))
        let area = CGRect(x: 50, y: 50, width: 200, height: 100)
        let rep = try #require(vista.bitmapImageRepForCachingDisplay(in: area))
        vista.cacheDisplay(in: area, to: rep)
        let escala = CGFloat(rep.pixelsWide) / area.width
        func cor(_ x: CGFloat, _ y: CGFloat) throws -> NSColor {
            try #require(
                rep.colorAt(x: Int(x * escala), y: Int(y * escala))?.usingColorSpace(.sRGB)
            )
        }
        // (60, 60) da vista está no bloco vermelho; (190, 60), fora dele.
        let vermelho = try cor(10, 10)
        #expect(vermelho.redComponent > vermelho.blueComponent)
        let azul = try cor(140, 10)
        #expect(azul.blueComponent > azul.redComponent)
    }

    @Test func selecaoMostraOsPixelsSemEscurecer() throws {
        let vista = try vista()
        vista.mostrar(
            estado(eventos: [
                .mouseBaixo(CGPoint(x: 200, y: 20)),
                .mouseSolto(CGPoint(x: 350, y: 120)),
                .cursorMoveu(Self.longe),
            ])
        )
        let dentro = try cor(de: vista, em: CGPoint(x: 280, y: 60))
        #expect(dentro.blueComponent > 0.95)
        let fora = try cor(de: vista, em: CGPoint(x: 280, y: 200))
        #expect(fora.blueComponent < 0.75)
    }

    @Test func reduzirTransparenciaEscureceMais() throws {
        let normal = try vista()
        let reduzida = try vista()
        reduzida.reduzirTransparencia = { true }
        normal.reduzirTransparencia = { false }
        let atual = estado(eventos: [.cursorMoveu(Self.longe)])
        normal.mostrar(atual)
        reduzida.mostrar(atual)
        let ponto = CGPoint(x: 300, y: 50)
        #expect(
            try cor(de: reduzida, em: ponto).blueComponent
                < cor(de: normal, em: ponto).blueComponent
        )
    }

    @Test func janelaRealcadaFicaMaisClaraQueOResto() throws {
        let janela = JanelaDeTela(
            id: 9,
            quadro: CGRect(x: 200, y: 20, width: 100, height: 60),
            camada: 0,
            naTela: true
        )
        let vista = try vista()
        vista.mostrar(
            estado(
                janelas: [janela],
                modo: .janela,
                eventos: [.cursorMoveu(CGPoint(x: 250, y: 50))]
            )
        )
        #expect(vista.cena?.janela != nil)
        let dentro = try cor(de: vista, em: CGPoint(x: 230, y: 40))
        let fora = try cor(de: vista, em: CGPoint(x: 350, y: 40))
        #expect(dentro.blueComponent > fora.blueComponent + 0.2)
    }

    @Test func lupaMostraOPixelDoCursorSemEscurecer() throws {
        let vista = try vista()
        vista.mostrar(
            estado(eventos: [
                .mouseBaixo(CGPoint(x: 200, y: 20)),
                .mouseSolto(CGPoint(x: 260, y: 60)),
                .tecla(.m),
            ])
        )
        let lupa = try #require(vista.cena?.lupa)
        #expect(vista.cena?.dimensoes != nil)
        let celula = lupa.pixelSobCursor
        // Um ponto dentro da célula, longe do contorno que marca o pixel.
        let centro = try cor(de: vista, em: CGPoint(x: celula.midX, y: celula.midY))
        #expect(centro.blueComponent > 0.9)
    }

    @Test func dicaDoModoEDesenhadaComOCursorNaTela() throws {
        let vista = try vista()
        vista.mostrar(estado(eventos: [.cursorMoveu(CGPoint(x: 200, y: 50))]))
        let dica = try #require(vista.cena?.dica)
        // O fundo do rótulo é opaco: o centro não é o azul escurecido da imagem.
        let fundo = try cor(de: vista, em: CGPoint(x: dica.quadro.minX + 3, y: dica.quadro.midY))
        #expect(abs(fundo.redComponent - fundo.blueComponent) < 0.2)
    }

    @Test func mostrarDeNovoComOMesmoEstadoNaoMudaACena() throws {
        let vista = try vista()
        let atual = estado(eventos: [.cursorMoveu(CGPoint(x: 200, y: 50))])
        vista.mostrar(atual)
        let antes = vista.cena
        vista.mostrar(atual)
        #expect(vista.cena == antes)
    }

    // MARK: - Mouse

    @Test func eventosDoMouseViramPontosGlobaisMesmoForaDaVista() throws {
        let descricao = DescricaoDeTela(
            id: 5,
            quadro: CGRect(x: 100, y: -50, width: 400, height: 300),
            escala: 1,
            principal: false
        )
        let vista = try vista(descricao)
        let janela = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        janela.contentView = vista
        var recebidos: [EventoDoOverlay] = []
        vista.aoEvento = { recebidos.append($0) }

        func evento(_ tipo: NSEvent.EventType, _ x: CGFloat, _ y: CGFloat) throws -> NSEvent {
            try #require(
                NSEvent.mouseEvent(
                    with: tipo,
                    location: NSPoint(x: x, y: y),
                    modifierFlags: [],
                    timestamp: 0,
                    windowNumber: janela.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: 1
                )
            )
        }
        vista.mouseMoved(with: try evento(.mouseMoved, 1, 299))
        vista.mouseDown(with: try evento(.leftMouseDown, 5, 290))
        vista.mouseDragged(with: try evento(.leftMouseDragged, 50, 200))
        // Soltar fora da janela (e da tela) ainda chega à máquina.
        vista.mouseUp(with: try evento(.leftMouseUp, -30, 400))

        #expect(
            recebidos == [
                .cursorMoveu(CGPoint(x: 101, y: -49)),
                .mouseBaixo(CGPoint(x: 105, y: -40)),
                .mouseArrastou(CGPoint(x: 150, y: 50)),
                .mouseSolto(CGPoint(x: 70, y: -150)),
            ]
        )
    }

    @Test func vistaAceitaOPrimeiroCliqueEOTeclado() throws {
        let vista = try vista()
        #expect(vista.acceptsFirstMouse(for: nil))
        #expect(vista.acceptsFirstResponder)
        #expect(vista.isFlipped)
        vista.updateTrackingAreas()
        #expect(vista.trackingAreas.count == 1)
        vista.updateTrackingAreas()
        #expect(vista.trackingAreas.count == 1)
    }

    @Test func rotuloDeAcessibilidade() throws {
        let vista = try vista()
        #expect(vista.accessibilityLabel() == "Seleção de captura. Esc cancela.")
        #expect(vista.isAccessibilityElement())
    }
}
