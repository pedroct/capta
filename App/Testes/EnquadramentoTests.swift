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
}
