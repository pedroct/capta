import AppKit
import CaptaNucleo
import Testing

@testable import Capta

/// Devolver o foco ao app anterior (correção da revisão final do plano 3): `Esc` sempre devolve,
/// a confirmação só devolve com atraso, e sem app anterior não há nada a fazer.
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

    @MainActor
    private final class RegistroDeFoco {
        private(set) var chamadas: [(NSRunningApplication?, ResultadoDoOverlay)] = []
        func anotar(_ app: NSRunningApplication?, _ resultado: ResultadoDoOverlay) {
            chamadas.append((app, resultado))
        }
    }
}
