import CoreGraphics
import Testing

@testable import CaptaNucleo

@Suite("Contrato de captura")
struct CapturaTests {
    private func capturada(_ largura: Int, _ altura: Int) -> ImagemCapturada {
        ImagemCapturada(
            imagem: imagemSolida(
                CGSize(width: largura, height: altura),
                cor: CorRGBA(r: 1, g: 0, b: 0, a: 1)
            ),
            escala: 2
        )
    }

    @Test func conferindoAceitaOTamanhoExato() throws {
        let original = capturada(40, 30)
        let conferida = try original.conferindo(largura: 40, altura: 30)
        #expect(conferida.imagem.width == 40)
        #expect(conferida.imagem.height == 30)
        #expect(conferida.escala == 2)
    }

    @Test func conferindoRecusaUmPixelADiferenca() {
        let original = capturada(40, 30)
        #expect(throws: ErroCaptura.tamanhoInesperado) {
            try original.conferindo(largura: 41, altura: 30)
        }
        #expect(throws: ErroCaptura.tamanhoInesperado) {
            try original.conferindo(largura: 40, altura: 29)
        }
    }

    @Test func telaCongeladaGuardaDescricaoEImagem() {
        let descricao = DescricaoDeTela(
            id: 7,
            quadro: CGRect(x: 0, y: 0, width: 20, height: 15),
            escala: 2,
            principal: true
        )
        let imagem = capturada(40, 30).imagem
        let tela = TelaCongelada(descricao: descricao, imagem: imagem)
        #expect(tela.descricao == descricao)
        #expect(tela.imagem === imagem)
    }
}
