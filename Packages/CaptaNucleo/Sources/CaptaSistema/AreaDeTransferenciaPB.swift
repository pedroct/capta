import AppKit
import CaptaNucleo

/// Área de transferência do sistema (`NSPasteboard`).
///
/// Guarda só o nome da pasteboard, porque `NSPasteboard` não é `Sendable`; ela é procurada a cada chamada.
public struct AreaDeTransferenciaPB: AreaDeTransferencia {
    private let nome: NSPasteboard.Name

    public init(nome: NSPasteboard.Name = .general) {
        self.nome = nome
    }

    /// Substitui o conteúdo da pasteboard por uma imagem PNG.
    public func copiarPNG(_ dados: Data) throws {
        guard !dados.isEmpty else { throw ErroExportacao.falhaAoCopiar }
        let pasteboard = NSPasteboard(name: nome)
        pasteboard.clearContents()
        guard pasteboard.setData(dados, forType: .png) else { throw ErroExportacao.falhaAoCopiar }
    }
}
