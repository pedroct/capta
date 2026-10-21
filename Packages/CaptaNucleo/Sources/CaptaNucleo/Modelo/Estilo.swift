/// Ponta de uma seta.
public enum PontaSeta: String, Codable, Equatable, Sendable {
    case triangulo
    case aberta
    case nenhuma
}

/// Alinhamento horizontal do texto.
public enum AlinhamentoTexto: String, Codable, Equatable, Sendable {
    case esquerda
    case centro
    case direita
}

/// Tipo de rótulo de uma etapa.
public enum RotuloEtapa: String, Codable, Equatable, Sendable {
    case numerico
    case alfabetico
}

/// Aparência de uma anotação.
public struct Estilo: Codable, Equatable, Sendable {
    public var cor: CorRGBA
    /// Espessura do traço em pixels do documento (≥ 0).
    public var largura: Double
    /// Opacidade de 0 a 1.
    public var opacidade: Double
    public var preenchimento: CorRGBA?
    public var tracejado: Bool
    public var ponta: PontaSeta
    /// Família da fonte do texto; `nil` usa a fonte padrão. Quando presente, não pode ser vazia.
    public var familiaFonte: String?
    public var alinhamento: AlinhamentoTexto
    public var rotulo: RotuloEtapa

    public init(
        cor: CorRGBA = .vermelho,
        largura: Double = 4,
        opacidade: Double = 1,
        preenchimento: CorRGBA? = nil,
        tracejado: Bool = false,
        ponta: PontaSeta = .triangulo,
        familiaFonte: String? = nil,
        alinhamento: AlinhamentoTexto = .esquerda,
        rotulo: RotuloEtapa = .numerico
    ) {
        self.cor = cor
        self.largura = largura
        self.opacidade = opacidade
        self.preenchimento = preenchimento
        self.tracejado = tracejado
        self.ponta = ponta
        self.familiaFonte = familiaFonte
        self.alinhamento = alinhamento
        self.rotulo = rotulo
    }

    private enum CodingKeys: String, CodingKey {
        case cor, largura, opacidade, preenchimento, tracejado
        case ponta, familiaFonte, alinhamento, rotulo
    }

    /// Chaves ausentes (documentos anteriores aos campos novos) assumem os padrões.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cor = try c.decode(CorRGBA.self, forKey: .cor)
        largura = try c.decode(Double.self, forKey: .largura)
        opacidade = try c.decode(Double.self, forKey: .opacidade)
        preenchimento = try c.decodeIfPresent(CorRGBA.self, forKey: .preenchimento)
        tracejado = try c.decode(Bool.self, forKey: .tracejado)
        ponta = try c.decodeIfPresent(PontaSeta.self, forKey: .ponta) ?? .triangulo
        familiaFonte = try c.decodeIfPresent(String.self, forKey: .familiaFonte)
        alinhamento =
            try c.decodeIfPresent(AlinhamentoTexto.self, forKey: .alinhamento) ?? .esquerda
        rotulo = try c.decodeIfPresent(RotuloEtapa.self, forKey: .rotulo) ?? .numerico
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cor, forKey: .cor)
        try c.encode(largura, forKey: .largura)
        try c.encode(opacidade, forKey: .opacidade)
        try c.encodeIfPresent(preenchimento, forKey: .preenchimento)
        try c.encode(tracejado, forKey: .tracejado)
        try c.encode(ponta, forKey: .ponta)
        try c.encodeIfPresent(familiaFonte, forKey: .familiaFonte)
        try c.encode(alinhamento, forKey: .alinhamento)
        try c.encode(rotulo, forKey: .rotulo)
    }
}
