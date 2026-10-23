import CaptaNucleo
import CoreGraphics
import Foundation
import Observation

/// Liga a máquina de estados do editor (núcleo) à captura aberta: monta o contexto de cada
/// evento, executa a ação devolvida e guarda a prévia do gesto em curso.
///
/// Regras de segurança da prévia: ela só existe enquanto uma ação `.previa` a sustenta; qualquer
/// outro evento a apaga. Depois de desfazer, refazer ou de uma edição recusada, o `.sincronizar`
/// tira da seleção o que deixou de existir.
@MainActor
@Observable
final class EditorDaCaptura {
    /// Distância de acerto, em pontos da tela (igual em qualquer zoom).
    private static let toleranciaEmPontos: CGFloat = 4
    /// Distância do ponto de giro ao objeto, em pontos da tela. A vista desenha o ponto com a
    /// mesma constante com que a máquina de estados o acerta.
    static let giroEmPontos: CGFloat = 20

    let captura: CapturaAberta
    private(set) var estado: EstadoDoEditor
    private(set) var previa: Documento?
    private(set) var zoom: Double = 1
    /// `ajustar`: o zoom acompanha a janela; `manual`: a pessoa escolheu (menu, atalho ou pinça).
    private(set) var modoDeZoom: ModoDeZoom = .ajustar

    @ObservationIgnored private let memoria: MemoriaLembrada
    @ObservationIgnored private let novoId: () -> UUID
    /// Área visível do canvas, em pontos. Fica fora da observação: a vista a informa durante o
    /// layout, e mexer em estado observado nessa hora é o que o SwiftUI reclama.
    @ObservationIgnored private var areaVisivel: CGSize = .zero

    /// O que a vista desenha: a prévia, se houver; senão, o documento da captura.
    var documentoExibido: Documento { previa ?? captura.documento }

    init(
        captura: CapturaAberta,
        memoria: MemoriaLembrada,
        novoId: @escaping () -> UUID = UUID.init
    ) {
        self.captura = captura
        self.memoria = memoria
        self.novoId = novoId
        estado = EstadoDoEditor(memoria: memoria.memoria)
    }

    /// O renderizador da captura, o mesmo do copiar e do salvar PNG.
    var renderizador: Renderizador { captura.renderizador }

    /// A composição do canvas, com o renderizador da captura.
    func novaComposicao() throws -> ComposicaoDoCanvas {
        try ComposicaoDoCanvas(base: captura.base, renderizador: renderizador)
    }

    func tratar(_ evento: EventoDoEditor, conversao: ConversaoDoCanvas) {
        executar(
            evento,
            tolerancia: conversao.pixels(dePontos: Self.toleranciaEmPontos),
            distanciaDoGiro: conversao.pixels(dePontos: Self.giroEmPontos)
        )
    }

    /// Evento que não depende de posição (barra, painel e menu): sem tolerância de acerto.
    func comandar(_ evento: EventoDoEditor) {
        executar(evento, tolerancia: 0, distanciaDoGiro: 0)
    }

    func selecionarTudo() { comandar(.selecionarTudo) }
    func duplicar() { comandar(.duplicar) }

    // MARK: Zoom

    /// A vista informa a área visível a cada layout. Devolve `true` se, no modo ajustar, o zoom
    /// precisa mudar: quem chama então agenda ``aplicarAjuste()`` fora do passe de layout.
    func areaVisivelMudou(_ area: CGSize) -> Bool {
        guard area.width > 0, area.height > 0, area != areaVisivel else { return false }
        areaVisivel = area
        return modoDeZoom == .ajustar && zoomDeAjuste != zoom
    }

    /// No modo ajustar, leva o zoom ao que cabe a imagem inteira na área visível.
    func aplicarAjuste() {
        guard modoDeZoom == .ajustar, areaVisivel.width > 0, areaVisivel.height > 0 else { return }
        zoom = zoomDeAjuste
    }

    func ajustarAJanela() {
        modoDeZoom = .ajustar
        aplicarAjuste()
    }

    func tamanhoReal() { definirZoom(1) }

    func definirZoom(_ valor: Double) {
        modoDeZoom = .manual
        zoom = Zoom.limitado(valor)
    }

    func aumentarZoom() { definirZoom(Zoom.acima(de: zoom)) }

