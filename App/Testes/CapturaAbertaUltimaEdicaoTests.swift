import CaptaNucleo
import CaptaSistema
import CoreGraphics
import Foundation
import Testing

@testable import Capta

/// Bordas em que a última edição podia se perder: "não existe estado não salvo" (spec §4.8).
@Suite("Captura aberta: a última edição nunca se perde")
@MainActor
struct CapturaAbertaUltimaEdicaoTests {
    static let nome = "Captura 2027-01-15 às 08.00.00"
    private static let recorte = Edicao.definirRecorte(CGRect(x: 0, y: 0, width: 4, height: 3))
    private let renderizador = Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF())
    private let gravado = URL(fileURLWithPath: "/rascunho.capta")

    private func aberta(
        rascunho: CapturaAberta.EstadoRascunho,
        gravador: GravadorDeDocumentoFalso,
        painel: PainelFalso = PainelFalso(destino: nil),
        gravadorDeRascunho: @escaping FluxoDeCaptura.GravadorDeRascunho = { _, _, _, _ in
            throw ErroDeTeste()
        }
    ) throws -> CapturaAberta {
        let captura = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        let relogio = RelogioFalso()
        return CapturaAberta(
            nome: Self.nome,
            documento: try Documento.novo(de: captura),
            base: captura.imagem,
            escala: captura.escala,
            rascunho: rascunho,
            renderizador: renderizador,
            painel: painel,
            areaDeTransferencia: AreaDeTransferenciaFalsa(),
            gravadorDeRascunho: gravadorDeRascunho,
            salvamento: SalvamentoAutomatico(
                dormir: { try await relogio.dormir($0) },
                gravar: { try await gravador.gravar($0, $1) }
            )
        )
    }

    /// Cede a vez até a tarefa de `salvarAgora` ter tido chance de rodar.
    private func ceder() async {
        for _ in 0..<50 { await Task.yield() }
    }

    @Test func salvarAgoraEsperaORascunhoTerminarDeGravar() async throws {
        let gravador = GravadorDeDocumentoFalso()
        let captura = try aberta(rascunho: .gravando, gravador: gravador)
        captura.aplicar(Self.recorte)

        let fechamento = Task { await captura.salvarAgora() }
        await ceder()
        #expect(await gravador.iniciadas.isEmpty)
        captura.rascunho = .gravado(gravado)
        await fechamento.value

        #expect(await gravador.concluidas == [captura.documento])
        #expect(await gravador.urls == [gravado])
    }

    @Test func salvarAgoraSemEdicaoNaoGravaNadaAoSairDeGravando() async throws {
        let gravador = GravadorDeDocumentoFalso()
        let captura = try aberta(rascunho: .gravando, gravador: gravador)

        let fechamento = Task { await captura.salvarAgora() }
        await ceder()
        captura.rascunho = .gravado(gravado)
        await fechamento.value

        #expect(await gravador.iniciadas.isEmpty)
    }

    @Test func edicaoDuranteGravandoRecriaORascunhoSeEleFalhar() async throws {
        let recriado = URL(fileURLWithPath: "/recriado.capta")
        let pedidos = PedidosDeRascunho()
        let captura = try aberta(
            rascunho: .gravando,
            gravador: GravadorDeDocumentoFalso(),
            gravadorDeRascunho: { _, documento, _, nome in
                pedidos.registrar(documento, nome)
                return recriado
            }
        )
        captura.aplicar(Self.recorte)

        captura.rascunho = .falhou
        await captura.aguardarRascunho()

        #expect(captura.rascunho == .gravado(recriado))
        #expect(captura.aviso == nil)
        #expect(pedidos.documentos == [captura.documento])
    }

    @Test func salvarAgoraDepoisDeGravandoQueFalhouRecriaEGravaODocumentoAtual() async throws {
        let recriado = URL(fileURLWithPath: "/recriado.capta")
        let pedidos = PedidosDeRascunho()
        let gravador = GravadorDeDocumentoFalso()
        let captura = try aberta(
            rascunho: .gravando,
            gravador: gravador,
            gravadorDeRascunho: { _, documento, _, nome in
                pedidos.registrar(documento, nome)
                return recriado
            }
        )
        captura.aplicar(Self.recorte)

        let fechamento = Task { await captura.salvarAgora() }
        await ceder()
        captura.rascunho = .falhou
        await fechamento.value

        // O rascunho refeito já leva o documento atual.
        #expect(captura.rascunho == .gravado(recriado))
        #expect(pedidos.documentos == [captura.documento])
    }

    @Test func gravandoQueFalhaSemEdicaoNaoRecriaNada() async throws {
        let pedidos = PedidosDeRascunho()
        let captura = try aberta(
            rascunho: .gravando,
            gravador: GravadorDeDocumentoFalso(),
            gravadorDeRascunho: { _, documento, _, nome in
                pedidos.registrar(documento, nome)
                return URL(fileURLWithPath: "/x.capta")
            }
        )

        captura.rascunho = .falhou
        await captura.aguardarRascunho()

        #expect(captura.rascunho == .falhou)
        #expect(pedidos.documentos.isEmpty)
    }

    @Test func salvarCaptaComFalhaNoSalvamentoUsaODocumentoEmMemoria() async throws {
        let pasta = try PastaTemporaria()
        defer { pasta.remover() }
        let imagem = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        let original = try Documento.novo(de: imagem)
        let rascunho = try Rascunho.gravar(imagem, documento: original, em: pasta.url, nome: "r")
        let destino = pasta.url.appendingPathComponent("salvo.capta", isDirectory: true)
        let captura = try aberta(
            rascunho: .gravado(rascunho),
            gravador: GravadorDeDocumentoFalso(falhar: true),
            painel: PainelFalso(destino: destino)
        )
        captura.aplicar(Self.recorte)

        #expect(await captura.salvarCapta() == .concluido)

        #expect(captura.estadoDoSalvamento == .falhou)
        let salvo = try PacoteCapta.ler(de: destino)
        #expect(salvo.documento == captura.documento)
        #expect(salvo.documento != original)
        // O rascunho em disco segue como estava: o fallback não o toca.
        #expect(try PacoteCapta.ler(de: rascunho).documento == original)
    }
}
