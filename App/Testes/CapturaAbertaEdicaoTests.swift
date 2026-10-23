import CaptaNucleo
import CaptaSistema
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import Capta

@Suite("Captura aberta: edição e salvamento")
@MainActor
struct CapturaAbertaEdicaoTests {
    static let nome = "Captura 2027-01-15 às 08.00.00"
    let renderizador = Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF())

    /// Captura com salvamento de mentira: o relógio só anda quando o teste manda.
    private func abertaComSalvamento(
        rascunho: CapturaAberta.EstadoRascunho,
        relogio: RelogioFalso,
        gravador: GravadorDeDocumentoFalso,
        gravadorDeRascunho: @escaping FluxoDeCaptura.GravadorDeRascunho = { _, _, _, _ in
            throw ErroDeTeste()
        },
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
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: area,
            gravadorDeRascunho: gravadorDeRascunho,
            salvamento: SalvamentoAutomatico(
                dormir: { try await relogio.dormir($0) },
                gravar: { try await gravador.gravar($0, $1) }
            )
        )
    }

    private static let recorte = Edicao.definirRecorte(CGRect(x: 0, y: 0, width: 4, height: 3))
    private let rascunhoGravado = URL(fileURLWithPath: "/rascunho.capta")

    @Test func aplicarMudaODocumentoEAgendaOSalvamento() async throws {
        let relogio = RelogioFalso()
        let gravador = GravadorDeDocumentoFalso()
        let aberta = try abertaComSalvamento(
            rascunho: .gravado(rascunhoGravado),
            relogio: relogio,
            gravador: gravador
        )
        #expect(!aberta.podeDesfazer && !aberta.podeRefazer)

        #expect(aberta.aplicar(Self.recorte))

        #expect(aberta.documento.recorte == CGRect(x: 0, y: 0, width: 4, height: 3))
        #expect(aberta.podeDesfazer)
        #expect(aberta.estadoDoSalvamento == .pendente)
        await aberta.salvarAgora()
        #expect(await gravador.concluidas == [aberta.documento])
        #expect(await gravador.urls == [rascunhoGravado])
        #expect(aberta.estadoDoSalvamento == .salvo)
    }

    @Test func aplicarInvalidaNaoMudaNadaNemAgenda() async throws {
        let relogio = RelogioFalso()
        let gravador = GravadorDeDocumentoFalso()
        let aberta = try abertaComSalvamento(
            rascunho: .gravado(rascunhoGravado),
            relogio: relogio,
            gravador: gravador
        )
        let antes = aberta.documento

        let invalida = Edicao.remover([UUID()])
        #expect(!aberta.aplicar(invalida))

        #expect(aberta.documento == antes)
        #expect(!aberta.podeDesfazer)
        #expect(aberta.estadoDoSalvamento == .salvo)
        await aberta.salvarAgora()
        #expect(await gravador.iniciadas.isEmpty)
    }

    @Test func desfazerERefazerAgendam() async throws {
        let relogio = RelogioFalso()
        let gravador = GravadorDeDocumentoFalso()
        let aberta = try abertaComSalvamento(
            rascunho: .gravado(rascunhoGravado),
            relogio: relogio,
            gravador: gravador
        )
        let original = aberta.documento
        aberta.aplicar(Self.recorte)
        let editado = aberta.documento
        await aberta.salvarAgora()

        aberta.desfazer()
        #expect(aberta.documento == original)
        #expect(aberta.podeRefazer)
        #expect(aberta.estadoDoSalvamento == .pendente)
        await aberta.salvarAgora()

        aberta.refazer()
        #expect(aberta.documento == editado)
        #expect(aberta.estadoDoSalvamento == .pendente)
        await aberta.salvarAgora()

        #expect(await gravador.concluidas == [editado, original, editado])
    }

    @Test func desfazerERefazerSemHistoricoNaoAgendam() async throws {
        let relogio = RelogioFalso()
        let gravador = GravadorDeDocumentoFalso()
        let aberta = try abertaComSalvamento(
            rascunho: .gravado(rascunhoGravado),
            relogio: relogio,
            gravador: gravador
        )

        aberta.desfazer()
        aberta.refazer()

        #expect(aberta.estadoDoSalvamento == .salvo)
    }

    @Test func edicaoDuranteGravandoSalvaQuandoORascunhoTerminar() async throws {
        let relogio = RelogioFalso()
        let gravador = GravadorDeDocumentoFalso()
        let aberta = try abertaComSalvamento(
            rascunho: .gravando,
            relogio: relogio,
            gravador: gravador
        )

        aberta.aplicar(Self.recorte)
        await aberta.salvarAgora()
        #expect(await gravador.iniciadas.isEmpty)

        aberta.rascunho = .gravado(rascunhoGravado)
        await aberta.salvarAgora()

        #expect(await gravador.concluidas == [aberta.documento])
        #expect(await gravador.urls == [rascunhoGravado])
    }

    @Test func rascunhoQueFalhouERecriadoNoPrimeiroSalvamento() async throws {
        let relogio = RelogioFalso()
        let gravador = GravadorDeDocumentoFalso()
        let recriado = URL(fileURLWithPath: "/recriado.capta")
        let pedidos = PedidosDeRascunho()
        let aberta = try abertaComSalvamento(
            rascunho: .falhou,
            relogio: relogio,
            gravador: gravador,
            gravadorDeRascunho: { _, documento, _, nome in
                pedidos.registrar(documento, nome)
                return recriado
            }
        )
        #expect(aberta.aviso == .rascunhoNaoGuardado)

        aberta.aplicar(Self.recorte)
        await aberta.aguardarRascunho()

        #expect(aberta.rascunho == .gravado(recriado))
        #expect(aberta.aviso == nil)
        #expect(pedidos.documentos == [aberta.documento])
        #expect(pedidos.nomes == [Self.nome])
        // O rascunho recriado já nasce com o documento atual: nada a regravar.
        await aberta.salvarAgora()
        #expect(await gravador.iniciadas.isEmpty)
    }

    @Test func rascunhoQueSegueFalhandoMantemOAvisoETentaDeNovoNaProximaEdicao() async throws {
        let relogio = RelogioFalso()
        let gravador = GravadorDeDocumentoFalso()
        let aberta = try abertaComSalvamento(
            rascunho: .falhou,
            relogio: relogio,
            gravador: gravador
        )

        aberta.aplicar(Self.recorte)
        await aberta.aguardarRascunho()

        #expect(aberta.rascunho == .falhou)
        #expect(aberta.aviso == .rascunhoNaoGuardado)
        #expect(await gravador.iniciadas.isEmpty)
    }

    @Test func edicaoQueChegaDuranteARecriacaoSalvaDepois() async throws {
        let relogio = RelogioFalso()
        let gravador = GravadorDeDocumentoFalso()
        let portao = Portao()
        let recriado = URL(fileURLWithPath: "/recriado.capta")
        let aberta = try abertaComSalvamento(
            rascunho: .falhou,
            relogio: relogio,
            gravador: gravador,
            gravadorDeRascunho: { _, _, _, _ in
                await portao.esperar()
                return recriado
            }
        )
        aberta.aplicar(Self.recorte)
        let segunda = Edicao.definirRecorte(CGRect(x: 0, y: 0, width: 5, height: 3))
        aberta.aplicar(segunda)

        await portao.abrir()
        await aberta.aguardarRascunho()
        await aberta.salvarAgora()

        #expect(await gravador.concluidas == [aberta.documento])
        #expect(await gravador.urls == [recriado])
    }

    @Test func copiarUsaODocumentoAtual() async throws {
        let area = AreaDeTransferenciaFalsa()
        let aberta = try abertaComSalvamento(
            rascunho: .gravando,
            relogio: RelogioFalso(),
            gravador: GravadorDeDocumentoFalso(),
            area: area
        )
        aberta.aplicar(Self.recorte)

        #expect(await aberta.copiar() == .concluido)

        let dados = try #require(area.dados)
        let fonte = try #require(CGImageSourceCreateWithData(dados as CFData, nil))
        let imagem = try #require(CGImageSourceCreateImageAtIndex(fonte, 0, nil))
        #expect(imagem.width == 4)
        #expect(imagem.height == 3)
    }

    @Test func salvarCaptaDoRascunhoLevaOSalvamentoPendente() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let captura = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        let documento = try Documento.novo(de: captura)
        let rascunho = try Rascunho.gravar(captura, documento: documento, em: pasta.url, nome: "r")
        let destino = pasta.url.appendingPathComponent("salvo.capta", isDirectory: true)
        let aberta = CapturaAberta(
            nome: Self.nome,
            documento: documento,
            base: captura.imagem,
            escala: 2,
            rascunho: .gravado(rascunho),
            renderizador: renderizador,
            painel: PainelFalso(destino: destino),
            areaDeTransferencia: AreaDeTransferenciaFalsa()
        )
        aberta.aplicar(Self.recorte)

        #expect(await aberta.salvarCapta() == .concluido)

        let salvo = try PacoteCapta.ler(de: destino)
        #expect(salvo.documento == aberta.documento)
        #expect(salvo.documento.recorte != nil)
    }

    @Test func gravadorPadraoAtualizaODocumentoDoRascunhoEAMiniatura() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let captura = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        let rascunho = try Rascunho.gravar(
            captura,
            documento: try Documento.novo(de: captura),
            em: pasta.url,
            nome: "r"
        )
        let novo = try documentoComRecorte(largura: 4)

        try await CapturaAberta.gravadorPadrao(base: captura, renderizador: renderizador)(
            novo,
            rascunho
        )

        let lido = try PacoteCapta.ler(de: rascunho)
        #expect(lido.documento == novo)
        #expect(lido.miniaturaDados?.isEmpty == false)
    }
}

/// Pedidos de recriação do rascunho, registrados de dentro de uma closure `@Sendable`.
final class PedidosDeRascunho: @unchecked Sendable {
    private let trava = NSLock()
    private var _documentos: [Documento] = []
    private var _nomes: [String] = []

    var documentos: [Documento] { trava.withLock { _documentos } }
    var nomes: [String] { trava.withLock { _nomes } }

    func registrar(_ documento: Documento, _ nome: String) {
        trava.withLock {
            _documentos.append(documento)
            _nomes.append(nome)
        }
    }
}
