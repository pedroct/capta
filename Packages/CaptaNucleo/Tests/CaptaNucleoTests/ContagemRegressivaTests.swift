import Foundation
import Testing

@testable import CaptaNucleo

/// Registra, de forma segura para concorrência, o que a contagem fez.
private final class Registro: @unchecked Sendable {
    private let trava = NSLock()
    private var _valores: [Int] = []
    private var _pausas: [Duration] = []

    var valores: [Int] { trava.withLock { _valores } }
    var pausas: [Duration] { trava.withLock { _pausas } }
    func valor(_ n: Int) { trava.withLock { _valores.append(n) } }
    func pausa(_ d: Duration) -> Int {
        trava.withLock {
            _pausas.append(d); return _pausas.count
        }
    }
}

@Suite("ContagemRegressiva")
struct ContagemRegressivaTests {
    @Test func atrasoTemOsValoresDoProduto() {
        #expect(Atraso.allCases.map(\.rawValue) == [0, 3, 5, 10])
    }

    @Test func contaDeNAUmEDevolveTrue() async {
        let r = Registro()
        let contagem = ContagemRegressiva(segundos: 3, pausa: { d in _ = r.pausa(d) })
        let fim = await contagem.executar { r.valor($0) }
        #expect(fim)
        #expect(r.valores == [3, 2, 1])
        #expect(r.pausas == [.seconds(1), .seconds(1), .seconds(1)])
    }

    @Test func cancelarNoMeioDevolveFalseESeParaDeChamar() async {
        let r = Registro()
        let contagem = ContagemRegressiva(
            segundos: 3,
            pausa: { d in
                if r.pausa(d) == 2 { throw CancellationError() }
            }
        )
        let tarefa = Task { await contagem.executar { r.valor($0) } }
        let fim = await tarefa.value
        #expect(!fim)
        #expect(r.valores == [3, 2])
    }

    @Test func cancelarATaskDevolveFalse() async {
        let r = Registro()
        let tarefa = Task {
            await ContagemRegressiva(segundos: 3).executar { r.valor($0) }
        }
        tarefa.cancel()
        let fim = await tarefa.value
        #expect(!fim)
        #expect(r.valores.count <= 1)
    }

    @Test func zeroSegundosDevolveTrueSemChamar() async {
        let r = Registro()
        let contagem = ContagemRegressiva(segundos: 0, pausa: { d in _ = r.pausa(d) })
        let fim = await contagem.executar { r.valor($0) }
        #expect(fim)
        #expect(r.valores.isEmpty)
        #expect(r.pausas.isEmpty)
    }

    @Test func segundosNegativosSeComportamComoZero() async {
        let r = Registro()
        let fim = await ContagemRegressiva(segundos: -2, pausa: { _ in }).executar { r.valor($0) }
        #expect(fim)
        #expect(r.valores.isEmpty)
    }
}
