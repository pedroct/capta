import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

/// Pasta temporária exclusiva do teste; remova com `defer`.
private func novaPastaTemporaria() throws -> URL {
    let pasta = FileManager.default.temporaryDirectory
        .appendingPathComponent("capta-teste-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
    return pasta
}

private func remover(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

private func documentoCompleto() -> Documento {
    let retangulo = CGRect(x: 10, y: 20, width: 30, height: 40)
    let geometrias: [Geometria] = [
        .seta(inicio: .init(x: 1, y: 2), fim: .init(x: 3, y: 4)),
        .linha(inicio: .init(x: 5, y: 6), fim: .init(x: 7, y: 8)),
        .forma(.retanguloArredondado, retangulo),
        .texto(retangulo, conteudo: "Olá", tamanhoFonte: 14, negrito: true, italico: false),
        .etapa(centro: .init(x: 50, y: 50), diametro: 24, reiniciaSequencia: true),
        .carimbo(retangulo, simbolo: "star"),
        .realce(retangulo),
        .desfoque(retangulo, .pixelizar, intensidade: 8),
    ]
    return Documento(
        versaoEsquema: Esquema.versaoAtual,
        tamanhoBase: CGSize(width: 200, height: 100),
        escala: 2,
        recorte: CGRect(x: 0, y: 0, width: 100, height: 50),
        objetos: geometrias.map { Anotacao(id: UUID(), geometria: $0) }
    )
}

private let base = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
private let miniatura = Data([0x89, 0x50, 0x4E, 0x47, 9, 9])

private func itens(_ url: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
}

@Test func gravarELerFazemIdaEVolta() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    let doc = documentoCompleto()
    try PacoteCapta.gravar(doc, baseDados: base, miniaturaDados: miniatura, em: destino)
    let lido = try PacoteCapta.ler(de: destino)
    #expect(lido.documento == doc)
    #expect(lido.baseDados == base)
    #expect(lido.miniaturaDados == miniatura)
}

@Test func pacoteTemAsTresPartesEExtensao() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    #expect(try itens(destino) == ["base.png", "documento.json", "miniatura.png"])
    #expect(destino.pathExtension == PacoteCapta.extensao)
    #expect(PacoteCapta.extensao == "capta")
    // Nenhuma pasta temporária sobra ao lado do pacote.
    #expect(try itens(pasta) == ["a.capta"])
}

@Test func atualizarNaoTocaABase() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    let arquivoBase = destino.appendingPathComponent("base.png")
    let passado = Date(timeIntervalSince1970: 1_000_000_000)
    try FileManager.default.setAttributes(
        [.modificationDate: passado],
        ofItemAtPath: arquivoBase.path
    )

    var novo = documentoCompleto()
    novo.objetos.removeLast()
    let novaMiniatura = Data([7, 7, 7])
    try PacoteCapta.atualizar(novo, miniaturaDados: novaMiniatura, em: destino)

    let atributos = try FileManager.default.attributesOfItem(atPath: arquivoBase.path)
    #expect(atributos[.modificationDate] as? Date == passado)
    #expect(try Data(contentsOf: arquivoBase) == base)
    let lido = try PacoteCapta.ler(de: destino)
    #expect(lido.documento == novo)
    #expect(lido.miniaturaDados == novaMiniatura)
}

@Test func atualizarSemMiniaturaMantemAMiniaturaAnterior() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    try PacoteCapta.atualizar(documentoCompleto(), miniaturaDados: nil, em: destino)
    #expect(try PacoteCapta.ler(de: destino).miniaturaDados == miniatura)
}

@Test func jsonTruncadoLancaJsonInvalido() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    let json = destino.appendingPathComponent("documento.json")
    let inteiro = try Data(contentsOf: json)
    try inteiro.prefix(inteiro.count / 2).write(to: json)
    #expect(throws: ErroPacote.jsonInvalido) { try PacoteCapta.ler(de: destino) }
}

@Test func semBasePngLancaArquivoAusente() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    try FileManager.default.removeItem(at: destino.appendingPathComponent("base.png"))
    #expect(throws: ErroPacote.arquivoAusente("base.png")) { try PacoteCapta.ler(de: destino) }
}

@Test func semDocumentoJsonLancaArquivoAusente() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    try FileManager.default.removeItem(at: destino.appendingPathComponent("documento.json"))
    #expect(throws: ErroPacote.arquivoAusente("documento.json")) {
        try PacoteCapta.ler(de: destino)
    }
}

@Test func semMiniaturaAindaLe() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    try FileManager.default.removeItem(at: destino.appendingPathComponent("miniatura.png"))
    let lido = try PacoteCapta.ler(de: destino)
    #expect(lido.miniaturaDados == nil)
    #expect(lido.baseDados == base)
}

@Test func baseVaziaNoDiscoLancaDadosVazios() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    try Data().write(to: destino.appendingPathComponent("base.png"))
    #expect(throws: ErroPacote.dadosVazios) { try PacoteCapta.ler(de: destino) }
}

@Test func versaoEsquema99LancaVersaoMaisNova() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    let json = destino.appendingPathComponent("documento.json")
    let texto = try String(contentsOf: json, encoding: .utf8)
        .replacingOccurrences(of: "\"versaoEsquema\" : 1", with: "\"versaoEsquema\" : 99")
    try Data(texto.utf8).write(to: json)
    #expect(throws: ErroPacote.versaoMaisNova(99)) { try PacoteCapta.ler(de: destino) }
}

