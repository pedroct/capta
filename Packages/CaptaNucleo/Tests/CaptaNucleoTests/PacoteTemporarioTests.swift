import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private func novaPasta() throws -> URL {
    let pasta = FileManager.default.temporaryDirectory
        .appendingPathComponent("capta-temporario-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
    return pasta
}

private func documento(largura: Double) -> Documento {
    Documento.novo(tamanhoBase: CGSize(width: largura, height: 10), escala: 2)
}

private let base = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
private let miniatura = Data([0x89, 0x50, 0x4E, 0x47, 9, 9])

private func conteudo(largura: Double) -> ConteudoPacote {
    ConteudoPacote(
        documento: documento(largura: largura),
        baseDados: base,
        miniaturaDados: miniatura
    )
}

private func nomes(_ url: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
}

private func existe(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
}

private struct ErroDeSubstituicao: Error {}

/// Pede a pasta de substituição ao sistema e anota quais foram entregues, para conferir depois
/// que nenhuma sobrou.
private final class PastasEntregues {
    private(set) var urls: [URL] = []

    func doSistema(_ destino: URL) throws -> URL {
        let url = try PacoteCapta.pastaDeSubstituicaoDoSistema(para: destino)
        urls.append(url)
        return url
    }
}

/// A montagem do pacote acontece fora da pasta do destino (no sandbox só o item escolhido no
/// painel é gravável) e nenhum temporário sobra, nem lá nem na pasta de substituição.
@Suite("PacoteCapta: temporário fora da pasta do destino")
struct PacoteTemporarioTests {
    @Test func gravarUsaAPastaDeSubstituicaoENaoDeixaTemporario() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let destino = pasta.appendingPathComponent("a.capta")
        let entregues = PastasEntregues()

        try PacoteCapta.gravar(
            conteudo(largura: 20),
            em: destino,
            substituir: true,
            pastaDeSubstituicao: entregues.doSistema
        )
        // Segunda gravação substitui o pacote existente pelo mesmo caminho.
        try PacoteCapta.gravar(
            conteudo(largura: 30),
            em: destino,
            substituir: true,
            pastaDeSubstituicao: entregues.doSistema
        )

        #expect(entregues.urls.count == 2)
        #expect(entregues.urls.allSatisfy { !existe($0) })
        #expect(try PacoteCapta.ler(de: destino).documento == documento(largura: 30))
        #expect(try nomes(pasta) == ["a.capta"])
    }

    @Test func gravarComFalhaNaoDeixaTemporarioEMantemODestino() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let destino = pasta.appendingPathComponent("a.capta")
        try PacoteCapta.gravar(
            documento(largura: 20),
            baseDados: base,
            miniaturaDados: miniatura,
            em: destino
        )
        let entregues = PastasEntregues()

        #expect(throws: ErroPacote.destinoJaExiste) {
            try PacoteCapta.gravar(
                conteudo(largura: 99),
                em: destino,
                substituir: false,
                pastaDeSubstituicao: entregues.doSistema
            )
        }

        #expect(entregues.urls.count == 1)
        #expect(entregues.urls.allSatisfy { !existe($0) })
        #expect(try PacoteCapta.ler(de: destino).documento == documento(largura: 20))
        #expect(try nomes(pasta) == ["a.capta"])
    }

    @Test func copiarUsaAPastaDeSubstituicaoENaoDeixaTemporario() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let origem = pasta.appendingPathComponent("a.capta")
        let destino = pasta.appendingPathComponent("b.capta")
        try PacoteCapta.gravar(
            documento(largura: 20),
            baseDados: base,
            miniaturaDados: miniatura,
            em: origem
        )
        let entregues = PastasEntregues()

        try PacoteCapta.copiar(de: origem, para: destino, pastaDeSubstituicao: entregues.doSistema)
        try PacoteCapta.copiar(de: origem, para: destino, pastaDeSubstituicao: entregues.doSistema)

        #expect(entregues.urls.count == 2)
        #expect(entregues.urls.allSatisfy { !existe($0) })
        #expect(try PacoteCapta.ler(de: destino).documento == documento(largura: 20))
        #expect(try nomes(pasta) == ["a.capta", "b.capta"])
    }

    @Test func copiarComFalhaNaoDeixaTemporarioEMantemODestino() throws {
        try #require(getuid() != 0)
        let pasta = try novaPasta()
        let origem = pasta.appendingPathComponent("a.capta")
        let pastaDestino = pasta.appendingPathComponent("saida", isDirectory: true)
        try FileManager.default.createDirectory(at: pastaDestino, withIntermediateDirectories: true)
        let destino = pastaDestino.appendingPathComponent("b.capta")
        try PacoteCapta.gravar(
            documento(largura: 20),
            baseDados: base,
            miniaturaDados: miniatura,
            em: origem
        )
        try PacoteCapta.gravar(
            documento(largura: 99),
            baseDados: base,
            miniaturaDados: miniatura,
            em: destino
        )
        // Pasta do destino sem escrita: a cópia é montada na pasta de substituição, mas não
        // pode entrar no lugar.
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
        let entregues = PastasEntregues()

        #expect(throws: (any Error).self) {
            try PacoteCapta.copiar(
                de: origem,
                para: destino,
                pastaDeSubstituicao: entregues.doSistema
            )
        }

        #expect(entregues.urls.count == 1)
        #expect(entregues.urls.allSatisfy { !existe($0) })
        #expect(try PacoteCapta.ler(de: destino).documento == documento(largura: 99))
        #expect(try nomes(pastaDestino) == ["b.capta"])
    }

    @Test func semPastaDeSubstituicaoGravarECopiarUsamUmIrmaoQueNaoSobra() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let origem = pasta.appendingPathComponent("a.capta")
        let destino = pasta.appendingPathComponent("b.capta")
        let semSubstituicao: (URL) throws -> URL = { _ in throw ErroDeSubstituicao() }

        try PacoteCapta.gravar(
            conteudo(largura: 20),
            em: origem,
            substituir: false,
            pastaDeSubstituicao: semSubstituicao
        )
        try PacoteCapta.copiar(de: origem, para: destino, pastaDeSubstituicao: semSubstituicao)
        try PacoteCapta.copiar(de: origem, para: destino, pastaDeSubstituicao: semSubstituicao)

        #expect(try PacoteCapta.ler(de: destino).documento == documento(largura: 20))
        #expect(try nomes(pasta) == ["a.capta", "b.capta"])
    }

    @Test func semPastaDeSubstituicaoAFalhaNaoDeixaOIrmao() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let destino = pasta.appendingPathComponent("a.capta")
        try PacoteCapta.gravar(
            documento(largura: 20),
            baseDados: base,
            miniaturaDados: miniatura,
            em: destino
        )

        #expect(throws: ErroPacote.destinoJaExiste) {
            try PacoteCapta.gravar(
                conteudo(largura: 99),
                em: destino,
                substituir: false,
                pastaDeSubstituicao: { _ in throw ErroDeSubstituicao() }
            )
        }

        #expect(try nomes(pasta) == ["a.capta"])
    }

    @Test func gravarSemMiniaturaLancaDadosVaziosSemCriarNada() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let entregues = PastasEntregues()
        var semMiniatura = conteudo(largura: 20)
        semMiniatura.miniaturaDados = nil

        #expect(throws: ErroPacote.dadosVazios) {
            try PacoteCapta.gravar(
                semMiniatura,
                em: pasta.appendingPathComponent("a.capta"),
                substituir: true,
                pastaDeSubstituicao: entregues.doSistema
            )
        }

        #expect(entregues.urls.isEmpty)
        #expect(try nomes(pasta) == [])
    }

    @Test func pastaDoSistemaFicaNoVolumeDoDestinoEDestinoSemPastaCaiNoIrmao() throws {
        let pasta = try novaPasta()
        defer { try? FileManager.default.removeItem(at: pasta) }
        let destino = pasta.appendingPathComponent("a.capta")

        let substituicao = try PacoteCapta.pastaDeSubstituicaoDoSistema(para: destino)
        defer { try? FileManager.default.removeItem(at: substituicao) }
        let volume = { (url: URL) in
            try url.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
                .map { "\($0)" }
        }
        #expect(try volume(substituicao) == volume(pasta))

        // A pasta do destino não existe: o sistema não dá pasta de substituição, o irmão é
        // tentado e a gravação falha sem criar nada.
        let semPasta = pasta.appendingPathComponent("nao-existe/b.capta")
        #expect(throws: (any Error).self) {
            try PacoteCapta.pastaDeSubstituicaoDoSistema(para: semPasta)
        }
        #expect(throws: (any Error).self) {
            try PacoteCapta.gravar(
                documento(largura: 20),
                baseDados: base,
                miniaturaDados: miniatura,
                em: semPasta
            )
        }
        #expect(try nomes(pasta) == [])
    }
}
