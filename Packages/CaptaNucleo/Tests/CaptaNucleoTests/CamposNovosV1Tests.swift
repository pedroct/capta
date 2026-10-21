import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private let retangulo = CGRect(x: 10, y: 20, width: 100, height: 50)
private let ponto = CGPoint(x: 5, y: 5)

private func anotacao(_ geometria: Geometria, rotacao: Double) -> Anotacao {
    Anotacao(geometria: geometria, estilo: Estilo(), rotacao: rotacao)
}

private func objetoJSON<T: Encodable>(_ valor: T) throws -> [String: Any] {
    let dados = try JSONEncoder().encode(valor)
    return try #require(try JSONSerialization.jsonObject(with: dados) as? [String: Any])
}

@Suite("Campos novos do esquema v1")
struct CamposNovosV1Tests {
    @Test func camposNovosFazemIdaEVolta() throws {
        let estilo = Estilo(
            ponta: .aberta,
            familiaFonte: "Helvetica Neue",
            alinhamento: .direita,
            rotulo: .alfabetico
        )
        let original = Anotacao(
            geometria: .realce(retangulo),
            estilo: estilo,
            rotacao: 0.75
        )
        let dados = try JSONEncoder().encode(original)
        let volta = try JSONDecoder().decode(Anotacao.self, from: dados)
        #expect(volta == original)
        #expect(volta.estilo.ponta == .aberta)
        #expect(volta.estilo.familiaFonte == "Helvetica Neue")
        #expect(volta.estilo.alinhamento == .direita)
        #expect(volta.estilo.rotulo == .alfabetico)
        #expect(volta.rotacao == 0.75)
    }

    @Test func jsonSemCamposNovosDecodificaNosPadroes() throws {
        let estiloJSON = Data(
            #"{"cor":{"r":1,"g":0,"b":0,"a":1},"largura":4,"opacidade":1,"tracejado":false}"#.utf8
        )
        let estilo = try JSONDecoder().decode(Estilo.self, from: estiloJSON)
        #expect(estilo.ponta == .triangulo)
        #expect(estilo.familiaFonte == nil)
        #expect(estilo.alinhamento == .esquerda)
        #expect(estilo.rotulo == .numerico)

        var objeto = try objetoJSON(Anotacao(geometria: .realce(retangulo)))
        objeto.removeValue(forKey: "rotacao")
        var estiloObjeto = try #require(objeto["estilo"] as? [String: Any])
        for chave in ["ponta", "familiaFonte", "alinhamento", "rotulo"] {
            estiloObjeto.removeValue(forKey: chave)
        }
        objeto["estilo"] = estiloObjeto
        let dados = try JSONSerialization.data(withJSONObject: objeto)
        let volta = try JSONDecoder().decode(Anotacao.self, from: dados)
        #expect(volta.rotacao == 0)
        #expect(volta.estilo == Estilo())
    }

    @Test(arguments: [
        Geometria.seta(inicio: ponto, fim: CGPoint(x: 50, y: 50)),
        Geometria.linha(inicio: ponto, fim: CGPoint(x: 50, y: 50)),
        Geometria.desfoque(retangulo, .borrar, intensidade: 8),
    ])
    func rotacaoNaoZeroEmSetaLinhaDesfoqueLanca(geometria: Geometria) {
        #expect(throws: ErroDocumento.valorForaDeFaixa("rotacao")) {
            try anotacao(geometria, rotacao: 0.5).validar()
        }
    }

    @Test func rotacaoValeEmFormaTextoCarimboRealceEEtapa() throws {
        let geometrias: [Geometria] = [
            .forma(.elipse, retangulo),
            .texto(retangulo, conteudo: "a", tamanhoFonte: 20, negrito: false, italico: false),
            .carimbo(retangulo, simbolo: "star"),
            .realce(retangulo),
            .etapa(centro: ponto, diametro: 30, reiniciaSequencia: false),
        ]
        for geometria in geometrias {
            try anotacao(geometria, rotacao: 1.2).validar()
        }
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity])
    func rotacaoNaoFinitaLancaValorNaoFinito(rotacao: Double) {
        #expect(throws: ErroDocumento.valorNaoFinito) {
            try anotacao(.realce(retangulo), rotacao: rotacao).validar()
        }
    }

    @Test(arguments: ["", "   ", " \t\n"])
    func familiaFonteVaziaOuSoEspacosLanca(familia: String) {
        let item = Anotacao(
            geometria: .realce(retangulo),
            estilo: Estilo(familiaFonte: familia)
        )
        #expect(throws: ErroDocumento.valorForaDeFaixa("familiaFonte")) {
            try item.validar()
        }
    }

    @Test func familiaFonteNilNaoApareceNoJson() throws {
        let estilo = try objetoJSON(Estilo())
        #expect(estilo["familiaFonte"] == nil)
        #expect(estilo["ponta"] as? String == "triangulo")
        #expect(estilo["alinhamento"] as? String == "esquerda")
        #expect(estilo["rotulo"] as? String == "numerico")
    }
}
