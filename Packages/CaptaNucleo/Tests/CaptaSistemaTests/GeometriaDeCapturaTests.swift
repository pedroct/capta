import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import CaptaSistema

@Suite("Geometria da captura ao vivo e da lista de janelas")
struct GeometriaDeCapturaTests {
    private let retina = DescricaoDeTela(
        id: 1,
        quadro: CGRect(x: 0, y: 0, width: 1440, height: 900),
        escala: 2,
        principal: true
    )
    private let externa = DescricaoDeTela(
        id: 2,
        quadro: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
        escala: 1,
        principal: false
    )
    private let acimaAEsquerda = DescricaoDeTela(
        id: 3,
        quadro: CGRect(x: -1920, y: -1080, width: 1920, height: 1080),
        escala: 1,
        principal: false
    )

    // MARK: Região

    @Test func regiaoEmRetinaViraPontosRelativosATelaEPixelsDeSaida() throws {
        let pixels = CGRect(x: 100, y: 50, width: 300, height: 201)
        let pedido = try GeometriaDeCaptura.pedidoDeRegiao(
            pixels: pixels,
            em: retina,
            atuais: [externa, retina]
        )
        #expect(pedido.origem == CGRect(x: 50, y: 25, width: 150, height: 100.5))
        #expect(pedido.largura == 300)
        #expect(pedido.altura == 201)
    }

    @Test func regiaoEmTelaComOrigemNegativaFicaRelativaATela() throws {
        let tela = acimaAEsquerda
        let pixels = CGRect(x: 10, y: 20, width: 30, height: 40)
        let pedido = try GeometriaDeCaptura.pedidoDeRegiao(pixels: pixels, em: tela, atuais: [tela])
        let global = tela.quadroEmPontos(dePixels: pixels)
        #expect(pedido.origem == global.offsetBy(dx: -tela.quadro.minX, dy: -tela.quadro.minY))
        #expect(pedido.origem == CGRect(x: 10, y: 20, width: 30, height: 40))
        #expect((pedido.largura, pedido.altura) == (30, 40))
    }

    @Test func regiaoDaTelaInteiraEAceita() throws {
        let pixels = CGRect(x: 0, y: 0, width: 2880, height: 1800)
        let pedido = try GeometriaDeCaptura.pedidoDeRegiao(
            pixels: pixels,
            em: retina,
            atuais: [retina]
        )
        #expect(pedido.origem == CGRect(x: 0, y: 0, width: 1440, height: 900))
        #expect((pedido.largura, pedido.altura) == (2880, 1800))
    }

    @Test func telaPrincipalTrocadaNaoImporta() throws {
        let mesma = DescricaoDeTela(id: 1, quadro: retina.quadro, escala: 2, principal: false)
        let pixels = CGRect(x: 0, y: 0, width: 2, height: 2)
        let pedido = try GeometriaDeCaptura.pedidoDeRegiao(
            pixels: pixels,
            em: retina,
            atuais: [mesma]
        )
        #expect((pedido.largura, pedido.altura) == (2, 2))
    }

    private static func tela(_ id: UInt32, _ quadro: CGRect, escala: Double) -> DescricaoDeTela {
        DescricaoDeTela(id: id, quadro: quadro, escala: escala, principal: true)
    }

