import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private func novaPasta() throws -> URL {
    let pasta = FileManager.default.temporaryDirectory
        .appendingPathComponent("capta-copiar-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
    return pasta
}

private func documento(largura: Double) -> Documento {
    Documento.novo(tamanhoBase: CGSize(width: largura, height: 10), escala: 2)
}

private let base = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
private let miniatura = Data([0x89, 0x50, 0x4E, 0x47, 9, 9])

private func gravarPacote(_ doc: Documento, em url: URL, base dados: Data = base) throws {
    try PacoteCapta.gravar(doc, baseDados: dados, miniaturaDados: miniatura, em: url)
}

private func nomes(_ url: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
}

@Suite("PacoteCapta.copiar")
struct PacoteCopiarTests {
    @Test func copiarGeraPacoteIgualAOriginal() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let origem = pasta.appendingPathComponent("a.capta")
        let destino = pasta.appendingPathComponent("b.capta")
        try gravarPacote(documento(largura: 20), em: origem)

        try PacoteCapta.copiar(de: origem, para: destino)

        let a = try PacoteCapta.ler(de: origem)
        let b = try PacoteCapta.ler(de: destino)
        #expect(a.documento == b.documento)
        #expect(a.baseDados == b.baseDados)
        #expect(a.miniaturaDados == b.miniaturaDados)
        #expect(try nomes(pasta) == ["a.capta", "b.capta"])
    }

    @Test func copiarDeOrigemInexistenteOuInvalidaLancaOErroDeLeitura() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let destino = pasta.appendingPathComponent("b.capta")

        let inexistente = pasta.appendingPathComponent("nao-existe.capta")
        #expect(throws: ErroPacote.arquivoAusente("nao-existe.capta")) {
            try PacoteCapta.copiar(de: inexistente, para: destino)
        }

        let invalida = pasta.appendingPathComponent("ruim.capta")
        try gravarPacote(documento(largura: 20), em: invalida)
        try Data("{".utf8).write(to: invalida.appendingPathComponent("documento.json"))
        #expect(throws: ErroPacote.jsonInvalido) {
            try PacoteCapta.copiar(de: invalida, para: destino)
        }
        #expect(!FileManager.default.fileExists(atPath: destino.path))
        #expect(try nomes(pasta) == ["ruim.capta"])
    }

    @Test func copiarSobreDestinoExistenteSubstituiPorInteiro() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let origem = pasta.appendingPathComponent("a.capta")
        let destino = pasta.appendingPathComponent("b.capta")
        try gravarPacote(documento(largura: 20), em: origem)
        try gravarPacote(documento(largura: 99), em: destino, base: Data([0x89, 7, 7, 7, 7]))

        try PacoteCapta.copiar(de: origem, para: destino)

        let a = try PacoteCapta.ler(de: origem)
        let b = try PacoteCapta.ler(de: destino)
        #expect(b.documento == a.documento)
        #expect(b.baseDados == a.baseDados)
        #expect(try nomes(pasta) == ["a.capta", "b.capta"])
        #expect(try nomes(destino) == ["base.png", "documento.json", "miniatura.png"])
    }

    @Test func copiarComFalhaMantemODestinoAntigo() throws {
        try #require(getuid() != 0)
        let pasta = try novaPasta()
        let origem = pasta.appendingPathComponent("a.capta")
        let pastaDestino = pasta.appendingPathComponent("saida", isDirectory: true)
        try FileManager.default.createDirectory(at: pastaDestino, withIntermediateDirectories: true)
        let destino = pastaDestino.appendingPathComponent("b.capta")
        try gravarPacote(documento(largura: 20), em: origem)
        try gravarPacote(documento(largura: 99), em: destino)
        let antes = try PacoteCapta.ler(de: destino)

        // Pasta do destino sem escrita: a cópia não pode entrar no lugar do destino.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: pastaDestino.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: pastaDestino.path
            )
            try? FileManager.default.removeItem(at: pasta)
        }

        #expect(throws: (any Error).self) {
            try PacoteCapta.copiar(de: origem, para: destino)
        }

        let depois = try PacoteCapta.ler(de: destino)
        #expect(depois.documento == antes.documento)
        #expect(depois.baseDados == antes.baseDados)
        #expect(try nomes(pastaDestino) == ["b.capta"])
    }

    @Test func copiarComOrigemCorrompidaMantemODestinoAntigo() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let origem = pasta.appendingPathComponent("a.capta")
        let destino = pasta.appendingPathComponent("b.capta")
        try gravarPacote(documento(largura: 20), em: origem)
        try gravarPacote(documento(largura: 99), em: destino)
        let antes = try PacoteCapta.ler(de: destino)
        try Data().write(to: origem.appendingPathComponent("base.png"))

        #expect(throws: ErroPacote.dadosVazios) {
            try PacoteCapta.copiar(de: origem, para: destino)
        }

        let depois = try PacoteCapta.ler(de: destino)
        #expect(depois.documento == antes.documento)
        #expect(try nomes(pasta) == ["a.capta", "b.capta"])
    }
}
