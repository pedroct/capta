import CoreGraphics
import Testing

@testable import Capta

@Suite("Enquadramento da imagem na janela")
struct EnquadramentoTests {
    @Test func tamanhoRealSempreUm() {
        let escala = Enquadramento.escala(
            imagem: CGSize(width: 4000, height: 3000),
            area: CGSize(width: 800, height: 600),
            modo: .tamanhoReal
        )
        #expect(escala == 1)
    }

    @Test func ajustarReduzSoQuandoNaoCabe() {
        let imagem = CGSize(width: 2000, height: 1000)
        // A largura limita: 1000 / 2000.
        let porLargura = Enquadramento.escala(
            imagem: imagem,
            area: CGSize(width: 1000, height: 900),
            modo: .ajustar
        )
        #expect(porLargura == 0.5)
        // A altura limita: 250 / 1000.
        let porAltura = Enquadramento.escala(
            imagem: imagem,
            area: CGSize(width: 1500, height: 250),
            modo: .ajustar
        )
        #expect(porAltura == 0.25)
    }

    @Test func ajustarNuncaAmplia() {
        let escala = Enquadramento.escala(
            imagem: CGSize(width: 100, height: 50),
            area: CGSize(width: 1000, height: 1000),
            modo: .ajustar
        )
        #expect(escala == 1)
    }

    @Test func ladoZeroDevolveUm() {
        let cheio = CGSize(width: 500, height: 500)
        let semLargura = CGSize(width: 0, height: 10)
        let semAltura = CGSize(width: 10, height: 0)
        #expect(Enquadramento.escala(imagem: semLargura, area: cheio, modo: .ajustar) == 1)
        #expect(Enquadramento.escala(imagem: semAltura, area: cheio, modo: .ajustar) == 1)
        let imagem = CGSize(width: 10, height: 10)
        #expect(Enquadramento.escala(imagem: imagem, area: semLargura, modo: .ajustar) == 1)
        #expect(Enquadramento.escala(imagem: imagem, area: semAltura, modo: .ajustar) == 1)
    }

    // MARK: - Janela inicial

    @Test func tamanhoInicialLimitaA80PorCentoDaTelaESomaABarra() {
        let tamanho = Enquadramento.tamanhoInicial(
            imagem: CGSize(width: 3000, height: 2000),
            telaVisivel: CGSize(width: 1500, height: 1000)
        )
        #expect(tamanho == CGSize(width: 1200, height: 800 + Enquadramento.alturaDaBarra))
    }

    @Test func tamanhoInicialRespeitaOMinimoEUsaATelaPadraoSemTela() {
        let pequena = Enquadramento.tamanhoInicial(
            imagem: CGSize(width: 100, height: 50),
            telaVisivel: nil
        )
        #expect(pequena == CGSize(width: 480, height: 320 + Enquadramento.alturaDaBarra))
        // Sem tela, o limite é 80 % de 1280 x 800.
        let grande = Enquadramento.tamanhoInicial(
            imagem: CGSize(width: 5000, height: 5000),
            telaVisivel: nil
        )
        #expect(grande == CGSize(width: 1024, height: 640 + Enquadramento.alturaDaBarra))
    }

    @Test func origemCentralizaNaTelaDadaInclusiveNaSegunda() {
        // Segunda tela à direita da principal, em coordenadas do AppKit.
        let segunda = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let origem = Enquadramento.origemCentralizada(
            CGSize(width: 1000, height: 600),
            em: segunda
        )
        #expect(origem == CGPoint(x: 1440 + 460, y: 240))
    }

    @Test func origemMantemOTopoEOLadoEsquerdoDentroDaTela() {
        let tela = CGRect(x: -800, y: 100, width: 800, height: 600)
        let origem = Enquadramento.origemCentralizada(
            CGSize(width: 1000, height: 900),
            em: tela
        )
        // Maior que a tela: encosta à esquerda e no topo, para a barra de título ficar visível.
        #expect(origem == CGPoint(x: -800, y: 700 - 900))
    }
}
