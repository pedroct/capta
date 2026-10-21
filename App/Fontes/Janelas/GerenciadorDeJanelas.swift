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

    // MARK: Apresentador

    func mostrarAjudaDePermissao() {
        modeloDeAjuda.permissaoSegueNegada()
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
                self?.modeloDeAjuda.tentouDeNovo()
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
        // A captura deu certo: a ajuda, se estava aberta, não é mais necessária, e uma
        // revogação futura a abre do começo, sem o botão de reiniciar.
        modeloDeAjuda.reiniciarEstado()
        janelaDeAjuda?.close()

        // A janela nasce depois da view; a referência fraca deixa o alerta achá-la depois.
        let referencia = ReferenciaDeJanela()
        let visao = JanelaDeCapturaView(
            captura: captura,
            mostrarAlerta: { [weak self] in self?.mostrarAlerta($0, em: referencia.janela) }
        )
        let janela = criarJanela(com: visao, titulo: captura.nome)
        referencia.janela = janela
        // Abre na tela do cursor, que é a tela capturada, e não na tela principal.
        let cursor = NSEvent.mouseLocation
        let tela =
            NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main
            ?? NSScreen.screens.first
        let imagem = CGSize(
            width: Double(captura.base.width) / captura.escala,
            height: Double(captura.base.height) / captura.escala
        )
        janela.setContentSize(
            Enquadramento.tamanhoInicial(imagem: imagem, telaVisivel: tela?.visibleFrame.size)
        )
        if let area = tela?.visibleFrame {
            janela.setFrameOrigin(Enquadramento.origemCentralizada(janela.frame.size, em: area))
        } else {
            janela.center()
        }
        janelasDeCaptura.append(janela)
        exibir(janela)
    }

    /// Alerta do fluxo (a captura falhou): em folha sobre a ajuda, se ela está aberta, porque
    /// foi dali que veio o "Tentar de novo"; senão, alerta do app.
    func mostrarAlerta(_ mensagem: MensagemDeErro) {
        // Se veio de um "Tentar de novo", o novo teste acabou aqui, e não por permissão.
        modeloDeAjuda.novoTesteFalhouPorOutroMotivo()
        mostrarAlerta(mensagem, em: janelaDeAjuda)
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

    /// Em folha sobre `janela` quando ela está na tela e livre; sem janela, alerta modal do app.
    private func mostrarAlerta(_ mensagem: MensagemDeErro, em janela: NSWindow?) {
        let alerta = NSAlert()
        alerta.messageText = mensagem.texto
        alerta.addButton(withTitle: String(localized: "OK"))
        NSApp.activate()
        if let janela, janela.isVisible, janela.attachedSheet == nil {
            janela.makeKeyAndOrderFront(nil)
            alerta.beginSheetModal(for: janela, completionHandler: nil)
            return
        }
        alerta.runModal()
    }

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

/// Guarda, sem reter, a janela de uma captura para a closure de alerta da sua view.
@MainActor
private final class ReferenciaDeJanela {
    weak var janela: NSWindow?
}
