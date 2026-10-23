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
        // 80 % da tela na largura inclui o painel de propriedades.
        #expect(tamanho == CGSize(width: 1200, height: 800 + Enquadramento.alturaDaBarra))
    }

    @Test func tamanhoInicialRespeitaOMinimoEUsaATelaPadraoSemTela() {
        let pequena = Enquadramento.tamanhoInicial(
            imagem: CGSize(width: 100, height: 50),
            telaVisivel: nil
        )
        #expect(
            pequena
                == CGSize(
                    width: 480 + Enquadramento.larguraDoPainel,
                    height: 320 + Enquadramento.alturaDaBarra
                )
        )
        // Sem tela, o limite é 80 % de 1280 x 800.
        let grande = Enquadramento.tamanhoInicial(
            imagem: CGSize(width: 5000, height: 5000),
            telaVisivel: nil
        )
        #expect(grande == CGSize(width: 1024, height: 640 + Enquadramento.alturaDaBarra))
    }

    @Test func aAlturaDaBarraSomaFerramentasERodape() {
        #expect(
            Enquadramento.alturaDaBarra
                == Enquadramento.alturaDasFerramentas + Enquadramento.alturaDoRodape
        )
        #expect(Enquadramento.larguraDoPainel == 232)
    }

    @Test func tamanhoMinimoCabeNoTamanhoInicialMinimo() {
        let inicial = Enquadramento.tamanhoInicial(
            imagem: CGSize(width: 10, height: 10),
            telaVisivel: nil
        )
        #expect(Enquadramento.tamanhoMinimo.width <= inicial.width)
        #expect(Enquadramento.tamanhoMinimo.height <= inicial.height)
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
    // MARK: - Tamanho em pontos

    @Test func pontosDividemOsPixelsPelaEscala() {
        let pontos = Enquadramento.pontos(larguraEmPixels: 3024, alturaEmPixels: 1964, escala: 2)
        #expect(pontos == CGSize(width: 1512, height: 982))
    }

    // MARK: - Tela do cursor

    /// Principal à esquerda, segunda à direita e terceira em cima da principal.
    static let principal = CGRect(x: 0, y: 0, width: 1440, height: 900)
    static let direita = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    static let acima = CGRect(x: 0, y: 900, width: 1440, height: 900)
    static let telas = [principal, direita, acima]

    private func tela(sob cursor: CGPoint, entre telas: [CGRect] = telas) -> CGRect? {
        Enquadramento.tela(sob: cursor, entre: telas, quadro: { $0 }, padrao: telas.first)
    }

    @Test func telaDoCursorEscolheAQueContemOPonto() {
        #expect(tela(sob: CGPoint(x: 100, y: 100)) == Self.principal)
        #expect(tela(sob: CGPoint(x: 2000, y: 500)) == Self.direita)
        #expect(tela(sob: CGPoint(x: 100, y: 1200)) == Self.acima)
    }

    @Test func linhaMaisAltaDaTelaPertenceAEla() {
        // No AppKit o cursor no pixel mais alto tem y igual a maxY: a borda de cima é da tela.
        let soPrincipal = [Self.direita, Self.principal]
        #expect(tela(sob: CGPoint(x: 100, y: 900), entre: soPrincipal) == Self.principal)
        // Com outra tela em cima, y = 900 continua sendo da de baixo, e não da de cima.
        #expect(tela(sob: CGPoint(x: 100, y: 900)) == Self.principal)
        #expect(tela(sob: CGPoint(x: 2000, y: 1080)) == Self.direita)
    }

    @Test func bordaDeBaixoEDaDireitaSaoDaTelaVizinha() {
        // x = 1440 é a primeira coluna da tela da direita, não a última da principal.
        #expect(tela(sob: CGPoint(x: 1440, y: 100)) == Self.direita)
        // y = 0 fica abaixo da principal: sem tela que o contenha, vale a padrão.
        #expect(
            tela(sob: CGPoint(x: 100, y: 0), entre: [Self.direita, Self.principal]) == Self.direita
        )
    }

    @Test func cursorForaDeTodasUsaAPadrao() {
        #expect(tela(sob: CGPoint(x: -50, y: 100)) == Self.principal)
        let semPadrao = Enquadramento.tela(
            sob: CGPoint(x: -50, y: 100),
            entre: Self.telas,
            quadro: { $0 },
            padrao: nil
        )
        #expect(semPadrao == nil)
    }

    @Test func semTelasDevolveAPadrao() {
        let padrao = CGRect(x: 0, y: 0, width: 1, height: 1)
        let escolhida = Enquadramento.tela(
            sob: CGPoint(x: 0, y: 0),
            entre: [CGRect](),
            quadro: { $0 },
            padrao: padrao
        )
        #expect(escolhida == padrao)
    }
}
