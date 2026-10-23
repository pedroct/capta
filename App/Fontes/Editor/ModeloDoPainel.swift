import CaptaNucleo
import Foundation

/// O que o painel de propriedades mostra para o estado atual do editor: o título, o estilo e
/// quais controles fazem sentido. Valor puro, para a view só desenhar.
struct ModeloDoPainel: Equatable {
    /// `nil` com a Seleção ativa e nada selecionado: o painel mostra a dica.
    let estilo: Estilo?
    let titulo: String
    /// O realce não tem espessura.
    let mostraLargura: Bool
    /// Seta, linha e forma.
    let mostraTracejado: Bool
    /// Só a forma.
    let mostraPreenchimento: Bool

    var temControles: Bool { estilo != nil }

    init(estado: EstadoDoEditor, documento: Documento) {
        estilo = estado.estiloExibido(em: documento)
        let selecionados = documento.objetos.filter { estado.selecao.contains($0.id) }
        let tipos =
            selecionados.isEmpty
            ? [Optional(estado.ferramenta)]
            : selecionados.map { MemoriaDeEstilos.ferramenta(de: $0.geometria) }
        // Com vários objetos, só o que todos têm em comum.
        mostraLargura = tipos.allSatisfy { $0 != .realce }
        mostraTracejado = tipos.allSatisfy { $0 == .seta || $0 == .linha || $0 == .forma }
        mostraPreenchimento = tipos.allSatisfy { $0 == .forma }
        titulo = Self.titulo(estado: estado, selecionados: selecionados)
    }

    private static func titulo(estado: EstadoDoEditor, selecionados: [Anotacao]) -> String {
        let base = String(localized: "Propriedades")
        let nome: String
        if selecionados.isEmpty {
            guard estado.ferramenta != .selecao else { return base }
            nome = NomesDoEditor.ferramenta(estado.ferramenta)
        } else {
            let nomes = Set(selecionados.map { NomesDoEditor.tipo(de: $0.geometria) })
            if nomes.count == 1, let unico = nomes.first {
                nome = unico
            } else {
                nome = String(localized: "\(selecionados.count) objetos")
            }
        }
        return String(localized: "Propriedades · \(nome)")
    }
}
