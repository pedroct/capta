import CaptaNucleo

/// Por que o overlay fechou: decide o texto do log e se o foco volta ao app de antes.
///
/// Os `switch` daqui não têm `default` de propósito: um caso novo em `EventoDoOverlay` ou aqui
/// não compila até alguém decidir de onde ele vem, e um encerramento causado de fora nunca
/// reativa o app de antes por esquecimento.
enum MotivoDoEncerramento: Equatable {
    /// `Esc`, pelo monitor local ou pelo atalho global.
    case esc
    /// Uma seleção confirmada no overlay.
    case confirmado
    /// Quem chamou `escolher` cancelou a tarefa.
    case tarefaCancelada
    /// O overlay não tinha telas para abrir.
    case semTelas
    /// Monitor ligado ou desligado, resolução alterada.
    case telasMudaram
    /// O Capta perdeu a ativação: o sistema ou o usuário já levou o foco a outro app.
    case perdeuAtivacao

    /// Quem decidiu encerrar.
    enum Origem: Equatable {
        /// O próprio Capta sai de cena: pode devolver o foco ao app de antes.
        case doProprioCapta
        /// Algo de fora encerrou por ele: o foco fica onde está.
        case externa
    }

    init(de evento: EventoDoOverlay) {
        switch evento {
        case .tecla(.esc): self = .esc
        case .telasMudaram: self = .telasMudaram
        case .perdeuAtivacao: self = .perdeuAtivacao
        // Entradas do próprio overlay: além do `Esc`, só encerram confirmando.
        case .tecla, .cursorMoveu, .mouseBaixo, .mouseArrastou, .mouseSolto, .opcoesMudaram:
            self = .confirmado
        }
    }

    var origem: Origem {
        switch self {
        case .esc, .confirmado, .tarefaCancelada, .semTelas: .doProprioCapta
        case .telasMudaram, .perdeuAtivacao: .externa
        }
    }

    /// Só devolve quando o próprio Capta sai de cena: cancelado ou com atraso, devolve; sem
    /// atraso, o resultado já abre a janela do Capta. Quando o encerramento vem de fora, o foco
    /// já está onde o sistema ou o usuário o pôs, e reativar o app de antes brigaria com isso
    /// (achado em tela real: `⌘Tab` para um terceiro app trazia de volta o app de antes).
    func devolveOFoco(com resultado: ResultadoDoOverlay) -> Bool {
        guard origem == .doProprioCapta else { return false }
        switch resultado {
        case .cancelado: return true
        case .confirmado(_, let opcoes): return opcoes.atraso != .nenhum
        }
    }

    /// O texto que vai ao log (`overlay fechou: …`); não mudar sem conferir quem lê o log.
    var textoDoLog: String {
        switch self {
        case .esc: "Esc"
        case .confirmado: "confirmado"
        case .tarefaCancelada: "tarefa cancelada"
        case .semTelas: "sem telas"
        case .telasMudaram: "telas mudaram"
        case .perdeuAtivacao: "perda de ativação"
        }
    }
}
