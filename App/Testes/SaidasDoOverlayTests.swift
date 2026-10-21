import AppKit
import CaptaNucleo
import Testing

@testable import Capta

@MainActor
@Suite("Saídas do overlay", .serialized)
struct SaidasDoOverlayTests: BancadaDoOverlay {
    let centro = NotificationCenter()

    @Test func escCancelaEFecha() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        let janelas = g.janelasAbertas
        g.aplicar(.tecla(.esc))
        #expect(await tarefa.value == .cancelado)
        confereFechado(g, atalho, janelas: janelas)
    }

    @Test func escGlobalCancelaEFecha() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        let janelas = g.janelasAbertas
        let escGlobal = try #require(atalho.acao)
        escGlobal()
        #expect(await tarefa.value == .cancelado)
        confereFechado(g, atalho, janelas: janelas)
    }

    @Test func telasMudaremCancela() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        let janelas = g.janelasAbertas
        centro.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(await tarefa.value == .cancelado)
        confereFechado(g, atalho, janelas: janelas)
    }

    @Test func perderAAtivacaoCancela() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho, ativo: true)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        let janelas = g.janelasAbertas
        centro.post(name: NSApplication.didResignActiveNotification, object: nil)
        #expect(await tarefa.value == .cancelado)
        confereFechado(g, atalho, janelas: janelas)
    }

    @Test func perdaDeAtivacaoSoValeDepoisDeOAppFicarAtivo() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho, ativo: false)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        centro.post(name: NSApplication.didResignActiveNotification, object: nil)
        #expect(g.aberto)
        centro.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        #expect(g.aberto)
        centro.post(name: NSApplication.didResignActiveNotification, object: nil)
        #expect(await tarefa.value == .cancelado)
        #expect(atalho.liberacoes == 1)
    }

    // MARK: - Esc global e saídas

    @Test func abrirRegistraOEscSemModificadores() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        #expect(atalho.combinacoes == [CombinacaoDeTeclas(codigoDaTecla: 53, modificadores: [])])
        g.aplicar(.tecla(.esc))
        _ = await tarefa.value
    }

    @Test func falhaDoRegistroDoEscDevolveCanceladoSemJanelas() async {
        let atalho = AtalhoFalso()
        atalho.erro = .conflito
        var criou = false
        let g = gerenciador(atalho) { _, _ in
            criou = true
            return NSWindow()
        }
        let resultado = await g.escolher(
            telas: [],
            janelas: [],
            modo: .regiao,
            opcoes: Self.opcoes,
            ajudaVisivel: true
        )
        #expect(resultado == .cancelado)
        #expect(!criou)
        #expect(!g.aberto)
        #expect(atalho.liberacoes == 0)
    }

    @Test func semTelasDevolveCanceladoELiberaOEsc() async {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let resultado = await g.escolher(
            telas: [],
            janelas: [],
            modo: .regiao,
            opcoes: Self.opcoes,
            ajudaVisivel: true
        )
        #expect(resultado == .cancelado)
        #expect(!g.aberto)
        #expect(atalho.liberacoes == 1)
    }

    @Test func disparoComOverlayAbertoEIgnorado() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let tela = try Self.congelada(Self.telaA)
        let tarefa = try await abrir(g, telas: [tela])
        let janelas = g.janelasAbertas
        let segundo = await g.escolher(
            telas: [tela],
            janelas: [],
            modo: .regiao,
            opcoes: Self.opcoes,
            ajudaVisivel: true
        )
        #expect(segundo == .cancelado)
        #expect(g.aberto)
        #expect(g.janelasAbertas.count == janelas.count)
        #expect(atalho.combinacoes.count == 1)
        g.aplicar(.tecla(.esc))
        #expect(await tarefa.value == .cancelado)
    }

    /// Toda saída devolve um resultado só e libera o Esc uma vez, mesmo com mais gatilhos
    /// chegando depois (uma continuação retomada duas vezes derrubaria o processo).
    @Test(arguments: SaidaDoOverlay.allCases)
    func todaSaidaRetomaUmaVezELiberaOEscUmaVez(saida: SaidaDoOverlay) async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        let janelas = g.janelasAbertas
        let escGlobal = try #require(atalho.acao)
        func disparar(_ saida: SaidaDoOverlay) {
            switch saida {
            case .escLocal: g.aplicar(.tecla(.esc))
            case .escGlobal: escGlobal()
            case .telasMudaram:
                centro.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            case .perdeuAtivacao:
                centro.post(name: NSApplication.didResignActiveNotification, object: nil)
            case .confirmou: g.aplicar(.tecla(.f))
            case .tarefaCancelada: tarefa.cancel()
            }
        }
        disparar(saida)
        let resultado = await tarefa.value
        if saida == .confirmou {
            #expect(resultado != .cancelado)
        } else {
            #expect(resultado == .cancelado)
        }
        for outra in SaidaDoOverlay.allCases { disparar(outra) }
        for _ in 0..<20 { await Task.yield() }
        confereFechado(g, atalho, janelas: janelas)
    }

    @Test func escGlobalAtrasadoNaoFechaOOverlaySeguinte() async throws {
        let atalho = AtalhoFalso()
        let g = gerenciador(atalho)
        let tela = try Self.congelada(Self.telaA)
        let primeira = try await abrir(g, telas: [tela])
        let escAntigo = try #require(atalho.acao)
        g.aplicar(.tecla(.esc))
        _ = await primeira.value

        let segunda = try await abrir(g, telas: [tela])
        escAntigo()
        for _ in 0..<20 { await Task.yield() }
        #expect(g.aberto)
        g.aplicar(.tecla(.esc))
        #expect(await segunda.value == .cancelado)
        #expect(atalho.liberacoes == 2)
    }

    @Test func eventoSemOverlayAbertoEIgnorado() {
        let g = gerenciador(AtalhoFalso())
        g.aplicar(.tecla(.esc))
        #expect(!g.aberto)
        #expect(g.estado == nil)
    }
}
