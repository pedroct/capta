import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

@Suite("Área alterada entre duas versões do documento")
struct AreaAlteradaTests {
    let tamanho = CGSize(width: 200, height: 120)

    func documento(_ objetos: [Anotacao], escala: Double = 1) -> Documento {
        Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: tamanho,
            escala: escala,
            recorte: nil,
            objetos: objetos
        )
    }

    func retangulo(_ r: CGRect) -> Anotacao {
        let cor = CorRGBA(r: 1, g: 0, b: 0)
        return Anotacao(
            geometria: .forma(.retangulo, r),
            estilo: Estilo(cor: cor, largura: 0, preenchimento: cor)
        )
    }

    func etapa(_ x: Double) -> Anotacao {
        Anotacao(
            geometria: .etapa(centro: CGPoint(x: x, y: 60), diametro: 20, reiniciaSequencia: false),
            estilo: Estilo(largura: 0)
        )
    }

    func editado(_ doc: Documento, _ edicao: Edicao) throws -> Documento {
        try SessaoEdicao(documento: doc).simular(edicao)
    }

    /// O retângulo da área, ou `nil` se não for `.retangulo`.
    func retanguloDa(_ area: AreaASerRedesenhada) -> CGRect? {
        guard case .retangulo(let r) = area else { return nil }
        return r
    }

    @Test func areaAlteradaDeMoverEUniaoAntesEDepois() throws {
        let fixo = retangulo(CGRect(x: 150, y: 80, width: 30, height: 30))
        let movido = retangulo(CGRect(x: 10, y: 10, width: 20, height: 20))
        let antes = documento([fixo, movido])
        let depois = try editado(antes, .mover([movido.id], deslocamento: CGVector(dx: 50, dy: 5)))
        #expect(
            depois.areaAlterada(desde: antes)
                == .retangulo(CGRect(x: 10, y: 10, width: 70, height: 25))
        )
    }

    @Test func areaAlteradaSoDeRecorteENada() throws {
        let antes = documento([retangulo(CGRect(x: 10, y: 10, width: 20, height: 20))])
        let depois = try editado(antes, .definirRecorte(CGRect(x: 0, y: 0, width: 50, height: 50)))
        #expect(depois.areaAlterada(desde: antes) == .nada)
        #expect(antes.areaAlterada(desde: antes) == .nada)
    }

    @Test func areaAlteradaDeEscalaETudo() {
        let objetos = [retangulo(CGRect(x: 10, y: 10, width: 20, height: 20))]
        #expect(documento(objetos, escala: 2).areaAlterada(desde: documento(objetos)) == .tudo)
        var outroTamanho = documento(objetos)
        outroTamanho.tamanhoBase = CGSize(width: 100, height: 120)
        #expect(outroTamanho.areaAlterada(desde: documento(objetos)) == .tudo)
    }

    @Test func adicionarRemoverESubstituirCobremOsLimites() throws {
        let a = retangulo(CGRect(x: 10, y: 10, width: 20, height: 20))
        let antes = documento([a])
        let novo = retangulo(CGRect(x: 100, y: 50, width: 10, height: 10))
        let comNovo = try editado(antes, .adicionar(novo))
        #expect(comNovo.areaAlterada(desde: antes) == .retangulo(novo.limites))
        #expect(antes.areaAlterada(desde: comNovo) == .retangulo(novo.limites))

        // Só o estilo muda (traço mais largo): a área cobre os limites novos, maiores.
        var tracado = a
        tracado.estilo.largura = 6
        let comTraco = try editado(antes, .substituir(tracado))
        #expect(comTraco.areaAlterada(desde: antes) == .retangulo(tracado.limites))

        var girado = a
        girado.rotacao = .pi / 4
        let comRotacao = try editado(antes, .substituir(girado))
        #expect(comRotacao.areaAlterada(desde: antes) == .retangulo(girado.limites))
    }

    @Test func removerEtapaIncluiAsQueRenumeram() throws {
        let primeira = etapa(30)
        let segunda = etapa(100)
        let terceira = etapa(170)
        let antes = documento([primeira, segunda, terceira])
        let depois = try editado(antes, .remover([primeira.id]))
        let area = try #require(retanguloDa(depois.areaAlterada(desde: antes)))
        #expect(area.contains(primeira.limites))
        #expect(area.contains(segunda.limites))
        #expect(area.contains(terceira.limites))
    }

    @Test func trocarORotuloDeUmaEtapaSoAfetaEla() throws {
        let primeira = etapa(30)
        let segunda = etapa(100)
        let antes = documento([primeira, segunda])
        var alfabetica = segunda
        alfabetica.estilo.rotulo = .alfabetico
        let depois = try editado(antes, .substituir(alfabetica))
        #expect(depois.areaAlterada(desde: antes) == .retangulo(segunda.limites))
    }

    @Test func reiniciarSequenciaIncluiAsEtapasSeguintes() throws {
        let primeira = etapa(30)
        let segunda = etapa(100)
        let terceira = etapa(170)
        let antes = documento([primeira, segunda, terceira])
        let depois = try editado(antes, .definirReinicioDeEtapa(segunda.id, true))
        let area = try #require(retanguloDa(depois.areaAlterada(desde: antes)))
        #expect(!area.intersects(primeira.limites))
        #expect(area.contains(segunda.limites))
        #expect(area.contains(terceira.limites))
    }

    @Test func reordenarIncluiOsQueTrocaram() throws {
        let a = retangulo(CGRect(x: 10, y: 10, width: 20, height: 20))
        let b = retangulo(CGRect(x: 60, y: 10, width: 20, height: 20))
        let c = retangulo(CGRect(x: 110, y: 10, width: 20, height: 20))
        let d = retangulo(CGRect(x: 160, y: 10, width: 20, height: 20))
        let antes = documento([a, b, c, d])
        let depois = try editado(antes, .reordenar(b.id, .umNivelAcima))
        let area = try #require(retanguloDa(depois.areaAlterada(desde: antes)))
        #expect(area.contains(b.limites))
        #expect(area.contains(c.limites))
        #expect(!area.intersects(a.limites))
        #expect(!area.intersects(d.limites))
    }

    @Test func entrarUmObjetoNaoContaComoTrocaDeCamadaDosOutros() throws {
        let a = retangulo(CGRect(x: 10, y: 10, width: 20, height: 20))
        let b = retangulo(CGRect(x: 160, y: 10, width: 20, height: 20))
        let antes = documento([a, b])
        let novo = retangulo(CGRect(x: 90, y: 80, width: 10, height: 10))
        // O novo entra embaixo de todos: `a` e `b` mudam de índice, não de posição relativa.
        let depois = try editado(antes, .lote([.adicionar(novo), .reordenar(novo.id, .paraTras)]))
        #expect(depois.areaAlterada(desde: antes) == .retangulo(novo.limites))
    }

    @Test func soAOrdemDeCriacaoDeUmaFormaMudandoENada() {
        let a = retangulo(CGRect(x: 10, y: 10, width: 20, height: 20))
        let antes = documento([a])
        var depois = antes
        depois.objetos[0].ordem = 5
        depois.proximaOrdem = 6
        #expect(depois.objetos != antes.objetos)
        #expect(depois.areaAlterada(desde: antes) == .nada)
    }
}
