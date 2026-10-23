import AppKit
import CaptaNucleo
import CaptaSistema
import Observation
import SwiftUI

/// Única fiação do app: compõe os adaptadores do sistema e liga o atalho global.
@main
struct CaptaApp: App {
    @NSApplicationDelegateAdaptor(DelegadoDoApp.self) private var delegado
    @State private var estado: EstadoDoMenu
    private let fluxo: FluxoDeCaptura
    private let atalho = AtalhoGlobalCarbon()
    private let atalhoDeCapturaLivre = AtalhoGlobalCarbon()

    init() {
        let estado = EstadoDoMenu()
        let janelas = GerenciadorDeJanelas()
        DelegadoDoApp.janelas = janelas
        let opcoes = OpcoesLembradas(defaults: .standard)
        let overlay = GerenciadorDoOverlay(
            atalhoDeEsc: AtalhoGlobalCarbon(),
            aoMudarAjuda: opcoes.gravarAjuda
        )
        let contagem = JanelaDaContagem(atalhoDeEsc: AtalhoGlobalCarbon())
        let fluxo = FluxoDeCaptura(
            capturador: CapturadorSC(),
            permissao: PermissaoCG(),
            apresentador: janelas,
            seletor: overlay,
            contagem: contagem,
            opcoes: opcoes,
            pastaDeRascunhos: Self.pastaDeRascunhos(),
            cursor: CapturadorSC.posicaoDoCursor,
            agora: { Date() },
            defaults: .standard,
            painel: PainelDeArquivosAppKit(),
            areaDeTransferencia: AreaDeTransferenciaPB()
        )
        // O fluxo guarda as janelas; a volta é fraca para não criar ciclo.
        janelas.tentarDeNovo = { [weak fluxo] in
            guard let fluxo else { return }
            Task { await fluxo.capturarTelaInteira() }
        }
        contagem.aoCancelar = { [weak fluxo] in fluxo?.cancelarContagem() }
        do {
            try atalho.registrar(.capturarTelaInteira) {
                Task { @MainActor in await fluxo.capturarTelaInteira() }
            }
        } catch {
            estado.atalhoDeTelaInteiraIndisponivel = true
        }
        do {
            try atalhoDeCapturaLivre.registrar(.capturaLivre) {
                Task { @MainActor in await fluxo.capturarLivre(modo: .regiao) }
            }
        } catch {
            estado.atalhoDeCapturaLivreIndisponivel = true
        }
        self.fluxo = fluxo
        self._estado = State(initialValue: estado)
    }

    var body: some Scene {
        MenuBarExtra("Capta", image: "GlifoMenu") {
            Button("Capturar região") {
                Task { await fluxo.capturarLivre(modo: .regiao) }
            }
            .keyboardShortcut("c", modifiers: [.control, .option])
            if estado.atalhoDeCapturaLivreIndisponivel {
                Text("Atalho ⌃⌥C indisponível")
            }
            Button("Capturar janela") {
                Task { await fluxo.capturarLivre(modo: .janela) }
            }
            Button("Capturar tela inteira") {
                Task { await fluxo.capturarTelaInteira() }
            }
            .keyboardShortcut("f", modifiers: [.control, .option])
            if estado.atalhoDeTelaInteiraIndisponivel {
                Text("Atalho ⌃⌥F indisponível")
            }
            Divider()
            Button("Sair do Capta") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    /// `Application Support/<app>/Capturas` no contêiner; `Rascunho.gravar` cria o que faltar.
    private static func pastaDeRascunhos() -> URL {
        let gerenciador = FileManager.default
        let base =
            gerenciador.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? gerenciador.temporaryDirectory
        let app = Bundle.main.bundleIdentifier ?? "com.pedroct.capta"
        return base.appending(path: app, directoryHint: .isDirectory)
            .appending(path: "Capturas", directoryHint: .isDirectory)
    }
}
