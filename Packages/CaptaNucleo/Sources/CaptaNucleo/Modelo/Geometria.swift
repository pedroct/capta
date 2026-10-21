import CoreGraphics

/// Formas básicas desenháveis.
public enum TipoForma: String, Codable, Equatable, Sendable {
    case retangulo
    case retanguloArredondado
    case elipse
}

/// Modos de ocultação de uma região.
public enum TipoDesfoque: String, Codable, Equatable, Sendable {
    case borrar
    case pixelizar
}

/// Geometria de uma anotação.
///
/// Todas as coordenadas estão em pixels da imagem base do documento, com origem no canto
/// superior esquerdo e eixo Y crescendo para baixo. Retângulos, `tamanhoFonte`, `diametro` e
/// `intensidade` também são medidos em pixels da imagem base, não em pontos de tela.
public enum Geometria: Codable, Equatable, Sendable {
    case seta(inicio: CGPoint, fim: CGPoint)
    case linha(inicio: CGPoint, fim: CGPoint)
    case forma(TipoForma, CGRect)
    case texto(CGRect, conteudo: String, tamanhoFonte: Double, negrito: Bool, italico: Bool)
    case etapa(centro: CGPoint, diametro: Double, reiniciaSequencia: Bool)
    case carimbo(CGRect, simbolo: String)
    case realce(CGRect)
    case desfoque(CGRect, TipoDesfoque, intensidade: Double)
}
