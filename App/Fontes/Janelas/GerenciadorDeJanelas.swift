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

    /// Leitura liberada para os testes; só o gerenciador muda.
    private(set) var janelasDeCaptura: [NSWindow] = []
    private(set) var janelaDeAjuda: NSWindow?
    private let modeloDeAjuda = AjudaDePermissaoModelo()
    /// Onde o editor guarda o último estilo de cada ferramenta.
    private let defaults: UserDefaults
    /// A captura de cada janela, para salvar o pendente ao fechar e ao encerrar o app.
    private var capturas: [ObjectIdentifier: CapturaAberta] = [:]
    /// Salvamentos disparados pelo fechamento de janelas que ainda não terminaram.
    private var fechamentos: [UUID: Task<Void, Never>] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
    }

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
        let editor = EditorDaCaptura(captura: captura, memoria: MemoriaLembrada(defaults: defaults))
        let visao = JanelaDoEditorView(
            editor: editor,
            mostrarAlerta: { [weak self] in self?.mostrarAlerta($0, em: referencia.janela) }
        )
        let janela = criarJanela(com: visao, titulo: captura.nome)
        referencia.janela = janela
        // Abre na tela do cursor, que é a tela capturada, e não na tela principal.
        let tela = Enquadramento.tela(
            sob: NSEvent.mouseLocation,
            entre: NSScreen.screens,
            quadro: \.frame,
            padrao: NSScreen.main ?? NSScreen.screens.first
        )
        let imagem = Enquadramento.pontos(
            larguraEmPixels: captura.base.width,
            alturaEmPixels: captura.base.height,
            escala: captura.escala
        )
        janela.contentMinSize = Enquadramento.tamanhoMinimo
        janela.setContentSize(
            Enquadramento.tamanhoInicial(imagem: imagem, telaVisivel: tela?.visibleFrame.size)
        )
        if let area = tela?.visibleFrame {
            janela.setFrameOrigin(Enquadramento.origemCentralizada(janela.frame.size, em: area))
        } else {
            janela.center()
        }
        janelasDeCaptura.append(janela)
        capturas[ObjectIdentifier(janela)] = captura
        exibir(janela)
    }

    /// Grava o que está pendente em todas as capturas, abertas ou em fechamento, e só volta
    /// com tudo no disco. É o que o encerramento do app espera.
    func salvarTodas() async {
        let abertas = Array(capturas.values)
        let fechando = Array(fechamentos.values)
        for captura in abertas { await captura.salvarAgora() }
        for tarefa in fechando { await tarefa.value }
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
        if let captura = capturas.removeValue(forKey: ObjectIdentifier(janela)) {
            // A tarefa segura a captura até gravar; o app não pergunta, só garante o disco.
            let identificador = UUID()
            fechamentos[identificador] = Task {
                await captura.salvarAgora()
                fechamentos[identificador] = nil
            }
        }
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
        let estado = janela.map { (visivel: $0.isVisible, comFolhaAberta: $0.attachedSheet != nil) }
        if let janela, DestinoDoAlerta.para(estado) == .folha {
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
        NSApp.setActivationPolicy(
            PoliticaDeAtivacao.para(
                janelasDeCaptura: janelasDeCaptura.count,
                ajudaAberta: janelaDeAjuda != nil
            )
        )
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
