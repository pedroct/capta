import Foundation
import Testing

@testable import CaptaNucleo

@Test func padroesDaMemoriaSaoOsDoBriefing() {
    let memoria = MemoriaDeEstilos.padrao
    #expect(memoria[.seta] == Estilo(cor: .vermelho, largura: 6))
    #expect(memoria[.linha] == Estilo(cor: .vermelho, largura: 4))
    #expect(memoria[.forma] == Estilo(cor: .vermelho, largura: 4))
    #expect(memoria[.forma].preenchimento == nil)
    #expect(memoria[.realce] == Estilo(cor: .realce, largura: 0))
    #expect(memoria[.selecao] == Estilo())
    #expect(MemoriaDeEstilos() == .padrao)
}

@Test func subscriptGravaPorFerramenta() {
    var memoria = MemoriaDeEstilos.padrao
    memoria[.seta].largura = 10
    #expect(memoria[.seta].largura == 10)
    #expect(memoria[.linha].largura == 4)
}

@Test func ferramentaDeCadaGeometria() {
    let ponto = CGPoint.zero
    let retangulo = CGRect(x: 0, y: 0, width: 1, height: 1)
    #expect(MemoriaDeEstilos.ferramenta(de: .seta(inicio: ponto, fim: ponto)) == .seta)
    #expect(MemoriaDeEstilos.ferramenta(de: .linha(inicio: ponto, fim: ponto)) == .linha)
    #expect(MemoriaDeEstilos.ferramenta(de: .forma(.elipse, retangulo)) == .forma)
    #expect(MemoriaDeEstilos.ferramenta(de: .realce(retangulo)) == .realce)
    #expect(
        MemoriaDeEstilos.ferramenta(
            de: .etapa(centro: ponto, diametro: 5, reiniciaSequencia: false)
        ) == nil
    )
}

@Test func memoriaFazIdaEVolta() throws {
    var memoria = MemoriaDeEstilos.padrao
    memoria[.seta] = Estilo(cor: .azul, largura: 9, opacidade: 0.5, tracejado: true)
    memoria[.forma].preenchimento = .verde
    let dados = try JSONEncoder().encode(memoria)
    #expect(try JSONDecoder().decode(MemoriaDeEstilos.self, from: dados) == memoria)
}

@Test func memoriaCodificaComoDicionarioPorRawValue() throws {
    let dados = try JSONEncoder().encode(MemoriaDeEstilos.padrao)
    let objeto = try JSONSerialization.jsonObject(with: dados) as? [String: Any]
    #expect(Set(objeto?.keys.map { $0 } ?? []) == Set(Ferramenta.allCases.map(\.rawValue)))
}

@Test func memoriaDecodificaJsonSemUmaFerramenta() throws {
    var memoria = MemoriaDeEstilos.padrao
    memoria[.seta].largura = 12
    var objeto = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(memoria)) as? [String: Any]
    )
    objeto.removeValue(forKey: "linha")
    let dados = try JSONSerialization.data(withJSONObject: objeto)
    let lida = try JSONDecoder().decode(MemoriaDeEstilos.self, from: dados)
    #expect(lida[.seta].largura == 12)
    #expect(lida[.linha] == MemoriaDeEstilos.padrao[.linha])
}

@Test func memoriaIgnoraChaveDesconhecida() throws {
    let json = Data(#"{"texto": {"cor": 1}, "futuro": 3}"#.utf8)
    #expect(try JSONDecoder().decode(MemoriaDeEstilos.self, from: json) == .padrao)
}

@Test func memoriaComEstiloInvalidoUsaOPadraoDaquelaFerramenta() throws {
    let json = Data(#"{"seta": "quebrado"}"#.utf8)
    #expect(try JSONDecoder().decode(MemoriaDeEstilos.self, from: json) == .padrao)
}
