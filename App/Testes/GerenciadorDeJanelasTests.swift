import AppKit
import CaptaNucleo
import CaptaSistema
import SwiftUI
import Testing

@testable import Capta

/// Abre janelas reais no app que hospeda os testes. Cada teste fecha o que abriu (o que também
/// devolve a política de ativação a `.accessory`, a do `LSUIElement`) e nenhum chama um caminho
/// que acabe em `runModal()`, que prenderia o teste.
@Suite("Gerenciador de janelas", .serialized)
@MainActor
struct GerenciadorDeJanelasTests {
    private func captura(nome: String = "Captura de teste") throws -> CapturaAberta {
        let imagem = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        return CapturaAberta(
            nome: nome,
            documento: try Documento.novo(de: imagem),
            base: imagem.imagem,
            escala: imagem.escala,
            rascunho: .gravando,
            renderizador: Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF()),
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa()
        )
    }

    /// Captura com rascunho gravado e salvamento de mentira.
    private func capturaComSalvamento(
        relogio: RelogioFalso,
        gravador: GravadorDeDocumentoFalso
    ) throws -> CapturaAberta {
        let imagem = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        return CapturaAberta(
            nome: "Captura de teste",
            documento: try Documento.novo(de: imagem),
            base: imagem.imagem,
            escala: imagem.escala,
            rascunho: .gravado(URL(fileURLWithPath: "/rascunho.capta")),
            renderizador: Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF()),
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa(),
            salvamento: SalvamentoAutomatico(
                dormir: { try await relogio.dormir($0) },
                gravar: { try await gravador.gravar($0, $1) }
            )
        )
    }

    /// Fecha as folhas e as janelas que o gerenciador acompanha.
    private func fecharTudo(_ gerenciador: GerenciadorDeJanelas) {
        let janelas = gerenciador.janelasDeCaptura + [gerenciador.janelaDeAjuda].compactMap { $0 }
        for janela in janelas {
            if let folha = janela.attachedSheet { janela.endSheet(folha) }
            janela.close()
        }
    }

    private func visaoDaAjuda(_ gerenciador: GerenciadorDeJanelas) throws -> JanelaDeAjudaView {
        let janela = try #require(gerenciador.janelaDeAjuda)
        let controlador = janela.contentViewController as? NSHostingController<JanelaDeAjudaView>
        return try #require(controlador).rootView
    }

    /// Textos dos rótulos dentro de `visao`, para conferir a mensagem de um alerta.
    private func textos(em visao: NSView?) -> [String] {
        guard let visao else { return [] }
        let proprio = (visao as? NSTextField).map { [$0.stringValue] } ?? []
        return proprio + visao.subviews.flatMap { textos(em: $0) }
    }

    // MARK: - Captura

    @Test func cadaCapturaAbreAPropriaJanelaVisivel() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }

        gerenciador.mostrarCaptura(try captura(nome: "Primeira"))
        gerenciador.mostrarCaptura(try captura(nome: "Segunda"))

        let janelas = gerenciador.janelasDeCaptura
        #expect(janelas.map(\.title) == ["Primeira", "Segunda"])
        #expect(janelas.allSatisfy { $0.isVisible && $0.delegate === gerenciador })
        #expect(!janelas.contains { $0.isReleasedWhenClosed })
        #expect(NSApp.activationPolicy() == .regular)
    }

    @Test func janelaDaCapturaNasceComOTamanhoInicialDentroDeUmaTela() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }

        // 8 x 6 pixels em escala 2 é menor que o mínimo: vale 480 x 320 mais o painel e as barras.
        gerenciador.mostrarCaptura(try captura())

        let janela = try #require(gerenciador.janelasDeCaptura.first)
        let conteudo = janela.contentRect(forFrameRect: janela.frame).size
        #expect(
            conteudo
                == CGSize(
                    width: 480 + Enquadramento.larguraDoPainel,
                    height: 320 + Enquadramento.alturaDaBarra
                )
        )
        #expect(janela.contentMinSize == Enquadramento.tamanhoMinimo)
        #expect(janela.styleMask.contains(.resizable))
        if !NSScreen.screens.isEmpty {
            #expect(NSScreen.screens.contains { $0.visibleFrame.contains(janela.frame) })
        }
    }

    @Test func fecharAJanelaDaCapturaTiraDaListaEVoltaAoAccessory() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        gerenciador.mostrarCaptura(try captura(nome: "Primeira"))
        gerenciador.mostrarCaptura(try captura(nome: "Segunda"))
        let primeira = try #require(gerenciador.janelasDeCaptura.first)

        primeira.close()

        #expect(gerenciador.janelasDeCaptura.map(\.title) == ["Segunda"])
        #expect(primeira.delegate == nil)
        #expect(NSApp.activationPolicy() == .regular)

        try #require(gerenciador.janelasDeCaptura.first).close()

        #expect(gerenciador.janelasDeCaptura.isEmpty)
        #expect(NSApp.activationPolicy() == .accessory)
    }

    @Test func avisoDeFechamentoSemJanelaNaoMudaNada() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        gerenciador.mostrarCaptura(try captura())

        gerenciador.windowWillClose(Notification(name: NSWindow.willCloseNotification))

        #expect(gerenciador.janelasDeCaptura.count == 1)
        #expect(NSApp.activationPolicy() == .regular)
    }

    @Test func falhaNaAcaoDaCapturaVemEmFolhaSobreAPropriaJanela() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        gerenciador.mostrarCaptura(try captura())
        let janela = try #require(gerenciador.janelasDeCaptura.first)
        let controlador = janela.contentViewController as? NSHostingController<JanelaDoEditorView>

        try #require(controlador).rootView.mostrarAlerta(.naoFoiPossivelCopiar)

        let folha = try #require(janela.attachedSheet)
        #expect(textos(em: folha.contentView).contains(MensagemDeErro.naoFoiPossivelCopiar.texto))
    }

    // MARK: - Salvamento ao fechar

    private let recorte = Edicao.definirRecorte(CGRect(x: 0, y: 0, width: 4, height: 3))

    @Test func fecharAJanelaSalvaOPendente() async throws {
        let relogio = RelogioFalso()
        let gravador = GravadorDeDocumentoFalso()
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        let captura = try capturaComSalvamento(relogio: relogio, gravador: gravador)
        gerenciador.mostrarCaptura(captura)
        captura.aplicar(recorte)
        let editado = captura.documento
        // O atraso ainda não passou: nada foi gravado.
        #expect(await gravador.iniciadas.isEmpty)

        try #require(gerenciador.janelasDeCaptura.first).close()
        await gerenciador.salvarTodas()

        #expect(await gravador.concluidas == [editado])
        #expect(captura.estadoDoSalvamento == .salvo)
    }

    @Test func fecharComGravacaoEmCursoEsperaTerminarAntesDeSalvarTodasVoltar() async throws {
        let relogio = RelogioFalso()
        let portao = Portao()
        let gravador = GravadorDeDocumentoFalso(portao: portao)
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        let captura = try capturaComSalvamento(relogio: relogio, gravador: gravador)
        gerenciador.mostrarCaptura(captura)
        captura.aplicar(recorte)
        await relogio.aguardarEsperas(1)
        await relogio.avancar()
        await gravador.aguardarInicio()

        try #require(gerenciador.janelasDeCaptura.first).close()
        var voltou = false
        let todas = Task { @MainActor in
            await gerenciador.salvarTodas()
            voltou = true
        }
        for _ in 0..<200 { await Task.yield() }
        #expect(!voltou)

        await portao.abrir()
        await todas.value

        #expect(voltou)
        #expect(await gravador.concluidas == [captura.documento])
    }

    @Test func salvarTodasEsperaTodas() async throws {
        let relogio = RelogioFalso()
        let gravadorA = GravadorDeDocumentoFalso()
        let gravadorB = GravadorDeDocumentoFalso()
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        let primeira = try capturaComSalvamento(relogio: relogio, gravador: gravadorA)
        let segunda = try capturaComSalvamento(relogio: relogio, gravador: gravadorB)
        gerenciador.mostrarCaptura(primeira)
        gerenciador.mostrarCaptura(segunda)
        primeira.aplicar(recorte)
        segunda.aplicar(.definirRecorte(CGRect(x: 0, y: 0, width: 5, height: 3)))

        await gerenciador.salvarTodas()

        #expect(await gravadorA.concluidas == [primeira.documento])
        #expect(await gravadorB.concluidas == [segunda.documento])
        #expect(primeira.estadoDoSalvamento == .salvo)
        #expect(segunda.estadoDoSalvamento == .salvo)
    }

    // MARK: - Ajuda de permissão

    @Test func ajudaEUnicaEReaproveitadaNaSegundaChamada() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }

        gerenciador.mostrarAjudaDePermissao()
        let primeira = try #require(gerenciador.janelaDeAjuda)
        gerenciador.mostrarAjudaDePermissao()

        #expect(gerenciador.janelaDeAjuda === primeira)
        #expect(primeira.isVisible)
        #expect(!primeira.styleMask.contains(.resizable))
        #expect(primeira.title == String(localized: "Permissão de Gravação de Tela"))
        #expect(NSApp.activationPolicy() == .regular)
    }

    @Test func fecharAAjudaEsqueceAJanelaEVoltaAoAccessory() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        gerenciador.mostrarAjudaDePermissao()
        let janela = try #require(gerenciador.janelaDeAjuda)

        janela.close()

        #expect(gerenciador.janelaDeAjuda == nil)
        #expect(NSApp.activationPolicy() == .accessory)
        // Reabrir cria uma janela nova.
        gerenciador.mostrarAjudaDePermissao()
        #expect(gerenciador.janelaDeAjuda !== janela)
    }

    @Test func capturaQueDaCertoFechaAAjuda() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        gerenciador.mostrarAjudaDePermissao()
        let ajuda = try #require(gerenciador.janelaDeAjuda)

        gerenciador.mostrarCaptura(try captura())

        #expect(gerenciador.janelaDeAjuda == nil)
        #expect(!ajuda.isVisible)
        #expect(gerenciador.janelasDeCaptura.count == 1)
    }

    @Test func tentarDeNovoChamaOFluxoEMostraReiniciarSeAPermissaoSegueNegada() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        var pedidos = 0
        gerenciador.tentarDeNovo = { pedidos += 1 }
        gerenciador.mostrarAjudaDePermissao()
        let visao = try visaoDaAjuda(gerenciador)
        #expect(!visao.modelo.mostraReiniciar)

        visao.tentarDeNovo()
        #expect(pedidos == 1)
        // O fluxo volta a pedir a ajuda: a permissão segue negada.
        gerenciador.mostrarAjudaDePermissao()

        #expect(visao.modelo.mostraReiniciar)
    }

    @Test func capturaQueDaCertoApagaOReiniciarDaProximaAjuda() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        gerenciador.mostrarAjudaDePermissao()
        let modelo = try visaoDaAjuda(gerenciador).modelo
        try visaoDaAjuda(gerenciador).tentarDeNovo()
        gerenciador.mostrarAjudaDePermissao()
        #expect(modelo.mostraReiniciar)

        gerenciador.mostrarCaptura(try captura())
        gerenciador.mostrarAjudaDePermissao()

        #expect(!modelo.mostraReiniciar)
        #expect(try !visaoDaAjuda(gerenciador).modelo.mostraReiniciar)
    }

    @Test func alertaDoFluxoVemEmFolhaSobreAAjudaENaoMostraReiniciar() throws {
        let gerenciador = GerenciadorDeJanelas()
        defer { fecharTudo(gerenciador) }
        gerenciador.mostrarAjudaDePermissao()
        let ajuda = try #require(gerenciador.janelaDeAjuda)
        let visao = try visaoDaAjuda(gerenciador)

        // O novo teste termina em outro erro, e não por permissão.
        visao.tentarDeNovo()
        gerenciador.mostrarAlerta(.capturaFalhou)

        let folha = try #require(ajuda.attachedSheet)
        #expect(textos(em: folha.contentView).contains(MensagemDeErro.capturaFalhou.texto))
        #expect(!visao.modelo.aguardandoNovoTeste)
        #expect(!visao.modelo.mostraReiniciar)
    }
}
