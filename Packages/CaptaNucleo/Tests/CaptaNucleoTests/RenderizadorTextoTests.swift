import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

@Suite("Renderizador: texto")
struct RenderizadorTextoTests {
    let lado = CGSize(width: 200, height: 100)
    let caixa = CGRect(x: 20, y: 30, width: 80, height: 20)

    func renderizar(
        _ conteudo: String,
        caixa: CGRect? = nil,
        negrito: Bool = false,
        italico: Bool = false
    ) throws -> CGImage {
        let area = caixa ?? self.caixa
        let doc = Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: lado,
            escala: 1,
            recorte: nil,
            objetos: [
                Anotacao(
                    geometria: .texto(
                        area,
                        conteudo: conteudo,
                        tamanhoFonte: 14,
                        negrito: negrito,
                        italico: italico
                    ),
                    estilo: Estilo(cor: .preto)
                )
            ]
        )
        return try Renderizador().renderizar(doc, base: imagemSolida(lado, cor: .branco))
    }

    var branca: [UInt8] { todosOsPixels(imagemSolida(lado, cor: .branco)) }

    @Test func textoVazioNaoDesenhaNada() throws {
        #expect(todosOsPixels(try renderizar("")) == branca)
    }

    @Test func textoLongoFicaDentroDoRetangulo() throws {
        let saida = todosOsPixels(try renderizar(String(repeating: "W", count: 500)))
        let ref = branca
        let largura = Int(lado.width)
        var dentro = 0
        for y in 0..<Int(lado.height) {
            for x in 0..<largura {
                let i = (y * largura + x) * 4
                let mudou = saida[i..<i + 4] != ref[i..<i + 4]
                if caixa.contains(CGPoint(x: x, y: y)) {
                    if mudou { dentro += 1 }
                } else {
                    #expect(!mudou, "pixel alterado fora do retângulo em (\(x), \(y))")
                }
            }
        }
        #expect(dentro > 0)
    }

    @Test(arguments: ["😀", "مرحبا", "שלום"])
    func emojiRTLENaoQuebram(texto: String) throws {
        let area = CGRect(x: 20, y: 30, width: 120, height: 40)
        let saida = todosOsPixels(try renderizar(texto, caixa: area))
        let ref = branca
        let largura = Int(lado.width)
        var alterados = 0
        for y in Int(area.minY)..<Int(area.maxY) {
            for x in Int(area.minX)..<Int(area.maxX) {
                let i = (y * largura + x) * 4
                if saida[i..<i + 4] != ref[i..<i + 4] { alterados += 1 }
            }
        }
        #expect(alterados > 0)
    }

    @Test func negritoEItalicoMudamOResultado() throws {
        let area = CGRect(x: 10, y: 20, width: 180, height: 40)
        let normal = todosOsPixels(try renderizar("Capta", caixa: area))
        let negrito = todosOsPixels(try renderizar("Capta", caixa: area, negrito: true))
        let italico = todosOsPixels(try renderizar("Capta", caixa: area, italico: true))
        #expect(normal != negrito)
        #expect(normal != italico)
    }

    @Test func textoNaoSaiEspelhado() throws {
        // "T" tem a barra no topo: mais tinta nas linhas de cima que nas de baixo da caixa.
        let area = CGRect(x: 10, y: 10, width: 60, height: 60)
        let doc = Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: lado,
            escala: 1,
            recorte: nil,
            objetos: [
                Anotacao(
                    geometria: .texto(
                        area,
                        conteudo: "T",
                        tamanhoFonte: 40,
                        negrito: true,
                        italico: false
                    ),
                    estilo: Estilo(cor: .preto)
                )
            ]
        )
        let saida = try Renderizador().renderizar(doc, base: imagemSolida(lado, cor: .branco))
        func tinta(_ y: Range<Int>) -> Int {
            var n = 0
            for yy in y {
                for x in 10..<70 where pixel(saida, x: x, y: yy).r < 128 { n += 1 }
            }
            return n
        }
        #expect(tinta(10..<35) > tinta(35..<60))
    }
}
