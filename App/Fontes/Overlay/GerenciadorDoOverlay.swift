import AppKit
import CaptaNucleo
import os

/// Abre e fecha o overlay: uma `JanelaDeOverlay` escura por tela.
///
/// Provisório (Tarefa 1): só prova que o teclado chega ao overlay.
///
/// Saída garantida: um app de barra de menus acionado por atalho global pode não ficar ativo
/// (a ativação por `NSApp.activate()` é cooperativa e o Carbon não a entrega), e então o teclado
/// continua no outro app e o monitor local nunca vê o `Esc`. Por isso, enquanto o overlay existe,
/// o `Esc` é um atalho global do Carbon (sem modificadores, sem permissão de Acessibilidade).
/// Se esse registro falhar, o overlay não abre.
@MainActor
final class GerenciadorDoOverlay {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedroct.capta",
        category: "overlay"
    )
    /// `kVK_ANSI_Escape`.
    static let codigoDoEsc: UInt32 = 53

    private let atalhoDeEsc: any AtalhoGlobal
    private let criarJanelas: @MainActor () -> [NSWindow]
    private let ativar: @MainActor () -> Task<Void, Never>?
    private var janelas: [NSWindow] = []
    private var aoFechar: (@MainActor () -> Void)?
    private var monitorDeTeclas: Any?
    private var monitorDeCliques: Any?
    private var observadorDeAtivacao: NSObjectProtocol?
    private var observadorDePerda: NSObjectProtocol?
    private var tarefaDeAtivacao: Task<Void, Never>?
    private var tarefaDeDiagnostico: Task<Void, Never>?

    /// Invariante: `aberto` liga no instante em que o Esc global é registrado e só desliga em
    /// `fechar`, que sempre o libera. Logo nunca sobra Esc registrado sem um `fechar` que o solte,
    /// qualquer que seja o estado de `janelas`.
    private(set) var aberto = false

    /// `criarJanelas` e `ativar` são costuras de teste; os padrões são os de produção.
    init(
        atalhoDeEsc: any AtalhoGlobal,
        criarJanelas: @escaping @MainActor () -> [NSWindow] = {
            NSScreen.screens.map { JanelaDeOverlay(tela: $0) }
        },
        ativar: @escaping @MainActor () -> Task<Void, Never>? = {
            NSApp.activate()
            return GerenciadorDoOverlay.reativarPeloSistema()
        }
    ) {
        self.atalhoDeEsc = atalhoDeEsc
        self.criarJanelas = criarJanelas
        self.ativar = ativar
    }

    /// Devolve `false` (sem abrir nada) se não houver como garantir a saída ou não houver telas.
    @discardableResult
    func abrir(aoFechar: @escaping @MainActor () -> Void) -> Bool {
        guard !aberto else { return true }
        do {
            try atalhoDeEsc.registrar(
                CombinacaoDeTeclas(codigoDaTecla: Self.codigoDoEsc, modificadores: [])
            ) { [weak self] in
                Task { @MainActor in self?.fechar(motivo: "atalho global") }
            }
        } catch {
            Self.log.error("overlay não abriu: registro do Esc global falhou")
            return false
        }
        aberto = true
        janelas = criarJanelas()
        guard !janelas.isEmpty else {
            Self.log.error("overlay não abriu: nenhuma tela")
            fechar(motivo: "sem telas")
            return false
        }
        self.aoFechar = aoFechar

        tarefaDeAtivacao = ativar()
        for janela in janelas { janela.orderFrontRegardless() }
        janelas.first(where: { $0.screen == NSScreen.main })?.makeKey()
            ?? janelas.first?.makeKey()

        monitorDeTeclas = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] evento in
            guard evento.keyCode == UInt16(GerenciadorDoOverlay.codigoDoEsc) else { return evento }
            MainActor.assumeIsolated { self?.fechar(motivo: "monitor local") }
            return nil
        }
        monitorDeCliques = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { evento in
            if let janela = evento.window as? JanelaDeOverlay, !janela.isKeyWindow {
                MainActor.assumeIsolated { janela.makeKey() }
            }
            return evento
        }
        armarObservadorDePerda()
        registrarDiagnostico(momento: "ao abrir")
        tarefaDeDiagnostico = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            self?.registrarDiagnostico(momento: "300 ms depois")
        }
        return true
    }

    func fechar() { fechar(motivo: "chamada direta") }

    private func fechar(motivo: String) {
        guard aberto else { return }
        aberto = false
        Self.log.info("overlay fechou: \(motivo, privacy: .public)")
        atalhoDeEsc.liberar()
        tarefaDeAtivacao?.cancel()
        tarefaDeDiagnostico?.cancel()
        tarefaDeAtivacao = nil
        tarefaDeDiagnostico = nil
        if let monitorDeTeclas { NSEvent.removeMonitor(monitorDeTeclas) }
        if let monitorDeCliques { NSEvent.removeMonitor(monitorDeCliques) }
        if let observadorDeAtivacao {
            NotificationCenter.default.removeObserver(observadorDeAtivacao)
        }
        if let observadorDePerda { NotificationCenter.default.removeObserver(observadorDePerda) }
        monitorDeTeclas = nil
        monitorDeCliques = nil
        observadorDeAtivacao = nil
        observadorDePerda = nil
        for janela in janelas { janela.orderOut(nil) }
        janelas = []
        let retorno = aoFechar
        aoFechar = nil
        retorno?()
    }

    /// Pede a ativação ao Launch Services, que reativa o app em execução (`NSApp.activate()` é
    /// cooperativa e pode ser ignorada quando o disparo vem de um atalho global).
    private static func reativarPeloSistema() -> Task<Void, Never> {
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
                Self.log.error(
                    "openApplication falhou: \(error.localizedDescription, privacy: .private)"
                )
            }
        }
    }

    /// Só passa a fechar por perda de ativação depois que o app de fato ficou ativo; senão o
    /// overlay se fecharia sozinho antes de a ativação chegar.
    private func armarObservadorDePerda() {
        if NSApp.isActive {
            observarPerda()
            return
        }
        observadorDeAtivacao = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.aberto, self.observadorDePerda == nil else { return }
                Self.log.info("app ficou ativo; armando fechamento por perda de ativação")
                self.janelas.first?.makeKey()
                self.observarPerda()
            }
        }
    }

    private func observarPerda() {
        observadorDePerda = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fechar(motivo: "perda de ativação") }
        }
    }

    private func registrarDiagnostico(momento: String) {
        let chaves = janelas.filter(\.isKeyWindow).count
        Self.log.info(
            "\(momento, privacy: .public): ativo=\(NSApp.isActive) janelas=\(self.janelas.count) chave=\(chaves)"
        )
    }
}
