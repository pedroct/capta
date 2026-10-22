import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

/// Provedor falso: devolve sempre a mesma imagem.
private struct ProvedorFixo: ProvedorDeSimbolos {
    let resposta: CGImage
    func imagem(simbolo: String, lado: Double, cor: CorRGBA) -> CGImage? { resposta }
}

/// Imagem 10×10 com a metade de cima vermelha e a de baixo azul (origem no topo).
private func imagemDeDuasMetades() -> CGImage {
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

@Suite("Renderizador: rotação das anotações")
struct RenderizadorRotacaoTests {
    let tamanho = CGSize(width: 200, height: 120)
    var branca: CGImage { imagemSolida(tamanho, cor: .branco) }
    static let vermelho = CorRGBA(r: 1, g: 0, b: 0)

    func documento(_ objetos: [Anotacao]) -> Documento {
        Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: tamanho,
            escala: 1,
            recorte: nil,
            objetos: objetos
        )
    }

    func renderizar(
        _ objetos: [Anotacao],
        provedor: (any ProvedorDeSimbolos)? = nil
    ) throws -> CGImage {
        try Renderizador(provedorDeSimbolos: provedor).renderizar(documento(objetos), base: branca)
    }

    /// `true` se algum pixel do retângulo (origem no topo) não é branco.
    func temTinta(_ imagem: CGImage, em regiao: CGRect) -> Bool {
        for y in Int(regiao.minY)..<Int(regiao.maxY) {
            for x in Int(regiao.minX)..<Int(regiao.maxX)
            where !proximos(pixel(imagem, x: x, y: y), 255, 255, 255, tolerancia: 8) {
                return true
            }
        }
        return false
    }

    @Test func formaGirada90GrausPintaOndeOsLimitesDizem() throws {
        let forma = Anotacao(
            geometria: .forma(.retangulo, CGRect(x: 50, y: 50, width: 100, height: 20)),
            estilo: Estilo(cor: Self.vermelho, largura: 0, preenchimento: Self.vermelho),
            rotacao: .pi / 2
        )
        let saida = try renderizar([forma])
        #expect(proximos(pixel(saida, x: 100, y: 20), 255, 0, 0))
        #expect(proximos(pixel(saida, x: 60, y: 60), 255, 255, 255))

        // Todo pixel pintado encosta nos limites do objeto.
        let limites = forma.limites
        let pixels = todosOsPixels(saida)
        let porLinha = pixels.count / saida.height
        var pintados = 0
        var foraDosLimites = 0
        for y in 0..<saida.height {
            for x in 0..<saida.width {
                let i = y * porLinha + x * 4
                guard pixels[i] != 255 || pixels[i + 1] != 255 || pixels[i + 2] != 255 else {
                    continue
                }
                pintados += 1
                if !CGRect(x: x, y: y, width: 1, height: 1).intersects(limites) {
                    foraDosLimites += 1
                }
            }
        }
        #expect(pintados > 1000)
        #expect(foraDosLimites == 0)
    }

    @Test func formaGiradaEmSentidoHorarioNaTela() throws {
        // Retângulo fino na horizontal, girado 45°: o lado direito desce (Y para baixo).
        let forma = Anotacao(
            geometria: .forma(.retangulo, CGRect(x: 60, y: 56, width: 80, height: 8)),
            estilo: Estilo(cor: Self.vermelho, largura: 0, preenchimento: Self.vermelho),
            rotacao: .pi / 4
        )
        let saida = try renderizar([forma])
        #expect(proximos(pixel(saida, x: 120, y: 80), 255, 0, 0))
        #expect(proximos(pixel(saida, x: 80, y: 40), 255, 0, 0))
        #expect(proximos(pixel(saida, x: 120, y: 40), 255, 255, 255))
        #expect(proximos(pixel(saida, x: 80, y: 80), 255, 255, 255))
    }

    @Test func realceGiradoETextoGiradoTambemGiram() throws {
        let realce = Anotacao(
            geometria: .realce(CGRect(x: 50, y: 50, width: 100, height: 20)),
            estilo: Estilo(cor: Self.vermelho, largura: 0),
            rotacao: .pi / 2
        )
        let comRealce = try renderizar([realce])
        #expect(proximos(pixel(comRealce, x: 100, y: 20), 255, 0, 0))
        #expect(proximos(pixel(comRealce, x: 60, y: 60), 255, 255, 255))

        // Texto em faixa horizontal (x 40…160, y 50…70) girado 90° em torno de (100, 60):
        // a faixa vira vertical (x 90…110, y 0…120).
        let texto = Anotacao(
            geometria: .texto(
                CGRect(x: 40, y: 50, width: 120, height: 20),
                conteudo: "MMMMMMMMMMMM",
                tamanhoFonte: 16,
                negrito: true,
                italico: false
            ),
            estilo: Estilo(cor: .preto),
            rotacao: .pi / 2
        )
        let comTexto = try renderizar([texto])
        #expect(temTinta(comTexto, em: CGRect(x: 90, y: 0, width: 20, height: 120)))
        #expect(!temTinta(comTexto, em: CGRect(x: 0, y: 0, width: 88, height: 120)))
        #expect(!temTinta(comTexto, em: CGRect(x: 112, y: 0, width: 88, height: 120)))
    }

    @Test func carimboGiradoMeiaVoltaFicaDeCabecaParaBaixo() throws {
        let carimbo = Anotacao(
            geometria: .carimbo(CGRect(x: 80, y: 40, width: 40, height: 40), simbolo: "x"),
            rotacao: .pi
        )
        let saida = try renderizar(
            [carimbo],
            provedor: ProvedorFixo(resposta: imagemDeDuasMetades())
        )
        // Sem rotação o vermelho fica em cima; meia volta o leva para baixo.
        #expect(proximos(pixel(saida, x: 100, y: 45), 0, 0, 255))
        #expect(proximos(pixel(saida, x: 100, y: 75), 255, 0, 0))
    }

    @Test func transformacaoGiraEmTornoDoCentroESeIgnoraEmSetaELinha() {
        let forma = Anotacao(
            geometria: .forma(.retangulo, CGRect(x: 150, y: 70, width: -100, height: -20)),
            rotacao: .pi / 2
        )
        // Centro (100, 60); o canto (50, 50) vai para (110, 10).
        let canto = CGPoint(x: 50, y: 50).applying(forma.transformacaoDeRotacao)
        #expect(abs(canto.x - 110) < 1e-9 && abs(canto.y - 10) < 1e-9)
        let centro = CGPoint(x: 100, y: 60).applying(forma.transformacaoDeRotacao)
        #expect(abs(centro.x - 100) < 1e-9 && abs(centro.y - 60) < 1e-9)
        // Montadas à mão (o documento recusaria): seta e linha não giram.
        let p = CGPoint(x: 1, y: 2)
        for geometria in [
            Geometria.seta(inicio: .zero, fim: p), .linha(inicio: .zero, fim: p),
        ] {
            #expect(Anotacao(geometria: geometria, rotacao: 1).transformacaoDeRotacao == .identity)
        }
        #expect(Anotacao(geometria: .realce(.zero)).transformacaoDeRotacao == .identity)
    }

    @Test func etapaGiradaGiraONumeroEmTornoDoCentro() throws {
        func etapa(_ rotacao: Double) -> Anotacao {
            Anotacao(
                geometria: .etapa(
                    centro: CGPoint(x: 100, y: 60),
                    diametro: 60,
                    reiniciaSequencia: false
                ),
                estilo: Estilo(cor: Self.vermelho, largura: 0),
                rotacao: rotacao
            )
        }
        let reta = try renderizar([etapa(0)])
        let girada = try renderizar([etapa(.pi)])
        #expect(todosOsPixels(reta) != todosOsPixels(girada))
        // Meia volta em torno de (100, 60): o pixel (x, y) vai para (199 - x, 119 - y). A
        // girada espelhada bate com a reta (salvo a borda antisserrilhada dos glifos), e a reta
        // espelhada não bate consigo mesma (o "1" não é simétrico).
        func diferencas(_ a: CGImage, _ b: CGImage) -> Int {
            var total = 0
            for y in 30..<90 {
                for x in 70..<130 {
                    let p = pixel(a, x: x, y: y)
                    let q = pixel(b, x: 199 - x, y: 119 - y)
                    if !proximos(p, Int(q.r), Int(q.g), Int(q.b), tolerancia: 40) { total += 1 }
                }
            }
            return total
        }
        let assimetria = diferencas(reta, reta)
        #expect(assimetria > 100)
        #expect(diferencas(reta, girada) * 3 < assimetria)
    }
}
