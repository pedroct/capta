/// Último estilo usado em cada ferramenta de desenho. Persiste como dicionário por
/// `rawValue` da ferramenta; ferramenta ausente ou chave desconhecida vira o padrão.
public struct MemoriaDeEstilos: Codable, Equatable, Sendable {
    private var porFerramenta: [Ferramenta: Estilo]

    /// Os padrões de cada ferramenta (seleção não desenha, então fica com o `Estilo()` neutro).
    public static let padrao = MemoriaDeEstilos(porFerramenta: [
        .selecao: Estilo(),
        .seta: Estilo(cor: .vermelho, largura: 6),
        .linha: Estilo(cor: .vermelho, largura: 4),
        .forma: Estilo(cor: .vermelho, largura: 4),
        .realce: Estilo(cor: .realce, largura: 0),
    ])

    public init() {
        self = .padrao
    }

    private init(porFerramenta: [Ferramenta: Estilo]) {
        self.porFerramenta = porFerramenta
    }

    public subscript(ferramenta: Ferramenta) -> Estilo {
        get { porFerramenta[ferramenta] ?? Self.padrao.porFerramenta[ferramenta] ?? Estilo() }
        set { porFerramenta[ferramenta] = newValue }
    }

    /// A ferramenta que cria esse tipo de geometria, ou `nil` se nenhuma (texto, etapa…).
    public static func ferramenta(de geometria: Geometria) -> Ferramenta? {
        switch geometria {
        case .seta: .seta
        case .linha: .linha
        case .forma: .forma
        case .realce: .realce
        default: nil
        }
    }

    private struct Chave: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ nome: String) { stringValue = nome }
        init?(stringValue: String) { self.init(stringValue) }
        init?(intValue: Int) { nil }
    }

    /// Tolerante: lê só as ferramentas conhecidas; o que faltar (ou vier inválido) é o padrão.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Chave.self)
        self = .padrao
        for ferramenta in Ferramenta.allCases {
            if let estilo = try? c.decode(Estilo.self, forKey: Chave(ferramenta.rawValue)) {
                self[ferramenta] = estilo
            }
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Chave.self)
        for ferramenta in Ferramenta.allCases {
            try c.encode(self[ferramenta], forKey: Chave(ferramenta.rawValue))
        }
    }
}
