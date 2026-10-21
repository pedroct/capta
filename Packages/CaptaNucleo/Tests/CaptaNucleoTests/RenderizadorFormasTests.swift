import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

@Suite("Renderizador: formas, linhas, setas, realce e etapas")
struct RenderizadorFormasTests {
    let lado = CGSize(width: 100, height: 100)
    var base: CGImage { imagemSolida(lado, cor: .branco) }

    func documento(_ objetos: [Anotacao]) -> Documento {
        Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: lado,
            escala: 1,
            recorte: nil,
            objetos: objetos
        )
    }

    func renderizar(_ objetos: [Anotacao]) throws -> CGImage {
        try Renderizador().renderizar(documento(objetos), base: base)
    }

    static let vermelhoPuro = CorRGBA(r: 1, g: 0, b: 0)
    static let azulPuro = CorRGBA(r: 0, g: 0, b: 1)
    static let verdePuro = CorRGBA(r: 0, g: 1, b: 0)

    func retangulo(_ r: CGRect, _ cor: CorRGBA) -> Anotacao {
        Anotacao(
            geometria: .forma(.retangulo, r),
            estilo: Estilo(cor: cor, largura: 0, preenchimento: cor)
        )
    }

    @Test func semObjetosDevolveABaseIgual() throws {
        let saida = try renderizar([])
        #expect(saida.width == 100 && saida.height == 100)
        for (x, y) in [(0, 0), (50, 50), (99, 99), (10, 80)] {
            #expect(proximos(pixel(saida, x: x, y: y), 255, 255, 255))
        }
    }

    @Test func formaRetanguloPreenchidoPintaSoDentro() throws {
        let saida = try renderizar([
            retangulo(CGRect(x: 10, y: 10, width: 40, height: 40), Self.vermelhoPuro)
        ])
        #expect(proximos(pixel(saida, x: 20, y: 20), 255, 0, 0))
        #expect(proximos(pixel(saida, x: 60, y: 60), 255, 255, 255))
    }

    @Test func origemNoCantoSuperiorEsquerdo() throws {
        let saida = try renderizar([
            retangulo(CGRect(x: 0, y: 0, width: 20, height: 20), Self.vermelhoPuro)
        ])
        #expect(proximos(pixel(saida, x: 5, y: 5), 255, 0, 0))
        #expect(proximos(pixel(saida, x: 5, y: 95), 255, 255, 255))
    }

    @Test func camadaPosteriorFicaPorCima() throws {
        let saida = try renderizar([
            retangulo(CGRect(x: 10, y: 10, width: 40, height: 40), Self.vermelhoPuro),
            retangulo(CGRect(x: 30, y: 30, width: 40, height: 40), Self.azulPuro),
        ])
        #expect(proximos(pixel(saida, x: 40, y: 40), 0, 0, 255))
        #expect(proximos(pixel(saida, x: 15, y: 15), 255, 0, 0))
    }

    @Test func realceAmareloTranslucidoMisturaComABase() throws {
        let amarelo = CorRGBA.amarelo
        let saida = try renderizar([
            Anotacao(
                geometria: .realce(CGRect(x: 10, y: 10, width: 50, height: 50)),
                estilo: Estilo(cor: amarelo, largura: 0, opacidade: 0.5, preenchimento: amarelo)
            )
        ])
        let p = pixel(saida, x: 30, y: 30)
        let esperadoB = Int((1 - 0.5) * 255 + 0.5 * amarelo.b * 255)
        #expect(abs(Int(p.b) - esperadoB) <= 2)
        #expect(p.b < p.r && p.b < p.g)
        #expect(p.r > 0 && p.r <= 255)
        #expect(proximos(pixel(saida, x: 80, y: 80), 255, 255, 255))
    }

    @Test func linhaAtravessaOPixelDoMeio() throws {
        let saida = try renderizar([
            Anotacao(
                geometria: .linha(inicio: CGPoint(x: 10, y: 50), fim: CGPoint(x: 90, y: 50)),
                estilo: Estilo(cor: Self.vermelhoPuro, largura: 6)
            )
        ])
        #expect(proximos(pixel(saida, x: 50, y: 50), 255, 0, 0))
        #expect(proximos(pixel(saida, x: 50, y: 80), 255, 255, 255))
    }

    @Test func linhaTracejadaTemLacunas() throws {
        let saida = try renderizar([
            Anotacao(
                geometria: .linha(inicio: CGPoint(x: 0, y: 50), fim: CGPoint(x: 100, y: 50)),
                estilo: Estilo(cor: Self.vermelhoPuro, largura: 4, tracejado: true)
            )
        ])
        let coloridos = (0..<100).filter { !proximos(pixel(saida, x: $0, y: 50), 255, 255, 255) }
        #expect(!coloridos.isEmpty && coloridos.count < 100)
    }

    @Test func setaTemCorpoECabeca() throws {
        let saida = try renderizar([
            Anotacao(
                geometria: .seta(inicio: CGPoint(x: 10, y: 50), fim: CGPoint(x: 90, y: 50)),
                estilo: Estilo(cor: Self.vermelhoPuro, largura: 4)
            )
        ])
        #expect(proximos(pixel(saida, x: 40, y: 50), 255, 0, 0))
        // Logo atrás da ponta, fora do eixo: só a cabeça cobre.
        #expect(proximos(pixel(saida, x: 78, y: 54), 255, 0, 0))
        #expect(proximos(pixel(saida, x: 40, y: 80), 255, 255, 255))
    }

    @Test func setaComprimentoZeroNaoQuebra() throws {
        let saida = try renderizar([
            Anotacao(
                geometria: .seta(inicio: CGPoint(x: 50, y: 50), fim: CGPoint(x: 50, y: 50)),
                estilo: Estilo(cor: Self.vermelhoPuro, largura: 4)
            )
        ])
        #expect(saida.width == 100)
        #expect(proximos(pixel(saida, x: 5, y: 5), 255, 255, 255))
    }

    @Test func geometriasDegeneradasNaoQuebram() throws {
        let estilo = Estilo(cor: Self.vermelhoPuro, largura: 2, preenchimento: Self.vermelhoPuro)
        let saida = try renderizar([
            Anotacao(
                geometria: .forma(.retangulo, CGRect(x: 10, y: 10, width: 0, height: 0)),
                estilo: estilo
            ),
            Anotacao(
                geometria: .forma(.elipse, CGRect(x: 10, y: 10, width: -20, height: -20)),
                estilo: estilo
            ),
            Anotacao(
                geometria: .etapa(
                    centro: CGPoint(x: 50, y: 50),
                    diametro: 0,
                    reiniciaSequencia: false
                ),
                estilo: estilo
            ),
            Anotacao(
                geometria: .etapa(
                    centro: CGPoint(x: 50, y: 50),
                    diametro: -5,
                    reiniciaSequencia: false
                ),
                estilo: estilo
            ),
            Anotacao(geometria: .realce(CGRect(x: 10, y: 10, width: 0, height: 5)), estilo: estilo),
        ])
        #expect(saida.width == 100)
        #expect(proximos(pixel(saida, x: 80, y: 80), 255, 255, 255))
    }

    @Test func retanguloComTamanhoNegativoEPadronizado() throws {
        let saida = try renderizar([
            retangulo(CGRect(x: 50, y: 50, width: -40, height: -40), Self.vermelhoPuro)
        ])
        #expect(proximos(pixel(saida, x: 30, y: 30), 255, 0, 0))
    }

    @Test func etapaDesenhaCirculoENumero() throws {
        let verde = Self.verdePuro
        func etapa(_ reinicia: Bool = false) -> Anotacao {
            Anotacao(
                geometria: .etapa(
                    centro: CGPoint(x: 50, y: 50),
                    diametro: 40,
                    reiniciaSequencia: reinicia
                ),
                estilo: Estilo(cor: verde, largura: 0, preenchimento: verde)
            )
        }
        let primeira = etapa()
        let segunda = etapa()
        let isolada = try renderizar([segunda])  // numerada como 1
        let emOrdem2 = try renderizar([primeira, segunda])
        var verdes = 0
        var brancos = 0
        for y in 30...70 {
            for x in 30...70 {
                let p = pixel(emOrdem2, x: x, y: y)
                if proximos(p, 0, 255, 0) { verdes += 1 }
                if proximos(p, 255, 255, 255) && hypot(Double(x) - 50, Double(y) - 50) < 15 {
                    brancos += 1
                }
            }
        }
        #expect(verdes > 100)
        #expect(brancos > 0)
        #expect(proximos(pixel(emOrdem2, x: 5, y: 5), 255, 255, 255))
        #expect(todosOsPixels(emOrdem2) != todosOsPixels(isolada))
    }

    @Test func retanguloArredondadoTemCantosVaziosECentroPreenchido() throws {
        let saida = try renderizar([
            Anotacao(
                geometria: .forma(
                    .retanguloArredondado,
                    CGRect(x: 10, y: 10, width: 80, height: 80)
                ),
                estilo: Estilo(cor: Self.vermelhoPuro, largura: 0, preenchimento: Self.vermelhoPuro)
            )
        ])
        #expect(proximos(pixel(saida, x: 10, y: 10), 255, 255, 255))
        #expect(proximos(pixel(saida, x: 89, y: 89), 255, 255, 255))
        #expect(proximos(pixel(saida, x: 50, y: 50), 255, 0, 0))
        #expect(proximos(pixel(saida, x: 50, y: 11), 255, 0, 0))
        #expect(proximos(pixel(saida, x: 11, y: 50), 255, 0, 0))
    }

    @Test func etapaComTracoDesenhaBordaDeCorDiferenteDoFundo() throws {
        let saida = try renderizar([
            Anotacao(
                geometria: .etapa(
                    centro: CGPoint(x: 50, y: 50),
                    diametro: 40,
                    reiniciaSequencia: false
                ),
                estilo: Estilo(cor: Self.azulPuro, largura: 4, preenchimento: Self.verdePuro)
            )
        ])
        // A borda de 4 px centrada no raio 20 cobre os raios de 18 a 22.
        #expect(proximos(pixel(saida, x: 70, y: 50), 0, 0, 255))
        #expect(proximos(pixel(saida, x: 50, y: 30), 0, 0, 255))
        #expect(proximos(pixel(saida, x: 61, y: 61), 0, 255, 0))
        #expect(proximos(pixel(saida, x: 75, y: 50), 255, 255, 255))
    }

    @Test func baseComTamanhoDivergenteLancaErro() {
        let doc = documento([])
        let outra = imagemSolida(CGSize(width: 50, height: 50), cor: .branco)
        #expect(throws: ErroDocumento.tamanhoInvalido) {
            try Renderizador().renderizar(doc, base: outra)
        }
    }
}
