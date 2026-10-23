import AppKit
import Testing

@testable import Capta

@Suite("Delegado do app")
@MainActor
struct DelegadoDoAppTests {
    @Test func encerrarSoRespondeDepoisDeSalvarTudo() async {
        let portao = Portao()
        let respostas = RespostasDeEncerramento()
        let delegado = DelegadoDoApp()
        delegado.salvarTodas = { await portao.esperar() }
        delegado.responder = { respostas.registrar($0) }

        let resposta = delegado.applicationShouldTerminate(NSApplication.shared)

        #expect(resposta == .terminateLater)
        for _ in 0..<200 { await Task.yield() }
        #expect(respostas.valores.isEmpty)

        await portao.abrir()
        await delegado.encerramento?.value

        #expect(respostas.valores == [true])
    }

    @Test func semGerenciadorEncerraDireto() async {
        let respostas = RespostasDeEncerramento()
        let delegado = DelegadoDoApp()
        delegado.responder = { respostas.registrar($0) }

        _ = delegado.applicationShouldTerminate(NSApplication.shared)
        await delegado.encerramento?.value

        #expect(respostas.valores == [true])
    }
}

@MainActor
final class RespostasDeEncerramento {
    private(set) var valores: [Bool] = []
    func registrar(_ valor: Bool) { valores.append(valor) }
}