    @Test(arguments: [
        [DescricaoDeTela](),
        // Outra tela só.
        [tela(2, CGRect(x: 0, y: 0, width: 1440, height: 900), escala: 2)],
        // Mesma tela, movida.
        [tela(1, CGRect(x: 1, y: 0, width: 1440, height: 900), escala: 2)],
        // Mesma tela, outra resolução.
        [tela(1, CGRect(x: 0, y: 0, width: 1680, height: 1050), escala: 2)],
        // Mesma tela, outra escala.
        [tela(1, CGRect(x: 0, y: 0, width: 1440, height: 900), escala: 1)],
    ])
    func telaQueSumiuOuMudouFalha(atuais: [DescricaoDeTela]) {
        #expect(throws: ErroCaptura.telaNaoEncontrada) {
            try GeometriaDeCaptura.pedidoDeRegiao(
                pixels: CGRect(x: 0, y: 0, width: 10, height: 10),
                em: retina,
                atuais: atuais
            )
        }
    }

    @Test(arguments: [
        CGRect(x: 0.5, y: 0, width: 10, height: 10),
        CGRect(x: 0, y: 0, width: 10.25, height: 10),
        CGRect(x: 0, y: 0, width: 0, height: 10),
        CGRect(x: 0, y: 0, width: 10, height: 0),
        CGRect(x: -1, y: 0, width: 10, height: 10),
        CGRect(x: 0, y: -1, width: 10, height: 10),
        CGRect(x: 2871, y: 0, width: 10, height: 10),
        CGRect(x: 0, y: 1791, width: 10, height: 10),
        CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10),
        CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 10),
    ])
    func pixelsInvalidosOuForaDaTelaFalham(pixels: CGRect) {
        #expect(throws: ErroCaptura.falhou) {
            try GeometriaDeCaptura.pedidoDeRegiao(pixels: pixels, em: retina, atuais: [retina])
        }
    }

    @Test func telaSemTamanhoEmPixelsFalha() {
        let vazia = DescricaoDeTela(id: 9, quadro: .zero, escala: 2, principal: true)
        #expect(throws: ErroCaptura.falhou) {
            try GeometriaDeCaptura.pedidoDeRegiao(
                pixels: CGRect(x: 0, y: 0, width: 1, height: 1),
                em: vazia,
                atuais: [vazia]
            )
        }
    }

    // MARK: Janela

    @Test func janelaNaRetinaUsaEscala2() throws {
        let janela = JanelaDeTela(
            id: 7,
            quadro: CGRect(x: 100, y: 100, width: 800, height: 600),
            camada: 0,
            naTela: true
        )
        let pedido = try GeometriaDeCaptura.pedidoDeJanela(janela, entre: [externa, retina])
        #expect(pedido == PedidoDeJanela(escala: 2, largura: 1600, altura: 1200))
    }

    @Test func janelaUsaATelaDeMaiorIntersecao() throws {
        // 100 pontos na Retina, 700 na externa.
        let janela = JanelaDeTela(
            id: 7,
            quadro: CGRect(x: 1340, y: 0, width: 800, height: 600),
            camada: 0,
            naTela: true
        )
        let pedido = try GeometriaDeCaptura.pedidoDeJanela(janela, entre: [retina, externa])
        #expect(pedido == PedidoDeJanela(escala: 1, largura: 800, altura: 600))
    }

    @Test func tamanhoDaJanelaArredondaQuadroVezesEscala() throws {
        let janela = JanelaDeTela(
            id: 7,
            quadro: CGRect(x: 10, y: 10, width: 100.25, height: 50.2),
            camada: 0,
            naTela: true
        )
        let pedido = try GeometriaDeCaptura.pedidoDeJanela(janela, entre: [retina])
        #expect((pedido.largura, pedido.altura) == (201, 100))
    }

    @Test func janelaForaDeTodasAsTelasFalha() {
        let janela = JanelaDeTela(
            id: 7,
            quadro: CGRect(x: 5000, y: 5000, width: 100, height: 100),
            camada: 0,
            naTela: false
        )
        #expect(throws: ErroCaptura.telaNaoEncontrada) {
            try GeometriaDeCaptura.pedidoDeJanela(janela, entre: [retina, externa])
        }
    }

    @Test func janelaPequenaDemaisParaUmPixelFalha() {
        let janela = JanelaDeTela(
            id: 7,
            quadro: CGRect(x: 1500, y: 10, width: 0.4, height: 100),
            camada: 0,
            naTela: true
        )
        #expect(throws: ErroCaptura.falhou) {
            try GeometriaDeCaptura.pedidoDeJanela(janela, entre: [externa])
        }
    }

    // MARK: Ordem das janelas

    private func janelas(_ ids: [UInt32]) -> [JanelaDeTela] {
        ids.map { JanelaDeTela(id: $0, quadro: .zero, camada: 0, naTela: true) }
    }

    @Test func ordenaPelaOrdemDaFrenteParaTras() {
        let ordenadas = GeometriaDeCaptura.ordenar(janelas([1, 2, 3]), frenteParaTras: [3, 1, 2])
        #expect(ordenadas.map(\.id) == [3, 1, 2])
    }

    @Test func janelaSemPosicaoVaiParaOFimNaOrdemOriginal() {
        let ordenadas = GeometriaDeCaptura.ordenar(
            janelas([5, 1, 6, 2]),
            frenteParaTras: [9, 2, 1, 2]
        )
        #expect(ordenadas.map(\.id) == [2, 1, 5, 6])
    }

    @Test func semOrdemConhecidaMantemAOrdemRecebida() {
        let ordenadas = GeometriaDeCaptura.ordenar(janelas([4, 2, 8]), frenteParaTras: [])
        #expect(ordenadas.map(\.id) == [4, 2, 8])
    }

    @Test func idsSaemDoNumeroDaJanelaNaOrdemDaLista() {
        let chave = kCGWindowNumber as String
        let info: [[String: Any]] = [
            [chave: NSNumber(value: 42)],
            [chave: 7],
            ["outra": 1],
            [chave: "texto"],
            [chave: -3],
            [chave: Int(UInt32.max) + 1],
            [chave: NSNumber(value: UInt32.max)],
        ]
        #expect(GeometriaDeCaptura.idsDeJanelas(info) == [42, 7, UInt32.max])
    }
}
