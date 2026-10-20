/// Aparência de uma anotação.
public struct Estilo: Codable, Equatable, Sendable {
    public var cor: CorRGBA
    /// Espessura do traço em pixels do documento (≥ 0).
    public var largura: Double
    /// Opacidade de 0 a 1.
    public var opacidade: Double
    public var preenchimento: CorRGBA?
    public var tracejado: Bool

    public init(
        cor: CorRGBA = .vermelho,
        largura: Double = 4,
        opacidade: Double = 1,
        preenchimento: CorRGBA? = nil,
        tracejado: Bool = false
    ) {
        self.cor = cor
        self.largura = largura
        self.opacidade = opacidade
        self.preenchimento = preenchimento
        self.tracejado = tracejado
    }
}
