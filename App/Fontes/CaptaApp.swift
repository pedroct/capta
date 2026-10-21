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
        let overlay = overlay
        let contagem = JanelaDaContagem(atalhoDeEsc: AtalhoGlobalCarbon())
        let fluxo = FluxoDeCaptura(
            capturador: CapturadorSC(),
            permissao: PermissaoCG(),
            apresentador: janelas,
            seletor: overlay,
            contagem: contagem,
            opcoes: OpcoesLembradas(defaults: .standard),
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
            estado.atalhoIndisponivel = true
        }
        do {
            try atalhoDeCapturaLivre.registrar(.capturaLivre) {
                Task { @MainActor in await Self.capturaLivreProvisoria(overlay) }
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

    /// Provisório até a Tarefa 13 ligar o fluxo: congela, lista as janelas e abre o overlay,
    /// sem capturar o que for escolhido.
    @MainActor
    private static func capturaLivreProvisoria(_ overlay: GerenciadorDoOverlay) async {
        let capturador = CapturadorSC()
        guard let telas = try? await capturador.congelarTelas() else { return }
        let todas = (try? await capturador.listarJanelas()) ?? []
        _ = await overlay.escolher(
            telas: telas,
            janelas: ListaDeJanelas.selecionaveis(todas, tamanhoMinimo: 40),
            modo: .regiao,
            opcoes: OpcoesDeCaptura(atraso: .nenhum, incluirCursor: false),
            ajudaVisivel: true
        )
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
