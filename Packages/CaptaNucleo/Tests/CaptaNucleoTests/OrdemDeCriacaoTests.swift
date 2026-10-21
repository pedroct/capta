import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private func etapa(reinicia: Bool = false, rotulo: RotuloEtapa = .numerico) -> Anotacao {
    Anotacao(
        geometria: .etapa(centro: CGPoint(x: 10, y: 10), diametro: 20, reiniciaSequencia: reinicia),
        estilo: Estilo(rotulo: rotulo)
    )
}

private func realce() -> Anotacao {
    Anotacao(geometria: .realce(CGRect(x: 0, y: 0, width: 5, height: 5)))
}

private func sessao(com objetos: [Anotacao]) throws -> SessaoEdicao {
    var s = SessaoEdicao(documento: .novo(tamanhoBase: CGSize(width: 100, height: 100), escala: 1))
    for objeto in objetos { try s.aplicar(.adicionar(objeto)) }
    return s
}

private func numeros(_ s: SessaoEdicao, _ etapas: [Anotacao]) -> [Int?] {
    etapas.map { s.documento.numeroDaEtapa($0.id) }
}

@Suite("Ordem de criação e numeração de etapas")
struct OrdemDeCriacaoTests {
    @Test func adicionarAtribuiOrdensCrescentes() throws {
        let s = try sessao(com: [realce(), etapa(), realce()])
        #expect(s.documento.objetos.map(\.ordem) == [0, 1, 2])
        #expect(s.documento.proximaOrdem == 3)
    }

    @Test func substituirMantemAOrdem() throws {
        let a = realce()
        var s = try sessao(com: [realce(), a])
        var nova = a
        nova.geometria = .realce(CGRect(x: 1, y: 1, width: 9, height: 9))
        nova.ordem = 99
        try s.aplicar(.substituir(nova))
        #expect(s.documento.objetos[1].ordem == 1)
        #expect(s.documento.objetos[1].geometria == nova.geometria)
        #expect(s.documento.proximaOrdem == 2)
    }

    @Test func removerNaoReaproveitaOrdem() throws {
        let a = realce()
        let b = realce()
        var s = try sessao(com: [a, b])
        try s.aplicar(.remover([b.id]))
        try s.aplicar(.adicionar(realce()))
        #expect(s.documento.objetos.map(\.ordem) == [0, 2])
        #expect(s.documento.proximaOrdem == 3)
    }

    @Test func trazerParaFrenteNaoMudaONumeroDaEtapa() throws {
        let e = [etapa(), etapa(), etapa()]
        var s = try sessao(com: e)
        try s.aplicar(.reordenar(e[0].id, .paraFrente))
        #expect(numeros(s, e) == [1, 2, 3])
    }

    @Test func excluirASegundaRenumeraEDesfazerRestaura() throws {
        let e = [etapa(), etapa(), etapa()]
        var s = try sessao(com: e)
        try s.aplicar(.remover([e[1].id]))
        #expect(numeros(s, e) == [1, nil, 2])
        s.desfazer()
        #expect(numeros(s, e) == [1, 2, 3])
    }

    @Test func reiniciarVoltaAUmEContinua() throws {
        let e = [etapa(), etapa(), etapa(), etapa()]
        var s = try sessao(com: e)
        try s.aplicar(.definirReinicioDeEtapa(e[2].id, true))
        #expect(numeros(s, e) == [1, 2, 1, 2])
    }

    @Test func duplicarCriaEtapaNovaNoFimDaSequencia() throws {
        let e = [etapa(), etapa()]
        var s = try sessao(com: e)
        var copia = e[0]
        copia.id = UUID()
        try s.aplicar(.adicionar(copia))
        #expect(s.documento.numeroDaEtapa(copia.id) == 3)
        #expect(numeros(s, e) == [1, 2])
    }

    @Test func rotuloAlfabeticoNosLimites() {
        let tabela: [(Int, String)] = [
            (1, "A"), (26, "Z"), (27, "AA"), (52, "AZ"), (53, "BA"), (702, "ZZ"), (703, "AAA"),
            (0, "A"), (-5, "A"),
        ]
        for (numero, texto) in tabela {
            #expect(RotuloEtapa.alfabetico.texto(paraNumero: numero) == texto)
        }
        #expect(RotuloEtapa.numerico.texto(paraNumero: 7) == "7")
        #expect(RotuloEtapa.numerico.texto(paraNumero: 0) == "1")
    }

