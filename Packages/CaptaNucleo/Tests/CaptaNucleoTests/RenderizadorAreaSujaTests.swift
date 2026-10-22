import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

@Suite("Renderizador: composição por área suja")
struct RenderizadorAreaSujaTests {
    let tamanho = CGSize(width: 200, height: 120)
    var xadrez: CGImage { imagemXadrez(tamanho) }
    static let vermelho = CorRGBA(r: 1, g: 0, b: 0)
    static let azul = CorRGBA(r: 0, g: 0, b: 1)

    func documento(_ objetos: [Anotacao], recorte: CGRect? = nil) -> Documento {
        Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: tamanho,
            escala: 1,
            recorte: recorte,
            objetos: objetos
        )
    }

    func retangulo(_ r: CGRect, _ cor: CorRGBA = vermelho, rotacao: Double = 0) -> Anotacao {
        Anotacao(
            geometria: .forma(.retangulo, r),
            estilo: Estilo(cor: cor, largura: 0, preenchimento: cor),
            rotacao: rotacao
        )
    }

    func desfoque(_ r: CGRect, _ tipo: TipoDesfoque, _ intensidade: Double) -> Anotacao {
        Anotacao(geometria: .desfoque(r, tipo, intensidade: intensidade))
    }

    func editado(_ doc: Documento, _ edicao: Edicao) throws -> Documento {
        try SessaoEdicao(documento: doc).simular(edicao)
    }

    func imagem(_ contexto: CGContext) throws -> CGImage {
        try #require(contexto.makeImage())
    }

    /// Quantos bytes RGBA diferem entre as duas imagens (do mesmo tamanho).
    func diferencas(_ a: CGImage, _ b: CGImage) -> Int {
        let pa = todosOsPixels(a)
        let pb = todosOsPixels(b)
        guard pa.count == pb.count else { return max(pa.count, pb.count) }
        return zip(pa, pb).filter { $0 != $1 }.count
    }

    /// Compõe `antes` inteiro e depois só a área alterada de `depois`, no mesmo contexto.
    /// Confere que o resultado é o render inteiro de `depois` e que a área não era a imagem toda.
    func confereRecomposicao(
        de antes: Documento,
        para depois: Documento,
        base: CGImage
    ) throws {
        let renderizador = Renderizador()
        let contexto = try renderizador.novoContexto(para: base)
        try renderizador.compor(antes, base: base, em: contexto, area: nil)
        let esperado = try renderizador.renderizar(depois, base: base)
        // Sem recompor, o contexto ainda mostra `antes`: a comparação final não é trivial.
        #expect(diferencas(try imagem(contexto), esperado) > 0)

        guard case .retangulo(let area) = depois.areaAlterada(desde: antes) else {
            Issue.record("a edição deveria alterar só um retângulo")
            return
        }
        #expect(area.width < tamanho.width || area.height < tamanho.height)
        try renderizador.compor(depois, base: base, em: contexto, area: area)
        #expect(diferencas(try imagem(contexto), esperado) == 0)
    }

    // MARK: Render inteiro

    @Test func renderizarContinuaIgualACompor() throws {
        let doc = documento(
            [
                retangulo(CGRect(x: 20, y: 20, width: 40, height: 30)),
                desfoque(CGRect(x: 40, y: 10, width: 60, height: 60), .borrar, 4),
            ],
            recorte: CGRect(x: 10, y: 5, width: 120, height: 90)
        )
        let renderizador = Renderizador()
        let contexto = try renderizador.novoContexto(para: xadrez)
        #expect(contexto.width == 200 && contexto.height == 120)
        try renderizador.compor(doc, base: xadrez, em: contexto, area: nil)
        let inteiro = try imagem(contexto)
        // `compor` não aplica o recorte; `renderizar` aplica por último.
        let recortado = try #require(
            inteiro.cropping(to: CGRect(x: 10, y: 5, width: 120, height: 90))
        )
        let saida = try renderizador.renderizar(doc, base: xadrez)
        #expect(saida.width == 120 && saida.height == 90)
        #expect(diferencas(saida, recortado) == 0)
    }

    @Test func margemDeLeituraPorTipo() {
        #expect(margemDeLeitura(tipo: .borrar, intensidade: 10) == 30)
        #expect(margemDeLeitura(tipo: .borrar, intensidade: 0.5) == 2)
        #expect(margemDeLeitura(tipo: .borrar, intensidade: 500) == 300)
        #expect(margemDeLeitura(tipo: .pixelizar, intensidade: 8) == 8)
        #expect(margemDeLeitura(tipo: .pixelizar, intensidade: 7.2) == 8)
        #expect(margemDeLeitura(tipo: .pixelizar, intensidade: 0.3) == 1)
        #expect(margemDeLeitura(tipo: .pixelizar, intensidade: 250) == 100)
    }

    // MARK: Por área

    @Test func comporPorAreaIgualAoRenderInteiro() throws {
        let movido = retangulo(CGRect(x: 20, y: 20, width: 40, height: 30))
        let elipse = Anotacao(
            geometria: .forma(.elipse, CGRect(x: 50, y: 35, width: 60, height: 40)),
            estilo: Estilo(
                cor: Self.azul,
                largura: 3,
                opacidade: 0.6,
                preenchimento: CorRGBA(r: 0, g: 1, b: 0),
                tracejado: true
            )
        )
        let texto = Anotacao(
            geometria: .texto(
                CGRect(x: 120, y: 10, width: 70, height: 40),
                conteudo: "Olá",
                tamanhoFonte: 18,
                negrito: true,
                italico: false
            ),
            estilo: Estilo(cor: .preto)
        )
        let girado = retangulo(
            CGRect(x: 130, y: 70, width: 50, height: 12),
            Self.azul,
            rotacao: 0.5
        )
        let etapa = Anotacao(
            geometria: .etapa(centro: CGPoint(x: 40, y: 95), diametro: 24, reiniciaSequencia: false)
        )
        let antes = documento([movido, elipse, texto, girado, etapa])
        let depois = try editado(antes, .mover([movido.id], deslocamento: CGVector(dx: 30, dy: 40)))
        try confereRecomposicao(de: antes, para: depois, base: xadrez)
    }

    @Test func objetoQueSoEncostaNaAreaEntraNaComposicao() throws {
        // O azul (por cima) entra na área por uma coluna só de pixels: tem de ser redesenhado.
        let movido = retangulo(CGRect(x: 20, y: 20, width: 40, height: 30))
        let antes = documento([
            movido,
            retangulo(CGRect(x: 98, y: 20, width: 40, height: 30), Self.azul),
        ])
        let depois = try editado(antes, .mover([movido.id], deslocamento: CGVector(dx: 39, dy: 0)))
        try confereRecomposicao(de: antes, para: depois, base: xadrez)
    }

    @Test func moverObjetoEmbaixoDeDesfoqueIgualAoRenderInteiro() throws {
        // Vermelho parcialmente sob o borrão; azul acima do borrão, encostado nele por fora.
        let movido = retangulo(CGRect(x: 50, y: 40, width: 40, height: 30))
        let antes = documento([
            movido,
            desfoque(CGRect(x: 80, y: 20, width: 60, height: 70), .borrar, 10),
            retangulo(CGRect(x: 142, y: 30, width: 20, height: 40), Self.azul),
        ])
        let depois = try editado(antes, .mover([movido.id], deslocamento: CGVector(dx: -30, dy: 0)))
        try confereRecomposicao(de: antes, para: depois, base: xadrez)
    }

    @Test func moverOProprioPixelizarIgualAoRenderInteiro() throws {
        // Lado de 43 px: os blocos de 8 px da última coluna e da linha de cima leem fora da
        // região, onde o azul (acima do desfoque) está no compósito antigo.
        let pixelizar = desfoque(CGRect(x: 40, y: 42, width: 43, height: 43), .pixelizar, 8)
        let antes = documento([
            retangulo(CGRect(x: 30, y: 60, width: 30, height: 30)),
            pixelizar,
            retangulo(CGRect(x: 103, y: 30, width: 20, height: 40), Self.azul),
        ])
        let depois = try editado(
            antes,
            .mover([pixelizar.id], deslocamento: CGVector(dx: 20, dy: 0))
        )
        try confereRecomposicao(de: antes, para: depois, base: xadrez)
    }

    @Test func moverObjetoPertoDeDesfoqueSemTocarARegiao() throws {
        // O objeto nunca entra na região do borrão, mas fica dentro da margem que ele lê.
        let movido = retangulo(CGRect(x: 40, y: 40, width: 30, height: 30))
        let antes = documento([
            movido,
            desfoque(CGRect(x: 80, y: 20, width: 60, height: 70), .borrar, 10),
        ])
        let depois = try editado(antes, .mover([movido.id], deslocamento: CGVector(dx: -30, dy: 0)))
        try confereRecomposicao(de: antes, para: depois, base: xadrez)
    }

    @Test func ampliacaoSeRepeteAteEstabilizar() throws {
        // Cadeia: a área do vermelho alcança o borrão 1, que alcança o 2, que alcança o 3. O 3
        // é o primeiro da lista, então uma passada só na ordem das camadas não o pegaria.
        let movido = retangulo(CGRect(x: 20, y: 40, width: 20, height: 20))
        let faixa = { (x: Double) in CGRect(x: x, y: 20, width: 30, height: 80) }
        let antes = documento([
            desfoque(faixa(145), .borrar, 5),
            movido,
            desfoque(faixa(50), .borrar, 5),
            desfoque(faixa(105), .borrar, 5),
        ])
        let depois = try editado(antes, .mover([movido.id], deslocamento: CGVector(dx: 5, dy: 0)))
        try confereRecomposicao(de: antes, para: depois, base: xadrez)
    }

    @Test func desfoqueSemEfeitoNaoAmplia() throws {
        let movido = retangulo(CGRect(x: 20, y: 40, width: 20, height: 20))
        let antes = documento([
            movido,
            desfoque(CGRect(x: 45, y: 20, width: 30, height: 80), .borrar, 0),
            desfoque(CGRect(x: 45, y: 20, width: 0, height: 80), .borrar, 10),
        ])
        let depois = try editado(antes, .mover([movido.id], deslocamento: CGVector(dx: 5, dy: 0)))
        try confereRecomposicao(de: antes, para: depois, base: xadrez)
    }

    @Test func baseTranslucidaNaoAcumulaAoRecompor() throws {
        let translucida = imagemSolida(tamanho, cor: CorRGBA(r: 0, g: 0.5, b: 1, a: 0.5))
        let movido = retangulo(CGRect(x: 20, y: 20, width: 40, height: 30))
        let antes = documento([movido])
        let depois = try editado(antes, .mover([movido.id], deslocamento: CGVector(dx: 50, dy: 0)))
        try confereRecomposicao(de: antes, para: depois, base: translucida)
    }

    @Test func areaSemAreaOuForaDaImagemNaoMudaNada() throws {
        let renderizador = Renderizador()
        let antes = documento([retangulo(CGRect(x: 20, y: 20, width: 40, height: 30))])
        let depois = documento([retangulo(CGRect(x: 100, y: 20, width: 40, height: 30))])
        let contexto = try renderizador.novoContexto(para: xadrez)
        try renderizador.compor(antes, base: xadrez, em: contexto, area: nil)
        let original = try imagem(contexto)
        for area in [
            CGRect(x: 100, y: 20, width: 0, height: 30),
            CGRect(x: 300, y: 20, width: 40, height: 30),
            CGRect(x: -80, y: -80, width: 40, height: 30),
        ] {
            try renderizador.compor(depois, base: xadrez, em: contexto, area: area)
            #expect(diferencas(try imagem(contexto), original) == 0)
        }
    }

    @Test func areaNaoFinitaRecompoeTudo() throws {
        let renderizador = Renderizador()
        let antes = documento([retangulo(CGRect(x: 20, y: 20, width: 40, height: 30))])
        let depois = documento([retangulo(CGRect(x: 100, y: 20, width: 40, height: 30))])
        let contexto = try renderizador.novoContexto(para: xadrez)
        try renderizador.compor(antes, base: xadrez, em: contexto, area: nil)
        let area = CGRect(x: Double.nan, y: 0, width: 10, height: 10)
        try renderizador.compor(depois, base: xadrez, em: contexto, area: area)
        let esperado = try renderizador.renderizar(depois, base: xadrez)
        #expect(diferencas(try imagem(contexto), esperado) == 0)
    }

    @Test func areaFracionariaArredondaParaFora() throws {
        let renderizador = Renderizador()
        let antes = documento([retangulo(CGRect(x: 20.3, y: 20.6, width: 40.2, height: 30.1))])
        let depois = documento([retangulo(CGRect(x: 20.3, y: 30.6, width: 40.2, height: 30.1))])
        let contexto = try renderizador.novoContexto(para: xadrez)
        try renderizador.compor(antes, base: xadrez, em: contexto, area: nil)
        let area = CGRect(x: 20.3, y: 20.6, width: 40.2, height: 40.1)
        try renderizador.compor(depois, base: xadrez, em: contexto, area: area)
        let esperado = try renderizador.renderizar(depois, base: xadrez)
        #expect(diferencas(try imagem(contexto), esperado) == 0)
    }

    // MARK: Erros

    @Test func contextoDeOutroTamanhoLanca() throws {
        let renderizador = Renderizador()
        let outro = try renderizador.novoContexto(
            para: imagemSolida(CGSize(width: 100, height: 100), cor: .branco)
        )
        #expect(throws: ErroRenderizacao.contextoIncompativel) {
            try renderizador.compor(documento([]), base: xadrez, em: outro, area: nil)
        }
    }

    @Test func comporConfereABaseEODocumento() throws {
        let renderizador = Renderizador()
        let contexto = try renderizador.novoContexto(para: xadrez)
        let pequena = imagemSolida(CGSize(width: 100, height: 100), cor: .branco)
        #expect(throws: ErroDocumento.tamanhoInvalido) {
            try renderizador.compor(documento([]), base: pequena, em: contexto, area: nil)
        }
        let invalido = documento([retangulo(CGRect(x: Double.nan, y: 0, width: 1, height: 1))])
        #expect(throws: ErroDocumento.valorNaoFinito) {
            try renderizador.compor(invalido, base: xadrez, em: contexto, area: nil)
        }
    }
}
