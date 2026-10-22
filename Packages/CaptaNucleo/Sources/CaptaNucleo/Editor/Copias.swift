import CoreGraphics
import Foundation

extension Documento {
    /// Cópias das anotações de `ids`, na ordem das camadas, com a geometria deslocada e id novo.
    /// Ids inexistentes são ignorados. A ordem de criação é atribuída ao adicionar a cópia.
    public func copias(
        de ids: Set<UUID>,
        deslocamento: CGVector,
        novoId: () -> UUID
    ) -> [Anotacao] {
        objetos.filter { ids.contains($0.id) }.map { original in
            var copia = original
            copia.id = novoId()
            copia.geometria = original.geometria.deslocada(por: deslocamento)
            return copia
        }
    }
}
