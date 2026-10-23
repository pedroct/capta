import AppKit
import CaptaNucleo
import SwiftUI

/// O canvas do editor em AppKit: traduz mouse, teclado e pinça em eventos do editor e desenha a
/// imagem composta, a seleção e as alças. Sem regra própria; ela mora no núcleo e no
/// `EditorDaCaptura`.
@MainActor
final class VistaDoCanvas: NSView {
    /// Lado das alças, em pontos da tela.
    private static let ladoDaAlca: CGFloat = 8

    private let editor: EditorDaCaptura
    private let composicao: ComposicaoDoCanvas?
    /// Há um ajuste de zoom agendado para depois do passe de layout atual.
    private var ajusteAgendado = false

    init(editor: EditorDaCaptura) {
        self.editor = editor
        // O mesmo renderizador da captura: o canvas e o copiar/salvar PNG desenham igual.
        composicao = try? editor.novaComposicao()
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel(String(localized: "Área de edição da captura"))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    // MARK: Geometria

    private var imagemEmPontos: CGSize {
        let base = editor.captura.base
        return Enquadramento.pontos(
            larguraEmPixels: base.width,
            alturaEmPixels: base.height,
            escala: editor.captura.escala
        )
    }

    private var conversao: ConversaoDoCanvas {
        ConversaoDoCanvas(zoom: editor.zoom, escala: editor.captura.escala)
    }

    /// Onde a imagem fica dentro da vista (centrada quando é menor que a área visível).
    private var retanguloDaImagem: CGRect {
        let tamanho = CGSize(
            width: imagemEmPontos.width * editor.zoom,
            height: imagemEmPontos.height * editor.zoom
        )
        return CGRect(
            x: max(0, (bounds.width - tamanho.width) / 2),
            y: max(0, (bounds.height - tamanho.height) / 2),
            width: tamanho.width,
            height: tamanho.height
        )
    }

    /// Chamada pela rolagem a cada layout: informa a área ao editor e acomoda o tamanho da vista.
    /// No modo ajustar, o zoom novo é aplicado logo depois do passe de layout, e não durante ele:
    /// mexer em estado observado no meio de uma atualização de view é o que o SwiftUI reclama.
    func ajustar(area: CGSize) {
        guard area.width > 0, area.height > 0 else { return }
        if editor.areaVisivelMudou(area), !ajusteAgendado {
            ajusteAgendado = true
            Task { @MainActor [weak self] in
                guard let self else { return }
                ajusteAgendado = false
                editor.aplicarAjuste()
                redimensionar(area: enclosingScrollView?.contentSize ?? bounds.size)
            }
        }
        redimensionar(area: area)
    }

    /// Acomoda o tamanho da vista ao zoom atual e à área visível.
    func redimensionar(area: CGSize) {
        guard area.width > 0, area.height > 0 else { return }
        let conteudo = CGSize(
            width: imagemEmPontos.width * editor.zoom,
            height: imagemEmPontos.height * editor.zoom
        )
        let novo = CGSize(
            width: max(conteudo.width, area.width),
            height: max(conteudo.height, area.height)
        )
        if frame.size != novo { setFrameSize(novo) }
        needsDisplay = true
    }

    /// Ponto do evento em pixels do documento.
    private func pixel(de evento: NSEvent) -> CGPoint {
        let local = convert(evento.locationInWindow, from: nil)
        let moldura = retanguloDaImagem
        return conversao.pixel(
            de: CGPoint(x: local.x - moldura.minX, y: local.y - moldura.minY)
        )
    }

    private func modificadores(de evento: NSEvent) -> Modificadores {
        evento.modifierFlags.contains(.shift) ? [.shift] : []
    }

    // MARK: Entrada

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        enviar(.pressionar(pixel(de: event), modificadores(de: event)))
    }

    override func mouseDragged(with event: NSEvent) {
        enviar(.arrastar(pixel(de: event), modificadores(de: event)))
    }

    override func mouseUp(with event: NSEvent) {
        enviar(.soltar(pixel(de: event), modificadores(de: event)))
    }

    override func magnify(with event: NSEvent) {
        editor.pinca(Double(event.magnification))
        redimensionar(area: enclosingScrollView?.contentSize ?? bounds.size)
    }

    override func keyDown(with event: NSEvent) {
        let atalhoDeMenu = event.modifierFlags.contains(.command)
        guard !atalhoDeMenu,
            let tecla = TeclaDoEditor(
                codigo: event.keyCode,
                caractere: event.charactersIgnoringModifiers
            )
        else {
            super.keyDown(with: event)
            return
        }
        editor.tratar(tecla, shift: event.modifierFlags.contains(.shift), conversao: conversao)
        needsDisplay = true
    }

