import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

@Suite("Editor da captura")
@MainActor
struct EditorDaCapturaTests {
    private let renderizador = Renderizador()
    private let conversao = ConversaoDoCanvas(zoom: 1, escala: 1)

    private func comDefaults(_ corpo: (UserDefaults) throws -> Void) throws {
        let nome = "capta.testes.editor.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: nome))
        defer { defaults.removePersistentDomain(forName: nome) }
        try corpo(defaults)
    }

    private func editor(
        _ defaults: UserDefaults,
        escala: Double = 1,
        objetos: [Anotacao] = []
    ) throws -> EditorDaCaptura {
        let imagem = try imagemDeTeste(largura: 200, altura: 100)
        let captura = ImagemCapturada(imagem: imagem, escala: escala)
        let aberta = CapturaAberta(
            nome: "teste",
            documento: try Documento.novo(de: captura),
            base: imagem,
            escala: escala,
            rascunho: .falhou,
            renderizador: renderizador,
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa(),
            gravadorDeRascunho: { _, _, _, _ in throw ErroDeTeste() },
            salvamento: SalvamentoAutomatico(dormir: { _ in }, gravar: { _, _ in })
        )
        for objeto in objetos { aberta.aplicar(.adicionar(objeto)) }
        return EditorDaCaptura(captura: aberta, memoria: MemoriaLembrada(defaults: defaults))
    }

    private func arrastarSeta(_ editor: EditorDaCaptura, ate fim: CGPoint, soltar: Bool) {
        editor.tratar(.escolher(.seta), conversao: conversao)
        editor.tratar(.pressionar(CGPoint(x: 20, y: 20), []), conversao: conversao)
        editor.tratar(.arrastar(fim, []), conversao: conversao)
        if soltar { editor.tratar(.soltar(fim, []), conversao: conversao) }
    }

    @Test func arrastarCriaPreviaESoltarAplica() throws {
        try comDefaults { defaults in
            let editor = try editor(defaults)
            arrastarSeta(editor, ate: CGPoint(x: 120, y: 60), soltar: false)
            #expect(editor.previa?.objetos.count == 1)
            #expect(editor.captura.documento.objetos.isEmpty)
            #expect(editor.documentoExibido.objetos.count == 1)

            editor.tratar(.soltar(CGPoint(x: 120, y: 60), []), conversao: conversao)
            #expect(editor.previa == nil)
            #expect(editor.captura.documento.objetos.count == 1)
            #expect(editor.estado.selecao.count == 1)
            editor.desfazer()
            #expect(editor.captura.documento.objetos.isEmpty)
            #expect(!editor.captura.podeDesfazer)
        }
    }

    @Test func escNoMeioDoArrastoTiraAPrevia() throws {
        try comDefaults { defaults in
            let editor = try editor(defaults)
            arrastarSeta(editor, ate: CGPoint(x: 120, y: 60), soltar: false)
            editor.tratar(.esc, conversao: conversao)
            #expect(editor.previa == nil)
            editor.tratar(.soltar(CGPoint(x: 120, y: 60), []), conversao: conversao)
            #expect(editor.captura.documento.objetos.isEmpty)
        }
    }

    @Test func desfazerNoMeioDoArrastoTiraAPreviaESincroniza() throws {
        try comDefaults { defaults in
            let editor = try editor(defaults)
            arrastarSeta(editor, ate: CGPoint(x: 120, y: 60), soltar: true)
            // Segundo arrasto em curso, com prévia.
            arrastarSeta(editor, ate: CGPoint(x: 150, y: 80), soltar: false)
            #expect(editor.previa != nil)
            editor.desfazer()
            #expect(editor.previa == nil)
            #expect(editor.captura.documento.objetos.isEmpty)
            #expect(editor.estado.selecao.isEmpty)
            // O soltar que sobra do gesto cancelado não cria nada.
            editor.tratar(.soltar(CGPoint(x: 150, y: 80), []), conversao: conversao)
            #expect(editor.captura.documento.objetos.isEmpty)
        }
    }

    @Test func desfazerACriacaoTiraOObjetoDaSelecao() throws {
        try comDefaults { defaults in
            let editor = try editor(defaults)
            arrastarSeta(editor, ate: CGPoint(x: 120, y: 60), soltar: true)
            #expect(editor.estado.selecao.count == 1)
            editor.desfazer()
            #expect(editor.estado.selecao.isEmpty)
            editor.refazer()
            #expect(editor.captura.documento.objetos.count == 1)
            // Refazer traz o objeto de volta, mas a seleção não é ressuscitada.
            #expect(editor.estado.selecao.isEmpty)
        }
    }

    @Test func trocarDeFerramentaNoMeioDoArrastoCancela() throws {
        try comDefaults { defaults in
            let editor = try editor(defaults)
            arrastarSeta(editor, ate: CGPoint(x: 120, y: 60), soltar: false)
            editor.tratar(.escolher(.linha), conversao: conversao)
            #expect(editor.previa == nil)
            editor.tratar(.soltar(CGPoint(x: 120, y: 60), []), conversao: conversao)
            #expect(editor.captura.documento.objetos.isEmpty)
        }
    }

