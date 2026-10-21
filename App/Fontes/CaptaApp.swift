import AppKit
import CaptaNucleo
import CaptaSistema
import Observation
import SwiftUI

/// O que o menu precisa saber do registro do atalho global.
@MainActor
@Observable
final class EstadoDoMenu {
    var atalhoIndisponivel = false
    var atalhoDeCapturaLivreIndisponivel = false
}

/// Única fiação do app: compõe os adaptadores do sistema e liga o atalho global.
@main
struct CaptaApp: App {
    @State private var estado: EstadoDoMenu
    private let fluxo: FluxoDeCaptura
    private let atalho = AtalhoGlobalCarbon()
    private let atalhoDeCapturaLivre = AtalhoGlobalCarbon()
    private let overlay = GerenciadorDoOverlay(atalhoDeEsc: AtalhoGlobalCarbon())

    init() {
        let estado = EstadoDoMenu()
        let janelas = GerenciadorDeJanelas()
        let fluxo = FluxoDeCaptura(
            capturador: CapturadorSC(),
            permissao: PermissaoCG(),
            apresentador: janelas,
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
        do {
            try atalho.registrar(.capturarTelaInteira) {
                Task { @MainActor in await fluxo.capturarTelaInteira() }
            }
        } catch {
            estado.atalhoIndisponivel = true
        }
        let overlay = overlay
        do {
            try atalhoDeCapturaLivre.registrar(.capturaLivre) {
                Task { @MainActor in overlay.abrir(aoFechar: {}) }
            }
        } catch {
            estado.atalhoDeCapturaLivreIndisponivel = true
        }
        self.fluxo = fluxo
        self._estado = State(initialValue: estado)
    }

    var body: some Scene {
        MenuBarExtra("Capta", image: "GlifoMenu") {
            Button("Capturar tela inteira") {
                Task { await fluxo.capturarTelaInteira() }
            }
            .keyboardShortcut("f", modifiers: [.control, .option])
            if estado.atalhoIndisponivel || estado.atalhoDeCapturaLivreIndisponivel {
                Text("Atalho indisponível")
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
