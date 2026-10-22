import Foundation
import Testing

@testable import CaptaNucleo

// A v2 só congela no fim do Plano 5c (spec §4.9). Até lá, quem acrescenta campo ao esquema
// atualiza `jsonEsquemaV2DeReferencia` no mesmo commit.
@Suite("Esquema v2")
struct EsquemaV2Tests {
    @Test func documentoCompletoTemJsonDeReferenciaV2() throws {
        let documento = try EsquemaV1CongeladoTests.documentoCompleto()
        let dados = try EsquemaV1CongeladoTests.codificador().encode(documento)
        let texto = try #require(String(data: dados, encoding: .utf8))
        #expect(texto == jsonEsquemaV2DeReferencia)
    }

    @Test func jsonV2DecodificaDeVolta() throws {
        let decodificado = try JSONDecoder().decode(
            Documento.self,
            from: Data(jsonEsquemaV2DeReferencia.utf8)
        )
        #expect(decodificado == (try EsquemaV1CongeladoTests.documentoCompleto()))
    }
}
