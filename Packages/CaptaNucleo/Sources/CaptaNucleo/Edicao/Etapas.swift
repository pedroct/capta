import Foundation

extension Documento {
    /// Número exibido da etapa `id`, ou `nil` se o id não for de uma etapa.
    ///
    /// Conta só geometrias `.etapa`, na ordem de criação (`ordem`), não na das camadas. A
    /// primeira é sempre `1`; uma etapa com `reiniciaSequencia == true` volta a `1` e as
    /// seguintes continuam a partir dela.
    public func numeroDaEtapa(_ id: UUID) -> Int? {
        var numero = 0
        for objeto in objetos.sorted(by: { $0.ordem < $1.ordem }) {
            guard case .etapa(_, _, let reinicia) = objeto.geometria else { continue }
            numero = reinicia ? 1 : numero + 1
            if objeto.id == id { return numero }
        }
        return nil
    }

    /// Texto exibido da etapa `id`: o número dela no formato do `estilo.rotulo` da própria etapa.
    public func rotuloDaEtapa(_ id: UUID) -> String? {
        guard let numero = numeroDaEtapa(id),
            let objeto = objetos.first(where: { $0.id == id })
        else { return nil }
        return objeto.estilo.rotulo.texto(paraNumero: numero)
    }
}

extension RotuloEtapa {
    /// `numerico`: `"1"`. `alfabetico`: base 26 sem zero (`1→A`, `26→Z`, `27→AA`).
    /// Número menor que 1 vale 1.
    public func texto(paraNumero numero: Int) -> String {
        var restante = max(numero, 1)
        switch self {
        case .numerico:
            return String(restante)
        case .alfabetico:
            var letras: [Character] = []
            while restante > 0 {
                restante -= 1
                let letra = Character(UnicodeScalar(UInt8(65 + restante % 26)))
                letras.append(letra)
                restante /= 26
            }
            return String(letras.reversed())
        }
    }
}
