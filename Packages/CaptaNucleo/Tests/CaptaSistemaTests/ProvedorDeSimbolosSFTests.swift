import CaptaNucleo
import CoreGraphics
import Testing

@testable import CaptaSistema

@Suite("Provedor de símbolos do sistema")
struct ProvedorDeSimbolosSFTests {
    @Test func provedorDoSistemaDevolveImagemParaSimboloConhecido() {
        let provedor = ProvedorDeSimbolosSF()
        let imagem = provedor.imagem(simbolo: "star.fill", lado: 24, cor: .preto)
        #expect(imagem != nil)
        #expect(imagem?.width == 24 && imagem?.height == 24)
        #expect(provedor.imagem(simbolo: "nao.existe.xyz", lado: 24, cor: .preto) == nil)
    }

    @Test(arguments: [Double.nan, .infinity, 0, 0.5, 5000])
    func ladoNaoFinitoOuForaDaFaixaDevolveNil(lado: Double) {
        #expect(ProvedorDeSimbolosSF().imagem(simbolo: "star.fill", lado: lado, cor: .preto) == nil)
    }

    @Test func corTingeOSimboloComOAlfaPreservado() throws {
        let cor = CorRGBA(r: 1, g: 0, b: 0, a: 1)
        let imagem = try #require(
            ProvedorDeSimbolosSF().imagem(simbolo: "circle.fill", lado: 64, cor: cor)
        )
        let centro = try #require(pixel(imagem, x: 32, y: 32))
        #expect(centro == [255, 0, 0, 255])
        let canto = try #require(pixel(imagem, x: 0, y: 0))
        #expect(canto[3] == 0)
    }

    /// Lê um pixel RGBA (não premultiplicado em cor opaca) redesenhando a imagem num buffer conhecido.
    private func pixel(_ imagem: CGImage, x: Int, y: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: imagem.width * imagem.height * 4)
        let largura = imagem.width
        let altura = imagem.height
        let desenhou: Bool = buffer.withUnsafeMutableBytes { bytes in
            guard
                let espaco = CGColorSpace(name: CGColorSpace.sRGB),
                let contexto = CGContext(
                    data: bytes.baseAddress,
                    width: largura,
                    height: altura,
                    bitsPerComponent: 8,
                    bytesPerRow: largura * 4,
                    space: espaco,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }
            contexto.draw(imagem, in: CGRect(x: 0, y: 0, width: largura, height: altura))
            return true
        }
        guard desenhou else { return nil }
        let i = (y * largura + x) * 4
        return Array(buffer[i..<i + 4])
    }
}
