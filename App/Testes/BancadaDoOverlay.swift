import AppKit
import CaptaNucleo
import Testing

@testable import Capta

/// Dublê de `AtalhoGlobal`: guarda as combinações pedidas, a última ação e conta as liberações.
final class AtalhoFalso: AtalhoGlobal, @unchecked Sendable {
    var erro: ErroAtalho?
    private(set) var combinacoes: [CombinacaoDeTeclas] = []
    private(set) var liberacoes = 0
    private(set) var acao: (@Sendable () -> Void)?

    func registrar(_ combinacao: CombinacaoDeTeclas, acao: @escaping @Sendable () -> Void) throws {
        if let erro { throw erro }
        combinacoes.append(combinacao)
        self.acao = acao
    }

    func liberar() { liberacoes += 1 }
}

/// Como o overlay termina, para os testes que percorrem toda saída.
enum SaidaDoOverlay: CaseIterable, Sendable {
    case escLocal, escGlobal, telasMudaram, perdeuAtivacao, confirmou, tarefaCancelada
}

/// Telas falsas e ajudantes comuns às suítes do gerenciador do overlay.
@MainActor
protocol BancadaDoOverlay {
    /// Centro de notificações próprio, para não mexer no do app que hospeda os testes.
    var centro: NotificationCenter { get }
}

extension BancadaDoOverlay {
    static var telaA: DescricaoDeTela {
        DescricaoDeTela(
            id: 1,
            quadro: CGRect(x: 0, y: 0, width: 40, height: 30),
            escala: 1,
            principal: true
        )
    }
    static var telaB: DescricaoDeTela {
        DescricaoDeTela(
            id: 2,
            quadro: CGRect(x: 40, y: 0, width: 20, height: 30),
            escala: 2,
            principal: false
        )
    }
    static var opcoes: OpcoesDeCaptura {
        OpcoesDeCaptura(atraso: .nenhum, incluirCursor: false)
    }

    static func congelada(_ descricao: DescricaoDeTela) throws -> TelaCongelada {
        TelaCongelada(
            descricao: descricao,
            imagem: try imagemDeTeste(
                largura: Int(descricao.quadro.width * descricao.escala),
                altura: Int(descricao.quadro.height * descricao.escala)
            )
        )
    }

    func gerenciador(
        _ atalho: AtalhoFalso,
        cursor: CGPoint = CGPoint(x: 5, y: 5),
        ativo: Bool = true,
        criarJanela: GerenciadorDoOverlay.CriarJanela? = nil
    ) -> GerenciadorDoOverlay {
        if let criarJanela {
            return GerenciadorDoOverlay(
                atalhoDeEsc: atalho,
                criarJanela: criarJanela,
                ativar: { nil },
                posicaoDoCursor: { cursor },
                centro: centro,
                appAtivo: { ativo }
            )
        }
        return GerenciadorDoOverlay(
            atalhoDeEsc: atalho,
            ativar: { nil },
            posicaoDoCursor: { cursor },
            centro: centro,
            appAtivo: { ativo }
        )
    }

    /// Chama `escolher` numa tarefa e espera o overlay abrir.
    func abrir(
        _ g: GerenciadorDoOverlay,
        telas: [TelaCongelada],
        janelas: [JanelaDeTela] = [],
        modo: ModoDoOverlay = .regiao
    ) async throws -> Task<ResultadoDoOverlay, Never> {
        let tarefa = Task {
            await g.escolher(
                telas: telas,
                janelas: janelas,
                modo: modo,
                opcoes: Self.opcoes,
                ajudaVisivel: true
            )
        }
        for _ in 0..<1000 where !g.aberto { await Task.yield() }
        try #require(g.aberto)
        return tarefa
    }

    /// Conferências comuns a toda saída: nada aberto e o Esc liberado uma vez.
    func confereFechado(
        _ g: GerenciadorDoOverlay,
        _ atalho: AtalhoFalso,
        janelas: [NSWindow]
    ) {
        #expect(!g.aberto)
        #expect(g.janelasAbertas.isEmpty)
        #expect(g.estado == nil)
        #expect(janelas.allSatisfy { !$0.isVisible })
        #expect(atalho.liberacoes == 1)
    }

    static func tecla(
        codigo: UInt16,
        caracteres: String,
        modificadores: NSEvent.ModifierFlags = []
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modificadores,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: caracteres,
            charactersIgnoringModifiers: caracteres,
            isARepeat: false,
            keyCode: codigo
        )
    }
}
