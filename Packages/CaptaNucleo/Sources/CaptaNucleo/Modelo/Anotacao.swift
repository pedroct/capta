import Foundation

/// Um objeto de anotação sobre a imagem base.
///
/// Os retângulos da geometria podem vir invertidos ou com tamanho zero; quem consome padroniza.
public struct Anotacao: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var geometria: Geometria
    public var estilo: Estilo
    /// Rotação em radianos, em torno do centro do retângulo da geometria. Só vale para formas,
    /// texto, carimbo, realce e etapa; seta, linha e desfoque exigem zero.
    public var rotacao: Double
    /// Posição na ordem de criação (base da numeração das etapas). Quem atribui é o documento.
    public internal(set) var ordem: Int = 0

    public init(
        id: UUID = UUID(),
        geometria: Geometria,
        estilo: Estilo = Estilo(),
        rotacao: Double = 0
    ) {
        self.id = id
        self.geometria = geometria
        self.estilo = estilo
        self.rotacao = rotacao
    }

    private enum CodingKeys: String, CodingKey {
        case id, geometria, estilo, rotacao, ordem
    }

    /// `rotacao` ausente (documentos anteriores ao campo) assume zero.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        geometria = try c.decode(Geometria.self, forKey: .geometria)
        estilo = try c.decode(Estilo.self, forKey: .estilo)
        rotacao = try c.decodeIfPresent(Double.self, forKey: .rotacao) ?? 0
        ordem = try c.decodeIfPresent(Int.self, forKey: .ordem) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(geometria, forKey: .geometria)
        try c.encode(estilo, forKey: .estilo)
        try c.encode(rotacao, forKey: .rotacao)
        try c.encode(ordem, forKey: .ordem)
    }
}
