import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

/// Garante que o JSON do esquema v1 (congelado, `docs/esquema-capta-v1.md`) continua legível:
/// a v1 não é mais gravada, só lida e migrada para a versão atual.
@Suite("Leitura do esquema v1")
struct EsquemaV1CongeladoTests {
    private static func anotacao(
        _ n: Int,
        ordem: Int,
        _ geometria: Geometria,
        estilo: Estilo,
        rotacao: Double = 0
    ) throws -> Anotacao {
        let id = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000\(n)"))
        var a = Anotacao(id: id, geometria: geometria, estilo: estilo, rotacao: rotacao)
        a.ordem = ordem
        return a
    }

    private static func estiloForaDoPadrao() -> Estilo {
        Estilo(
            cor: CorRGBA(r: 1, g: 0.5, b: 0.25, a: 0.75),
            largura: 2.5,
            opacidade: 0.5,
            preenchimento: CorRGBA(r: 0, g: 0.25, b: 0.5, a: 1),
            tracejado: true,
            ponta: .aberta,
            familiaFonte: "Helvetica Neue",
            alinhamento: .direita,
            rotulo: .alfabetico
        )
    }

    private static func objetosCompletos() throws -> [Anotacao] {
        let estilo = estiloForaDoPadrao()
        let retangulo = CGRect(x: 10.5, y: 20.5, width: 30.25, height: 40.75)
        return [
            try anotacao(
                1,
                ordem: 8,
                .seta(inicio: CGPoint(x: 1.5, y: 2.5), fim: CGPoint(x: 3.5, y: 4.5)),
                estilo: estilo
            ),
            try anotacao(
                2,
                ordem: 3,
                .linha(inicio: CGPoint(x: 5.5, y: 6.5), fim: CGPoint(x: 7.5, y: 8.5)),
                estilo: estilo
            ),
            try anotacao(
                3,
                ordem: 5,
                .forma(.retanguloArredondado, retangulo),
                estilo: estilo,
                rotacao: 0.5
            ),
            try anotacao(
                4,
                ordem: 0,
                .texto(
                    retangulo,
                    conteudo: "Olá",
                    tamanhoFonte: 18.5,
                    negrito: true,
                    italico: true
                ),
                estilo: estilo,
                rotacao: -0.25
            ),
            try anotacao(
                5,
                ordem: 6,
                .etapa(centro: CGPoint(x: 50.5, y: 60.5), diametro: 24.5, reiniciaSequencia: true),
                estilo: estilo,
                rotacao: 1.5
            ),
            try anotacao(
                6,
                ordem: 1,
                .carimbo(retangulo, simbolo: "star.fill"),
                estilo: estilo,
                rotacao: 0.75
            ),
            try anotacao(7, ordem: 4, .realce(retangulo), estilo: estilo, rotacao: 2),
            try anotacao(
                8,
                ordem: 2,
                .desfoque(retangulo, .pixelizar, intensidade: 12.5),
                estilo: estilo
            ),
        ]
    }

    static func documentoCompleto() throws -> Documento {
        let documento = Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: CGSize(width: 800.5, height: 600.5),
            escala: 2,
            recorte: CGRect(x: 100.5, y: 50.5, width: 200.25, height: 150.75),
            objetos: try objetosCompletos(),
            proximaOrdem: 9
        )
        try documento.validar()
        return documento
    }

    static func codificador() -> JSONEncoder {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.sortedKeys, .prettyPrinted]
        return codificador
    }

    @Test func jsonV1DeReferenciaDecodificaMigrado() throws {
        let decodificado = try JSONDecoder().decode(
            Documento.self,
            from: Data(jsonEsquemaV1DeReferencia.utf8)
        )
        #expect(decodificado.versaoEsquema == 2)
        #expect(decodificado == (try Self.documentoCompleto()))
    }
}
