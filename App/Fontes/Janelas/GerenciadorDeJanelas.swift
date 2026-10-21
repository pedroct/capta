import AppKit
import CaptaSistema
import SwiftUI

/// Abre e acompanha as janelas do app: uma por captura e uma única de ajuda de permissão.
///
/// Não guarda o `FluxoDeCaptura` (ele guarda este apresentador); o "Tentar de novo" chega pela
/// closure `tentarDeNovo`, atribuída depois da construção.
@MainActor
final class GerenciadorDeJanelas: NSObject, Apresentador, NSWindowDelegate {
    /// Refaz a captura quando a pessoa pede "Tentar de novo" na ajuda.
    var tentarDeNovo: (@MainActor () -> Void)?

    private var janelasDeCaptura: [NSWindow] = []
    private var janelaDeAjuda: NSWindow?
    private let modeloDeAjuda = AjudaDePermissaoModelo()
    private var aguardandoResultadoDoNovoTeste = false

    // MARK: Apresentador

    func mostrarAjudaDePermissao() {
        if aguardandoResultadoDoNovoTeste {
            aguardandoResultadoDoNovoTeste = false
            modeloDeAjuda.tentouDeNovoSemSucesso()
        }
        if let janela = janelaDeAjuda {
            exibir(janela)
            return
        }
        let visao = JanelaDeAjudaView(
            modelo: modeloDeAjuda,
            abrirConfiguracoes: {
                NSWorkspace.shared.open(ConfiguracoesDoSistema.urlGravacaoDeTela)
            },
            tentarDeNovo: { [weak self] in
                self?.aguardandoResultadoDoNovoTeste = true
                self?.tentarDeNovo?()
            },
            reiniciar: { Self.reiniciar() }
        )
        let janela = criarJanela(
            com: visao,
            titulo: String(localized: "Permissão de Gravação de Tela")
        )
        janela.styleMask.remove(.resizable)
        janelaDeAjuda = janela
        exibir(janela)
    }

    func mostrarCaptura(_ captura: CapturaAberta) {
        // A captura deu certo: a ajuda, se estava aberta, não é mais necessária.
        aguardandoResultadoDoNovoTeste = false
        janelaDeAjuda?.close()

        let visao = JanelaDeCapturaView(
            captura: captura,
            mostrarAlerta: { [weak self] in self?.mostrarAlerta($0) }
        )
        let janela = criarJanela(com: visao, titulo: captura.nome)
        let tela = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size
        let largura = min(captura.base.width.pontos(captura.escala), (tela?.width ?? 1280) * 0.8)
        let altura = min(captura.base.height.pontos(captura.escala), (tela?.height ?? 800) * 0.8)
        janela.setContentSize(NSSize(width: max(largura, 480), height: max(altura, 320) + 52))
        janela.center()
        janelasDeCaptura.append(janela)
        exibir(janela)
    }

    func mostrarAlerta(_ mensagem: MensagemDeErro) {
        let alerta = NSAlert()
        alerta.messageText = mensagem.texto
        alerta.addButton(withTitle: String(localized: "OK"))
        NSApp.activate()
        alerta.runModal()
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let janela = notification.object as? NSWindow else { return }
        janela.delegate = nil
        janelasDeCaptura.removeAll { $0 === janela }
        if janelaDeAjuda === janela { janelaDeAjuda = nil }
        aplicarPolitica()
    }

    // MARK: Privado

    private func criarJanela<V: View>(com visao: V, titulo: String) -> NSWindow {
        let controlador = NSHostingController(rootView: visao)
        controlador.sizingOptions = []
        let janela = NSWindow(contentViewController: controlador)
        janela.title = titulo
        janela.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        janela.isReleasedWhenClosed = false
        janela.delegate = self
        return janela
    }

    private func exibir(_ janela: NSWindow) {
        aplicarPolitica()
        NSApp.activate()
        janela.makeKeyAndOrderFront(nil)
    }

    private func aplicarPolitica() {
        let total = janelasDeCaptura.count + (janelaDeAjuda == nil ? 0 : 1)
        NSApp.setActivationPolicy(PoliticaDeAtivacao.para(janelasAbertas: total))
    }

    /// Abre uma nova instância do app e encerra a atual.
    private static func reiniciar() {
        Task { @MainActor in
            let configuracao = NSWorkspace.OpenConfiguration()
            configuracao.createsNewApplicationInstance = true
            do {
                _ = try await NSWorkspace.shared.openApplication(
                    at: Bundle.main.bundleURL,
                    configuration: configuracao
                )
                NSApp.terminate(nil)
            } catch {
                RegistroDeCaptura.falha("reiniciar", error)
            }
        }
    }
}

extension Int {
    fileprivate func pontos(_ escala: Double) -> Double { Double(self) / escala }
}
