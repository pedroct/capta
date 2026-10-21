import AppKit
import CaptaNucleo
import os

/// A contagem regressiva que o fluxo mostra enquanto espera o atraso (spec §4.4).
protocol ApresentadorDaContagem {
    @MainActor func mostrar(segundos: Int, naTela tela: DescricaoDeTela)
    @MainActor func atualizar(_ segundos: Int)
    @MainActor func fechar()
}

/// Janelinha flutuante no topo da tela da seleção, longe do centro, com o número e "Esc cancela".
///
/// O overlay já fechou quando a contagem corre, então o `Esc` precisa ser global como no
/// `GerenciadorDoOverlay`: o atalho é registrado em `mostrar` e liberado em `fechar`, que é o
/// único caminho de saída (o `Esc` e o clique passam por `cancelar`, que fecha antes de avisar).
/// Se o registro falhar, a contagem aparece mesmo assim e o clique continua cancelando.
///
/// Sem animação alguma, o que já cobre *Reduzir movimento*. A janela é do próprio app, então a
/// captura a exclui junto com todo o app (por PID).
@MainActor
final class JanelaDaContagem: ApresentadorDaContagem {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedroct.capta",
        category: "overlay"
    )
    /// Distância do topo da tela até a janelinha, em pontos (abaixo da barra de menus).
    static let margemDoTopo: CGFloat = 48

    private let atalhoDeEsc: any AtalhoGlobal
    private let alturaDaPrincipal: @MainActor () -> CGFloat
    private let anunciar: @MainActor (String) -> Void
    /// Chamado depois de fechar, quando o `Esc` ou o clique cancelam. Pode ser ligado depois de
    /// criar a janela, porque quem cancela (o fluxo) é criado com ela.
    var aoCancelar: @MainActor () -> Void

    private var painel: NSPanel?
    private var vista: VistaDaContagem?
    private var sessao: UInt64 = 0

    /// Invariante: `visivel` ⇔ há painel; o `Esc` global só fica registrado enquanto `visivel`
    /// e `fechar` o libera exatamente uma vez.
    private(set) var visivel = false

    /// O número que está na janelinha (vazio quando fechada).
    var numeroExibido: String { vista?.numero.stringValue ?? "" }

    init(
        atalhoDeEsc: any AtalhoGlobal,
        alturaDaPrincipal: @escaping @MainActor () -> CGFloat = {
            NSScreen.screens.first?.frame.height ?? 0
        },
        anunciar: @escaping @MainActor (String) -> Void = JanelaDaContagem.anunciarNoVoiceOver,
        aoCancelar: @escaping @MainActor () -> Void = {}
    ) {
        self.atalhoDeEsc = atalhoDeEsc
        self.alturaDaPrincipal = alturaDaPrincipal
        self.anunciar = anunciar
        self.aoCancelar = aoCancelar
    }

    // MARK: - Texto e posição (puros)

    static func numero(_ segundos: Int) -> String { String(max(segundos, 0)) }

    static func anuncio(_ segundos: Int) -> String {
        segundos == 1
            ? String(localized: "Captura em 1 segundo. Esc cancela.")
            : String(localized: "Captura em \(max(segundos, 0)) segundos. Esc cancela.")
    }

    /// Quadro no espaço do AppKit: centrado na largura da tela e colado ao topo, com margem.
    static func quadro(tamanho: CGSize, naTela tela: DescricaoDeTela, alturaDaPrincipal: CGFloat)
        -> NSRect
    {
        let tela = JanelaDeOverlay.quadroNoAppKit(
            de: tela.quadro,
            alturaDaPrincipal: alturaDaPrincipal
        )
        return NSRect(
            x: tela.midX - tamanho.width / 2,
            y: tela.maxY - margemDoTopo - tamanho.height,
            width: tamanho.width,
            height: tamanho.height
        )
    }

    // MARK: - ApresentadorDaContagem

    func mostrar(segundos: Int, naTela tela: DescricaoDeTela) {
        if visivel {
            posicionar(naTela: tela)
            atualizar(segundos)
            return
        }
        sessao &+= 1
        let minhaSessao = sessao
        do {
            let esc = CombinacaoDeTeclas(
                codigoDaTecla: GerenciadorDoOverlay.codigoDoEsc,
                modificadores: []
            )
            try atalhoDeEsc.registrar(esc) { [weak self] in
                Task { @MainActor in self?.cancelar(sessao: minhaSessao) }
            }
        } catch {
            Self.log.warning("contagem sem Esc global: registro falhou; o clique ainda cancela")
        }
        let vista = VistaDaContagem()
        vista.aoClicar = { [weak self] in self?.cancelar(sessao: minhaSessao) }
        let painel = Self.criarPainel(vista)
        self.vista = vista
        self.painel = painel
        visivel = true
        posicionar(naTela: tela)
        painel.orderFrontRegardless()
        atualizar(segundos)
    }

    func atualizar(_ segundos: Int) {
        guard visivel, let vista else { return }
        vista.mostrar(numero: Self.numero(segundos), anuncio: Self.anuncio(segundos))
        anunciar(Self.anuncio(segundos))
    }

    func fechar() {
        guard visivel else { return }
        visivel = false
        atalhoDeEsc.liberar()
        painel?.orderOut(nil)
        painel = nil
        vista = nil
    }

    /// Cancela a contagem (Esc ou clique): fecha, o que libera o `Esc`, e só então avisa.
    func cancelar() { cancelar(sessao: sessao) }

    private func cancelar(sessao: UInt64) {
        guard visivel, sessao == self.sessao else { return }
        fechar()
        aoCancelar()
    }

    // MARK: - Janela

    private func posicionar(naTela tela: DescricaoDeTela) {
        guard let painel else { return }
        let tamanho = painel.frame.size
        painel.setFrame(
            Self.quadro(tamanho: tamanho, naTela: tela, alturaDaPrincipal: alturaDaPrincipal()),
            display: false
        )
    }

    private static func criarPainel(_ vista: VistaDaContagem) -> NSPanel {
        let painel = NSPanel(
            contentRect: NSRect(origin: .zero, size: vista.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        painel.level = .screenSaver
        painel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
        ]
        painel.isOpaque = false
        painel.backgroundColor = .clear
        painel.hasShadow = true
        painel.hidesOnDeactivate = false
        painel.isReleasedWhenClosed = false
        painel.animationBehavior = .none
        painel.contentView = vista
        return painel
    }

    /// Pede ao VoiceOver que leia o texto, sem tirar o foco de onde está.
    static func anunciarNoVoiceOver(_ texto: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: texto,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}

/// O painel da contagem: número grande e a dica; o clique em qualquer ponto cancela.
final class VistaDaContagem: FundoDePainel {
    let numero = NSTextField(labelWithString: "")
    var aoClicar: (@MainActor () -> Void)?

    init() {
        super.init(orientacao: .vertical)
        pilha.alignment = .centerX
        numero.font = .monospacedDigitSystemFont(ofSize: 40, weight: .semibold)
        numero.textColor = Tema.Overlay.texto
        pilha.addArrangedSubview(numero)
        pilha.addArrangedSubview(
            FundoDePainel.rotulo(String(localized: "Esc cancela"), secundario: true)
        )
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        frame = NSRect(origin: .zero, size: fittingSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func mostrar(numero texto: String, anuncio: String) {
        numero.stringValue = texto
        setAccessibilityLabel(anuncio)
    }

    override func mouseDown(with event: NSEvent) {
        MainActor.assumeIsolated { aoClicar?() }
    }
}
