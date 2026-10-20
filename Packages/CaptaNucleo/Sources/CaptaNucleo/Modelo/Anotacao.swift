import Foundation

/// Um objeto de anotação sobre a imagem base.
public struct Anotacao: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var geometria: Geometria
    public var estilo: Estilo

    public init(id: UUID = UUID(), geometria: Geometria, estilo: Estilo = Estilo()) {
        self.id = id
        self.geometria = geometria
        self.estilo = estilo
    }
}
