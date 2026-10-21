import Foundation
import Testing

@testable import Capta

@MainActor
struct MenuEFiacaoTests {
    @Test func estadoDoMenuMarcaCadaAtalhoIndisponivelSeparadamente() {
        let estado = EstadoDoMenu()
        #expect(!estado.atalhoDeTelaInteiraIndisponivel)
        #expect(!estado.atalhoDeCapturaLivreIndisponivel)
        estado.atalhoDeCapturaLivreIndisponivel = true
        #expect(estado.atalhoDeCapturaLivreIndisponivel)
        #expect(!estado.atalhoDeTelaInteiraIndisponivel)
        estado.atalhoDeCapturaLivreIndisponivel = false
        estado.atalhoDeTelaInteiraIndisponivel = true
        #expect(estado.atalhoDeTelaInteiraIndisponivel)
        #expect(!estado.atalhoDeCapturaLivreIndisponivel)
    }

    @Test func gravarAjudaPersisteAEscolhaDaAjudaNasOpcoesLembradas() throws {
        let nome = "MenuEFiacaoTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: nome))
        defer { defaults.removePersistentDomain(forName: nome) }
        let opcoes = OpcoesLembradas(defaults: defaults)
        #expect(opcoes.ajudaVisivel)
        opcoes.gravarAjuda(false)
        #expect(!OpcoesLembradas(defaults: defaults).ajudaVisivel)
        opcoes.gravarAjuda(true)
        #expect(OpcoesLembradas(defaults: defaults).ajudaVisivel)
    }
}
