import AppKit
import CaptaNucleo
import Testing

@testable import Capta

/// Devolver o foco ao app anterior (correção da revisão final do plano 3): `Esc` sempre devolve,
/// a confirmação só devolve com atraso, e sem app anterior não há nada a fazer. Quando o
/// encerramento vem de fora (perda de ativação, mudança de telas), nunca devolve.
extension GerenciadorDoOverlayTests {
    @Test func devolveOFocoAoAppAnteriorQuandoCancela() async throws {
        let atalho = AtalhoFalso()
        let registro = RegistroDeFoco()
        let anterior = NSRunningApplication.current
        let g = GerenciadorDoOverlay(
            atalhoDeEsc: atalho,
            ativar: { nil },
            posicaoDoCursor: { CGPoint(x: 5, y: 5) },
            centro: centro,
            appAtivo: { true },
            appFrontmost: { anterior },
            devolverFoco: { app, resultado in registro.anotar(app, resultado) }
        )
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        g.aplicar(.tecla(.esc))
        let resultado = await tarefa.value

        #expect(resultado == .cancelado)
        #expect(registro.chamadas.count == 1)
        #expect(registro.chamadas.first?.0 === anterior)
        #expect(registro.chamadas.first?.1 == .cancelado)
    }

    @Test func devolveOFocoAoAppAnteriorQuandoConfirmaComAtraso() async throws {
        let atalho = AtalhoFalso()
        let registro = RegistroDeFoco()
        let anterior = NSRunningApplication.current
        let g = GerenciadorDoOverlay(
            atalhoDeEsc: atalho,
            ativar: { nil },
            posicaoDoCursor: { CGPoint(x: 5, y: 5) },
            centro: centro,
            appAtivo: { true },
            appFrontmost: { anterior },
            devolverFoco: { app, resultado in registro.anotar(app, resultado) }
        )
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        g.aplicar(.opcoesMudaram(OpcoesDeCaptura(atraso: .tres, incluirCursor: false)))
        g.aplicar(.tecla(.f))
        _ = await tarefa.value

        #expect(registro.chamadas.count == 1)
        #expect(registro.chamadas.first?.0 === anterior)
        guard case .confirmado(_, let opcoes) = registro.chamadas.first?.1 else {
            Issue.record("esperava um resultado confirmado")
            return
        }
        #expect(opcoes.atraso == .tres)
    }

    @Test func naoDevolveOFocoQuandoConfirmaSemAtraso() async throws {
        let atalho = AtalhoFalso()
        let registro = RegistroDeFoco()
        let g = GerenciadorDoOverlay(
            atalhoDeEsc: atalho,
            ativar: { nil },
            posicaoDoCursor: { CGPoint(x: 5, y: 5) },
            centro: centro,
            appAtivo: { true },
            appFrontmost: { NSRunningApplication.current },
            devolverFoco: { app, resultado in registro.anotar(app, resultado) }
        )
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        g.aplicar(.tecla(.f))
        _ = await tarefa.value

        #expect(registro.chamadas.isEmpty)
    }

    @Test func naoDevolveOFocoQuandoNaoHaviaAppAnterior() async throws {
        let atalho = AtalhoFalso()
        let registro = RegistroDeFoco()
        let g = GerenciadorDoOverlay(
            atalhoDeEsc: atalho,
            ativar: { nil },
            posicaoDoCursor: { CGPoint(x: 5, y: 5) },
            centro: centro,
            appAtivo: { true },
            appFrontmost: { nil },
            devolverFoco: { app, resultado in registro.anotar(app, resultado) }
        )
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        g.aplicar(.tecla(.esc))
        _ = await tarefa.value

        #expect(registro.chamadas.isEmpty)
    }

    /// Perder a ativação é o sistema ou o usuário levando o foco a outro app (por exemplo com
    /// `⌘Tab`); reativar o app de antes brigaria com essa escolha. Confirmado em tela real.
    @Test func naoDevolveOFocoQuandoPerdeAAtivacao() async throws {
        let registro = RegistroDeFoco()
        let g = gerenciadorComFoco(registro)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        centro.post(name: NSApplication.didResignActiveNotification, object: nil)

        #expect(await tarefa.value == .cancelado)
        #expect(registro.chamadas.isEmpty)
    }

