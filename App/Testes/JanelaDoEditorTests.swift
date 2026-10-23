import AppKit
import CaptaNucleo
import CaptaSistema
import SwiftUI
import Testing

@testable import Capta

/// A janela de uma captura hospeda o editor. Abre uma janela real no app dos testes e a fecha.
@Suite("Janela do editor", .serialized)
@MainActor
struct JanelaDoEditorTests {
    private func captura() throws -> CapturaAberta {
        let imagem = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        return CapturaAberta(
            nome: "Captura de teste",
            documento: try Documento.novo(de: imagem),
            base: imagem.imagem,
            escala: imagem.escala,
            rascunho: .gravando,
            renderizador: Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF()),
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa()
        )
    }

    @Test func mostrarCapturaAbreAJanelaComOEditor() throws {
        let nome = "capta.testes.janela.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: nome))
        defer { defaults.removePersistentDomain(forName: nome) }
        let gerenciador = GerenciadorDeJanelas(defaults: defaults)
        let aberta = try captura()
        defer { gerenciador.janelasDeCaptura.forEach { $0.close() } }

        gerenciador.mostrarCaptura(aberta)

        let janela = try #require(gerenciador.janelasDeCaptura.first)
        let controlador = janela.contentViewController as? NSHostingController<JanelaDoEditorView>
        let editor = try #require(controlador).rootView.editor
        #expect(editor.captura === aberta)
        #expect(editor.estado.ferramenta == .selecao)
        #expect(janela.contentMinSize == Enquadramento.tamanhoMinimo)
    }

    @Test func oEditorLembraOEstiloNasDefaultsDoGerenciador() throws {
        let nome = "capta.testes.janela.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: nome))
        defer { defaults.removePersistentDomain(forName: nome) }
        let gerenciador = GerenciadorDeJanelas(defaults: defaults)
        defer { gerenciador.janelasDeCaptura.forEach { $0.close() } }
        gerenciador.mostrarCaptura(try captura())

        let janela = try #require(gerenciador.janelasDeCaptura.first)
        let controlador = janela.contentViewController as? NSHostingController<JanelaDoEditorView>
        let editor = try #require(controlador).rootView.editor
        editor.comandar(.escolher(.linha))
        editor.comandar(.alterarEstilo(.largura(17)))

        #expect(MemoriaLembrada(defaults: defaults).memoria[.linha].largura == 17)
    }
}
