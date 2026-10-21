import CaptaNucleo
import CoreGraphics
import Testing

@testable import Capta

@Suite("Cena do overlay")
struct CenaDoOverlayTests {
    /// Tela Retina pequena com origem fora do zero, para pegar erros de conversão.
    static let retina = DescricaoDeTela(
        id: 1,
        quadro: CGRect(x: 100, y: 50, width: 40, height: 30),
        escala: 2,
        principal: true
    )
    /// Tela 1x à direita da Retina, na mesma faixa vertical.
    static let lateral = DescricaoDeTela(
        id: 2,
        quadro: CGRect(x: 140, y: 50, width: 40, height: 30),
        escala: 1,
        principal: false
    )
    static let grande = DescricaoDeTela(
        id: 3,
        quadro: CGRect(x: 0, y: 0, width: 400, height: 300),
        escala: 1,
        principal: true
    )
    static let opcoes = OpcoesDeCaptura(atraso: .nenhum, incluirCursor: false)
    static let medida = CGSize(width: 50, height: 10)
    /// Rótulo de `medida` com a folga dos dois lados.
    static let rotulo = CGSize(width: 66, height: 14)

    private func estado(
        telas: [DescricaoDeTela] = [retina, lateral],
        janelas: [JanelaDeTela] = [],
        modo: ModoDoOverlay = .regiao,
        eventos: [EventoDoOverlay]
    ) -> EstadoDoOverlay {
        eventos.reduce(
            EstadoDoOverlay.inicial(
                modo: modo,
                telas: telas,
                janelas: janelas,
                opcoes: Self.opcoes,
                ajudaVisivel: true
            )
        ) { $0.reduzindo($1) }
    }

    private func cena(_ estado: EstadoDoOverlay, tela: DescricaoDeTela) -> CenaDoOverlay {
        let pixels = tela.limitesEmPixels ?? .zero
        return CenaDoOverlay(estado: estado, tela: tela, tamanhoDaImagem: pixels) { _ in
            Self.medida
        }
    }

    // MARK: - Conversões

