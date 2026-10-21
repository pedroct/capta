import CaptaNucleo
import Testing

@testable import CaptaSistema

@Suite("Máscara de modificadores do Carbon")
struct CombinacaoDeTeclasCarbonTests {
    @Test func mascaraCarbonSomaOsModificadores() {
        #expect(Modificadores([.controle, .opcao]).mascaraCarbon == (4096 | 2048))
        #expect(Modificadores.comando.mascaraCarbon == 256)
        #expect(Modificadores.shift.mascaraCarbon == 512)
        #expect(
            Modificadores([.controle, .opcao, .comando, .shift]).mascaraCarbon == 4096 | 2048 | 256
                | 512
        )
    }

    @Test func mascaraVaziaEZero() {
        #expect(Modificadores([]).mascaraCarbon == 0)
    }
}
