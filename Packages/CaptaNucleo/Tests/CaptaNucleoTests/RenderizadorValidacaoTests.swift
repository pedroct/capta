import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

@Suite("Renderizador: opacidade do desfoque e validação")
struct RenderizadorValidacaoTests {
    let lado = CGSize(width: 100, height: 100)

    func documento(_ objetos: [Anotacao], recorte: CGRect? = nil) -> Documento {
        Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: lado,
            escala: 1,
            recorte: recorte,
            objetos: objetos
        )
    }

    func renderizar(_ objetos: [Anotacao]) throws -> CGImage {
        try Renderizador().renderizar(documento(objetos), base: imagemXadrez(lado))
    }

    @Test func desfoqueIgnoraAOpacidadeDoEstilo() throws {
        let regiao = CGRect(x: 20, y: 20, width: 40, height: 40)
        for tipo in [TipoDesfoque.borrar, .pixelizar] {
            var opaco = Anotacao(geometria: .desfoque(regiao, tipo, intensidade: 10))
            var translucido = opaco
            opaco.estilo.opacidade = 1
            translucido.estilo.opacidade = 0.3
            let a = try renderizar([opaco])
            let b = try renderizar([translucido])
            #expect(todosOsPixels(a) == todosOsPixels(b), "tipo \(tipo)")
        }
    }

    @Test func documentoInvalidoMontadoAMaoLanca() {
        let base = imagemSolida(lado, cor: .branco)
        let nan = Anotacao(
            geometria: .forma(.retangulo, CGRect(x: 1, y: 1, width: 5, height: 5)),
            estilo: Estilo(opacidade: .nan)
        )
        #expect(throws: ErroDocumento.valorNaoFinito) {
            try Renderizador().renderizar(documento([nan]), base: base)
        }
        let foraDosLimites = documento([], recorte: CGRect(x: 80, y: 80, width: 50, height: 50))
        #expect(throws: ErroDocumento.recorteInvalido) {
            try Renderizador().renderizar(foraDosLimites, base: base)
        }
    }
}
