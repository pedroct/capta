import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

@Suite("Composição do canvas")
@MainActor
struct ComposicaoDoCanvasTests {
    let renderizador = Renderizador()

    private func documento(largura: Int = 64, altura: Int = 48) throws -> Documento {
        try Documento.novo(
            de: ImagemCapturada(
                imagem: imagemDeTeste(largura: largura, altura: altura),
                escala: 1
            )
        )
    }

    private func retangulo(_ id: UUID, _ x: Double) -> Anotacao {
        Anotacao(
            id: id,
            geometria: .forma(.retangulo, CGRect(x: x, y: 10, width: 12, height: 12)),
            estilo: Estilo(cor: .vermelho, largura: 3)
        )
    }

    private func bytes(_ imagem: CGImage) throws -> Data {
        try #require(imagem.dataProvider?.data as Data?)
    }

    @Test func atualizarComMudancaPequenaIgualAoRenderInteiro() throws {
        let base = try imagemDeTeste(largura: 64, altura: 48)
        let composicao = try ComposicaoDoCanvas(base: base, renderizador: renderizador)
        var sessao = SessaoEdicao(documento: try documento())
        _ = try composicao.atualizar(para: sessao.documento)

        try sessao.aplicar(.adicionar(retangulo(UUID(), 5)))
        _ = try composicao.atualizar(para: sessao.documento)
        try sessao.aplicar(.adicionar(retangulo(UUID(), 30)))
        let incremental = try composicao.atualizar(para: sessao.documento)
        let documento = sessao.documento

        let inteira = try renderizador.renderizar(documento, base: base)
        #expect(try bytes(incremental) == bytes(inteira))
    }

    @Test func semMudancaDevolveAMesmaImagem() throws {
        let composicao = try ComposicaoDoCanvas(
            base: imagemDeTeste(largura: 64, altura: 48),
            renderizador: renderizador
        )
        let documento = try documento()
        let primeira = try composicao.atualizar(para: documento)
        let segunda = try composicao.atualizar(para: documento)
        #expect(primeira === segunda)
    }

    @Test func composicaoQueFalhaNaoDeixaEstadoVelhoParaTras() throws {
        let base = try imagemDeTeste(largura: 64, altura: 48)
        let composicao = try ComposicaoDoCanvas(base: base, renderizador: renderizador)
        let valido = try documento()
        let primeira = try composicao.atualizar(para: valido)
        // Documento de outro tamanho: o renderizador recusa.
        let outro = try documento(largura: 32, altura: 24)
        #expect(throws: (any Error).self) { try composicao.atualizar(para: outro) }
        // Depois da falha, o mesmo documento de antes recompõe tudo, em vez de devolver a
        // imagem velha porque "nada mudou".
        let depois = try composicao.atualizar(para: valido)
        #expect(depois !== primeira)
        #expect(try bytes(depois) == bytes(primeira))
    }

    /// Custo medido (não é um piso): documento grande com um objeto enorme tocado por uma área
    /// pequena. Só confere que a recomposição incremental termina; o número vai no relatório.
    @Test func custoDaRecomposicaoEmDocumentoGrande() throws {
        let base = try imagemDeTeste(largura: 4000, altura: 3000)
        let composicao = try ComposicaoDoCanvas(base: base, renderizador: renderizador)
        var sessao = SessaoEdicao(documento: try documento(largura: 4000, altura: 3000))
        let grande = Anotacao(
            id: UUID(),
            geometria: .forma(.retangulo, CGRect(x: 0, y: 0, width: 4000, height: 3000)),
            estilo: Estilo(cor: .vermelho, largura: 6, preenchimento: .realce)
        )
        try sessao.aplicar(.adicionar(grande))
        let relogio = ContinuousClock()
        let inicial = try relogio.measure { _ = try composicao.atualizar(para: sessao.documento) }
        try sessao.aplicar(.adicionar(retangulo(UUID(), 100)))
        let pequena = try relogio.measure { _ = try composicao.atualizar(para: sessao.documento) }
        // Medido neste Mac (4000 x 3000, objeto cheio do tamanho da imagem): inicial ~35 ms,
        // pequena ~23 ms. Sem piso: só registra que o custo não explode.
        _ = (inicial, pequena)
        #expect(pequena < .seconds(2))
    }
}
