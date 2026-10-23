import CoreGraphics
import Foundation

/// Ferramenta ativa do editor. A fatia 5b acrescenta as demais.
public enum Ferramenta: String, Codable, CaseIterable, Sendable {
    case selecao, seta, linha, forma, realce
}

/// Mudança de estilo pedida pela barra de propriedades.
public enum AlteracaoDeEstilo: Equatable, Sendable {
    case cor(CorRGBA)
    case largura(Double)
    case opacidade(Double)
    case tracejado(Bool)
    case preenchimento(CorRGBA?)
}

/// Entrada da máquina de estados do editor. Os pontos estão em pixels do documento.
public enum EventoDoEditor: Equatable, Sendable {
    case escolher(Ferramenta)
    case escolherForma(TipoForma)
    case pressionar(CGPoint, Modificadores)
    case arrastar(CGPoint, Modificadores)
    case soltar(CGPoint, Modificadores)
    case esc
    case selecionarTudo
    case excluir
    case duplicar
    case deslocar(CGVector)
    case alterarEstilo(AlteracaoDeEstilo)
    /// O documento mudou por fora (desfazer, refazer): descarta o que deixou de existir.
    case sincronizar
}

/// Saída da máquina de estados: o que a sessão de edição deve fazer.
public enum AcaoDoEditor: Equatable, Sendable {
    /// Grava a edição no histórico.
    case aplicar(Edicao)
    /// Mostra a edição sem gravar (gesto em curso).
    case previa(Edicao)
    /// Descarta a prévia mostrada.
    case cancelarPrevia
}

/// O que a máquina precisa saber do mundo a cada evento. Tolerância e distância do giro já
/// vêm em pixels do documento (a vista converte de pontos da tela).
public struct ContextoDoEditor {
    public var documento: Documento
    public var tolerancia: CGFloat
    /// Folga para acertar uma alça, quando difere da dos objetos (a alça é desenhada como um
    /// quadrado maior que a tolerância dos objetos). `nil` usa ``tolerancia``.
    public var toleranciaDasAlcas: CGFloat?
    public var distanciaDoGiro: CGFloat
    public var novoId: () -> UUID

    public init(
        documento: Documento,
        tolerancia: CGFloat,
        toleranciaDasAlcas: CGFloat? = nil,
        distanciaDoGiro: CGFloat,
        novoId: @escaping () -> UUID
    ) {
        self.documento = documento
        self.tolerancia = tolerancia
        self.toleranciaDasAlcas = toleranciaDasAlcas
        self.distanciaDoGiro = distanciaDoGiro
        self.novoId = novoId
    }
}
