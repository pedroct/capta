import CoreGraphics

/// Formas do JSON do esquema v1 para tipos geométricos.
///
/// O `Codable` do CoreGraphics grava arrays (`[[x,y],[w,h]]`); o arquivo `.capta` usa objetos
/// com chaves nomeadas, que seguem estáveis mesmo que o CoreGraphics mude.

/// Ponto: `{"x","y"}`.
struct PontoJSON: Codable, Equatable {
    var x: Double
    var y: Double

    init(_ ponto: CGPoint) {
        x = ponto.x
        y = ponto.y
    }

    var ponto: CGPoint { CGPoint(x: x, y: y) }
}

/// Retângulo: `{"x","y","largura","altura"}`. Largura e altura podem ser negativas.
struct RetanguloJSON: Codable, Equatable {
    var x: Double
    var y: Double
    var largura: Double
    var altura: Double

    init(_ retangulo: CGRect) {
        x = retangulo.origin.x
        y = retangulo.origin.y
        largura = retangulo.size.width
        altura = retangulo.size.height
    }

    var retangulo: CGRect { CGRect(x: x, y: y, width: largura, height: altura) }
}

/// Tamanho: `{"largura","altura"}`.
struct TamanhoJSON: Codable, Equatable {
    var largura: Double
    var altura: Double

    init(_ tamanho: CGSize) {
        largura = tamanho.width
        altura = tamanho.height
    }

    var tamanho: CGSize { CGSize(width: largura, height: altura) }
}
