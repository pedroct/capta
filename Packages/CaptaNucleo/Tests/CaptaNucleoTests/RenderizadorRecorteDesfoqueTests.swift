import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

/// Provedor falso: devolve sempre a mesma imagem (ou nada).
private struct ProvedorFalso: ProvedorDeSimbolos {
    let resposta: CGImage?
    func imagem(simbolo: String, lado: Double, cor: CorRGBA) -> CGImage? { resposta }
}

private func imagemDeDuasMetades() -> CGImage {
    // Metade de cima (na imagem) vermelha, metade de baixo azul.
    guard let espaco = CGColorSpace(name: CGColorSpace.sRGB),
        let c = CGContext(
            data: nil,
            width: 10,
            height: 10,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: espaco,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else { preconditionFailure("contexto") }
    c.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
    c.fill(CGRect(x: 0, y: 0, width: 10, height: 5))
    c.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    c.fill(CGRect(x: 0, y: 5, width: 10, height: 5))
    guard let imagem = c.makeImage() else { preconditionFailure("makeImage") }
    return imagem
}

@Suite("Renderizador: recorte, desfoque e carimbo")
struct RenderizadorRecorteDesfoqueTests {
    let lado = CGSize(width: 100, height: 100)
    var xadrez: CGImage { imagemXadrez(lado) }

    func documento(_ objetos: [Anotacao], recorte: CGRect? = nil) -> Documento {
        Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: lado,
            escala: 1,
            recorte: recorte,
            objetos: objetos
        )
    }

    func desfoque(
        _ regiao: CGRect,
        _ tipo: TipoDesfoque,
        intensidade: Double = 4
    ) -> Anotacao {
        Anotacao(geometria: .desfoque(regiao, tipo, intensidade: intensidade))
    }

    func retangulo(_ r: CGRect, _ cor: CorRGBA) -> Anotacao {
        Anotacao(
            geometria: .forma(.retangulo, r),
            estilo: Estilo(cor: cor, largura: 0, preenchimento: cor)
        )
    }

    func renderizar(
        _ objetos: [Anotacao],
        base: CGImage? = nil,
        recorte: CGRect? = nil,
        provedor: (any ProvedorDeSimbolos)? = nil
    ) throws -> CGImage {
        try Renderizador(provedorDeSimbolos: provedor)
            .renderizar(documento(objetos, recorte: recorte), base: base ?? xadrez)
    }

    // MARK: Recorte

    @Test func recorteDefineOTamanhoDaSaida() throws {
        let saida = try renderizar([], recorte: CGRect(x: 12, y: 10, width: 30, height: 20))
        #expect(saida.width == 30 && saida.height == 20)
        let original = try renderizar([])
        let a = pixel(saida, x: 0, y: 0)
        let b = pixel(original, x: 12, y: 10)
        #expect(a.r == b.r && a.g == b.g && a.b == b.b)
        // O quadrado (12, 10) cai no padrão oposto ao (0, 0): garante que não é o pixel errado.
        let c = pixel(original, x: 0, y: 0)
        #expect(a.r != c.r)
    }

    @Test func anotacaoForaDoRecorteNaoApareceNaSaida() throws {
        let vermelho = CorRGBA(r: 1, g: 0, b: 0)
        let saida = try renderizar(
            [retangulo(CGRect(x: 60, y: 60, width: 30, height: 30), vermelho)],
            recorte: CGRect(x: 0, y: 0, width: 40, height: 40)
        )
        let pixels = todosOsPixels(saida)
        var achouVermelho = false
        for i in stride(from: 0, to: pixels.count, by: 4)
        where pixels[i] > 200 && pixels[i + 1] < 50 && pixels[i + 2] < 50 {
            achouVermelho = true
        }
        #expect(!achouVermelho)
    }

    // MARK: Desfoque

    @Test func borrarReduzALocalmenteAVariacao() throws {
        let regiao = CGRect(x: 20, y: 20, width: 40, height: 40)
        let saida = try renderizar([desfoque(regiao, .borrar)])
        let antes = desvioPadraoDaLuminancia(xadrez, regiao: regiao)
        let depois = desvioPadraoDaLuminancia(saida, regiao: regiao)
        #expect(depois < antes * 0.5)
        #expect(pixel(saida, x: 5, y: 5) == pixel(xadrez, x: 5, y: 5))
        #expect(pixel(saida, x: 80, y: 80) == pixel(xadrez, x: 80, y: 80))
    }

    @Test func pixelizarCriaBlocosUniformes() throws {
        let regiao = CGRect(x: 20, y: 20, width: 40, height: 40)
        let saida = try renderizar([desfoque(regiao, .pixelizar, intensidade: 10)])
        var iguais = 0
        var total = 0
        for y in 22..<58 {
            for x in 22..<57 {
                let a = pixel(saida, x: x, y: y)
                let b = pixel(saida, x: x + 1, y: y)
                total += 1
                if a.r == b.r && a.g == b.g && a.b == b.b { iguais += 1 }
            }
        }
        // Em blocos de 10 px, só ~1 em cada 10 pares vizinhos cruza a divisa de um bloco.
        #expect(Double(iguais) / Double(total) > 0.8)
        #expect(pixel(saida, x: 5, y: 5) == pixel(xadrez, x: 5, y: 5))
    }

    @Test func desfoqueSoAfetaCamadasAbaixo() throws {
        let branca = imagemSolida(lado, cor: .branco)
        let vermelho = CorRGBA(r: 1, g: 0, b: 0)
        let azul = CorRGBA(r: 0, g: 0, b: 1)
        let saida = try renderizar(
            [
                retangulo(CGRect(x: 20, y: 20, width: 40, height: 40), vermelho),
                desfoque(CGRect(x: 0, y: 0, width: 100, height: 100), .borrar, intensidade: 3),
                retangulo(CGRect(x: 70, y: 70, width: 25, height: 25), azul),
            ],
            base: branca
        )
        // Borda do vermelho (x = 60, y = 40) suavizada: valores intermediários dos dois lados.
        let dentro = pixel(saida, x: 59, y: 40)
        let fora = pixel(saida, x: 60, y: 40)
        #expect(dentro.g > 20 && dentro.g < 235)
        #expect(fora.g > 20 && fora.g < 235)
        // Azul desenhado depois do desfoque: borda nítida.
        #expect(proximos(pixel(saida, x: 70, y: 80), 0, 0, 255))
        #expect(proximos(pixel(saida, x: 69, y: 80), 255, 255, 255))
        #expect(proximos(pixel(saida, x: 94, y: 80), 0, 0, 255))
        #expect(proximos(pixel(saida, x: 95, y: 80), 255, 255, 255))
    }

    @Test func desfoqueParcialmenteForaDaImagemBorraSoOTrechoInterno() throws {
        let regiao = CGRect(x: -20, y: -20, width: 60, height: 60)
        let saida = try renderizar([desfoque(regiao, .borrar)])
        let interno = CGRect(x: 4, y: 4, width: 30, height: 30)
        #expect(
            desvioPadraoDaLuminancia(saida, regiao: interno)
                < desvioPadraoDaLuminancia(xadrez, regiao: interno) * 0.5
        )
        // Borda da imagem: sem transparência nem escurecimento por bordas vazias.
        let canto = pixel(saida, x: 0, y: 0)
        #expect(canto.a == 255)
        let miolo = desvioPadraoDaLuminancia(saida, regiao: CGRect(x: 0, y: 0, width: 4, height: 4))
        #expect(miolo < 100)
        // Fora da região: idêntico.
        #expect(pixel(saida, x: 60, y: 60) == pixel(xadrez, x: 60, y: 60))
        #expect(pixel(saida, x: 41, y: 10) == pixel(xadrez, x: 41, y: 10))
        #expect(pixel(saida, x: 10, y: 41) == pixel(xadrez, x: 10, y: 41))
    }

    @Test func desfoqueTotalmenteForaOuComTamanhoZeroNaoMudaNada() throws {
        let esperado = todosOsPixels(try renderizar([]))
        let regioes = [
            CGRect(x: 200, y: 200, width: 50, height: 50),
            CGRect(x: -80, y: -80, width: 50, height: 50),
            CGRect(x: 30, y: 30, width: 0, height: 20),
            CGRect(x: 30, y: 30, width: 20, height: 0),
            CGRect(x: 30, y: 30, width: 0, height: 0),
        ]
        for tipo in [TipoDesfoque.borrar, .pixelizar] {
            for regiao in regioes {
                let saida = try renderizar([desfoque(regiao, tipo)])
                #expect(todosOsPixels(saida) == esperado)
            }
        }
    }

    @Test func desfoqueComIntensidadeZeroNaoMudaNada() throws {
        let esperado = todosOsPixels(try renderizar([]))
        let regiao = CGRect(x: 20, y: 20, width: 40, height: 40)
        for tipo in [TipoDesfoque.borrar, .pixelizar] {
            for intensidade in [0, -3] as [Double] {
                let saida = try renderizar([desfoque(regiao, tipo, intensidade: intensidade)])
                #expect(todosOsPixels(saida) == esperado)
            }
            // Não finita é documento inválido: o renderizador valida e lança.
            for intensidade in [Double.nan, Double.infinity] {
                #expect(throws: ErroDocumento.valorNaoFinito) {
                    try renderizar([desfoque(regiao, tipo, intensidade: intensidade)])
                }
            }
        }
    }

    @Test func desfoqueComRetanguloInvertidoEquivaleAoNormal() throws {
        let normal = try renderizar([desfoque(CGRect(x: 20, y: 20, width: 40, height: 40), .borrar)]
        )
        let invertido = try renderizar([
            desfoque(CGRect(x: 60, y: 60, width: -40, height: -40), .borrar)
        ])
        #expect(todosOsPixels(normal) == todosOsPixels(invertido))
    }

    // MARK: Carimbo

    @Test func carimboUsaOProvedor() throws {
        let branca = imagemSolida(lado, cor: .branco)
        let verde = imagemSolida(CGSize(width: 10, height: 10), cor: CorRGBA(r: 0, g: 1, b: 0))
        let carimbo = Anotacao(
            geometria: .carimbo(CGRect(x: 20, y: 20, width: 30, height: 30), simbolo: "star")
        )
        let saida = try renderizar(
            [carimbo],
            base: branca,
            provedor: ProvedorFalso(resposta: verde)
        )
        #expect(proximos(pixel(saida, x: 35, y: 35), 0, 255, 0))
        #expect(proximos(pixel(saida, x: 21, y: 21), 0, 255, 0))
        #expect(proximos(pixel(saida, x: 60, y: 60), 255, 255, 255))
        #expect(proximos(pixel(saida, x: 19, y: 35), 255, 255, 255))
    }

    @Test func carimboRespeitaAOrientacaoDaImagem() throws {
        let branca = imagemSolida(lado, cor: .branco)
        let carimbo = Anotacao(
            geometria: .carimbo(CGRect(x: 20, y: 20, width: 30, height: 30), simbolo: "x")
        )
        let saida = try renderizar(
            [carimbo],
            base: branca,
            provedor: ProvedorFalso(resposta: imagemDeDuasMetades())
        )
        #expect(proximos(pixel(saida, x: 35, y: 25), 255, 0, 0))
        #expect(proximos(pixel(saida, x: 35, y: 45), 0, 0, 255))
    }

    @Test func carimboCentralizaMantendoAProporcao() throws {
        let branca = imagemSolida(lado, cor: .branco)
        let verde = imagemSolida(CGSize(width: 10, height: 10), cor: CorRGBA(r: 0, g: 1, b: 0))
        let carimbo = Anotacao(
            geometria: .carimbo(CGRect(x: 10, y: 10, width: 60, height: 20), simbolo: "star")
        )
        let saida = try renderizar(
            [carimbo],
            base: branca,
            provedor: ProvedorFalso(resposta: verde)
        )
        // Quadrado de 20 px centralizado: x de 30 a 50.
        #expect(proximos(pixel(saida, x: 40, y: 20), 0, 255, 0))
        #expect(proximos(pixel(saida, x: 15, y: 20), 255, 255, 255))
        #expect(proximos(pixel(saida, x: 65, y: 20), 255, 255, 255))
    }

    @Test func carimboSemProvedorOuSemImagemNaoDesenhaNada() throws {
        let branca = imagemSolida(lado, cor: .branco)
        let carimbo = Anotacao(
            geometria: .carimbo(CGRect(x: 20, y: 20, width: 30, height: 30), simbolo: "star")
        )
        let esperado = todosOsPixels(branca)
        let semProvedor = try renderizar([carimbo], base: branca, provedor: nil)
        #expect(todosOsPixels(semProvedor) == esperado)
        let semImagem = try renderizar(
            [carimbo],
            base: branca,
            provedor: ProvedorFalso(resposta: nil)
        )
        #expect(todosOsPixels(semImagem) == esperado)
    }

    // MARK: Robustez

    @Test func tamanhoBaseNaoFinitoLancaEmVezDeTravar() {
        let base = imagemSolida(lado, cor: .branco)
        let tamanhos = [
            CGSize(width: Double.nan, height: Double.nan),
            CGSize(width: Double.infinity, height: 100),
            CGSize(width: 1e30, height: 1e30),
        ]
        for tamanho in tamanhos {
            let doc = Documento(
                versaoEsquema: Esquema.versaoAtual,
                tamanhoBase: tamanho,
                escala: 1,
                recorte: nil,
                objetos: []
            )
            #expect(throws: ErroDocumento.tamanhoInvalido) {
                try Renderizador().renderizar(doc, base: base)
            }
        }
    }
}
