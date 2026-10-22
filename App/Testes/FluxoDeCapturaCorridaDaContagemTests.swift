import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

/// Corrida estreita da correção da revisão final do plano 3: o `Esc` chega bem quando a última
/// pausa de 1 s da contagem termina normalmente.
extension FluxoDeCapturaTests {
    // `ContagemRegressiva.executar` não torna a conferir `Task.isCancelled` depois da última
    // pausa, então `tarefaDaContagem?.cancel()` sozinho não bastaria: a captura ao vivo
    // aconteceria mesmo cancelada. A marca `contagemCancelada` cobre essa corrida.
    @Test(.timeLimit(.minutes(1))) func cancelarNoInstanteExatoDoFimDaContagemNaoCaptura()
        async throws
    {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        let apresentador = ApresentadorFalso()
        let contagem = ContagemFalsa()
        let caixa = CaixaDoFluxo()
        let fluxoCriado = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: SeletorFalso(.confirmado(Self.regiao, Self.opcoes(.tres))),
            contagem: contagem,
            defaults: temporarios.defaults,
            pausa: { _ in
                if caixa.proximaChamada() == 3 {
                    await caixa.fluxo?.cancelarContagem()
                }
            }
        )
        caixa.fluxo = fluxoCriado

        await fluxoCriado.capturarLivre(modo: .regiao)

        #expect(await capturador.chamadasDeRegiao.isEmpty)
        #expect(apresentador.capturas.isEmpty)
        #expect(apresentador.alertas.isEmpty)
        #expect(fluxoCriado.gravacaoDoRascunho == nil)
    }
}
