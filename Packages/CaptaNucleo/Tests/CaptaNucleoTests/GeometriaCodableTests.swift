import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private let todasAsGeometrias: [Geometria] = [
    .seta(inicio: CGPoint(x: 1, y: 2), fim: CGPoint(x: 3, y: 4)),
    .linha(inicio: CGPoint(x: 5, y: 6), fim: CGPoint(x: 7, y: 8)),
    .forma(.elipse, CGRect(x: 1, y: 2, width: 30, height: 40)),
    .texto(
        CGRect(x: 1, y: 2, width: 30, height: 40),
        conteudo: "Olá",
        tamanhoFonte: 24,
        negrito: true,
        italico: false
    ),
    .etapa(centro: CGPoint(x: 9, y: 10), diametro: 32, reiniciaSequencia: true),
    .carimbo(CGRect(x: 1, y: 2, width: 30, height: 40), simbolo: "star"),
    .realce(CGRect(x: 1, y: 2, width: 30, height: 40)),
    .desfoque(CGRect(x: 1, y: 2, width: 30, height: 40), .pixelizar, intensidade: 12),
]

private func decodificar(_ json: String) throws -> Geometria {
    try JSONDecoder().decode(Geometria.self, from: Data(json.utf8))
}

@Suite("Codable explícito da geometria")
struct GeometriaCodableTests {
    @Test(arguments: todasAsGeometrias)
    func cadaTipoFazIdaEVolta(geometria: Geometria) throws {
        let dados = try JSONEncoder().encode(geometria)
        #expect(try JSONDecoder().decode(Geometria.self, from: dados) == geometria)
    }

    @Test func retanguloInvertidoFazIdaEVoltaSemNormalizar() throws {
        let invertido = Geometria.realce(CGRect(x: 50, y: 60, width: -20, height: -30))
        let dados = try JSONEncoder().encode(invertido)
        let volta = try JSONDecoder().decode(Geometria.self, from: dados)
        #expect(volta == invertido)
        guard case .realce(let retangulo) = volta else {
            Issue.record("tipo inesperado")
            return
        }
        #expect(retangulo.size.width == -20)
        #expect(retangulo.size.height == -30)
    }

    @Test func jsonDeSetaTemChavesEstaveis() throws {
        let literal = #"{"tipo":"seta","inicio":{"x":1,"y":2},"fim":{"x":3,"y":4}}"#
        let geometria = try decodificar(literal)
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.sortedKeys]
        let texto = try #require(
            String(bytes: try codificador.encode(geometria), encoding: .utf8)
        )
        #expect(texto == #"{"fim":{"x":3,"y":4},"inicio":{"x":1,"y":2},"tipo":"seta"}"#)
    }

    @Test func tipoDesconhecidoLancaDecodingError() {
        #expect(throws: DecodingError.self) {
            try decodificar(#"{"tipo":"pincel"}"#)
        }
    }

    @Test func chaveObrigatoriaAusenteLancaDecodingError() {
        #expect(throws: DecodingError.self) {
            try decodificar(#"{"tipo":"seta","inicio":{"x":1,"y":2}}"#)
        }
    }

    @Test func documentoGravaTamanhoERecorteComoObjetos() throws {
        let documento = Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: CGSize(width: 100, height: 80),
            escala: 2,
            recorte: CGRect(x: 10, y: 10, width: 50, height: 40),
            objetos: []
        )
        let dados = try JSONEncoder().encode(documento)
        let texto = try #require(String(bytes: dados, encoding: .utf8))
        #expect(texto.contains("\"largura\""))
        #expect(!texto.contains("[["))
        #expect(try JSONDecoder().decode(Documento.self, from: dados) == documento)
    }
}
