import AppKit
import CaptaNucleo
import Foundation
import Testing

@testable import CaptaSistema

@Suite("Área de transferência do sistema")
struct AreaDeTransferenciaPBTests {
    private func comPasteboardUnica(_ corpo: (NSPasteboard.Name, NSPasteboard) throws -> Void)
        rethrows
    {
        let nome = NSPasteboard.Name(UUID().uuidString)
        let pasteboard = NSPasteboard(name: nome)
        defer { pasteboard.releaseGlobally() }
        try corpo(nome, pasteboard)
    }

    @Test func copiarPNGGravaOsBytesNaPasteboardNomeada() throws {
        try comPasteboardUnica { nome, pasteboard in
            let dados = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
            try AreaDeTransferenciaPB(nome: nome).copiarPNG(dados)
            #expect(pasteboard.data(forType: .png) == dados)
        }
    }

    @Test func copiarPNGComDadosVaziosLanca() {
        comPasteboardUnica { nome, _ in
            #expect(throws: ErroExportacao.falhaAoCopiar) {
                try AreaDeTransferenciaPB(nome: nome).copiarPNG(Data())
            }
        }
    }

    @Test func copiarPNGSubstituiOConteudoAnterior() throws {
        try comPasteboardUnica { nome, pasteboard in
            pasteboard.clearContents()
            pasteboard.setString("texto antigo", forType: .string)
            let dados = Data([9, 8, 7])
            try AreaDeTransferenciaPB(nome: nome).copiarPNG(dados)
            #expect(pasteboard.string(forType: .string) == nil)
            #expect(pasteboard.data(forType: .png) == dados)
        }
    }
}
