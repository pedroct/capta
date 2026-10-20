import Foundation

/// Sessão de edição com desfazer e refazer.
///
/// O histórico guarda *snapshots* de ``Documento`` (que não contém a imagem base), sem limite
/// de tamanho durante a sessão. Toda edição é aplicada a uma cópia, validada e só então
/// confirmada: uma edição inválida não altera o documento nem o histórico. Uma edição que não
/// muda o documento (por exemplo, `reordenar` de quem já está no topo) é aceita sem erro e
/// não cria entrada no histórico.
public struct SessaoEdicao: Sendable {
    public private(set) var documento: Documento
    private var passado: [Documento] = []
    private var futuro: [Documento] = []

    public init(documento: Documento) {
        self.documento = documento
    }

    public var podeDesfazer: Bool { !passado.isEmpty }
    public var podeRefazer: Bool { !futuro.isEmpty }

    /// Aplica a edição; lança ``ErroDocumento`` se ela for inválida, sem mudar nada.
    public mutating func aplicar(_ edicao: Edicao) throws {
        var copia = documento
        try copia.aplicarSemValidar(edicao)
        try copia.validar()
        guard copia != documento else { return }
        passado.append(documento)
        futuro.removeAll()
        documento = copia
    }

    /// Volta ao estado anterior; devolve `false` se não há o que desfazer.
    @discardableResult
    public mutating func desfazer() -> Bool {
        guard let anterior = passado.popLast() else { return false }
        futuro.append(documento)
        documento = anterior
        return true
    }

    /// Reaplica o último passo desfeito; devolve `false` se não há o que refazer.
    @discardableResult
    public mutating func refazer() -> Bool {
        guard let proximo = futuro.popLast() else { return false }
        passado.append(documento)
        documento = proximo
        return true
    }
}
