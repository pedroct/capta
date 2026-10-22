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
    /// Token `anotacao-laranja` (#FF9500).
    public static let laranja = CorRGBA(255, 149, 0)
    /// Token `anotacao-amarelo` (#FFCC00).
    public static let amarelo = CorRGBA(255, 204, 0)
    /// Token `anotacao-verde` (#34C759).
    public static let verde = CorRGBA(52, 199, 89)
    /// Token `anotacao-azul` (#0A84FF).
    public static let azul = CorRGBA(10, 132, 255)
    /// Token `anotacao-roxo` (#AF52DE).
    public static let roxo = CorRGBA(175, 82, 222)
    /// Token `anotacao-preto` (#1C1C1E); não é o preto puro.
    public static let preto = CorRGBA(28, 28, 30)
    /// Token `anotacao-branco` (#FFFFFF).
    public static let branco = CorRGBA(255, 255, 255)

    /// Token `anotacao-realce` (#FFD60A com alfa 0x8C), cor padrão do marca-texto.
    public static let realce = CorRGBA(
        r: 255.0 / 255,
        g: 214.0 / 255,
        b: 10.0 / 255,
        a: Double(0x8C) / 255
    )

    /// As oito cores da paleta de anotação, na ordem do `tokens.json`.
    public static let paleta: [CorRGBA] = [
        vermelho, laranja, amarelo, verde, azul, roxo, preto, branco,
    ]
}