    @Test(arguments: [0.25, 4.0])
    func cliqueEmLinhaFinaComZoom25E400Acerta(zoom: Double) throws {
        try comDefaults { defaults in
            let escala = 2.0
            let linha = Anotacao(
                id: UUID(),
                geometria: .linha(inicio: CGPoint(x: 20, y: 50), fim: CGPoint(x: 180, y: 50)),
                estilo: Estilo(cor: .vermelho, largura: 1)
            )
            let editor = try editor(defaults, escala: escala, objetos: [linha])
            let conversao = ConversaoDoCanvas(zoom: zoom, escala: escala)

            @MainActor func clicar(aPontos distancia: CGFloat) -> Bool {
                let ponto = CGPoint(x: 100, y: 50 + conversao.pixels(dePontos: distancia))
                editor.tratar(.pressionar(ponto, []), conversao: conversao)
                editor.tratar(.soltar(ponto, []), conversao: conversao)
                let acertou = editor.estado.selecao == [linha.id]
                editor.tratar(.esc, conversao: conversao)
                return acertou
            }

            #expect(clicar(aPontos: 3))
            // A tolerância é 4 pt mais metade do traço; 7 pt está fora nos dois zooms.
            #expect(!clicar(aPontos: 7))
        }
    }

    @Test func alterarEstiloGravaNaMemoriaLembrada() throws {
        try comDefaults { defaults in
            let editor = try editor(defaults)
            editor.tratar(.escolher(.seta), conversao: conversao)
            editor.tratar(.alterarEstilo(.largura(13)), conversao: conversao)
            #expect(MemoriaLembrada(defaults: defaults).memoria[.seta].largura == 13)
        }
    }
}

@Suite("Teclado do editor")
@MainActor
struct TeclasDoEditorTests {
    private let conversao = ConversaoDoCanvas(zoom: 1, escala: 1)

    private func editor() throws -> EditorDaCaptura {
        let nome = "capta.testes.teclas.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: nome))
        defaults.removePersistentDomain(forName: nome)
        let imagem = try imagemDeTeste(largura: 200, altura: 100)
        let aberta = CapturaAberta(
            nome: "teste",
            documento: try Documento.novo(de: ImagemCapturada(imagem: imagem, escala: 1)),
            base: imagem,
            escala: 1,
            rascunho: .falhou,
            renderizador: Renderizador(),
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa(),
            gravadorDeRascunho: { _, _, _, _ in throw ErroDeTeste() },
            salvamento: SalvamentoAutomatico(dormir: { _ in }, gravar: { _, _ in })
        )
        return EditorDaCaptura(captura: aberta, memoria: MemoriaLembrada(defaults: defaults))
    }

    @Test func traduzCodigosEConjuntos() {
        #expect(TeclaDoEditor(codigo: 53, caractere: nil) == .esc)
        #expect(TeclaDoEditor(codigo: 51, caractere: nil) == .apagar)
        #expect(TeclaDoEditor(codigo: 117, caractere: nil) == .apagar)
        #expect(TeclaDoEditor(codigo: 123, caractere: nil) == .seta(dx: -1, dy: 0))
        #expect(TeclaDoEditor(codigo: 124, caractere: nil) == .seta(dx: 1, dy: 0))
        #expect(TeclaDoEditor(codigo: 125, caractere: nil) == .seta(dx: 0, dy: 1))
        #expect(TeclaDoEditor(codigo: 126, caractere: nil) == .seta(dx: 0, dy: -1))
        #expect(TeclaDoEditor(codigo: 9, caractere: "A") == .ferramenta(.seta))
        #expect(TeclaDoEditor(codigo: 9, caractere: "l") == .ferramenta(.linha))
        #expect(TeclaDoEditor(codigo: 9, caractere: "x") == nil)
    }

    @Test func letrasTrocamDeFerramenta() throws {
        let editor = try editor()
        let esperadas: [(String, Ferramenta)] = [
            ("v", .selecao), ("a", .seta), ("l", .linha), ("r", .forma), ("h", .realce),
        ]
        for (letra, ferramenta) in esperadas {
            let tecla = try #require(TeclaDoEditor(codigo: 0, caractere: letra))
            #expect(editor.tratar(tecla, shift: false, conversao: conversao))
            #expect(editor.estado.ferramenta == ferramenta)
        }
    }

    @Test func setasDeslocamUmPixelEComShiftDez() throws {
        let editor = try editor()
        let objeto = Anotacao(
            id: UUID(),
            geometria: .forma(.retangulo, CGRect(x: 50, y: 50, width: 20, height: 20)),
            estilo: Estilo()
        )
        editor.captura.aplicar(.adicionar(objeto))
        editor.tratar(.selecionarTudo, conversao: conversao)
        _ = editor.tratar(.seta(dx: 1, dy: 0), shift: false, conversao: conversao)
        _ = editor.tratar(.seta(dx: 0, dy: -1), shift: true, conversao: conversao)
        guard case .forma(_, let retangulo) = editor.captura.documento.objetos[0].geometria else {
            Issue.record("geometria inesperada")
            return
        }
        #expect(retangulo.origin == CGPoint(x: 51, y: 40))
    }

    @Test func apagarExcluiASelecaoEEscLimpa() throws {
        let editor = try editor()
        let objeto = Anotacao(
            id: UUID(),
            geometria: .forma(.retangulo, CGRect(x: 50, y: 50, width: 20, height: 20)),
            estilo: Estilo()
        )
        editor.captura.aplicar(.adicionar(objeto))
        editor.tratar(.selecionarTudo, conversao: conversao)
        #expect(editor.tratar(.esc, shift: false, conversao: conversao))
        #expect(editor.estado.selecao.isEmpty)
        editor.tratar(.selecionarTudo, conversao: conversao)
        #expect(editor.tratar(.apagar, shift: false, conversao: conversao))
        #expect(editor.captura.documento.objetos.isEmpty)
    }
}
