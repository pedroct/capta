import Foundation
import Testing

@testable import CaptaNucleo

@Suite("Capturas recentes")
struct CapturasRecentesTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func pastaTemporaria() throws -> URL {
        let pasta = FileManager.default.temporaryDirectory
            .appendingPathComponent("capturas-recentes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        return pasta
    }

    @discardableResult
    private func criarPacote(
        _ nome: String,
        em pasta: URL,
        segundos: TimeInterval = 0,
        comDocumento: Bool = true
    ) throws -> URL {
        let pacote = pasta.appendingPathComponent(nome, isDirectory: true)
        try FileManager.default.createDirectory(at: pacote, withIntermediateDirectories: true)
        if comDocumento {
            let json = pacote.appendingPathComponent("documento.json")
            try Data("{}".utf8).write(to: json)
            try FileManager.default.setAttributes(
                [.modificationDate: base.addingTimeInterval(segundos)],
                ofItemAtPath: json.path
            )
        }
        return pacote
    }

    @Test func listaOsMaisRecentesPrimeiro() throws {
        let pasta = try pastaTemporaria()
        try criarPacote("A.capta", em: pasta, segundos: 10)
        try criarPacote("B.capta", em: pasta, segundos: 30)
        try criarPacote("C.capta", em: pasta, segundos: 20)
        let lista = try CapturasRecentes.listar(em: pasta)
        #expect(lista.map(\.nome) == ["B", "C", "A"])
        #expect(lista[0].modificadaEm == base.addingTimeInterval(30))
        #expect(lista[0].url.lastPathComponent == "B.capta")
    }

    @Test func respeitaOLimite() throws {
        let pasta = try pastaTemporaria()
        for i in 0..<12 { try criarPacote("P\(i).capta", em: pasta, segundos: Double(i)) }
        #expect(try CapturasRecentes.listar(em: pasta).count == 10)
        #expect(try CapturasRecentes.listar(em: pasta, limite: 3).count == 3)
    }

    @Test func ignoraOcultosETemporarios() throws {
        let pasta = try pastaTemporaria()
        try criarPacote("Boa.capta", em: pasta)
        try criarPacote(".Captura x.capta.tmp-\(UUID().uuidString)", em: pasta)
        try criarPacote(".oculto.capta", em: pasta)
        #expect(try CapturasRecentes.listar(em: pasta).map(\.nome) == ["Boa"])
    }

    @Test func ignoraOQueNaoECapta() throws {
        let pasta = try pastaTemporaria()
        try criarPacote("Boa.capta", em: pasta)
        try criarPacote("x", em: pasta)
        try Data().write(to: pasta.appendingPathComponent("y.capta"))
        #expect(try CapturasRecentes.listar(em: pasta).map(\.nome) == ["Boa"])
    }

    @Test func pacoteSemDocumentoFicaDeFora() throws {
        let pasta = try pastaTemporaria()
        try criarPacote("Boa.capta", em: pasta)
        try criarPacote("Vazio.capta", em: pasta, comDocumento: false)
        #expect(try CapturasRecentes.listar(em: pasta).map(\.nome) == ["Boa"])
    }

    @Test func pastaInexistenteDevolveVazio() throws {
        let pasta = FileManager.default.temporaryDirectory
            .appendingPathComponent("nao-existe-\(UUID().uuidString)")
        #expect(try CapturasRecentes.listar(em: pasta).isEmpty)
    }

    @Test func empateOrdenaPeloNome() throws {
        let pasta = try pastaTemporaria()
        try criarPacote("Zeta.capta", em: pasta, segundos: 5)
        try criarPacote("Alfa.capta", em: pasta, segundos: 5)
        #expect(try CapturasRecentes.listar(em: pasta).map(\.nome) == ["Alfa", "Zeta"])
    }
}
