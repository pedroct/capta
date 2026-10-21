import Foundation

/// Conteúdo de um pacote `.capta`, lido do disco ou a gravar.
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

    /// Devolve a pasta onde montar a substituição de `destino`; lança se não houver.
    typealias PastaDeSubstituicao = (URL) throws -> URL

    /// Grava um pacote novo em `destino`, sem renomear nem acrescentar extensão.
    ///
    /// Valida as entradas, escreve tudo numa pasta temporária e só então a coloca no lugar
    /// (ver `colocar(em:substituir:usando:montar:)`). Em qualquer falha o temporário é removido
    /// e o `destino` anterior fica intacto. Com `substituir == false`, um destino existente
    /// lança ``ErroPacote/destinoJaExiste``.
    public static func gravar(
        _ documento: Documento,
        baseDados: Data,
        miniaturaDados: Data,
        em destino: URL,
        substituir: Bool = true
    ) throws {
        try gravar(
            ConteudoPacote(
                documento: documento,
                baseDados: baseDados,
                miniaturaDados: miniaturaDados
            ),
            em: destino,
            substituir: substituir,
            pastaDeSubstituicao: pastaDeSubstituicaoDoSistema
        )
    }

    /// ``gravar(_:baseDados:miniaturaDados:em:substituir:)`` com a pasta de substituição
    /// injetável, para os testes conferirem a limpeza e o recurso ao irmão. Na gravação a
    /// miniatura é obrigatória: `nil` ou vazia lança ``ErroPacote/dadosVazios``.
    static func gravar(
        _ conteudo: ConteudoPacote,
        em destino: URL,
        substituir: Bool,
        pastaDeSubstituicao: PastaDeSubstituicao
    ) throws {
        guard !conteudo.baseDados.isEmpty, let miniatura = conteudo.miniaturaDados,
            !miniatura.isEmpty
        else { throw ErroPacote.dadosVazios }
        try conteudo.documento.validar()
        let json = try codificador().encode(conteudo.documento)

        try colocar(em: destino, substituir: substituir, usando: pastaDeSubstituicao) { pacote in
            try FileManager.default.createDirectory(at: pacote, withIntermediateDirectories: false)
            try json.write(to: pacote.appendingPathComponent(nomeDocumento))
            try conteudo.baseDados.write(to: pacote.appendingPathComponent(nomeBase))
            try miniatura.write(to: pacote.appendingPathComponent(nomeMiniatura))
        }
    }

    /// Copia o pacote `origem` para `destino`, substituindo um destino existente.
    ///
    /// A origem é conferida com ``ler(de:)`` (mesmos erros). A cópia vai para uma pasta
    /// temporária e só então é colocada no lugar (ver `colocar(em:substituir:usando:montar:)`).
    /// Em qualquer falha o `destino` anterior fica intacto e o temporário é removido.
    public static func copiar(de origem: URL, para destino: URL) throws {
        try copiar(de: origem, para: destino, pastaDeSubstituicao: pastaDeSubstituicaoDoSistema)
    }

    /// ``copiar(de:para:)`` com a pasta de substituição injetável, para os testes.
    static func copiar(
        de origem: URL,
        para destino: URL,
        pastaDeSubstituicao: PastaDeSubstituicao
    ) throws {
        _ = try ler(de: origem)
        try colocar(em: destino, substituir: true, usando: pastaDeSubstituicao) { pacote in
            try FileManager.default.copyItem(at: origem, to: pacote)
        }
    }

    /// Pasta de substituição que o sistema dá para `destino`, no mesmo volume e criada agora.
    ///
    /// É a pasta desenhada para `replaceItemAt`: no App Sandbox o painel de salvar libera só o
    /// item escolhido, não a pasta que o contém, então um temporário ao lado do destino não
    /// poderia ser criado. Lança se a pasta do destino não existe.
    static func pastaDeSubstituicaoDoSistema(para destino: URL) throws -> URL {
        try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: destino,
            create: true
        )
    }

    /// Monta um pacote fora do lugar e o coloca em `destino`.
    ///
    /// O pacote é montado por `montar` dentro da pasta de substituição; se ela não vier, numa
    /// pasta oculta irmã do destino (`.<nome>.tmp-<UUID>`). Depois entra no lugar com
    /// `replaceItemAt` (substituição atômica) se `substituir` e `destino` existe, ou com
    /// `moveItem`, que falha se o destino existe e então nunca substitui em silêncio. No fim,
    /// com sucesso ou falha, a pasta de substituição inteira (ou o irmão) é removida.
    private static func colocar(
        em destino: URL,
        substituir: Bool,
        usando pastaDeSubstituicao: PastaDeSubstituicao,
        montar: (URL) throws -> Void
    ) throws {
        let gerenciador = FileManager.default
        let pacote: URL
        let raiz: URL
        if let pasta = try? pastaDeSubstituicao(destino) {
            pacote = pasta.appendingPathComponent(destino.lastPathComponent, isDirectory: true)
            raiz = pasta
        } else {
            pacote = destino.deletingLastPathComponent()
                .appendingPathComponent(
                    ".\(destino.lastPathComponent).tmp-\(UUID().uuidString)",
                    isDirectory: true
                )
            raiz = pacote
        }
        // Após o move/replace o pacote não existe mais; `try?` remove a pasta de substituição
        // (vazia) ou o que sobrou de uma falha.
        defer { try? gerenciador.removeItem(at: raiz) }

        try montar(pacote)
        if substituir, gerenciador.fileExists(atPath: destino.path) {
            _ = try gerenciador.replaceItemAt(destino, withItemAt: pacote)
            return
        }
        do {
            try gerenciador.moveItem(at: pacote, to: destino)
        } catch {
            if !substituir, gerenciador.fileExists(atPath: destino.path) {
                throw ErroPacote.destinoJaExiste
            }
            throw error
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