    /// A mudança de telas também vem de fora: o app de antes guardado na abertura pode já não
    /// ser o que o usuário quer à frente.
    @Test func naoDevolveOFocoQuandoAsTelasMudam() async throws {
        let registro = RegistroDeFoco()
        let g = gerenciadorComFoco(registro)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        centro.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)

        #expect(await tarefa.value == .cancelado)
        #expect(registro.chamadas.isEmpty)
    }

    /// O `Esc` pelo atalho global (o Capta pode nem ter ficado ativo) é o mesmo `Esc`: devolve.
    @Test func devolveOFocoNoEscGlobal() async throws {
        let atalho = AtalhoFalso()
        let registro = RegistroDeFoco()
        let g = gerenciadorComFoco(registro, atalho: atalho)
        let tarefa = try await abrir(g, telas: [try Self.congelada(Self.telaA)])
        let escGlobal = try #require(atalho.acao)
        escGlobal()

        #expect(await tarefa.value == .cancelado)
        #expect(registro.chamadas.count == 1)
        // `NSRunningApplication.current` devolve um objeto novo a cada chamada: compara o PID.
        #expect(
            registro.chamadas.first?.0?.processIdentifier
                == NSRunningApplication.current.processIdentifier
        )
        #expect(registro.chamadas.first?.1 == .cancelado)
    }

    /// Só a perda de ativação e a mudança de telas vêm de fora; o texto do log não muda.
    @Test func motivoDoEncerramentoClassificaAOrigemEMantemOLog() {
        typealias Motivo = MotivoDoEncerramento
        let porEvento: [(EventoDoOverlay, Motivo)] = [
            (.tecla(.esc), .esc),
            (.tecla(.f), .confirmado),
            (.mouseSolto(.zero), .confirmado),
            (.telasMudaram, .telasMudaram),
            (.perdeuAtivacao, .perdeuAtivacao),
        ]
        for (evento, motivo) in porEvento { #expect(Motivo(de: evento) == motivo) }
        let externos: [Motivo] = [.telasMudaram, .perdeuAtivacao]
        let proprios: [Motivo] = [.esc, .confirmado, .tarefaCancelada, .semTelas]
        #expect(externos.allSatisfy { $0.origem == .externa })
        #expect(proprios.allSatisfy { $0.origem == .doProprioCapta })
        let logs = (proprios + externos).map(\.textoDoLog)
        #expect(
            logs == [
                "Esc", "confirmado", "tarefa cancelada", "sem telas", "telas mudaram",
                "perda de ativação",
            ]
        )
    }

    /// Fora o `Esc` e a confirmação com atraso, o foco fica onde está.
    @Test func soOProprioCaptaDevolveOFoco() {
        let comAtraso = ResultadoDoOverlay.confirmado(
            .janela(id: 1),
            OpcoesDeCaptura(atraso: .tres, incluirCursor: false)
        )
        let semAtraso = ResultadoDoOverlay.confirmado(.janela(id: 1), Self.opcoes)
        #expect(MotivoDoEncerramento.esc.devolveOFoco(com: .cancelado))
        #expect(MotivoDoEncerramento.confirmado.devolveOFoco(com: comAtraso))
        #expect(!MotivoDoEncerramento.confirmado.devolveOFoco(com: semAtraso))
        for externo in [MotivoDoEncerramento.telasMudaram, .perdeuAtivacao] {
            #expect(!externo.devolveOFoco(com: .cancelado))
            #expect(!externo.devolveOFoco(com: comAtraso))
        }
    }

    private func gerenciadorComFoco(
        _ registro: RegistroDeFoco,
        atalho: AtalhoFalso = AtalhoFalso()
    ) -> GerenciadorDoOverlay {
        GerenciadorDoOverlay(
            atalhoDeEsc: atalho,
            ativar: { nil },
            posicaoDoCursor: { CGPoint(x: 5, y: 5) },
            centro: centro,
            appAtivo: { true },
            appFrontmost: { NSRunningApplication.current },
            devolverFoco: { app, resultado in registro.anotar(app, resultado) }
        )
    }

    @MainActor
    private final class RegistroDeFoco {
        private(set) var chamadas: [(NSRunningApplication?, ResultadoDoOverlay)] = []
        func anotar(_ app: NSRunningApplication?, _ resultado: ResultadoDoOverlay) {
            chamadas.append((app, resultado))
        }
    }
}
