import Foundation

/// Conteúdo de um pacote `.capta` lido do disco.
public struct ConteudoPacote: Sendable {
    public var documento: Documento
    public var baseDados: Data
    /// `nil` quando o pacote não tem `miniatura.png` (a miniatura é opcional na leitura).
    public var miniaturaDados: Data?

    public init(documento: Documento, baseDados: Data, miniaturaDados: Data?) {
        self.documento = documento
        self.baseDados = baseDados
        self.miniaturaDados = miniaturaDados
    }
}

/// Pacote `.capta`: pasta com `documento.json`, `base.png` e `miniatura.png`.
///
/// Regra central: uma falha nunca apaga nem sobrescreve um pacote bom.
public enum PacoteCapta {
    public static let extensao = "capta"

    private static let nomeDocumento = "documento.json"
    private static let nomeBase = "base.png"
    private static let nomeMiniatura = "miniatura.png"

    /// Lê só a versão, para o portão de versão antes de decodificar o documento completo.
    private struct CabecalhoVersao: Decodable {
        let versaoEsquema: Int
    }

    /// Grava um pacote novo em `destino`, sem renomear nem acrescentar extensão.
    ///
    /// Valida as entradas, escreve tudo numa pasta temporária irmã e só então a coloca no lugar:
    /// `moveItem` se `destino` não existe, `replaceItemAt` (substituição atômica) se existe.
    /// Em qualquer falha a pasta temporária é removida e o `destino` anterior fica intacto.
    /// Com `substituir == false`, um destino existente lança ``ErroPacote/destinoJaExiste``.
    public static func gravar(
        _ documento: Documento,
        baseDados: Data,
        miniaturaDados: Data,
        em destino: URL,
        substituir: Bool = true
    ) throws {
        guard !baseDados.isEmpty, !miniaturaDados.isEmpty else { throw ErroPacote.dadosVazios }
        try documento.validar()
        let json = try codificador().encode(documento)

        let gerenciador = FileManager.default
        let temporario = destino.deletingLastPathComponent()
            .appendingPathComponent(
                ".\(destino.lastPathComponent).tmp-\(UUID().uuidString)",
                isDirectory: true
            )
        try gerenciador.createDirectory(at: temporario, withIntermediateDirectories: false)
        // Após o move/replace o temporário não existe mais; `try?` só limpa o que sobrou de falha.
        defer { try? gerenciador.removeItem(at: temporario) }

        try json.write(to: temporario.appendingPathComponent(nomeDocumento))
        try baseDados.write(to: temporario.appendingPathComponent(nomeBase))
        try miniaturaDados.write(to: temporario.appendingPathComponent(nomeMiniatura))

        if substituir, gerenciador.fileExists(atPath: destino.path) {
            _ = try gerenciador.replaceItemAt(destino, withItemAt: temporario)
        } else {
            do {
                // `moveItem` falha se o destino existe, então nunca substitui em silêncio.
                try gerenciador.moveItem(at: temporario, to: destino)
            } catch {
                if !substituir, gerenciador.fileExists(atPath: destino.path) {
                    throw ErroPacote.destinoJaExiste
                }
                throw error
            }
        }
    }

    /// Regrava só `documento.json` (e `miniatura.png`, se vier), cada um de forma atômica.
    ///
    /// Nunca toca `base.png`. Não lê o JSON antigo: um `documento.json` corrompido é simplesmente
    /// sobrescrito. O documento é validado e codificado antes de qualquer escrita; se falhar,
    /// nada muda no disco. A miniatura é gravada antes do JSON, que é o último passo.
    public static func atualizar(
        _ documento: Documento,
        miniaturaDados: Data?,
        em destino: URL
    ) throws {
        if let miniaturaDados, miniaturaDados.isEmpty { throw ErroPacote.dadosVazios }
        try documento.validar()
        let json = try codificador().encode(documento)

        let gerenciador = FileManager.default
        for nome in [nomeBase, nomeDocumento]
        where !gerenciador.fileExists(atPath: destino.appendingPathComponent(nome).path) {
            throw ErroPacote.arquivoAusente(nome)
        }

        if let miniaturaDados {
            try miniaturaDados.write(
                to: destino.appendingPathComponent(nomeMiniatura),
                options: .atomic
            )
        }
        try json.write(to: destino.appendingPathComponent(nomeDocumento), options: .atomic)
    }

    /// Lê um pacote.
    ///
    /// JSON truncado ou malformado vira ``ErroPacote/jsonInvalido``; valores inválidos num
    /// documento bem formado propagam ``ErroDocumento`` sem conversão. A versão é conferida
    /// antes do documento completo, porque um arquivo futuro pode nem caber no esquema de hoje.
    /// `base.png` vazio vira ``ErroPacote/dadosVazios``.
    public static func ler(de origem: URL) throws -> ConteudoPacote {
        let gerenciador = FileManager.default
        var ehPasta: ObjCBool = false
        guard gerenciador.fileExists(atPath: origem.path, isDirectory: &ehPasta), ehPasta.boolValue
        else {
            throw ErroPacote.arquivoAusente(origem.lastPathComponent)
        }
        let urlJson = origem.appendingPathComponent(nomeDocumento)
        let urlBase = origem.appendingPathComponent(nomeBase)
        guard gerenciador.fileExists(atPath: urlJson.path) else {
            throw ErroPacote.arquivoAusente(nomeDocumento)
        }
        guard gerenciador.fileExists(atPath: urlBase.path) else {
            throw ErroPacote.arquivoAusente(nomeBase)
        }

        let json = try Data(contentsOf: urlJson)
        let decodificador = JSONDecoder()
        let documento: Documento
        do {
            let cabecalho = try decodificador.decode(CabecalhoVersao.self, from: json)
            if cabecalho.versaoEsquema > Esquema.versaoAtual {
                throw ErroPacote.versaoMaisNova(cabecalho.versaoEsquema)
            }
            documento = try decodificador.decode(Documento.self, from: json)
        } catch is DecodingError {
            throw ErroPacote.jsonInvalido
        }

        let baseDados = try Data(contentsOf: urlBase)
        guard !baseDados.isEmpty else { throw ErroPacote.dadosVazios }
        let urlMiniatura = origem.appendingPathComponent(nomeMiniatura)
        let miniaturaDados =
            gerenciador.fileExists(atPath: urlMiniatura.path)
            ? try Data(contentsOf: urlMiniatura) : nil
        return ConteudoPacote(
            documento: documento,
            baseDados: baseDados,
            miniaturaDados: miniaturaDados
        )
    }

    private static func codificador() -> JSONEncoder {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.sortedKeys, .prettyPrinted]
        return codificador
    }
}
