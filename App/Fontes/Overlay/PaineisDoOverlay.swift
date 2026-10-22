import AppKit
import CaptaNucleo

/// Fundo opaco e arredondado dos painéis do overlay (`superficie-janela`, `raio-cartao`).
/// Engole o mouse para um clique no painel não começar uma seleção na vista de baixo.
class FundoDePainel: NSView {
    let pilha: NSStackView

    init(orientacao: NSUserInterfaceLayoutOrientation) {
        pilha = NSStackView()
        super.init(frame: .zero)
        pilha.orientation = orientacao
        pilha.alignment = orientacao == .vertical ? .leading : .centerY
        pilha.spacing = CGFloat(Tema.Espaco.e2)
        pilha.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pilha)
        let folgaX = CGFloat(Tema.Espaco.e3)
        let folgaY = CGFloat(Tema.Espaco.e2)
        NSLayoutConstraint.activate([
            pilha.leadingAnchor.constraint(equalTo: leadingAnchor, constant: folgaX),
            pilha.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -folgaX),
            pilha.topAnchor.constraint(equalTo: topAnchor, constant: folgaY),
            pilha.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -folgaY),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let raio = CGFloat(Tema.Raio.cartao)
        let caminho = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: raio,
            yRadius: raio
        )
        Tema.Overlay.superficie.setFill()
        caminho.fill()
        Tema.Overlay.borda.setStroke()
        caminho.lineWidth = 1
        caminho.stroke()
    }

    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}

    static func rotulo(_ texto: String, negrito: Bool = false, secundario: Bool = false)
        -> NSTextField
    {
        let campo = NSTextField(labelWithString: texto)
        campo.font = .systemFont(ofSize: 11, weight: negrito ? .semibold : .regular)
        campo.textColor = secundario ? Tema.Overlay.textoSecundario : Tema.Overlay.texto
        return campo
    }
}

/// Teclas do overlay (spec §4.3) e o modo atual, no canto inferior esquerdo.
final class PainelDeAjuda: FundoDePainel {
    let titulo = FundoDePainel.rotulo("", negrito: true)

    init() {
        super.init(orientacao: .vertical)
        titulo.font = .systemFont(ofSize: 13, weight: .semibold)
        pilha.addArrangedSubview(titulo)
        let grade = NSGridView(
            views: Self.linhas.map { tecla, efeito in
                [Self.rotulo(tecla, negrito: true), Self.rotulo(efeito, secundario: true)]
            }
        )
        grade.rowSpacing = CGFloat(Tema.Espaco.e1)
        grade.columnSpacing = CGFloat(Tema.Espaco.e3)
        pilha.addArrangedSubview(grade)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private static var linhas: [(String, String)] {
        [
            (String(localized: "Esc"), String(localized: "Cancelar")),
            (String(localized: "Enter"), String(localized: "Confirmar")),
            (String(localized: "F"), String(localized: "Tela inteira")),
            (String(localized: "Espaço"), String(localized: "Alternar região e janela")),
            (String(localized: "Setas"), String(localized: "Mover 1 pixel")),
            (String(localized: "⇧ Setas"), String(localized: "Mover 10 pixels")),
            (String(localized: "M"), String(localized: "Lupa")),
            (String(localized: "H"), String(localized: "Ocultar a ajuda")),
        ]
    }

    func mostrar(modo: ModoDoOverlay) {
        let texto =
            switch modo {
            case .regiao: String(localized: "Modo: região")
            case .janela: String(localized: "Modo: janela")
            }
        if titulo.stringValue != texto { titulo.stringValue = texto }
    }
}

/// Barra curta com o atraso e o "incluir cursor" (spec §4.3).
final class BarraDeOpcoes: FundoDePainel {
    let atraso: NSSegmentedControl
    let incluirCursor: NSButton
    /// Por que o cursor está desabilitado sem atraso.
    let explicacao = FundoDePainel.rotulo(
        String(localized: "Sem atraso, a captura usa a imagem congelada, sem o cursor."),
        secundario: true
    )
    /// Como trazer a ajuda de volta, quando ela está oculta.
    let dicaDaAjuda = FundoDePainel.rotulo(String(localized: "H mostra a ajuda"), secundario: true)
    var aoMudar: ((OpcoesDeCaptura) -> Void)?
    private var opcoes = OpcoesDeCaptura(atraso: .nenhum, incluirCursor: false)

    init() {
        atraso = NSSegmentedControl(
            labels: Atraso.allCases.map(Self.nome),
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )
        incluirCursor = NSButton(
            checkboxWithTitle: String(localized: "Incluir cursor"),
            target: nil,
            action: nil
        )
        super.init(orientacao: .horizontal)
        atraso.target = self
        atraso.action = #selector(mudouAtraso)
        atraso.controlSize = .small
        atraso.setAccessibilityLabel(String(localized: "Atraso"))
        incluirCursor.target = self
        incluirCursor.action = #selector(mudouCursor)
        incluirCursor.controlSize = .small
        // O teclado é do overlay: Espaço e setas não podem ir para um controle.
        atraso.refusesFirstResponder = true
        incluirCursor.refusesFirstResponder = true
        for vista in [
            Self.rotulo(String(localized: "Atraso")), atraso, incluirCursor, explicacao,
            dicaDaAjuda,
        ] {
            pilha.addArrangedSubview(vista)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    static func nome(_ atraso: Atraso) -> String {
        switch atraso {
        case .nenhum: String(localized: "Nenhum")
        case .tres: String(localized: "3 s")
        case .cinco: String(localized: "5 s")
        case .dez: String(localized: "10 s")
        }
    }

    /// Mostra as opções do estado. Sem atraso, o cursor fica desabilitado com o valor lembrado.
    func mostrar(opcoes: OpcoesDeCaptura, ajudaVisivel: Bool) {
        self.opcoes = opcoes
        atraso.selectedSegment = Atraso.allCases.firstIndex(of: opcoes.atraso) ?? 0
        incluirCursor.state = opcoes.incluirCursor ? .on : .off
        incluirCursor.isEnabled = opcoes.atraso != .nenhum
        explicacao.isHidden = opcoes.atraso != .nenhum
        dicaDaAjuda.isHidden = ajudaVisivel
    }

    @objc private func mudouAtraso() {
        let indice = atraso.selectedSegment
        guard Atraso.allCases.indices.contains(indice) else { return }
        aoMudar?(
            OpcoesDeCaptura(atraso: Atraso.allCases[indice], incluirCursor: opcoes.incluirCursor)
        )
    }

    @objc private func mudouCursor() {
        aoMudar?(OpcoesDeCaptura(atraso: opcoes.atraso, incluirCursor: incluirCursor.state == .on))
    }
}

/// Ajuda em cima, barra embaixo, no canto inferior esquerdo da tela sob o cursor.
final class PaineisDoOverlay: NSStackView {
    let ajuda = PainelDeAjuda()
    let barra = BarraDeOpcoes()

    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = CGFloat(Tema.Espaco.e2)
        translatesAutoresizingMaskIntoConstraints = false
        addArrangedSubview(ajuda)
        addArrangedSubview(barra)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func mostrar(_ estado: EstadoDoOverlay) {
        ajuda.isHidden = !estado.ajudaVisivel
        ajuda.mostrar(modo: estado.modo)
        barra.mostrar(opcoes: estado.opcoes, ajudaVisivel: estado.ajudaVisivel)
    }

    // A pilha não cobre o vão entre `ajuda` e `barra` com nenhuma vista: sem isto, um clique
    // bem no vão caía na vista de baixo e começava uma seleção vazia, perdendo a escolhida.
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
}
