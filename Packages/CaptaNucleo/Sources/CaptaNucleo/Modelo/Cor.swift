/// Cor sRGB com componentes de 0 a 1.
public struct CorRGBA: Codable, Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// Cria uma cor a partir de componentes de 0 a 255.
    private init(_ r: Int, _ g: Int, _ b: Int) {
        self.init(r: Double(r) / 255, g: Double(g) / 255, b: Double(b) / 255)
    }

    /// Token `anotacao-vermelho` (#FF3B30).
    public static let vermelho = CorRGBA(255, 59, 48)
    /// Token `anotacao-amarelo` (#FFCC00).
    public static let amarelo = CorRGBA(255, 204, 0)
    /// Token `anotacao-preto` (#1C1C1E); não é o preto puro.
    public static let preto = CorRGBA(28, 28, 30)
    /// Token `anotacao-branco` (#FFFFFF).
    public static let branco = CorRGBA(255, 255, 255)
}