    private func enviar(_ evento: EventoDoEditor) {
        editor.tratar(evento, conversao: conversao)
        needsDisplay = true
    }

    // MARK: Desenho

    override func draw(_ dirtyRect: NSRect) {
        let moldura = retanguloDaImagem
        let documento = editor.documentoExibido
        let composta = (try? composicao?.atualizar(para: documento)) ?? editor.captura.base
        NSImage(cgImage: composta, size: moldura.size).draw(
            in: moldura,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high.rawValue]
        )
        desenharSelecao(em: documento, moldura: moldura)
        if let retangulo = editor.estado.retanguloDeSelecao {
            let area = emPontos(retangulo, moldura: moldura)
            Tema.Overlay.destaqueFundo.setFill()
            area.fill()
            Tema.Overlay.destaque.setStroke()
            let contorno = NSBezierPath(rect: area)
            contorno.lineWidth = 1
            contorno.stroke()
        }
    }

    private func emPontos(_ retangulo: CGRect, moldura: CGRect) -> CGRect {
        let origem = conversao.ponto(de: retangulo.origin)
        let extremo = conversao.ponto(de: CGPoint(x: retangulo.maxX, y: retangulo.maxY))
        return CGRect(
            x: origem.x + moldura.minX,
            y: origem.y + moldura.minY,
            width: extremo.x - origem.x,
            height: extremo.y - origem.y
        )
    }

    private func emPontos(_ ponto: CGPoint, moldura: CGRect) -> CGPoint {
        let convertido = conversao.ponto(de: ponto)
        return CGPoint(x: convertido.x + moldura.minX, y: convertido.y + moldura.minY)
    }

    private func desenharSelecao(em documento: Documento, moldura: CGRect) {
        let selecionados = documento.objetos.filter { editor.estado.selecao.contains($0.id) }
        for objeto in selecionados {
            Tema.Overlay.destaque.setStroke()
            let contorno = NSBezierPath(rect: emPontos(objeto.limites, moldura: moldura))
            contorno.lineWidth = 1
            contorno.stroke()
        }
        guard selecionados.count == 1, let unico = selecionados.first else { return }
        for posicao in unico.alcas().values {
            desenharAlca(em: emPontos(posicao, moldura: moldura))
        }
        let distancia = conversao.pixels(dePontos: EditorDaCaptura.giroEmPontos)
        if let giro = unico.pontoDeGiro(distancia: distancia) {
            let centro = emPontos(giro, moldura: moldura)
            let raio = Self.ladoDaAlca / 2
            let circulo = NSBezierPath(
                ovalIn: CGRect(
                    x: centro.x - raio,
                    y: centro.y - raio,
                    width: Self.ladoDaAlca,
                    height: Self.ladoDaAlca
                )
            )
            Tema.Overlay.superficie.setFill()
            circulo.fill()
            Tema.Overlay.destaque.setStroke()
            circulo.stroke()
        }
    }

    private func desenharAlca(em centro: CGPoint) {
        let lado = Self.ladoDaAlca
        let quadrado = NSBezierPath(
            rect: CGRect(x: centro.x - lado / 2, y: centro.y - lado / 2, width: lado, height: lado)
        )
        Tema.Overlay.superficie.setFill()
        quadrado.fill()
        Tema.Overlay.destaque.setStroke()
        quadrado.lineWidth = 1
        quadrado.stroke()
    }
}

/// A rolagem que avisa a vista do tamanho visível a cada layout.
final class RolagemDoCanvas: NSScrollView {
    var aoOrganizar: ((CGSize) -> Void)?

    override func layout() {
        super.layout()
        aoOrganizar?(contentSize)
    }
}

/// O canvas dentro da hierarquia SwiftUI.
struct CanvasDoEditor: NSViewRepresentable {
    let editor: EditorDaCaptura

    func makeNSView(context: Context) -> RolagemDoCanvas {
        let vista = VistaDoCanvas(editor: editor)
        let rolagem = RolagemDoCanvas()
        rolagem.hasVerticalScroller = true
        rolagem.hasHorizontalScroller = true
        rolagem.drawsBackground = false
        rolagem.documentView = vista
        rolagem.aoOrganizar = { [weak vista] area in vista?.ajustar(area: area) }
        return rolagem
    }

    func updateNSView(_ rolagem: RolagemDoCanvas, context: Context) {
        // Ler o estado observável aqui faz o SwiftUI chamar de novo quando ele muda.
        _ = editor.documentoExibido
        _ = editor.estado
        _ = editor.zoom
        guard let vista = rolagem.documentView as? VistaDoCanvas else { return }
        vista.redimensionar(area: rolagem.contentSize)
    }
}
