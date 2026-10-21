import CaptaNucleo
import CaptaSistema
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import Capta

@Suite("Captura aberta")
@MainActor
struct CapturaAbertaTests {
    static let nome = "Captura 2027-01-15 às 08.00.00"
    let renderizador = Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF())

    private func aberta(
        rascunho: CapturaAberta.EstadoRascunho = .gravando,
        painel: PainelFalso = PainelFalso(destino: nil),
        area: AreaDeTransferenciaFalsa = AreaDeTransferenciaFalsa()
    ) throws -> CapturaAberta {
        let captura = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        return CapturaAberta(
            nome: Self.nome,
            documento: try Documento.novo(de: captura),
            base: captura.imagem,
            escala: captura.escala,
            rascunho: rascunho,
            renderizador: renderizador,
            painel: painel,
            areaDeTransferencia: area
        )
    }

    private func pngEsperado(de aberta: CapturaAberta) throws -> Data {
        try Exportador.png(aberta.documento, base: aberta.base, renderizador: renderizador)
    }

    // MARK: - Copiar

    @Test func copiarGravaOPngRenderizadoNaAreaDeTransferencia() throws {
        let area = AreaDeTransferenciaFalsa()
        let aberta = try aberta(area: area)

        #expect(aberta.copiar() == .concluido)

        let dados = try #require(area.dados)
        #expect(dados == (try pngEsperado(de: aberta)))
        let fonte = try #require(CGImageSourceCreateWithData(dados as CFData, nil))
        let imagem = try #require(CGImageSourceCreateImageAtIndex(fonte, 0, nil))
        #expect(imagem.width == 8)
        #expect(imagem.height == 6)
    }

    @Test func copiarComFalhaDevolveFalhou() throws {
        let aberta = try aberta(area: AreaDeTransferenciaFalsa(falhar: true))

        #expect(aberta.copiar() == .falhou(.naoFoiPossivelCopiar))
    }

    // MARK: - Salvar PNG

    @Test func salvarPNGGravaNoDestinoEscolhido() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let destino = pasta.url.appendingPathComponent("imagem.png")
        let painel = PainelFalso(destino: destino)
        let aberta = try aberta(painel: painel)

        #expect(await aberta.salvarPNG() == .concluido)

        #expect(try Data(contentsOf: destino) == (try pngEsperado(de: aberta)))
        #expect(painel.pedidos.count == 1)
        #expect(painel.pedidos.first?.nomeSugerido == Self.nome)
        #expect(painel.pedidos.first?.extensao == "png")
    }

    @Test(arguments: [false, true])
    func painelCanceladoDevolveCanceladoESemEfeito(capta: Bool) async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let area = AreaDeTransferenciaFalsa()
        let aberta = try aberta(rascunho: .falhou, area: area)

        let resultado = capta ? await aberta.salvarCapta() : await aberta.salvarPNG()

        #expect(resultado == .cancelado)
        #expect(try pasta.conteudo().isEmpty)
        #expect(area.dados == nil)
    }

    @Test func salvarPNGEmDestinoInvalidoDevolveFalhou() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let destino = pasta.url.appendingPathComponent("nao-existe/imagem.png")
        let aberta = try aberta(painel: PainelFalso(destino: destino))

        #expect(await aberta.salvarPNG() == .falhou(.naoFoiPossivelSalvar))
        #expect(try pasta.conteudo().isEmpty)
    }

    // MARK: - Salvar Capta

    @Test func salvarCaptaCopiaORascunhoGravado() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        // O rascunho tem outra imagem: o pacote salvo prova que veio dele, não da memória.
        let outra = ImagemCapturada(imagem: try imagemDeTeste(verde: 1), escala: 2)
        let rascunho = try Rascunho.gravar(
            outra,
            documento: try Documento.novo(de: outra),
            em: pasta.url,
            nome: "rascunho"
        )
        let destino = pasta.url.appendingPathComponent("salvo.capta", isDirectory: true)
        let painel = PainelFalso(destino: destino)
        let aberta = try aberta(rascunho: .gravado(rascunho), painel: painel)

        #expect(await aberta.salvarCapta() == .concluido)

        let salvo = try PacoteCapta.ler(de: destino)
        let original = try PacoteCapta.ler(de: rascunho)
        #expect(salvo.baseDados == original.baseDados)
        #expect(salvo.documento == original.documento)
        #expect(painel.pedidos.first?.nomeSugerido == Self.nome)
        #expect(painel.pedidos.first?.extensao == PacoteCapta.extensao)
    }

    @Test func salvarCaptaComRascunhoFalhoGravaDaMemoria() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let destino = pasta.url.appendingPathComponent("salvo.capta", isDirectory: true)
        let aberta = try aberta(rascunho: .falhou, painel: PainelFalso(destino: destino))

        #expect(await aberta.salvarCapta() == .concluido)

        let salvo = try PacoteCapta.ler(de: destino)
        #expect(salvo.documento == aberta.documento)
        #expect(salvo.baseDados == (try CodificadorPNG.codificar(aberta.base, escala: 2)))
        #expect(salvo.miniaturaDados?.isEmpty == false)
    }

    @Test func salvarCaptaEmDestinoInvalidoDevolveFalhou() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let destino = pasta.url.appendingPathComponent("nao-existe/salvo.capta")
        let aberta = try aberta(rascunho: .falhou, painel: PainelFalso(destino: destino))

        #expect(await aberta.salvarCapta() == .falhou(.naoFoiPossivelSalvar))
        #expect(try pasta.conteudo().isEmpty)
    }

    @Test func avisoSoApareceQuandoORascunhoFalha() throws {
        let aberta = try aberta(rascunho: .gravando)
        #expect(aberta.aviso == nil)

        aberta.rascunho = .gravado(URL(fileURLWithPath: "/rascunho.capta"))
        #expect(aberta.aviso == nil)

        aberta.rascunho = .falhou
        #expect(aberta.aviso == .rascunhoNaoGuardado)
    }

    @Test func podeSalvarCaptaSoDepoisDaGravacao() throws {
        let aberta = try aberta(rascunho: .gravando)
        #expect(!aberta.podeSalvarCapta)

        aberta.rascunho = .gravado(URL(fileURLWithPath: "/rascunho.capta"))
        #expect(aberta.podeSalvarCapta)

        aberta.rascunho = .falhou
        #expect(aberta.podeSalvarCapta)
    }
}
