import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

@Suite("Fluxo de captura: reabrir enquanto a janela fecha")
@MainActor
struct FluxoDeCapturaRecentesFechamentoTests: PacotesRecentesDeTeste {
    private static let recorte = Edicao.definirRecorte(CGRect(x: 0, y: 0, width: 4, height: 3))

    @Test func reabrirEsperaOFechamentoGravarAUltimaEdicao() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let url = try pacote(em: pasta.url)
        let defaults = try DefaultsTemporarios()
        defer { defaults.remover() }
        let apresentador = ApresentadorFalso()
        let portao = Portao()
        let gravador = GravadorDeDocumentoFalso(portao: portao)

        // A janela que está fechando ainda tem uma edição por gravar, e a gravação demora.
        let imagem = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        let fechando = CapturaAberta(
            nome: "Captura antiga",
            documento: try PacoteCapta.ler(de: url).documento,
            base: imagem.imagem,
            escala: 2,
            rascunho: .gravado(url),
            renderizador: Renderizador(),
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa(),
            salvamento: SalvamentoAutomatico(
                dormir: { _ in try await Task.sleep(for: .seconds(60)) },
                gravar: { documento, destino in
                    try await gravador.gravar(documento, destino)
                    try PacoteCapta.atualizar(documento, miniaturaDados: nil, em: destino)
                }
            )
        )
        fechando.aplicar(Self.recorte)
        apresentador.iniciarFechamento(fechando)
        await portao.aguardarAlguemPreso()

        let fluxo = fluxo(apresentador: apresentador, defaults: defaults.defaults, pasta: pasta.url)
        let reabertura = Task { await fluxo.abrirRecente(url) }
        try await Task.sleep(for: .milliseconds(300))
        // Enquanto o fechamento não termina, o fluxo não pode ter lido o documento velho.
        #expect(apresentador.capturas.isEmpty)

        await portao.abrir()
        await reabertura.value

        let aberta = try #require(apresentador.capturas.first)
        #expect(aberta.documento == fechando.documento)
        #expect(aberta.documento.recorte == CGRect(x: 0, y: 0, width: 4, height: 3))
    }
}
