import AppKit
import CaptaNucleo
import os

/// Escolha do que capturar sobre as telas congeladas. O fluxo depende só disto.
protocol SeletorDeCaptura {
    /// Mostra o overlay e devolve como ele terminou. Cancelar a tarefa cancela o overlay.
    @MainActor
    func escolher(
        telas: [TelaCongelada],
        janelas: [JanelaDeTela],
        modo: ModoDoOverlay,
        opcoes: OpcoesDeCaptura,
        ajudaVisivel: Bool
    ) async -> ResultadoDoOverlay
}

/// Overlay de captura: uma `JanelaDeOverlay` com a `VistaDoOverlay` de cada tela congelada,
/// todas alimentando **um** `EstadoDoOverlay`, que decide tudo.
///
/// Saída garantida: um app de barra de menus acionado por atalho global pode não ficar ativo
/// (a ativação por `NSApp.activate()` é cooperativa), e então o monitor local nunca vê o `Esc`.
/// Por isso, enquanto o overlay existe, o `Esc` também é um atalho global do Carbon (sem
/// modificadores, sem permissão de Acessibilidade). Se esse registro falhar, o overlay não abre.
@MainActor
final class GerenciadorDoOverlay: SeletorDeCaptura {
    typealias CriarJanela = @MainActor (TelaCongelada, VistaDoOverlay) -> NSWindow

