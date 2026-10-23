import Foundation
import Testing

@testable import Capta

@Suite("Ações da barra do editor")
@MainActor
struct AcoesDaBarraTests {
    /// Relógio de mentira: `dormir` só termina quando o teste libera.
    @MainActor
    final class Bancada {
        var alertas: [MensagemDeErro] = []
        var anuncios: [String] = []
        var dormidas = 0

        func acoes(dormir: @escaping @Sendable (Duration) async throws -> Void = { _ in })
            -> AcoesDaBarra
        {
            AcoesDaBarra(
                mostrarAlerta: { self.alertas.append($0) },
                anunciar: { self.anuncios.append($0) },
                dormir: dormir
            )
        }
    }

    @Test func concluidoConfirmaAnunciaEApagaDepoisDoTempo() async {
        let bancada = Bancada()
        let acoes = bancada.acoes()
        await acoes.executar(confirmacao: "Copiado") { .concluido }.value
        // O sono de mentira volta na hora: a limpeza roda e apaga a confirmação.
        await acoes.aguardarLimpeza()
        #expect(bancada.anuncios == ["Copiado"])
        #expect(acoes.confirmacao == nil)
    }

    @Test func confirmacaoFicaEnquantoOSonoNaoTermina() async throws {
        let bancada = Bancada()
        let (fluxo, continuacao) = AsyncStream<Void>.makeStream()
        let acoes = bancada.acoes(dormir: { _ in
            for await _ in fluxo { return }
        })
        await acoes.executar(confirmacao: "Salvo") { .concluido }.value
        #expect(acoes.confirmacao == "Salvo")
        continuacao.yield()
        await acoes.aguardarLimpeza()
        #expect(acoes.confirmacao == nil)
    }

    @Test func confirmacaoNovaSubstituiAAnteriorSemSerApagadaPelaVelha() async throws {
        let bancada = Bancada()
        let (fluxo, continuacao) = AsyncStream<Void>.makeStream()
        let acoes = bancada.acoes(dormir: { _ in
            for await _ in fluxo { return }
        })
        await acoes.executar(confirmacao: "Salvo") { .concluido }.value
        await acoes.executar(confirmacao: "Copiado") { .concluido }.value
        #expect(acoes.confirmacao == "Copiado")
        continuacao.yield()
        await acoes.aguardarLimpeza()
        #expect(acoes.confirmacao == nil)
    }

    @Test func canceladoNaoFazNada() async {
        let bancada = Bancada()
        let acoes = bancada.acoes()
        await acoes.executar(confirmacao: "Salvo") { .cancelado }.value
        #expect(acoes.confirmacao == nil)
        #expect(bancada.anuncios.isEmpty)
        #expect(bancada.alertas.isEmpty)
    }

    @Test func falhaChamaOAlertaSemConfirmar() async {
        let bancada = Bancada()
        let acoes = bancada.acoes()
        await acoes.executar(confirmacao: "Copiado") { .falhou(.naoFoiPossivelCopiar) }.value
        #expect(bancada.alertas == [.naoFoiPossivelCopiar])
        #expect(acoes.confirmacao == nil)
    }

    @Test func cancelarEncerraALimpezaPendente() async {
        let bancada = Bancada()
        let (fluxo, _) = AsyncStream<Void>.makeStream()
        let acoes = bancada.acoes(dormir: { _ in
            for await _ in fluxo { return }
            throw CancellationError()
        })
        await acoes.executar(confirmacao: "Salvo") { .concluido }.value
        acoes.cancelar()
        await acoes.aguardarLimpeza()
        // Cancelada, a limpeza não apaga: quem a cancelou está fechando a janela.
        #expect(acoes.confirmacao == "Salvo")
    }
}
