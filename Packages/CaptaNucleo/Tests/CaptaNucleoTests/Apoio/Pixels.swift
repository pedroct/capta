import CoreGraphics
import Foundation

@testable import CaptaNucleo

// O contrato da tarefa fixa a tupla `(r, g, b, a)` como retorno de `pixel`.
// swiftlint:disable:next large_tuple
typealias PixelRGBA = (r: UInt8, g: UInt8, b: UInt8, a: UInt8)

/// Contexto RGBA 8 bits sRGB com layout conhecido, para criar e ler imagens nos testes.
private func contextoRGBA(largura: Int, altura: Int) -> CGContext {
    guard
        let espaco = CGColorSpace(name: CGColorSpace.sRGB),
        let contexto = CGContext(
            data: nil,
            width: largura,
            height: altura,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: espaco,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else { preconditionFailure("não foi possível criar o CGContext de teste") }
    return contexto
}

/// Imagem de uma cor só, no tamanho dado (em pixels).
func imagemSolida(_ tamanho: CGSize, cor: CorRGBA) -> CGImage {
    let contexto = contextoRGBA(largura: Int(tamanho.width), altura: Int(tamanho.height))
    contexto.setFillColor(red: cor.r, green: cor.g, blue: cor.b, alpha: cor.a)
    contexto.fill(CGRect(origin: .zero, size: tamanho))
    guard let imagem = contexto.makeImage() else { preconditionFailure("makeImage falhou") }
    return imagem
}

/// Pixel `(x, y)` com origem no canto superior esquerdo, lido de qualquer imagem de entrada.
func pixel(_ imagem: CGImage, x: Int, y: Int) -> PixelRGBA {
    let contexto = contextoRGBA(largura: imagem.width, altura: imagem.height)
    contexto.draw(imagem, in: CGRect(x: 0, y: 0, width: imagem.width, height: imagem.height))
    guard let dados = contexto.data, x >= 0, y >= 0, x < imagem.width, y < imagem.height else {
        return (0, 0, 0, 0)
    }
    let bytes = dados.assumingMemoryBound(to: UInt8.self)
    let i = y * contexto.bytesPerRow + x * 4
    return (bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3])
}

/// Todos os pixels (RGBA) com origem no canto superior esquerdo, para comparar imagens inteiras.
func todosOsPixels(_ imagem: CGImage) -> [UInt8] {
    let contexto = contextoRGBA(largura: imagem.width, altura: imagem.height)
    contexto.draw(imagem, in: CGRect(x: 0, y: 0, width: imagem.width, height: imagem.height))
    guard let dados = contexto.data else { return [] }
    let n = contexto.bytesPerRow * imagem.height
    return Array(UnsafeBufferPointer(start: dados.assumingMemoryBound(to: UInt8.self), count: n))
}

/// Compara dois pixels com tolerância por canal.
func proximos(
    _ a: PixelRGBA,
    _ r: Int,
    _ g: Int,
    _ b: Int,
    tolerancia: Int = 2
) -> Bool {
    abs(Int(a.r) - r) <= tolerancia && abs(Int(a.g) - g) <= tolerancia
        && abs(Int(a.b) - b) <= tolerancia
}

/// Xadrez preto e branco puro, com quadrados de `quadrado` pixels; o pixel (0, 0) é branco.
func imagemXadrez(_ tamanho: CGSize, quadrado: Int = 2) -> CGImage {
    let largura = Int(tamanho.width)
    let altura = Int(tamanho.height)
    let contexto = contextoRGBA(largura: largura, altura: altura)
    contexto.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    contexto.fill(CGRect(origin: .zero, size: tamanho))
    contexto.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
    for y in 0..<altura {
        for x in 0..<largura where ((x / quadrado) + (y / quadrado)) % 2 == 1 {
            // Origem do contexto embaixo: converte para linhas contadas do topo.
            contexto.fill(CGRect(x: x, y: altura - 1 - y, width: 1, height: 1))
        }
    }
    guard let imagem = contexto.makeImage() else { preconditionFailure("makeImage falhou") }
    return imagem
}

/// Desvio-padrão da luminância (0 a 255) dos pixels dentro de `regiao` (origem no topo).
func desvioPadraoDaLuminancia(_ imagem: CGImage, regiao: CGRect) -> Double {
    var valores: [Double] = []
    for y in Int(regiao.minY)..<Int(regiao.maxY) {
        for x in Int(regiao.minX)..<Int(regiao.maxX) {
            let p = pixel(imagem, x: x, y: y)
            valores.append(0.2126 * Double(p.r) + 0.7152 * Double(p.g) + 0.0722 * Double(p.b))
        }
    }
    guard !valores.isEmpty else { return 0 }
    let media = valores.reduce(0, +) / Double(valores.count)
    let variancia = valores.map { ($0 - media) * ($0 - media) }.reduce(0, +) / Double(valores.count)
    return variancia.squareRoot()
}