    @Test func conversoesEntrePontosGlobaisELocais() {
        let tela = Self.retina
        #expect(tela.local(de: CGPoint(x: 110, y: 55)) == CGPoint(x: 10, y: 5))
        #expect(tela.global(de: CGPoint(x: 10, y: 5)) == CGPoint(x: 110, y: 55))
        #expect(
            tela.local(de: CGRect(x: 90, y: 60, width: 20, height: 10))
                == CGRect(x: -10, y: 10, width: 20, height: 10)
        )
        #expect(
            tela.localDePixels(CGRect(x: 4, y: 6, width: 20, height: 10))
                == CGRect(x: 2, y: 3, width: 10, height: 5)
        )
    }

    // MARK: - Mira

    @Test func miraNaTelaDoCursorAlinhadaAoPixel() {
        let atual = estado(eventos: [.cursorMoveu(CGPoint(x: 110.7, y: 60.2))])
        let cena = cena(atual, tela: Self.retina)
        #expect(cena.miraX == 10.5)
        #expect(cena.miraY == 10)
        #expect(cena.temOCursor)
    }

    @Test func miraEmOutraTelaSoNoEixoQueACruza() {
        let atual = estado(eventos: [.cursorMoveu(CGPoint(x: 110.7, y: 60.2))])
        let cena = cena(atual, tela: Self.lateral)
        #expect(cena.miraX == nil)
        #expect(cena.miraY == 10)
        #expect(!cena.temOCursor)
        #expect(cena.dica == nil)
        #expect(cena.lupa == nil)
    }

    // MARK: - Seleção

    @Test func selecaoViraFuroContornoEDimensoesEmPixels() throws {
        let atual = estado(eventos: [
            .mouseBaixo(CGPoint(x: 102, y: 53)),
            .mouseArrastou(CGPoint(x: 112, y: 58)),
            .mouseSolto(CGPoint(x: 112, y: 58)),
        ])
        let cena = cena(atual, tela: Self.retina)
        let esperado = CGRect(x: 2, y: 3, width: 10, height: 5)
        #expect(cena.selecao == esperado)
        #expect(cena.furo == esperado)
        #expect(cena.janela == nil)
        let dimensoes = try #require(cena.dimensoes)
        #expect(dimensoes.texto == "20 × 10")
        let origem = Posicionamento.origem(
            junto: CGPoint(x: esperado.maxX, y: esperado.maxY),
            tamanho: Self.rotulo,
            dentro: CGRect(x: 0, y: 0, width: 40, height: 30),
            afastamento: MedidasDoOverlay.afastamento
        )
        #expect(
            dimensoes.quadro.origin
                == CGPoint(x: origem.x.rounded(.down), y: origem.y.rounded(.down))
        )
        #expect(dimensoes.quadro.size == Self.rotulo)
        // Com seleção, a dica do modo some.
        #expect(cena.dica == nil)
    }

    @Test func selecaoDeOutraTelaNaoAparece() {
        let atual = estado(eventos: [
            .mouseBaixo(CGPoint(x: 102, y: 53)),
            .mouseSolto(CGPoint(x: 112, y: 58)),
        ])
        let cena = cena(atual, tela: Self.lateral)
        #expect(cena.selecao == nil)
        #expect(cena.furo == nil)
        #expect(cena.dimensoes == nil)
    }

    // MARK: - Janela

    @Test func janelaRealcadaViraFuroRecortadoNaTela() {
        let janela = JanelaDeTela(
            id: 7,
            quadro: CGRect(x: 90, y: 40, width: 30, height: 20),
            camada: 0,
            naTela: true
        )
        let atual = estado(
            janelas: [janela],
            modo: .janela,
            eventos: [.cursorMoveu(CGPoint(x: 101, y: 51))]
        )
        let cena = cena(atual, tela: Self.retina)
        #expect(cena.janela == CGRect(x: -10, y: -10, width: 30, height: 20))
        #expect(cena.furo == CGRect(x: 0, y: 0, width: 20, height: 10))
        #expect(cena.selecao == nil)
        #expect(cena.dica?.texto == "Janela")
    }

    @Test func janelaForaDaTelaNaoFura() {
        let janela = JanelaDeTela(
            id: 7,
            quadro: CGRect(x: 100, y: 50, width: 10, height: 10),
            camada: 0,
            naTela: true
        )
        let atual = estado(
            janelas: [janela],
            modo: .janela,
            eventos: [.cursorMoveu(CGPoint(x: 101, y: 51))]
        )
        let cena = cena(atual, tela: Self.lateral)
        #expect(cena.janela == nil)
        #expect(cena.furo == nil)
    }

    // MARK: - Dica e lupa

    @Test func dicaDoModoJuntoAoCursorSemSelecao() throws {
        let atual = estado(telas: [Self.grande], eventos: [.cursorMoveu(CGPoint(x: 100, y: 80))])
        let cena = cena(atual, tela: Self.grande)
        let dica = try #require(cena.dica)
        #expect(dica.texto == "Região")
        #expect(dica.quadro == CGRect(origin: CGPoint(x: 112, y: 92), size: Self.rotulo))
    }

    @Test func lupaAmostraAImagemEMarcaOPixelDoCursor() throws {
        let atual = estado(
            telas: [Self.grande],
            eventos: [.cursorMoveu(CGPoint(x: 100.5, y: 80.2)), .tecla(.m)]
        )
        let cena = cena(atual, tela: Self.grande)
        let lupa = try #require(cena.lupa)
        #expect(lupa.amostra == CGRect(x: 93, y: 73, width: 15, height: 15))
        // 15 pixels × 8 = 120 pontos; o rótulo da coordenada fica embaixo, com a mesma largura.
        #expect(lupa.quadro == CGRect(x: 116, y: 96, width: 120, height: 120))
        #expect(lupa.pixelSobCursor == CGRect(x: 116 + 56, y: 96 + 56, width: 8, height: 8))
        #expect(lupa.coordenada.texto == "100, 80")
        #expect(lupa.coordenada.quadro == CGRect(x: 116, y: 216, width: 120, height: 14))
        #expect(cena.dica == nil)
    }

    @Test func lupaNaBordaDaImagemMarcaOPixelForaDoCentro() throws {
        let atual = estado(
            telas: [Self.grande],
            eventos: [.cursorMoveu(CGPoint(x: 1, y: 2)), .tecla(.m)]
        )
        let lupa = try #require(cena(atual, tela: Self.grande).lupa)
        #expect(lupa.amostra.origin == .zero)
        let origem = lupa.quadro.origin
        #expect(lupa.pixelSobCursor.origin == CGPoint(x: origem.x + 8, y: origem.y + 16))
    }

    @Test func semImagemNaoHaLupa() {
        let atual = estado(
            telas: [Self.grande],
            eventos: [.cursorMoveu(CGPoint(x: 1, y: 2)), .tecla(.m)]
        )
        let cena = CenaDoOverlay(estado: atual, tela: Self.grande, tamanhoDaImagem: .zero) { _ in
            Self.medida
        }
        #expect(cena.lupa == nil)
    }

    /// Sem posição do cursor (o `CGEvent` pode falhar), a lupa não aparece em vez de quebrar.
    @Test func cursorNaoFinitoNaoTemMiraNemLupa() {
        let atual = estado(
            telas: [Self.grande],
            eventos: [.cursorMoveu(CGPoint(x: CGFloat.nan, y: .nan)), .tecla(.m)]
        )
        let cena = cena(atual, tela: Self.grande)
        #expect(cena.lupa == nil)
        #expect(cena.miraX == nil)
        #expect(cena.miraY == nil)
    }

    // MARK: - Invalidação

    @Test func areasCobremTudoOQueEDesenhado() throws {
        let atual = estado(
            telas: [Self.grande],
            eventos: [
                .mouseBaixo(CGPoint(x: 50, y: 40)),
                .mouseSolto(CGPoint(x: 150, y: 120)),
                .tecla(.m),
            ]
        )
        let cena = cena(atual, tela: Self.grande)
        let areas = cena.areasDeDesenho
        func coberto(_ retangulo: CGRect) -> Bool { areas.contains { $0.contains(retangulo) } }
        let x = try #require(cena.miraX)
        let y = try #require(cena.miraY)
        #expect(coberto(CGRect(x: x, y: 0, width: 1, height: 300)))
        #expect(coberto(CGRect(x: 0, y: y, width: 400, height: 1)))
        let selecao = try #require(cena.selecao)
        let margem = MedidasDoOverlay.ladoDaAlca
        #expect(coberto(selecao.insetBy(dx: -margem, dy: -margem)))
        #expect(coberto(try #require(cena.dimensoes).quadro))
        let lupa = try #require(cena.lupa)
        #expect(coberto(lupa.quadro.union(lupa.coordenada.quadro)))
    }

    @Test func areasDaJanelaEDaDica() throws {
        let janela = JanelaDeTela(
            id: 7,
            quadro: CGRect(x: 10, y: 10, width: 100, height: 50),
            camada: 0,
            naTela: true
        )
        let atual = estado(
            telas: [Self.grande],
            janelas: [janela],
            modo: .janela,
            eventos: [.cursorMoveu(CGPoint(x: 20, y: 20))]
        )
        let cena = cena(atual, tela: Self.grande)
        let areas = cena.areasDeDesenho
        #expect(areas.contains { $0.contains(CGRect(x: 10, y: 10, width: 100, height: 50)) })
        let dica = try #require(cena.dica)
        #expect(areas.contains { $0.contains(dica.quadro) })
    }

    // MARK: - Textos

    @Test func textosDoOverlay() {
        #expect(
            TextosDoOverlay.dimensoes(CGRect(x: 4, y: 6, width: 1920, height: 1080))
                == "1920 × 1080"
        )
        #expect(TextosDoOverlay.coordenada(CGPoint(x: 3, y: 4)) == "3, 4")
        #expect(TextosDoOverlay.modo(.regiao) == "Região")
        #expect(TextosDoOverlay.modo(.janela) == "Janela")
        #expect(TextosDoOverlay.acessibilidade == "Seleção de captura. Esc cancela.")
    }
}
