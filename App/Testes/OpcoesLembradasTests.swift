import CaptaNucleo
import Foundation
import Testing

@testable import Capta

@Suite("Opções lembradas")
struct OpcoesLembradasTests {
    /// `UserDefaults` isolado e limpo ao fim de cada teste.
    private static func comDefaults(_ corpo: (UserDefaults, String) throws -> Void) throws {
        let nome = "capta.testes.opcoes.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: nome))
        defer { defaults.removePersistentDomain(forName: nome) }
        try corpo(defaults, nome)
    }

    @Test func padroesSemNadaGravado() throws {
        try Self.comDefaults { defaults, _ in
            let lembradas = OpcoesLembradas(defaults: defaults)
            #expect(lembradas.opcoes == OpcoesDeCaptura(atraso: .nenhum, incluirCursor: false))
            #expect(lembradas.ajudaVisivel)
        }
    }

    @Test func gravaELeAtrasoECursorEntreInstancias() throws {
        try Self.comDefaults { defaults, _ in
            OpcoesLembradas(defaults: defaults).opcoes =
                OpcoesDeCaptura(atraso: .cinco, incluirCursor: true)
            let outra = OpcoesLembradas(defaults: defaults)
            #expect(outra.opcoes == OpcoesDeCaptura(atraso: .cinco, incluirCursor: true))
        }
    }

    @Test func atrasoInvalidoVoltaAoPadrao() throws {
        try Self.comDefaults { defaults, _ in
            defaults.set(7, forKey: "atraso")
            defaults.set(true, forKey: "incluirCursor")
            let lembradas = OpcoesLembradas(defaults: defaults)
            #expect(lembradas.opcoes == OpcoesDeCaptura(atraso: .nenhum, incluirCursor: true))
        }
    }

    @Test func incluirCursorFicaGuardadoComAtrasoNenhum() throws {
        try Self.comDefaults { defaults, _ in
            let lembradas = OpcoesLembradas(defaults: defaults)
            lembradas.opcoes = OpcoesDeCaptura(atraso: .nenhum, incluirCursor: true)
            #expect(defaults.bool(forKey: "incluirCursor"))
            #expect(lembradas.opcoes.incluirCursor)
        }
    }

    @Test func ajudaVisivelPadraoVerdadeiroELembraAEscolha() throws {
        try Self.comDefaults { defaults, _ in
            let lembradas = OpcoesLembradas(defaults: defaults)
            #expect(lembradas.ajudaVisivel)
            lembradas.ajudaVisivel = false
            #expect(!OpcoesLembradas(defaults: defaults).ajudaVisivel)
            lembradas.ajudaVisivel = true
            #expect(OpcoesLembradas(defaults: defaults).ajudaVisivel)
        }
    }
}