    @Test func rotuloMistoContaPosicaoEmTodasAsEtapas() throws {
        let e = [etapa(), etapa(), etapa(rotulo: .alfabetico)]
        let s = try sessao(com: e)
        #expect(e.map { s.documento.rotuloDaEtapa($0.id) } == ["1", "2", "C"])
        #expect(s.documento.rotuloDaEtapa(UUID()) == nil)
    }

    @Test func arquivoSemOrdemUsaAOrdemDaLista() throws {
        let doc = try sessao(com: [realce(), etapa(), etapa()]).documento
        let dados = try JSONEncoder().encode(doc)
        var json = try #require(try JSONSerialization.jsonObject(with: dados) as? [String: Any])
        json.removeValue(forKey: "proximaOrdem")
        var objetos = try #require(json["objetos"] as? [[String: Any]])
        for i in objetos.indices { objetos[i].removeValue(forKey: "ordem") }
        json["objetos"] = objetos
        let antigo = try JSONSerialization.data(withJSONObject: json)
        let lido = try JSONDecoder().decode(Documento.self, from: antigo)
        #expect(lido.objetos.map(\.ordem) == [0, 1, 2])
        #expect(lido.proximaOrdem == 3)
        let ida = try JSONDecoder().decode(Documento.self, from: JSONEncoder().encode(doc))
        #expect(ida == doc)
    }

    @Test func ordemRepetidaOuForaDeFaixaLanca() throws {
        var doc = try sessao(com: [realce(), realce()]).documento
        doc.objetos[1].ordem = 0
        #expect(throws: ErroDocumento.valorForaDeFaixa("ordem")) { try doc.validar() }
        doc.objetos[1].ordem = 2
        #expect(throws: ErroDocumento.valorForaDeFaixa("ordem")) { try doc.validar() }
        doc.objetos[1].ordem = -1
        #expect(throws: ErroDocumento.valorForaDeFaixa("ordem")) { try doc.validar() }
    }

    private func jsonDoDocumento(_ doc: Documento, proximaOrdem: Int) throws -> Data {
        let dados = try JSONEncoder().encode(doc)
        var json = try #require(try JSONSerialization.jsonObject(with: dados) as? [String: Any])
        json["proximaOrdem"] = proximaOrdem
        return try JSONSerialization.data(withJSONObject: json)
    }

    @Test func proximaOrdemNegativaLancaSemTravar() throws {
        for objetos in [[], [realce(), realce()]] {
            var doc = try sessao(com: objetos).documento
            let json = try jsonDoDocumento(doc, proximaOrdem: -1)
            #expect(throws: ErroDocumento.valorForaDeFaixa("ordem")) {
                try JSONDecoder().decode(Documento.self, from: json)
            }
            doc.proximaOrdem = -1
            #expect(throws: ErroDocumento.valorForaDeFaixa("ordem")) { try doc.validar() }
        }
    }

    @Test func proximaOrdemNoLimiteDeIntNaoTravaOAdicionar() throws {
        var doc = Documento.novo(tamanhoBase: CGSize(width: 100, height: 100), escala: 1)
        doc.proximaOrdem = Int.max
        #expect(throws: ErroDocumento.valorForaDeFaixa("ordem")) { try doc.validar() }
        let json = try jsonDoDocumento(doc, proximaOrdem: Int.max)
        #expect(throws: ErroDocumento.valorForaDeFaixa("ordem")) {
            try JSONDecoder().decode(Documento.self, from: json)
        }
        var s = SessaoEdicao(documento: doc)
        #expect(throws: ErroDocumento.valorForaDeFaixa("ordem")) {
            try s.aplicar(.adicionar(realce()))
        }
    }

    @Test func idaEVoltaMantemAsOrdensGravadas() throws {
        let a = realce()
        let b = realce()
        var s = try sessao(com: [a, b])
        try s.aplicar(.remover([b.id]))
        try s.aplicar(.adicionar(realce()))
        try s.aplicar(.reordenar(a.id, .paraFrente))
        let doc = s.documento
        // Ordens não sequenciais e diferentes dos índices da lista.
        #expect(doc.objetos.map(\.ordem) == [2, 0])
        #expect(doc.proximaOrdem == 3)

        let dados = try JSONEncoder().encode(doc)
        let json = try #require(try JSONSerialization.jsonObject(with: dados) as? [String: Any])
        #expect(json["proximaOrdem"] as? Int == 3)
        let objetos = try #require(json["objetos"] as? [[String: Any]])
        #expect(objetos.map { $0["ordem"] as? Int } == [2, 0])

        let volta = try JSONDecoder().decode(Documento.self, from: dados)
        #expect(volta.objetos.map(\.ordem) == [2, 0])
        #expect(volta.proximaOrdem == 3)
        #expect(volta == doc)
    }
}