    static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedroct.capta",
        category: "overlay"
    )
    /// `kVK_ANSI_Escape`.
    static let codigoDoEsc: UInt32 = 53

    private let atalhoDeEsc: any AtalhoGlobal
    private let criarJanela: CriarJanela
    private let ativar: @MainActor () -> Task<Void, Never>?
    private let posicaoDoCursor: @MainActor () -> CGPoint
    private let centro: NotificationCenter
    private let appAtivo: @MainActor () -> Bool
    private let aoMudarAjuda: @MainActor (Bool) -> Void
    private let appFrontmost: @MainActor () -> NSRunningApplication?
    private let devolverFoco: @MainActor (NSRunningApplication?, ResultadoDoOverlay) -> Void

    private(set) var estado: EstadoDoOverlay?
    private(set) var janelasAbertas: [NSWindow] = []
    private var vistas: [VistaDoOverlay] = []
    private var continuacao: CheckedContinuation<ResultadoDoOverlay, Never>?
    /// App à frente antes de `ativar()`; devolvido no `Esc` e na confirmação com atraso, nunca
    /// quando o encerramento vem de fora (ver `MotivoDoEncerramento.origem`).
    private var anterior: NSRunningApplication?
    /// Cada abertura tem um número; gatilhos atrasados de uma sessão velha são ignorados.
    private var sessao: UInt64 = 0
    private var monitorDeTeclas: Any?
    private var observadores: [NSObjectProtocol] = []
    private var observadorDePerda: NSObjectProtocol?
    private var tarefaDeAtivacao: Task<Void, Never>?
    private var tarefaDeDiagnostico: Task<Void, Never>?

    /// Invariante: `aberto` liga no instante em que o Esc global é registrado e só desliga em
    /// `encerrar`, que sempre o libera, remove monitores e observadores, fecha as janelas e
    /// retoma a continuação de `escolher` (uma vez). Nenhum outro caminho sai do overlay.
    private(set) var aberto = false

    /// Todos os parâmetros, menos `atalhoDeEsc`, são costuras de teste com o padrão de produção.
    init(
        atalhoDeEsc: any AtalhoGlobal,
        criarJanela: @escaping CriarJanela = GerenciadorDoOverlay.janelaDeOverlay,
        ativar: @escaping @MainActor () -> Task<Void, Never>? = {
            NSApp.activate()
            return GerenciadorDoOverlay.reativarPeloSistema()
        },
        posicaoDoCursor: @escaping @MainActor () -> CGPoint = {
            // O mesmo espaço do núcleo (origem no topo), como `CapturadorSC.posicaoDoCursor`.
            CGEvent(source: nil)?.location ?? CGPoint(x: CGFloat.nan, y: .nan)
        },
        centro: NotificationCenter = .default,
        appAtivo: @escaping @MainActor () -> Bool = { NSApp.isActive },
        aoMudarAjuda: @escaping @MainActor (Bool) -> Void = { _ in },
        // `nil` quando já era o próprio Capta (nada a devolver).
        appFrontmost: @escaping @MainActor () -> NSRunningApplication? = {
            let frontmost = NSWorkspace.shared.frontmostApplication
            return frontmost?.processIdentifier == NSRunningApplication.current.processIdentifier
                ? nil : frontmost
        },
        devolverFoco: @escaping @MainActor (NSRunningApplication?, ResultadoDoOverlay) -> Void =
            GerenciadorDoOverlay.devolverFocoPeloSistema
    ) {
        self.atalhoDeEsc = atalhoDeEsc
        self.criarJanela = criarJanela
        self.ativar = ativar
        self.posicaoDoCursor = posicaoDoCursor
        self.centro = centro
        self.appAtivo = appAtivo
        self.aoMudarAjuda = aoMudarAjuda
        self.appFrontmost = appFrontmost
        self.devolverFoco = devolverFoco
    }

    func escolher(
        telas: [TelaCongelada],
        janelas: [JanelaDeTela],
        modo: ModoDoOverlay,
        opcoes: OpcoesDeCaptura,
        ajudaVisivel: Bool
    ) async -> ResultadoDoOverlay {
        guard !aberto, continuacao == nil else {
            Self.log.info("disparo ignorado: overlay já aberto")
            return .cancelado
        }
        sessao &+= 1
        let sessao = sessao
        let inicial = EstadoDoOverlay.inicial(
            modo: modo,
            telas: telas.map(\.descricao),
            janelas: janelas,
            opcoes: opcoes,
            ajudaVisivel: ajudaVisivel
        )
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuacao in
                self.continuacao = continuacao
                abrir(telas, estado: inicial, sessao: sessao)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.encerrar(.cancelado, motivo: .tarefaCancelada, sessao: sessao)
            }
        }
    }

    /// Ponto de entrada de todo evento (vistas, teclado, notificações e testes).
    func aplicar(_ evento: EventoDoOverlay) { aplicar(evento, sessao: sessao) }

    /// Monitor local de teclas: aplica as do overlay e engole o resto, menos as com `⌘`.
    func tratar(tecla evento: NSEvent) -> NSEvent? {
        let consumida = consumir(
            codigo: evento.keyCode,
            caracteres: evento.charactersIgnoringModifiers,
            modificadores: evento.modifierFlags
        )
        return consumida ? nil : evento
    }

    /// Índice da tela sob `ponto` (a principal se o ponto não estiver em nenhuma).
    static func indiceDaTela(sob ponto: CGPoint, em telas: [DescricaoDeTela]) -> Int? {
        guard let tela = SelecaoDeTela.escolher(entre: telas, sob: ponto) else { return nil }
        return telas.firstIndex(of: tela)
    }

    // MARK: - Abrir e encerrar

    private func abrir(_ telas: [TelaCongelada], estado inicial: EstadoDoOverlay, sessao: UInt64) {
        // Um retorno antecipado abaixo não deve devolver o foco de uma sessão anterior.
        anterior = nil
        do {
            try atalhoDeEsc.registrar(
                CombinacaoDeTeclas(codigoDaTecla: Self.codigoDoEsc, modificadores: [])
            ) { [weak self] in
                Task { @MainActor in self?.aplicar(.tecla(.esc), sessao: sessao) }
            }
        } catch {
            Self.log.error("overlay não abriu: registro do Esc global falhou")
            retomar(.cancelado)
            return
        }
        aberto = true
        guard !telas.isEmpty else {
            Self.log.error("overlay não abriu: nenhuma tela")
            encerrar(.cancelado, motivo: .semTelas, sessao: sessao)
            return
        }
        // O cursor do estado inicial é (0, 0): sem a posição real, o realce e o `F` errariam.
        let estado = inicial.reduzindo(.cursorMoveu(posicaoDoCursor()))
        self.estado = estado
        vistas = telas.map { tela in
            let vista = VistaDoOverlay(tela: tela)
            vista.aoEvento = { [weak self] evento in self?.aplicar(evento, sessao: sessao) }
            vista.mostrar(estado)
            return vista
        }
        janelasAbertas = zip(telas, vistas).map { criarJanela($0, $1) }

        anterior = appFrontmost()
        tarefaDeAtivacao = ativar()
        for janela in janelasAbertas { janela.orderFrontRegardless() }
        tornarChaveAJanelaDoCursor()
        NSCursor.crosshair.set()

        monitorDeTeclas = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] evento in
            // O `NSEvent` não é `Sendable`: só os valores dele entram no isolamento principal.
            let codigo = evento.keyCode
            let caracteres = evento.charactersIgnoringModifiers
            let modificadores = evento.modifierFlags
            let consumida = MainActor.assumeIsolated {
                self?.consumir(codigo: codigo, caracteres: caracteres, modificadores: modificadores)
                    ?? false
            }
            return consumida ? nil : evento
        }
        observar(NSApplication.didChangeScreenParametersNotification) { gerenciador in
            gerenciador.aplicar(.telasMudaram, sessao: sessao)
        }
        armarObservadorDePerda(sessao: sessao)
        registrarDiagnostico(momento: "ao abrir")
        tarefaDeDiagnostico = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            self?.registrarDiagnostico(momento: "300 ms depois")
        }
    }

    private func aplicar(_ evento: EventoDoOverlay, sessao: UInt64) {
        guard aberto, sessao == self.sessao, let atual = estado else { return }
        let novo = atual.reduzindo(evento)
        estado = novo
        if let resultado = novo.resultado {
            encerrar(resultado, motivo: MotivoDoEncerramento(de: evento), sessao: sessao)
            return
        }
        for vista in vistas { vista.mostrar(novo) }
        if novo.ajudaVisivel != atual.ajudaVisivel { aoMudarAjuda(novo.ajudaVisivel) }
    }

    private func encerrar(
        _ resultado: ResultadoDoOverlay,
        motivo: MotivoDoEncerramento,
        sessao: UInt64
    ) {
        guard aberto, sessao == self.sessao else { return }
        aberto = false
        Self.log.info(
            "overlay fechou: \(motivo.textoDoLog, privacy: .public) frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil", privacy: .public)"
        )
        atalhoDeEsc.liberar()
        tarefaDeAtivacao?.cancel()
        tarefaDeDiagnostico?.cancel()
        tarefaDeAtivacao = nil
        tarefaDeDiagnostico = nil
        if let monitorDeTeclas { NSEvent.removeMonitor(monitorDeTeclas) }
        monitorDeTeclas = nil
        for observador in observadores { centro.removeObserver(observador) }
        if let observadorDePerda { centro.removeObserver(observadorDePerda) }
        observadores = []
        observadorDePerda = nil
        for janela in janelasAbertas { janela.orderOut(nil) }
        janelasAbertas = []
        // Solta as imagens congeladas.
        vistas = []
        estado = nil
        NSCursor.arrow.set()
        let aDevolver = anterior
        anterior = nil
        if let aDevolver, motivo.devolveOFoco(com: resultado) {
            Self.log.info(
                "devolverFoco: vai reativar \(aDevolver.localizedName ?? "nil", privacy: .public)"
            )
            devolverFoco(aDevolver, resultado)
            Self.log.info(
                "devolverFoco: depois de reativar, frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil", privacy: .public)"
            )
        }
        retomar(resultado)
    }

    private func retomar(_ resultado: ResultadoDoOverlay) {
        let pendente = continuacao
        continuacao = nil
        pendente?.resume(returning: resultado)
    }

    private func consumir(
        codigo: UInt16,
        caracteres: String?,
        modificadores: NSEvent.ModifierFlags
    ) -> Bool {
        guard aberto, !TeclaDoOverlay.deixaPassar(modificadores: modificadores) else {
            return false
        }
        let tecla = TeclaDoOverlay.de(
            codigo: codigo,
            caracteres: caracteres,
            modificadores: modificadores
        )
        if let tecla { aplicar(.tecla(tecla)) }
        return true
    }

}

