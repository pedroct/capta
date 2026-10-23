import Foundation

/// Um pacote `.capta` listado entre as capturas recentes.
public struct CapturaRecente: Equatable, Sendable {
    /// Caminho do pacote.
    public let url: URL
    /// Nome do pacote sem a extensão `.capta`.
    public let nome: String
    /// Data de modificação do `documento.json`.
    public let modificadaEm: Date

    public init(url: URL, nome: String, modificadaEm: Date) {
        self.url = url
        self.nome = nome
        self.modificadaEm = modificadaEm
    }
}

/// Lista os pacotes `.capta` de uma pasta, do mais novo para o mais antigo.
public enum CapturasRecentes {
    /// Quantidade padrão de capturas devolvidas.
    public static let limitePadrao = 10

    private static let extensaoPacote = "capta"
    private static let nomeDocumento = "documento.json"

    /// Devolve até `limite` pacotes de `pasta`, do mais recente para o mais antigo.
    ///
    /// Só entram pastas com extensão `capta` que não começam com `.` (isso deixa de fora os
    /// temporários da gravação) e que tenham `documento.json`; a data é a de modificação dele.
    /// Empates ordenam pelo nome. Pasta inexistente devolve `[]`.
    /// - Throws: o erro do `FileManager` se a pasta existir mas não puder ser lida.
    public static func listar(
        em pasta: URL,
        limite: Int = limitePadrao
    ) throws -> [CapturaRecente] {
        let gerenciador = FileManager.default
        guard gerenciador.fileExists(atPath: pasta.path) else { return [] }
        let itens = try gerenciador.contentsOfDirectory(
            at: pasta,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
        let capturas = itens.compactMap { url -> CapturaRecente? in
            guard
                url.pathExtension == extensaoPacote,
                !url.lastPathComponent.hasPrefix("."),
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                let data = try? url.appendingPathComponent(nomeDocumento)
                    .resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate
            else { return nil }
            return CapturaRecente(
                url: url,
                nome: url.deletingPathExtension().lastPathComponent,
                modificadaEm: data
            )
        }
        let ordenadas = capturas.sorted {
            if $0.modificadaEm != $1.modificadaEm { return $0.modificadaEm > $1.modificadaEm }
            return $0.nome < $1.nome
        }
        return Array(ordenadas.prefix(max(0, limite)))
    }
}
