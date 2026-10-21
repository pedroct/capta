import CoreGraphics

/// O que o overlay seleciona: um retângulo de uma tela ou uma janela inteira.
public enum ModoDoOverlay: Equatable, Sendable {
    case regiao, janela
}

/// Opções escolhidas na barra do overlay.
///
/// `incluirCursor` só vale com atraso (só aí há captura ao vivo), mas é guardado mesmo com
/// `atraso == .nenhum`, para o controle desabilitado mostrar o valor lembrado.
public struct OpcoesDeCaptura: Equatable, Sendable {
    public var atraso: Atraso
    public var incluirCursor: Bool

    public init(atraso: Atraso, incluirCursor: Bool) {
        self.atraso = atraso
        self.incluirCursor = incluirCursor
    }
}

/// O que foi confirmado no overlay.
public enum SelecaoConfirmada: Equatable, Sendable {
    /// Retângulo em pixels nativos inteiros, local à tela (origem no canto superior esquerdo).
    case regiao(tela: DescricaoDeTela, pixels: CGRect)
    /// `CGWindowID` da janela.
    case janela(id: UInt32)
}

/// Como o overlay terminou.
public enum ResultadoDoOverlay: Equatable, Sendable {
    case confirmado(SelecaoConfirmada, OpcoesDeCaptura)
    case cancelado
}

/// Sentido de uma seta do teclado.
public enum Direcao: Equatable, Sendable {
    case cima, baixo, esquerda, direita
}

/// Teclas que o overlay trata. `grande` é a seta com `⇧` (passo de 10 px).
public enum TeclaDoOverlay: Equatable, Sendable {
    case esc, f, espaco, enter, m, h
    case seta(Direcao, grande: Bool)
}

/// Entrada da máquina de estados. Os pontos são globais, em pontos: origem no canto
/// superior esquerdo da tela principal, Y para baixo (o mesmo espaço de `DescricaoDeTela`).
public enum EventoDoOverlay: Equatable, Sendable {
    case cursorMoveu(CGPoint)
    case mouseBaixo(CGPoint)
    case mouseArrastou(CGPoint)
    case mouseSolto(CGPoint)
    case tecla(TeclaDoOverlay)
    case opcoesMudaram(OpcoesDeCaptura)
    /// Monitor ligado ou desligado, resolução alterada: o overlay cancela.
    case telasMudaram
    /// O app perdeu a ativação: o overlay cancela para não prender o usuário.
    case perdeuAtivacao
}
