import AppKit
import CaptaNucleo

/// Uma tela do overlay: a imagem congelada dela escurecida, com a seleção (ou a janela
/// realçada) sem escurecer, a mira, os rótulos, a lupa e os painéis.
///
/// Só desenha a partir do estado (via `CenaDoOverlay`) e traduz mouse e opções em
/// `EventoDoOverlay`; a regra da seleção mora no núcleo. Coordenadas locais em pontos, origem
/// no canto superior esquerdo da tela (vista invertida), como o espaço global do núcleo.
final class VistaDoOverlay: NSView {
    let tela: TelaCongelada
    var aoEvento: ((EventoDoOverlay) -> Void)?
    /// Costura de teste; o padrão lê o ajuste do sistema na hora de desenhar.
    var reduzirTransparencia: () -> Bool = {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
    let paineis = PaineisDoOverlay()
    private(set) var estado: EstadoDoOverlay?
    private(set) var cena: CenaDoOverlay?
    private var areaDeRastreio: NSTrackingArea?

    init(tela: TelaCongelada) {
        self.tela = tela
        super.init(frame: CGRect(origin: .zero, size: tela.descricao.quadro.size))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(TextosDoOverlay.acessibilidade)
        addSubview(paineis)
        let margem = CGFloat(Tema.Espaco.e4)
        NSLayoutConstraint.activate([
            paineis.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margem),
            paineis.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -margem),
        ])
        paineis.isHidden = true
        paineis.barra.aoMudar = { [weak self] opcoes in
            self?.aoEvento?(.opcoesMudaram(opcoes))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Passa a desenhar `estado`, redesenhando só o que mudou.
    func mostrar(_ estado: EstadoDoOverlay) {
        self.estado = estado
        let nova = CenaDoOverlay(
            estado: estado,
            tela: tela.descricao,
            tamanhoDaImagem: CGSize(width: tela.imagem.width, height: tela.imagem.height),
            medir: Self.medir
        )
        if nova != cena {
            let velhas = cena?.areasDeDesenho ?? [bounds]
            for area in velhas + nova.areasDeDesenho {
                let visivel = area.intersection(bounds)
                if !visivel.isNull { setNeedsDisplay(visivel) }
            }
            cena = nova
        }
        paineis.isHidden = !nova.temOCursor
        paineis.mostrar(estado)
    }

    // MARK: - Mouse

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let areaDeRastreio { removeTrackingArea(areaDeRastreio) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        areaDeRastreio = area
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
        // A janela sob o cursor fica com o teclado e com o primeiro clique nos painéis.
        if let janela = window, !janela.isKeyWindow, NSApp.isActive { janela.makeKey() }
        aoEvento?(.cursorMoveu(pontoGlobal(de: event)))
    }

    override func mouseDown(with event: NSEvent) {
        if let janela = window, !janela.isKeyWindow { janela.makeKey() }
        aoEvento?(.mouseBaixo(pontoGlobal(de: event)))
    }

    override func mouseDragged(with event: NSEvent) {
        aoEvento?(.mouseArrastou(pontoGlobal(de: event)))
    }

    /// Sempre encaminhado, mesmo fora da vista: o AppKit entrega o `mouseUp` à vista que
    /// recebeu o `mouseDown`, e a máquina precisa dele para encerrar o gesto.
    override func mouseUp(with event: NSEvent) {
        aoEvento?(.mouseSolto(pontoGlobal(de: event)))
    }

    /// Ponto global (pontos, origem no topo) do evento, pela posição local na vista: é a mesma
    /// conta que leva a imagem desenhada ao ponto global, então o que se vê é o que se seleciona.
    private func pontoGlobal(de evento: NSEvent) -> CGPoint {
        tela.descricao.global(de: convert(evento.locationInWindow, from: nil))
    }

    // MARK: - Desenho

    override func draw(_ dirtyRect: NSRect) {
        guard let contexto = NSGraphicsContext.current?.cgContext else { return }
        // A imagem e a máscara cobrem a tela toda: só os pedaços sujos são redesenhados (a mira
        // em cruz suja faixas finas, não a tela inteira).
        for area in areasSendoDesenhadas(dirtyRect) {
            desenharImagemCongelada(em: area, contexto: contexto)
            desenharMascara(em: area, furo: cena?.furo)
        }
        guard let cena else { return }
        if let janela = cena.janela, let furo = cena.furo {
            Tema.Overlay.destaqueFundo.setFill()
            NSBezierPath(rect: furo).fill()
            Self.contornar(janela.insetBy(dx: 1, dy: 1), tracejado: false)
        }
        if let selecao = cena.selecao { desenharSelecao(selecao) }
        desenharMira(cena)
        for rotulo in [cena.dimensoes, cena.dica].compactMap({ $0 }) {
            Self.desenhar(rotulo, raio: rotulo.quadro.height / 2)
        }
        if let lupa = cena.lupa { desenharLupa(lupa, contexto: contexto) }
    }

    /// `imagem` em `retangulo`, sem suavizar: na tela da própria imagem, um pixel por pixel.
    private static func desenhar(_ imagem: CGImage, em retangulo: CGRect, contexto: CGContext) {
        contexto.saveGState()
        contexto.interpolationQuality = .none
        // A vista é invertida e o `CGImage` desenha com a origem embaixo: desinverte só aqui.
        contexto.translateBy(x: retangulo.minX, y: retangulo.maxY)
        contexto.scaleBy(x: 1, y: -1)
        contexto.draw(imagem, in: CGRect(origin: .zero, size: retangulo.size))
        contexto.restoreGState()
    }

    private func areasSendoDesenhadas(_ suja: NSRect) -> [NSRect] {
        var ponteiro: UnsafePointer<NSRect>?
        var quantas = 0
        getRectsBeingDrawn(&ponteiro, count: &quantas)
        guard let ponteiro, quantas > 0 else { return [suja] }
        return Array(UnsafeBufferPointer(start: ponteiro, count: quantas))
    }

    /// O pedaço da imagem congelada sob `area`, recortado em pixels inteiros (o recorte não
    /// copia a imagem), para o custo por quadro ser o da área suja.
    private func desenharImagemCongelada(em area: CGRect, contexto: CGContext) {
        let imagem = tela.imagem
        guard bounds.width > 0, bounds.height > 0 else { return }
        let escalaX = CGFloat(imagem.width) / bounds.width
        let escalaY = CGFloat(imagem.height) / bounds.height
        let pixels = CGRect(
            x: area.minX * escalaX,
            y: area.minY * escalaY,
            width: area.width * escalaX,
            height: area.height * escalaY
        ).integral.intersection(CGRect(x: 0, y: 0, width: imagem.width, height: imagem.height))
        guard !pixels.isNull, !pixels.isEmpty, let pedaco = imagem.cropping(to: pixels) else {
            return
        }
        let destino = CGRect(
            x: pixels.minX / escalaX,
            y: pixels.minY / escalaY,
            width: pixels.width / escalaX,
            height: pixels.height / escalaY
        )
        Self.desenhar(pedaco, em: destino, contexto: contexto)
    }

    private func desenharMascara(em area: CGRect, furo: CGRect?) {
        let caminho = NSBezierPath(rect: area)
        if let furo {
            let dentro = furo.intersection(area)
            if !dentro.isNull, !dentro.isEmpty { caminho.appendRect(dentro) }
        }
        caminho.windingRule = .evenOdd
        Tema.Overlay.mascara(reduzirTransparencia: reduzirTransparencia()).setFill()
        caminho.fill()
    }

    /// Contorno tracejado por fora da seleção (os pixels dela ficam à vista) e as alças.
    private func desenharSelecao(_ selecao: CGRect) {
        let espessura = MedidasDoOverlay.espessuraDoContorno
        let externo = selecao.insetBy(dx: -espessura / 2, dy: -espessura / 2)
        Self.contornar(externo, tracejado: true)
        let lado = MedidasDoOverlay.ladoDaAlca
        for centro in Self.centrosDasAlcas(de: externo) {
            let alca = NSBezierPath(
                rect: CGRect(
                    x: centro.x - lado / 2,
                    y: centro.y - lado / 2,
                    width: lado,
                    height: lado
                )
            )
            Tema.Overlay.superficie.setFill()
            alca.fill()
            Tema.Overlay.destaque.setStroke()
            alca.lineWidth = 1
            alca.stroke()
        }
    }

    private static func centrosDasAlcas(de retangulo: CGRect) -> [CGPoint] {
        let xs = [retangulo.minX, retangulo.midX, retangulo.maxX]
        let ys = [retangulo.minY, retangulo.midY, retangulo.maxY]
        return ys.flatMap { y in xs.map { CGPoint(x: $0, y: y) } }
            .filter { $0 != CGPoint(x: retangulo.midX, y: retangulo.midY) }
    }

    private static func contornar(_ retangulo: CGRect, tracejado: Bool) {
        let caminho = NSBezierPath(rect: retangulo)
        caminho.lineWidth = MedidasDoOverlay.espessuraDoContorno
        if tracejado { caminho.setLineDash([6, 4], count: 2, phase: 0) }
        Tema.Overlay.destaque.setStroke()
        caminho.stroke()
    }

    private func desenharMira(_ cena: CenaDoOverlay) {
        Tema.Overlay.mira.setFill()
        if let x = cena.miraX {
            NSBezierPath(rect: CGRect(x: x, y: 0, width: 1, height: bounds.height)).fill()
        }
        if let y = cena.miraY {
            NSBezierPath(rect: CGRect(x: 0, y: y, width: bounds.width, height: 1)).fill()
        }
    }

    private func desenharLupa(_ lupa: CenaDoOverlay.Ampliacao, contexto: CGContext) {
        guard let amostra = tela.imagem.cropping(to: lupa.amostra) else { return }
        Self.desenhar(amostra, em: lupa.quadro, contexto: contexto)
        let grade = NSBezierPath()
        let passo = MedidasDoOverlay.ampliacao
        for x in stride(from: lupa.quadro.minX, through: lupa.quadro.maxX, by: passo) {
            grade.move(to: CGPoint(x: x, y: lupa.quadro.minY))
            grade.line(to: CGPoint(x: x, y: lupa.quadro.maxY))
        }
        for y in stride(from: lupa.quadro.minY, through: lupa.quadro.maxY, by: passo) {
            grade.move(to: CGPoint(x: lupa.quadro.minX, y: y))
            grade.line(to: CGPoint(x: lupa.quadro.maxX, y: y))
        }
        grade.lineWidth = 0.5
        Tema.Overlay.borda.setStroke()
        grade.stroke()
        let pixel = NSBezierPath(rect: lupa.pixelSobCursor.insetBy(dx: 0.75, dy: 0.75))
        pixel.lineWidth = 1.5
        Tema.Overlay.destaque.setStroke()
        pixel.stroke()
        Self.desenhar(lupa.coordenada, raio: 0)
    }

    // MARK: - Texto

    private static var atributos: [NSAttributedString.Key: Any] {
        [
            // `dimensao`: SF Mono 12, números tabulares.
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: Tema.Overlay.texto,
        ]
    }

    static func medir(_ texto: String) -> CGSize {
        (texto as NSString).size(withAttributes: atributos)
    }

    /// Rótulo opaco (`superficie-janela`) com o texto centrado.
    private static func desenhar(_ rotulo: CenaDoOverlay.Rotulo, raio: CGFloat) {
        let fundo = NSBezierPath(roundedRect: rotulo.quadro, xRadius: raio, yRadius: raio)
        Tema.Overlay.superficie.setFill()
        fundo.fill()
        Tema.Overlay.borda.setStroke()
        fundo.lineWidth = 1
        fundo.stroke()
        let medida = medir(rotulo.texto)
        (rotulo.texto as NSString).draw(
            at: CGPoint(
                x: rotulo.quadro.midX - medida.width / 2,
                y: rotulo.quadro.midY - medida.height / 2
            ),
            withAttributes: atributos
        )
    }
}
