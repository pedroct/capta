import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

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
    Documento(
        versaoEsquema: Esquema.versaoAtual,
        tamanhoBase: CGSize(width: 200, height: 100),
        escala: 2,
        recorte: CGRect(x: 0, y: 0, width: 100, height: 50),
        objetos: [
            Anotacao(geometria: .seta(inicio: .init(x: 1, y: 2), fim: .init(x: 3, y: 4))),
            Anotacao(geometria: .realce(CGRect(x: 10, y: 20, width: 30, height: 40))),
        ]
    )
}

private let base = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
private let miniatura = Data([0x89, 0x50, 0x4E, 0x47, 9, 9])

private func itens(_ url: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
}

@Test func gravarComVersaoEsquemaDiferenteDaAtualLancaENaoCriaNada() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    var futuro = documentoCompleto()
    futuro.versaoEsquema = 99
    #expect(throws: ErroDocumento.valorForaDeFaixa("versaoEsquema")) {
        try PacoteCapta.gravar(futuro, baseDados: base, miniaturaDados: miniatura, em: destino)
    }
    #expect(try itens(pasta).isEmpty)
}

@Test func atualizarComVersaoEsquemaDiferenteDaAtualLanca() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let destino = pasta.appendingPathComponent("a.capta")
    let original = documentoCompleto()
    try PacoteCapta.gravar(original, baseDados: base, miniaturaDados: miniatura, em: destino)
    var futuro = original
    futuro.versaoEsquema = 99
    #expect(throws: ErroDocumento.valorForaDeFaixa("versaoEsquema")) {
        try PacoteCapta.atualizar(futuro, miniaturaDados: nil, em: destino)
    }
    #expect(try PacoteCapta.ler(de: destino).documento == original)
}

/// Versão 0 ou negativa no disco: a decodificação valida o documento e propaga `ErroDocumento`.
@Test(arguments: [0, -1])
func lerVersaoEsquemaZeroOuNegativaLancaValorForaDeFaixa(versao: Int) throws {
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
        .replacingOccurrences(of: "\"versaoEsquema\" : 1", with: "\"versaoEsquema\" : \(versao)")
    try Data(texto.utf8).write(to: json)
    #expect(throws: ErroDocumento.valorForaDeFaixa("versaoEsquema")) {
        try PacoteCapta.ler(de: destino)
    }
}
