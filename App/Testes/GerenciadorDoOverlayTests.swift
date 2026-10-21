import AppKit
import CaptaNucleo
import Testing

@testable import Capta

/// Dublê de `AtalhoGlobal`: guarda as combinações pedidas e conta as liberações.
private final class AtalhoFalso: AtalhoGlobal, @unchecked Sendable {
    var erro: ErroAtalho?
    private(set) var combinacoes: [CombinacaoDeTeclas] = []
    private(set) var liberacoes = 0

    func registrar(_ combinacao: CombinacaoDeTeclas, acao: @escaping @Sendable () -> Void) throws {
        if let erro { throw erro }
        combinacoes.append(combinacao)
    }

    func liberar() { liberacoes += 1 }
}

@MainActor
@Suite("Gerenciador do overlay")
struct GerenciadorDoOverlayTests {
    private static func janelaFalsa() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
    }

    private func gerenciador(
        _ atalho: AtalhoFalso,
        janelas: @escaping @MainActor () -> [NSWindow]
    ) -> GerenciadorDoOverlay {
        GerenciadorDoOverlay(atalhoDeEsc: atalho, criarJanelas: janelas, ativar: { nil })
    }

    @Test func abrirRegistraOEscSemModificadores() {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho) { [Self.janelaFalsa()] }
        let abriu = g.abrir(aoFechar: {})
        #expect(abriu)
        #expect(atalho.combinacoes == [CombinacaoDeTeclas(codigoDaTecla: 53, modificadores: [])])
        #expect(g.aberto)
        g.fechar()
    }

    @Test func fecharLiberaUmaVezEChamaOCallback() {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho) { [Self.janelaFalsa()] }
        var fechou = 0
        g.abrir(aoFechar: { fechou += 1 })
        g.fechar()
        #expect(atalho.liberacoes == 1)
        #expect(fechou == 1)
        #expect(!g.aberto)
    }

    @Test func fecharDuasVezesLiberaUmaVez() {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho) { [Self.janelaFalsa()] }
        g.abrir(aoFechar: {})
        g.fechar()
        g.fechar()
        #expect(atalho.liberacoes == 1)
    }

    @Test func semTelasNaoDeixaEscRegistrado() {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho) { [] }
        var fechou = false
        let abriu = g.abrir(aoFechar: { fechou = true })
        #expect(!abriu)
        #expect(atalho.liberacoes == atalho.combinacoes.count)
        #expect(!g.aberto)
        #expect(!fechou)
        // Um novo ciclo não duplica o registro.
        g.fechar()
        #expect(atalho.liberacoes == 1)
    }

    @Test func falhaDeRegistroNaoCriaJanelas() {
        let atalho = AtalhoFalso()
        atalho.erro = .conflito
        var criou = false
        let g = gerenciador(atalho) {
            criou = true
            return [Self.janelaFalsa()]
        }
        var fechou = false
        let abriu = g.abrir(aoFechar: { fechou = true })
        #expect(!abriu)
        #expect(!criou)
        #expect(!g.aberto)
        #expect(!fechou)
        #expect(atalho.liberacoes == 0)
    }

    @Test func oEscGlobalUsaOCodigoDeTeclaDoEscape() {
        #expect(GerenciadorDoOverlay.codigoDoEsc == 53)
    }
}
