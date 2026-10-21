import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

@Suite("Renderizador: estilos sem traço ou sem preenchimento")
struct RenderizadorEstiloSemTracoTests {
    let lado = CGSize(width: 100, height: 100)
    var base: CGImage { imagemSolida(lado, cor: .branco) }

    func renderizar(_ objetos: [Anotacao]) throws -> CGImage {
        let doc = Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: lado,
            escala: 1,
            recorte: nil,
            objetos: objetos
        )
        return try Renderizador().renderizar(doc, base: base)
    }

    static let vermelhoPuro = CorRGBA(r: 1, g: 0, b: 0)
    static let azulPuro = CorRGBA(r: 0, g: 0, b: 1)

    @Test func linhaESetaSemLarguraNaoDesenham() throws {
        let estilo = Estilo(cor: Self.vermelhoPuro, largura: 0)
        let saida = try renderizar([
            Anotacao(
                geometria: .linha(inicio: CGPoint(x: 10, y: 50), fim: CGPoint(x: 90, y: 50)),
                estilo: estilo
            )
        ])
        #expect(todosOsPixels(saida) == todosOsPixels(base))
    }

    @Test func realceESemPreenchimentoUsaACorDoEstilo() throws {
        let saida = try renderizar([
            Anotacao(
                geometria: .realce(CGRect(x: 20, y: 20, width: 40, height: 40)),
                estilo: Estilo(cor: Self.azulPuro, largura: 0)
            )
        ])
        #expect(proximos(pixel(saida, x: 40, y: 40), 0, 0, 255))
        #expect(proximos(pixel(saida, x: 70, y: 70), 255, 255, 255))
    }

    @Test func etapaSemPreenchimentoUsaACorDoEstiloComoFundo() throws {
        let saida = try renderizar([
            Anotacao(
                geometria: .etapa(
                    centro: CGPoint(x: 50, y: 50),
                    diametro: 40,
                    reiniciaSequencia: false
                ),
                estilo: Estilo(cor: Self.azulPuro, largura: 0)
            )
        ])
        #expect(proximos(pixel(saida, x: 65, y: 50), 0, 0, 255))
        #expect(proximos(pixel(saida, x: 80, y: 50), 255, 255, 255))
    }

    @Test func etapaDeFundoClaroTemNumeroPreto() throws {
        let saida = try renderizar([
            Anotacao(
                geometria: .etapa(
                    centro: CGPoint(x: 50, y: 50),
                    diametro: 40,
                    reiniciaSequencia: false
                ),
                estilo: Estilo(cor: .branco, largura: 0, preenchimento: .branco)
            )
        ])
        var escuros = 0
        for y in 35...65 {
            for x in 35...65 where pixel(saida, x: x, y: y).r < 100 { escuros += 1 }
        }
        #expect(escuros > 0)
    }
}
