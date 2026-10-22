import AppKit
import CaptaNucleo

/// Implementações de produção das costuras de `GerenciadorDoOverlay` (ativação, foco e janela),
/// separadas por tamanho de arquivo. Sem `private`: `init` as referencia de outro arquivo.
extension GerenciadorDoOverlay {

    /// Pede a ativação ao Launch Services, que reativa o app em execução (`NSApp.activate()` é
    /// cooperativa e pode ser ignorada quando o disparo vem de um atalho global).
    static func reativarPeloSistema() -> Task<Void, Never> {
        Task { @MainActor in
            guard !Task.isCancelled else { return }
            let configuracao = NSWorkspace.OpenConfiguration()
            configuracao.activates = true
            do {
                _ = try await NSWorkspace.shared.openApplication(
                    at: Bundle.main.bundleURL,
                    configuration: configuracao
                )
            } catch {
                log.error(
                    "openApplication falhou: \(error.localizedDescription, privacy: .private)"
                )
            }
        }
    }

    /// Pede ao app anterior que retome a ativação (macOS 14+, a partir de quem está ativo agora).
    static func devolverFocoPeloSistema(
        _ anterior: NSRunningApplication?,
        _ resultado: ResultadoDoOverlay
    ) {
        _ = anterior?.activate(from: .current, options: [])
    }

    /// Janela de produção: sobre a tela, no espaço do AppKit.
    static func janelaDeOverlay(_ tela: TelaCongelada, _ vista: VistaDoOverlay) -> NSWindow {
        let alturaDaPrincipal = NSScreen.screens.first?.frame.height ?? tela.descricao.quadro.height
        let janela = JanelaDeOverlay(
            quadro: JanelaDeOverlay.quadroNoAppKit(
                de: tela.descricao.quadro,
                alturaDaPrincipal: alturaDaPrincipal
            )
        )
        janela.contentView = vista
        return janela
    }
}
