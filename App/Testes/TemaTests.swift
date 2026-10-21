import AppKit
import SwiftUI
import Testing

@testable import Capta

@Suite("Tokens do tema")
@MainActor
struct TemaTests {
    /// Cores do catálogo e o token de `Tema` que as usa.
    nonisolated static let coresDoCatalogo: [(nome: String, token: Color)] = [
        ("SuperficieCanvas", Tema.superficieCanvas),
        ("BordaControle", Tema.bordaControle),
        ("AnotacaoVermelho", Tema.Anotacao.vermelho),
        ("AnotacaoLaranja", Tema.Anotacao.laranja),
        ("AnotacaoAmarelo", Tema.Anotacao.amarelo),
        ("AnotacaoVerde", Tema.Anotacao.verde),
        ("AnotacaoAzul", Tema.Anotacao.azul),
        ("AnotacaoRoxo", Tema.Anotacao.roxo),
        ("AnotacaoPreto", Tema.Anotacao.preto),
        ("AnotacaoBranco", Tema.Anotacao.branco),
        ("AnotacaoRealce", Tema.Anotacao.realce),
    ]

    @Test func fundoDoPainelUsaSuperficieOpacaComReduzirTransparencia() throws {
        let fundo = try #require(pixel(de: Tema.fundoDoPainel(reduzirTransparencia: true)))
        let janela = try #require(pixel(de: AnyShapeStyle(Tema.superficieJanela)))
        #expect(fundo == janela)
        #expect(fundo[3] == 255)
    }

    @Test func fundoDoPainelUsaMaterialPorPadrao() throws {
        let fundo = try #require(pixel(de: Tema.fundoDoPainel(reduzirTransparencia: false)))
        let material = try #require(pixel(de: AnyShapeStyle(Tema.superficiePainel)))
        let janela = try #require(pixel(de: AnyShapeStyle(Tema.superficieJanela)))
        #expect(fundo == material)
        #expect(fundo != janela)
    }

    @Test(arguments: coresDoCatalogo)
    func corDoTemaVemDoCatalogo(nome: String, token: Color) throws {
        let catalogo = try #require(NSColor(named: nome), "cor \(nome) ausente do catálogo")
        for esquema in [ColorScheme.light, .dark] {
            let resolvido = token.resolve(in: ambiente(esquema))
            let esperado = Color(nsColor: catalogo).resolve(in: ambiente(esquema))
            #expect(quaseIgual(resolvido.red, esperado.red))
            #expect(quaseIgual(resolvido.green, esperado.green))
            #expect(quaseIgual(resolvido.blue, esperado.blue))
            #expect(quaseIgual(resolvido.opacity, esperado.opacity))
        }
    }

    @Test(arguments: [(ColorScheme.light, Float(0.16)), (.dark, 0.24)])
    func destaqueFundoEODestaqueDoSistemaComOpacidadeDoTema(
        esquema: ColorScheme,
        opacidade: Float
    ) {
        let ambiente = ambiente(esquema)
        let fundo = Tema.destaqueFundo.resolve(in: ambiente)
        let destaque = Color(nsColor: .controlAccentColor).resolve(in: ambiente)
        #expect(quaseIgual(fundo.red, destaque.red))
        #expect(quaseIgual(fundo.green, destaque.green))
        #expect(quaseIgual(fundo.blue, destaque.blue))
        #expect(quaseIgual(fundo.opacity, opacidade))
    }

    @Test(arguments: [(ColorScheme.light, Float(1)), (.dark, 0.039)])
    func sobreDestaqueEBrancoNoClaroEQuasePretoNoEscuro(esquema: ColorScheme, canal: Float) {
        let cor = Tema.sobreDestaque.resolve(in: ambiente(esquema))
        #expect(quaseIgual(cor.red, canal))
        #expect(quaseIgual(cor.green, canal))
        #expect(quaseIgual(cor.blue, canal))
        #expect(cor.opacity == 1)
    }

    @Test func mascaraDoOverlayUsaAsOpacidadesDosTokens() {
        #expect(Tema.Overlay.mascara(reduzirTransparencia: false).alphaComponent == 0.45)
        #expect(Tema.Overlay.mascara(reduzirTransparencia: true).alphaComponent == 0.75)
        #expect(Tema.Overlay.mira.alphaComponent == 0.7)
    }

    @Test(arguments: [
        (NSAppearance.Name.aqua, CGFloat(0x1a) / 255), (.darkAqua, CGFloat(0x1f) / 255),
    ])
    func bordaDoOverlaySegueOToken(nome: NSAppearance.Name, alfa: CGFloat) throws {
        let aparencia = try #require(NSAppearance(named: nome))
        var resolvida: NSColor?
        aparencia.performAsCurrentDrawingAppearance {
            resolvida = Tema.Overlay.borda.usingColorSpace(.sRGB)
        }
        let cor = try #require(resolvida)
        #expect(abs(cor.alphaComponent - alfa) < 0.5 / 255)
    }

    private func ambiente(_ esquema: ColorScheme) -> EnvironmentValues {
        var ambiente = EnvironmentValues()
        ambiente.colorScheme = esquema
        return ambiente
    }

    /// Meio passo de 8 bits: absorve a diferença entre caminhos de conversão de cor.
    private func quaseIgual(_ a: Float, _ b: Float) -> Bool {
        abs(a - b) < 0.5 / 255
    }

    /// Pixel RGBA do centro de um retângulo preenchido com o estilo, renderizado fora da tela.
    private func pixel(de estilo: AnyShapeStyle) -> [UInt8]? {
        let lado = 8
        let renderizador = ImageRenderer(
            content: Rectangle().fill(estilo).frame(width: CGFloat(lado), height: CGFloat(lado))
        )
        renderizador.scale = 1
        guard let imagem = renderizador.cgImage,
            let espaco = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        var buffer = [UInt8](repeating: 0, count: lado * lado * 4)
        let desenhou: Bool = buffer.withUnsafeMutableBytes { bytes in
            guard
                let contexto = CGContext(
                    data: bytes.baseAddress,
                    width: lado,
                    height: lado,
                    bitsPerComponent: 8,
                    bytesPerRow: lado * 4,
                    space: espaco,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }
            contexto.draw(imagem, in: CGRect(x: 0, y: 0, width: lado, height: lado))
            return true
        }
        guard desenhou else { return nil }
        let inicio = (lado / 2 * lado + lado / 2) * 4
        return Array(buffer[inicio..<inicio + 4])
    }
}
