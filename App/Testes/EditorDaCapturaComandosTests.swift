import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

@Suite("Comandos e zoom do editor")
@MainActor
struct EditorDaCapturaComandosTests {
    // MARK: Comandos de menu

    @Test func selecionarTudoPeloComando() throws {
        try comDefaultsDeTeste { defaults in
            let a = setaDeTeste()
            let b = setaDeTeste()
            let editor = try editorDeTeste(defaults, objetos: [a, b])
            editor.selecionarTudo()
            #expect(editor.estado.selecao == [a.id, b.id])
        }
    }

    @Test func duplicarPeloComandoSelecionaAsCopias() throws {
        try comDefaultsDeTeste { defaults in
            let original = setaDeTeste()
            let editor = try editorDeTeste(defaults, objetos: [original])
            editor.selecionarTudo()
            editor.duplicar()
            let objetos = editor.captura.documento.objetos
            #expect(objetos.count == 2)
            #expect(editor.estado.selecao.count == 1)
            #expect(!editor.estado.selecao.contains(original.id))
            #expect(editor.captura.podeDesfazer)
        }
    }

    @Test func duplicarSemSelecaoNaoFazNada() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults, objetos: [setaDeTeste()])
            editor.duplicar()
            #expect(editor.captura.documento.objetos.count == 1)
        }
    }

    @Test func comandarEscolheFerramentaEEstilo() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            editor.comandar(.escolherForma(.elipse))
            #expect(editor.estado.ferramenta == .forma)
            #expect(editor.estado.tipoForma == .elipse)
            editor.comandar(.alterarEstilo(.largura(9)))
            #expect(MemoriaLembrada(defaults: defaults).memoria[.forma].largura == 9)
        }
    }

    // MARK: Um renderizador só / constante do giro

    @Test func aComposicaoUsaOMesmoRenderizadorDaCaptura() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults, objetos: [setaDeTeste()])
            let composicao = try editor.novaComposicao()
            let composta = try composicao.atualizar(para: editor.captura.documento)
            let inteira = try editor.renderizador.renderizar(
                editor.captura.documento,
                base: editor.captura.base
            )
            #expect(composta.dataProvider?.data as Data? == inteira.dataProvider?.data as Data?)
        }
    }

    @Test func distanciaDoGiroEUmaConstanteSo() {
        #expect(EditorDaCaptura.giroEmPontos == 20)
    }

    // MARK: Zoom

    @Test func comecaNoModoAjustarComZoomUm() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            #expect(editor.modoDeZoom == .ajustar)
            #expect(editor.zoom == 1)
        }
    }

    @Test func ajusteInicialCabeAImagemNaAreaSemAmpliar() throws {
        try comDefaultsDeTeste { defaults in
            // 200 x 100 pontos numa área de 100 x 100: cabe pela largura, a 50 %.
            let editor = try editorDeTeste(defaults)
            #expect(editor.areaVisivelMudou(CGSize(width: 100, height: 100)))
            editor.aplicarAjuste()
            #expect(editor.zoom == 0.5)
            // Área maior que a imagem: nunca amplia.
            #expect(editor.areaVisivelMudou(CGSize(width: 900, height: 900)))
            editor.aplicarAjuste()
            #expect(editor.zoom == 1)
        }
    }

    @Test func areaIgualOuSemAreaNaoPedeAjuste() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            #expect(!editor.areaVisivelMudou(.zero))
            #expect(editor.areaVisivelMudou(CGSize(width: 100, height: 100)))
            editor.aplicarAjuste()
            #expect(!editor.areaVisivelMudou(CGSize(width: 100, height: 100)))
        }
    }

    @Test func zoomManualSobreviveAMudancaDeArea() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            _ = editor.areaVisivelMudou(CGSize(width: 100, height: 100))
            editor.aplicarAjuste()
            editor.definirZoom(2)
            #expect(editor.modoDeZoom == .manual)
            #expect(!editor.areaVisivelMudou(CGSize(width: 300, height: 300)))
            editor.aplicarAjuste()
            #expect(editor.zoom == 2)
        }
    }

    @Test func ajustarAJanelaVoltaAoModoAjustar() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            _ = editor.areaVisivelMudou(CGSize(width: 100, height: 100))
            editor.definirZoom(3)
            editor.ajustarAJanela()
            #expect(editor.modoDeZoom == .ajustar)
            #expect(editor.zoom == 0.5)
        }
    }

    @Test func tamanhoRealEZoomUmManual() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            editor.definirZoom(0.5)
            editor.tamanhoReal()
            #expect(editor.zoom == 1)
            #expect(editor.modoDeZoom == .manual)
        }
    }

    @Test func maisEMenosAndamPelosNiveis() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            editor.aumentarZoom()
            #expect(editor.zoom == 1.5)
            editor.diminuirZoom()
            editor.diminuirZoom()
            #expect(editor.zoom == 0.75)
        }
    }

    @Test func definirZoomPrendeNosLimites() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            editor.definirZoom(10)
            #expect(editor.zoom == 4)
            editor.definirZoom(0.01)
            #expect(editor.zoom == 0.25)
        }
    }

    @Test func pincaPartindoDeZoomAbaixoDoPisoNaoPula() throws {
        try comDefaultsDeTeste { defaults in
            // Imagem enorme: o ajuste fica em ~10 %, abaixo do piso de 25 %.
            let editor = try editorDeTeste(defaults, largura: 2000, altura: 1000)
            _ = editor.areaVisivelMudou(CGSize(width: 200, height: 200))
            editor.aplicarAjuste()
            #expect(editor.zoom == 0.1)
            editor.pinca(0.02)
            #expect(abs(editor.zoom - 0.102) < 1e-9)
            #expect(editor.modoDeZoom == .manual)
            // Afastar mais não cabe: fica onde está, sem pular para o piso nem zerar.
            let antes = editor.zoom
            editor.pinca(-0.5)
            #expect(editor.zoom == antes)
        }
    }

    @Test func pincaNormalSegueOPercentualEPrendeNoTopo() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            editor.pinca(0.5)
            #expect(editor.zoom == 1.5)
            editor.pinca(5)
            #expect(editor.zoom == 4)
        }
    }
}
