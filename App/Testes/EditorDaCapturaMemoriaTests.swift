import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

@Suite("Editor da captura: memória de estilos com várias janelas")
@MainActor
struct EditorDaCapturaMemoriaTests {
    private let conversao = ConversaoDoCanvas(zoom: 1, escala: 1)

    @Test func eventoSemMudarAMemoriaNaoSobrescreveOEstiloDeOutraJanela() throws {
        try comDefaultsDeTeste { defaults in
            let a = try editorDeTeste(defaults)
            let b = try editorDeTeste(defaults)

            a.tratar(.escolher(.seta), conversao: conversao)
            a.tratar(.alterarEstilo(.largura(13)), conversao: conversao)
            #expect(MemoriaLembrada(defaults: defaults).memoria[.seta].largura == 13)

            // B ainda tem a memória velha, mas nenhum evento seu a muda.
            b.tratar(.escolher(.linha), conversao: conversao)
            b.tratar(.pressionar(CGPoint(x: 5, y: 5), []), conversao: conversao)
            b.tratar(.soltar(CGPoint(x: 5, y: 5), []), conversao: conversao)
            _ = b.tratar(.seta(dx: 1, dy: 0), shift: false, conversao: conversao)

            #expect(MemoriaLembrada(defaults: defaults).memoria[.seta].largura == 13)
        }
    }
}
