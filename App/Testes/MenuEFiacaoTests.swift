import CaptaNucleo
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

@MainActor
struct RecentesDoMenuTests {
    private func pacote(_ nome: String, em pasta: URL, modificadoEm data: Date) throws {
        let imagem = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        let url = try Rascunho.gravar(
            imagem,
            documento: try Documento.novo(de: imagem),
            em: pasta,
            nome: nome
        )
        try FileManager.default.setAttributes(
            [.modificationDate: data],
            ofItemAtPath: url.appendingPathComponent("documento.json").path
        )
    }

    @Test func comecaSemRecentes() {
        #expect(EstadoDoMenu().recentes.isEmpty)
    }

    @Test func atualizarRecentesPreencheOEstadoDoMaisNovoParaOMaisAntigo() throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        try pacote("antiga", em: pasta.url, modificadoEm: Date(timeIntervalSince1970: 1_000))
        try pacote("nova", em: pasta.url, modificadoEm: Date(timeIntervalSince1970: 2_000))
        let estado = EstadoDoMenu()

        estado.atualizarRecentes(em: pasta.url)

        #expect(estado.recentes.map(\.nome) == ["nova", "antiga"])
    }

    @Test func atualizarRecentesRefleteOQueMudouNoDisco() throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let estado = EstadoDoMenu()
        estado.atualizarRecentes(em: pasta.url)
        #expect(estado.recentes.isEmpty)

        try pacote("uma", em: pasta.url, modificadoEm: Date(timeIntervalSince1970: 1_000))
        estado.atualizarRecentes(em: pasta.url)
        #expect(estado.recentes.map(\.nome) == ["uma"])

        try FileManager.default.removeItem(at: try #require(estado.recentes.first).url)
        estado.atualizarRecentes(em: pasta.url)
        #expect(estado.recentes.isEmpty)
    }

    @Test func atualizarRecentesDePastaInexistenteEsvaziaALista() throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        try pacote("uma", em: pasta.url, modificadoEm: Date(timeIntervalSince1970: 1_000))
        let estado = EstadoDoMenu()
        estado.atualizarRecentes(em: pasta.url)
        #expect(estado.recentes.count == 1)

        estado.atualizarRecentes(em: pasta.url.appendingPathComponent("nao-existe"))

        #expect(estado.recentes.isEmpty)
    }

    @Test func atualizarRecentesDePastaIlegivelEsvaziaALista() throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        // Um arquivo no lugar da pasta: existe, mas não pode ser listado.
        let arquivo = pasta.url.appendingPathComponent("arquivo")
        try Data([1]).write(to: arquivo)
        let estado = EstadoDoMenu()

        estado.atualizarRecentes(em: arquivo)

        #expect(estado.recentes.isEmpty)
    }
}