// MARK: - Foco, ativação e apoio

extension GerenciadorDoOverlay {

    /// A janela da tela sob o cursor fica com o teclado (não a `NSScreen.main`).
    private func tornarChaveAJanelaDoCursor() {
        guard let estado,
            let indice = Self.indiceDaTela(sob: estado.cursor, em: estado.telas),
            janelasAbertas.indices.contains(indice)
        else { return }
        let janela = janelasAbertas[indice]
        janela.makeKey()
        janela.makeFirstResponder(vistas[indice])
    }

    /// Só passa a cancelar por perda de ativação depois que o app de fato ficou ativo; senão o
    /// overlay se fecharia sozinho antes de a ativação chegar.
    private func armarObservadorDePerda(sessao: UInt64) {
        if appAtivo() {
            observarPerda(sessao: sessao)
            return
        }
        observar(NSApplication.didBecomeActiveNotification) { gerenciador in
            Self.log.info(
                "didBecomeActive: ativo=\(NSApp.isActive) frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil", privacy: .public)"
            )
            guard gerenciador.aberto, gerenciador.observadorDePerda == nil else { return }
            Self.log.info("app ficou ativo; armando cancelamento por perda de ativação")
            gerenciador.tornarChaveAJanelaDoCursor()
            gerenciador.observarPerda(sessao: sessao)
        }
    }

    private func observarPerda(sessao: UInt64) {
        observadorDePerda = centro.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // O fechamento de `addObserver` não é `@MainActor` (ao contrário do `acao` de
            // `observar(_:_:)`), então ler `NSApp`/`NSWorkspace` precisa do isolamento explícito.
            MainActor.assumeIsolated {
                Self.log.info(
                    "didResignActive: ativo=\(NSApp.isActive) frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil", privacy: .public)"
                )
                self?.aplicar(.perdeuAtivacao, sessao: sessao)
            }
        }
    }

    private func observar(
        _ nome: Notification.Name,
        _ acao: @escaping @MainActor (GerenciadorDoOverlay) -> Void
    ) {
        let observador = centro.addObserver(forName: nome, object: nil, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                acao(self)
            }
        }
        observadores.append(observador)
    }

    private func registrarDiagnostico(momento: String) {
        let chaves = janelasAbertas.filter(\.isKeyWindow).count
        Self.log.info(
            "\(momento, privacy: .public): ativo=\(NSApp.isActive) janelas=\(self.janelasAbertas.count) chave=\(chaves)"
        )
    }
}