@Test func versaoMaisNovaVenceMesmoQuandoORestoDoJsonNaoCabeNoEsquema() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    let futuro = "{\"versaoEsquema\": 7, \"camadasNovas\": [1, 2]}"
    try Data(futuro.utf8).write(to: destino.appendingPathComponent("documento.json"))
    #expect(throws: ErroPacote.versaoMaisNova(7)) { try PacoteCapta.ler(de: destino) }
}

@Test func semVersaoEsquemaLancaJsonInvalido() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    try Data("{\"outra\": 1}".utf8).write(to: destino.appendingPathComponent("documento.json"))
    #expect(throws: ErroPacote.jsonInvalido) { try PacoteCapta.ler(de: destino) }
}

@Test func documentoComValorInvalidoPropagaErroDocumento() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    let json = destino.appendingPathComponent("documento.json")
    let texto = try String(contentsOf: json, encoding: .utf8)
        .replacingOccurrences(of: "\"escala\" : 2", with: "\"escala\" : -2")
    try Data(texto.utf8).write(to: json)
    #expect(throws: ErroDocumento.tamanhoInvalido) { try PacoteCapta.ler(de: destino) }
}

@Test func lerPastaQueNaoExisteLancaArquivoAusente() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("nao-existe.capta")
    #expect(throws: ErroPacote.arquivoAusente("nao-existe.capta")) {
        try PacoteCapta.ler(de: destino)
    }
}

@Test func gravarComBaseVaziaLancaDadosVaziosENaoCriaNada() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    #expect(throws: ErroPacote.dadosVazios) {
        try PacoteCapta.gravar(
            documentoCompleto(),
            baseDados: Data(),
            miniaturaDados: miniatura,
            em: destino
        )
    }
    #expect(throws: ErroPacote.dadosVazios) {
        try PacoteCapta.gravar(
            documentoCompleto(),
            baseDados: base,
            miniaturaDados: Data(),
            em: destino
        )
    }
    #expect(try itens(pasta).isEmpty)
}

@Test func gravarDocumentoInvalidoLancaErroDocumentoENaoCriaNada() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    var invalido = documentoCompleto()
    invalido.escala = 0
    #expect(throws: ErroDocumento.tamanhoInvalido) {
        try PacoteCapta.gravar(invalido, baseDados: base, miniaturaDados: miniatura, em: destino)
    }
    #expect(try itens(pasta).isEmpty)
}

@Test func gravarSobreUmPacoteExistenteQueFalhaMantemOAntigo() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    let original = documentoCompleto()
    try PacoteCapta.gravar(original, baseDados: base, miniaturaDados: miniatura, em: destino)
    #expect(throws: ErroPacote.dadosVazios) {
        try PacoteCapta.gravar(
            Documento.novo(tamanhoBase: .init(width: 5, height: 5), escala: 1),
            baseDados: Data(),
            miniaturaDados: Data([1]),
            em: destino
        )
    }
    let lido = try PacoteCapta.ler(de: destino)
    #expect(lido.documento == original)
    #expect(lido.baseDados == base)
    #expect(lido.miniaturaDados == miniatura)
    #expect(try itens(pasta) == ["a.capta"])
}

@Test func gravarSobreUmPacoteExistenteSubstituiPorInteiro() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    let novo = Documento.novo(tamanhoBase: .init(width: 5, height: 5), escala: 1)
    try PacoteCapta.gravar(novo, baseDados: Data([5]), miniaturaDados: Data([6]), em: destino)
    let lido = try PacoteCapta.ler(de: destino)
    #expect(lido.documento == novo)
    #expect(lido.baseDados == Data([5]))
    #expect(try itens(pasta) == ["a.capta"])
}

@Test func atualizarComJsonCorrompidoNoDiscoNaoApagaABase() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    try PacoteCapta.gravar(
        documentoCompleto(),
        baseDados: base,
        miniaturaDados: miniatura,
        em: destino
    )
    let json = destino.appendingPathComponent("documento.json")
    try Data("{ lixo".utf8).write(to: json)

    // `atualizar` não lê o JSON antigo: sobrescreve o corrompido de forma atômica.
    let novo = documentoCompleto()
    try PacoteCapta.atualizar(novo, miniaturaDados: nil, em: destino)

    #expect(try Data(contentsOf: destino.appendingPathComponent("base.png")) == base)
    #expect(try PacoteCapta.ler(de: destino).documento == novo)
}

@Test func atualizarComDocumentoInvalidoNaoMudaONoDisco() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    let original = documentoCompleto()
    try PacoteCapta.gravar(original, baseDados: base, miniaturaDados: miniatura, em: destino)
    var invalido = original
    invalido.escala = .nan
    #expect(throws: ErroDocumento.valorNaoFinito) {
        try PacoteCapta.atualizar(invalido, miniaturaDados: Data([1]), em: destino)
    }
    let lido = try PacoteCapta.ler(de: destino)
    #expect(lido.documento == original)
    #expect(lido.miniaturaDados == miniatura)
}

@Test func atualizarSemPacoteValidoLancaArquivoAusente() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("nada.capta")
    #expect(throws: ErroPacote.arquivoAusente("base.png")) {
        try PacoteCapta.atualizar(documentoCompleto(), miniaturaDados: nil, em: destino)
    }
    #expect(!FileManager.default.fileExists(atPath: destino.path))
}
