import CaptaNucleo
import Testing

@testable import Capta

/// Dublê de `AtalhoGlobal`: guarda a combinação pedida e pode falhar o registro.
private final class AtalhoFalso: AtalhoGlobal, @unchecked Sendable {
    var erro: ErroAtalho?
    private(set) var combinacoes: [CombinacaoDeTeclas] = []

    func registrar(_ combinacao: CombinacaoDeTeclas, acao: @escaping @Sendable () -> Void) throws {
        if let erro { throw erro }
        combinacoes.append(combinacao)
    }

    func liberar() {}
}

@MainActor
@Suite("Gerenciador do overlay")
struct GerenciadorDoOverlayTests {
    @Test func semSaidaGarantidaNaoAbre() {
        let atalho = AtalhoFalso()
        atalho.erro = .conflito
        let gerenciador = GerenciadorDoOverlay(atalhoDeEsc: atalho)
        var fechou = false

        let abriu = gerenciador.abrir(aoFechar: { fechou = true })

        #expect(!abriu)
        #expect(!gerenciador.aberto)
        #expect(!fechou)
    }

    @Test func fecharSemAbrirNaoFazNada() {
        let gerenciador = GerenciadorDoOverlay(atalhoDeEsc: AtalhoFalso())
        gerenciador.fechar()
        #expect(!gerenciador.aberto)
    }

    @Test func oEscGlobalUsaOCodigoDeTeclaDoEscape() {
        #expect(GerenciadorDoOverlay.codigoDoEsc == 53)
    }
}
