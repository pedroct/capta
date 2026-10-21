import AppKit
import CaptaNucleo
import Testing

@testable import Capta

@MainActor
@Suite("Gerenciador do overlay", .serialized)
struct GerenciadorDoOverlayTests: BancadaDoOverlay {
    let centro = NotificationCenter()

    // MARK: - Resultado

    @Test func escolherRetornaOResultadoDaMaquinaEFechaAsJanelas() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let tela = try Self.congelada(Self.telaA)
        let tarefa = try await abrir(g, telas: [tela])
        let janelas = g.janelasAbertas
        let eventos: [EventoDoOverlay] = [
            .mouseBaixo(CGPoint(x: 2, y: 3)),
            .mouseArrastou(CGPoint(x: 12, y: 13)),
            .mouseSolto(CGPoint(x: 12, y: 13)),
            .tecla(.enter),
        ]
        for evento in eventos { g.aplicar(evento) }

        let esperado = eventos.reduce(
            EstadoDoOverlay.inicial(
                modo: .regiao,
                telas: [Self.telaA],
                janelas: [],
                opcoes: Self.opcoes,
                ajudaVisivel: true
            ).reduzindo(.cursorMoveu(CGPoint(x: 5, y: 5)))
        ) { $0.reduzindo($1) }.resultado
        let resultado = await tarefa.value
        #expect(resultado == esperado)
        #expect(
            resultado
                == .confirmado(
                    .regiao(tela: Self.telaA, pixels: CGRect(x: 2, y: 3, width: 10, height: 10)),
                    Self.opcoes
                )
        )
        confereFechado(g, atalho, janelas: janelas)
    }

    @Test func umaJanelaDeOverlayPorTela() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let telas = [try Self.congelada(Self.telaA), try Self.congelada(Self.telaB)]
        let tarefa = try await abrir(g, telas: telas)
        let janelas = g.janelasAbertas
        #expect(janelas.count == 2)
        #expect(janelas.allSatisfy { $0 is JanelaDeOverlay })
        let ids = janelas.compactMap { ($0.contentView as? VistaDoOverlay)?.tela.descricao.id }
        #expect(ids == [1, 2])
        #expect(
            janelas.map(\.frame.size) == [
                CGSize(width: 40, height: 30), CGSize(width: 20, height: 30),
            ]
        )
        g.aplicar(.tecla(.esc))
        _ = await tarefa.value
        confereFechado(g, atalho, janelas: janelas)
    }

    @Test func todasAsVistasRecebemOMesmoEstado() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let telas = [try Self.congelada(Self.telaA), try Self.congelada(Self.telaB)]
        let tarefa = try await abrir(g, telas: telas)
        let vistas = g.janelasAbertas.compactMap { $0.contentView as? VistaDoOverlay }
        // Um evento que nasce numa vista chega à máquina e volta para todas.
        vistas.last?.aoEvento?(.tecla(.m))
        #expect(g.estado?.lupaLigada == true)
        #expect(vistas.allSatisfy { $0.estado == g.estado })
        g.aplicar(.tecla(.esc))
        _ = await tarefa.value
    }

    @Test func cursorRealEntraNoEstadoAoAbrir() async throws {
        let atalho = AtalhoFalso()
        let cursor = CGPoint(x: 50, y: 10)
        let g = gerenciador(atalho, cursor: cursor)
        let telas = [try Self.congelada(Self.telaA), try Self.congelada(Self.telaB)]
        let tarefa = try await abrir(g, telas: telas)
        #expect(g.estado?.cursor == cursor)
        // `F` pega a tela sob o cursor real, não a de (0, 0).
        g.aplicar(.tecla(.f))
        let resultado = await tarefa.value
        #expect(
            resultado
                == .confirmado(
                    .regiao(tela: Self.telaB, pixels: CGRect(x: 0, y: 0, width: 40, height: 60)),
                    Self.opcoes
                )
        )
    }

    @Test func modoJanelaRealcaAJanelaSobOCursorReal() async throws {
        let atalho = AtalhoFalso()
        let janela = JanelaDeTela(
            id: 77,
            quadro: CGRect(x: 0, y: 0, width: 20, height: 20),
            camada: 0,
            naTela: true
        )
        let g = gerenciador(atalho, cursor: CGPoint(x: 10, y: 10))
        let tarefa = try await abrir(
            g,
            telas: [try Self.congelada(Self.telaA)],
            janelas: [janela],
            modo: .janela
        )
        #expect(g.estado?.janelaRealcada == janela)
        g.aplicar(.tecla(.enter))
        #expect(await tarefa.value == .confirmado(.janela(id: 77), Self.opcoes))
    }

    // MARK: - Teclado

    @Test func teclaDoOverlayEConsumidaEAplicada() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        let m = try #require(Self.tecla(codigo: 46, caracteres: "m"))
        #expect(g.tratar(tecla: m) == nil)
        #expect(g.estado?.lupaLigada == true)
        // Tecla que não é do overlay também é engolida (sem bipe).
        let a = try #require(Self.tecla(codigo: 0, caracteres: "a"))
        #expect(g.tratar(tecla: a) == nil)
        // Com ⌘ passa adiante.
        let q = try #require(Self.tecla(codigo: 12, caracteres: "q", modificadores: .command))
        #expect(g.tratar(tecla: q) === q)
        let esc = try #require(Self.tecla(codigo: 53, caracteres: "\u{1b}"))
        #expect(g.tratar(tecla: esc) == nil)
        #expect(await tarefa.value == .cancelado)
        // Fechado, o monitor deixa tudo passar.
        #expect(g.tratar(tecla: a) === a)
    }

    // MARK: - Geometria das janelas

    @Test func quadroDaJanelaNoEspacoDoAppKit() {
        // Principal com 900 pontos de altura; o AppKit tem a origem embaixo.
        #expect(
            JanelaDeOverlay.quadroNoAppKit(
                de: CGRect(x: 0, y: 0, width: 1440, height: 900),
                alturaDaPrincipal: 900
            ) == CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
        // Tela acima da principal: y negativo no espaço global, acima de 900 no AppKit.
        #expect(
            JanelaDeOverlay.quadroNoAppKit(
                de: CGRect(x: -200, y: -1080, width: 1920, height: 1080),
                alturaDaPrincipal: 900
            ) == CGRect(x: -200, y: 900, width: 1920, height: 1080)
        )
        // Tela abaixo e à direita.
        #expect(
            JanelaDeOverlay.quadroNoAppKit(
                de: CGRect(x: 1440, y: 600, width: 800, height: 600),
                alturaDaPrincipal: 900
            ) == CGRect(x: 1440, y: -300, width: 800, height: 600)
        )
    }

    @Test func janelaDeOverlayNaoEmpurraOQuadro() {
        let quadro = CGRect(x: 0, y: 0, width: 40, height: 30)
        let janela = JanelaDeOverlay(quadro: quadro)
        #expect(janela.canBecomeKey)
        #expect(!janela.canBecomeMain)
        #expect(janela.level == .screenSaver)
        let acima = CGRect(x: 0, y: 5000, width: 40, height: 30)
        #expect(janela.constrainFrameRect(acima, to: nil) == acima)
    }

    @Test func indiceDaTelaSobOCursor() {
        let telas = [Self.telaA, Self.telaB]
        #expect(GerenciadorDoOverlay.indiceDaTela(sob: CGPoint(x: 45, y: 5), em: telas) == 1)
        #expect(GerenciadorDoOverlay.indiceDaTela(sob: CGPoint(x: 5, y: 5), em: telas) == 0)
        // Fora de todas: a principal.
        #expect(GerenciadorDoOverlay.indiceDaTela(sob: CGPoint(x: -99, y: 5), em: telas) == 0)
        #expect(GerenciadorDoOverlay.indiceDaTela(sob: .zero, em: []) == nil)
    }

    @Test func gerenciadorEUmSeletorDeCaptura() {
        let seletor: any SeletorDeCaptura = gerenciador(AtalhoFalso())
        #expect(seletor is GerenciadorDoOverlay)
    }

    // MARK: - Ajuda lembrada

    @Test func hAvisaAMudancaDaAjudaSoQuandoElaMuda() async throws {
        let atalho = AtalhoFalso()
        let avisos = Avisos()
        let g = GerenciadorDoOverlay(
            atalhoDeEsc: atalho,
            ativar: { nil },
            posicaoDoCursor: { CGPoint(x: 5, y: 5) },
            centro: centro,
            appAtivo: { true },
            aoMudarAjuda: { avisos.valores.append($0) }
        )
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        g.aplicar(.tecla(.h))
        g.aplicar(.tecla(.m))
        g.aplicar(.tecla(.h))
        #expect(avisos.valores == [false, true])
        g.aplicar(.tecla(.esc))
        _ = await tarefa.value
    }

    @MainActor
    private final class Avisos {
        var valores: [Bool] = []
    }
}