    func diminuirZoom() {
        modoDeZoom = .manual
        zoom = Zoom.abaixo(de: zoom)
    }

    /// Pinça: `magnificacao` é a variação relativa do evento do trackpad.
    func pinca(_ magnificacao: Double) {
        modoDeZoom = .manual
        zoom = Zoom.limitado(zoom * (1 + magnificacao), partindoDe: zoom)
    }

    private var zoomDeAjuste: Double {
        let base = captura.base
        let tamanho = Enquadramento.pontos(
            larguraEmPixels: base.width,
            alturaEmPixels: base.height,
            escala: captura.escala
        )
        return Double(Enquadramento.escala(imagem: tamanho, area: areaVisivel, modo: .ajustar))
    }

    func desfazer() {
        captura.desfazer()
        sincronizar()
    }

    func refazer() {
        captura.refazer()
        sincronizar()
    }

    // MARK: Privado

    /// O documento mudou fora da máquina: apaga a prévia e descarta da seleção o que sumiu.
    private func sincronizar() {
        previa = nil
        executar(.sincronizar, tolerancia: 0, distanciaDoGiro: 0)
        previa = nil
    }

    private func executar(
        _ evento: EventoDoEditor,
        tolerancia: CGFloat,
        distanciaDoGiro: CGFloat
    ) {
        let contexto = ContextoDoEditor(
            documento: captura.documento,
            tolerancia: tolerancia,
            distanciaDoGiro: distanciaDoGiro,
            novoId: novoId
        )
        let acao = estado.reduzir(evento, contexto: contexto)
        var recusada = false
        switch acao {
        case .aplicar(let edicao):
            previa = nil
            recusada = !captura.aplicar(edicao)
        case .previa(let edicao):
            previa = try? captura.sessao.simular(edicao)
        case .cancelarPrevia:
            previa = nil
        case nil:
            previa = nil
        }
        if estado.memoria != memoria.memoria { memoria.memoria = estado.memoria }
        // Edição recusada: a seleção pode apontar para um objeto que nunca existiu.
        if recusada { executar(.sincronizar, tolerancia: 0, distanciaDoGiro: 0) }
    }
}

/// Como o zoom do canvas é decidido.
enum ModoDeZoom: Equatable {
    case ajustar
    case manual
}

/// Tecla do editor já traduzida do evento do AppKit, para que a regra fique testável.
enum TeclaDoEditor: Equatable {
    case esc
    case apagar
    /// Seta: deslocamento de um pixel por eixo, Y para baixo.
    case seta(dx: Int, dy: Int)
    case ferramenta(Ferramenta)

    /// `codigo` é o código de tecla virtual; `caractere`, o texto da tecla sem modificadores.
    /// Devolve `nil` para tecla que o editor não usa.
    init?(codigo: UInt16, caractere: String?) {
        switch codigo {
        case 53: self = .esc
        case 51, 117: self = .apagar
        case 123: self = .seta(dx: -1, dy: 0)
        case 124: self = .seta(dx: 1, dy: 0)
        case 125: self = .seta(dx: 0, dy: 1)
        case 126: self = .seta(dx: 0, dy: -1)
        default:
            switch caractere?.lowercased() {
            case "v": self = .ferramenta(.selecao)
            case "a": self = .ferramenta(.seta)
            case "l": self = .ferramenta(.linha)
            case "r": self = .ferramenta(.forma)
            case "h": self = .ferramenta(.realce)
            default: return nil
            }
        }
    }
}

extension EditorDaCaptura {
    /// Passo das setas com `⇧`, em pixels do documento.
    private static let passoComShift = 10

    /// Executa a tecla. Devolve `true` se o editor a usou.
    @discardableResult
    func tratar(_ tecla: TeclaDoEditor, shift: Bool, conversao: ConversaoDoCanvas) -> Bool {
        switch tecla {
        case .esc:
            tratar(.esc, conversao: conversao)
        case .apagar:
            tratar(.excluir, conversao: conversao)
        case .seta(let dx, let dy):
            let passo = shift ? Self.passoComShift : 1
            tratar(.deslocar(CGVector(dx: dx * passo, dy: dy * passo)), conversao: conversao)
        case .ferramenta(let ferramenta):
            tratar(.escolher(ferramenta), conversao: conversao)
        }
        return true
    }
}
