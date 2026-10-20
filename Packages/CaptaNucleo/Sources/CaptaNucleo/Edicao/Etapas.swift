import Foundation

extension Documento {
    /// Número exibido da etapa `id`, ou `nil` se o id não for de uma etapa.
    ///
    /// Conta só geometrias `.etapa`, na ordem das camadas. A primeira é sempre `1`; uma etapa
    /// com `reiniciaSequencia == true` volta a `1` e as seguintes continuam a partir dela.
    public func numeroDaEtapa(_ id: UUID) -> Int? {
        var numero = 0
        for objeto in objetos {
            guard case .etapa(_, _, let reinicia) = objeto.geometria else { continue }
            numero = reinicia ? 1 : numero + 1
            if objeto.id == id { return numero }
        }
        return nil
    }
}
