import CaptaNucleo
import Foundation
import Testing

@testable import Capta

@Suite("Memória de estilos lembrada")
@MainActor
struct MemoriaLembradaTests {
    private static func comDefaults(_ corpo: (UserDefaults) throws -> Void) throws {
        let nome = "capta.testes.memoria.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: nome))
        defer { defaults.removePersistentDomain(forName: nome) }
        try corpo(defaults)
    }

    @Test func semValorDevolvePadrao() throws {
        try Self.comDefaults { defaults in
            #expect(MemoriaLembrada(defaults: defaults).memoria == .padrao)
        }
    }

    @Test func valorIlegivelDevolvePadrao() throws {
        try Self.comDefaults { defaults in
            defaults.set(Data("isto não é JSON".utf8), forKey: "editor.memoriaDeEstilos")
            #expect(MemoriaLembrada(defaults: defaults).memoria == .padrao)
        }
    }

    @Test func gravaEle() throws {
        try Self.comDefaults { defaults in
            var memoria = MemoriaDeEstilos.padrao
            memoria[.seta].largura = 11
            MemoriaLembrada(defaults: defaults).memoria = memoria
            #expect(MemoriaLembrada(defaults: defaults).memoria[.seta].largura == 11)
        }
    }
}
