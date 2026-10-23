import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

@Suite("Apresentação do editor: nomes, painel e rodapé")
@MainActor
struct ApresentacaoDoEditorTests {
    // MARK: Nomes

    @Test func nomesDasFerramentasEDasFormas() {
        #expect(NomesDoEditor.ferramenta(.selecao) == "Seleção")
        #expect(NomesDoEditor.ferramenta(.seta) == "Seta")
        #expect(NomesDoEditor.ferramenta(.linha) == "Linha")
        #expect(NomesDoEditor.ferramenta(.forma) == "Forma")
        #expect(NomesDoEditor.ferramenta(.realce) == "Realce")
        #expect(NomesDoEditor.tipoDeForma(.retangulo) == "Retângulo")
        #expect(NomesDoEditor.tipoDeForma(.retanguloArredondado) == "Retângulo arredondado")
        #expect(NomesDoEditor.tipoDeForma(.elipse) == "Elipse")
        #expect(NomesDoEditor.formas == [.retangulo, .retanguloArredondado, .elipse])
    }

    @Test func nomeDoTipoDeGeometria() {
        let ponto = CGPoint(x: 1, y: 2)
        #expect(NomesDoEditor.tipo(de: .seta(inicio: ponto, fim: ponto)) == "Seta")
        #expect(NomesDoEditor.tipo(de: .linha(inicio: ponto, fim: ponto)) == "Linha")
        #expect(NomesDoEditor.tipo(de: .forma(.elipse, .zero)) == "Forma")
        #expect(NomesDoEditor.tipo(de: .realce(.zero)) == "Realce")
        #expect(NomesDoEditor.tipo(de: .carimbo(.zero, simbolo: "star")) == "Objeto")
    }

    @Test func oAnuncioDizAFerramentaOuOTipoDeForma() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            #expect(NomesDoEditor.anuncio(de: editor.estado) == "Seleção")
            editor.comandar(.escolher(.seta))
            #expect(NomesDoEditor.anuncio(de: editor.estado) == "Seta")
            editor.comandar(.escolherForma(.elipse))
            #expect(NomesDoEditor.anuncio(de: editor.estado) == "Elipse")
        }
    }

    // MARK: Paleta

    @Test func paletaTemAsOitoCoresNaOrdemDoNucleo() {
        #expect(PaletaDoEditor.cores.map(\.cor) == CorRGBA.paleta)
        #expect(Set(PaletaDoEditor.cores.map(\.nome)).count == 8)
        #expect(PaletaDoEditor.cores.first?.nome == "Vermelho")
        #expect(PaletaDoEditor.cores.last?.nome == "Branco")
    }

    @Test func corSelecionadaIgnoraOAlfa() {
        let amarelo = CorRGBA.amarelo
        var translucida = amarelo
        translucida.a = 0.5
        #expect(PaletaDoEditor.mesmaCor(amarelo, translucida))
        #expect(!PaletaDoEditor.mesmaCor(amarelo, .verde))
    }

    // MARK: Painel

    @Test func semSelecaoComSelecaoAtivaMostraADica() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults, objetos: [setaDeTeste()])
            let modelo = ModeloDoPainel(estado: editor.estado, documento: editor.captura.documento)
            #expect(modelo.estilo == nil)
            #expect(!modelo.temControles)
            #expect(modelo.titulo == "Propriedades")
        }
    }

    @Test func ferramentaDeCriacaoMostraOEstiloLembrado() throws {
        try comDefaultsDeTeste { defaults in
            let editor = try editorDeTeste(defaults)
            editor.comandar(.escolher(.seta))
            var modelo = ModeloDoPainel(estado: editor.estado, documento: editor.captura.documento)
            #expect(modelo.titulo == "Propriedades · Seta")
            #expect(modelo.estilo == editor.estado.memoria[.seta])
            #expect(modelo.mostraLargura && modelo.mostraTracejado && !modelo.mostraPreenchimento)

            editor.comandar(.escolherForma(.elipse))
            modelo = ModeloDoPainel(estado: editor.estado, documento: editor.captura.documento)
            #expect(modelo.titulo == "Propriedades · Forma")
            #expect(modelo.mostraPreenchimento && modelo.mostraTracejado)

            editor.comandar(.escolher(.realce))
            modelo = ModeloDoPainel(estado: editor.estado, documento: editor.captura.documento)
            #expect(modelo.titulo == "Propriedades · Realce")
            #expect(modelo.temControles)
            #expect(!modelo.mostraLargura && !modelo.mostraTracejado && !modelo.mostraPreenchimento)
        }
    }

    @Test func selecaoMostraOTipoEOEstiloDoObjeto() throws {
        try comDefaultsDeTeste { defaults in
            let estilo = Estilo(cor: .azul, largura: 11)
            let seta = setaDeTeste(estilo: estilo)
            let editor = try editorDeTeste(defaults, objetos: [seta])
            editor.selecionarTudo()
            let modelo = ModeloDoPainel(estado: editor.estado, documento: editor.captura.documento)
            #expect(modelo.titulo == "Propriedades · Seta")
            #expect(modelo.estilo == estilo)
        }
    }

    @Test func selecaoMistaMostraSoOQueTodosTem() throws {
        try comDefaultsDeTeste { defaults in
            let forma = Anotacao(
                id: UUID(),
                geometria: .forma(.retangulo, CGRect(x: 5, y: 5, width: 30, height: 30)),
                estilo: Estilo()
            )
            let realce = Anotacao(
                id: UUID(),
                geometria: .realce(CGRect(x: 50, y: 50, width: 30, height: 20)),
                estilo: Estilo(cor: .realce, largura: 0)
            )
            let editor = try editorDeTeste(defaults, objetos: [setaDeTeste(), forma, realce])
            editor.selecionarTudo()
            var modelo = ModeloDoPainel(estado: editor.estado, documento: editor.captura.documento)
            #expect(modelo.titulo == "Propriedades · 3 objetos")
            #expect(modelo.temControles)
            #expect(!modelo.mostraLargura && !modelo.mostraTracejado && !modelo.mostraPreenchimento)

            // Só a forma: tem tudo.
            editor.comandar(.esc)
            editor.comandar(.pressionar(CGPoint(x: 5, y: 20), []))
            editor.comandar(.soltar(CGPoint(x: 5, y: 20), []))
            modelo = ModeloDoPainel(estado: editor.estado, documento: editor.captura.documento)
            #expect(modelo.titulo == "Propriedades · Forma")
            #expect(modelo.mostraLargura && modelo.mostraTracejado && modelo.mostraPreenchimento)
        }
    }

    // MARK: Rodapé

    @Test func zoomEmPorcento() {
        #expect(TextosDoRodape.zoom(1) == "100 %")
        #expect(TextosDoRodape.zoom(0.25) == "25 %")
        #expect(TextosDoRodape.zoom(1.0 / 3) == "33 %")
        #expect(TextosDoRodape.zoom(4) == "400 %")
    }

    @Test func tamanhoDeSaidaMostraPixelsEEscala() throws {
        let imagem = ImagemCapturada(
            imagem: try imagemDeTeste(largura: 1600, altura: 900),
            escala: 2
        )
        let documento = try Documento.novo(de: imagem)
        #expect(TextosDoRodape.tamanhoDeSaida(documento) == "1600 × 900 @2x")
    }

    @Test func tamanhoDeSaidaUsaORecorteEEscalaFracionaria() throws {
        let imagem = ImagemCapturada(
            imagem: try imagemDeTeste(largura: 200, altura: 100),
            escala: 1.5
        )
        var sessao = SessaoEdicao(documento: try Documento.novo(de: imagem))
        try sessao.aplicar(.definirRecorte(CGRect(x: 10, y: 10, width: 120, height: 60)))
        let texto = TextosDoRodape.tamanhoDeSaida(sessao.documento)
        #expect(texto.hasPrefix("120 × 60 @1"))
        #expect(texto.hasSuffix("5x"))
    }

    @Test func textoDoSalvamento() {
        #expect(TextosDoRodape.salvamento(.salvo).texto == "Salvo automaticamente")
        #expect(!TextosDoRodape.salvamento(.salvo).alerta)
        #expect(TextosDoRodape.salvamento(.pendente).texto == "Salvando…")
        #expect(TextosDoRodape.salvamento(.salvando).texto == "Salvando…")
        let falha = TextosDoRodape.salvamento(.falhou)
        #expect(falha.alerta)
        #expect(falha.texto == "Não foi possível salvar automaticamente")
    }

    @Test func rascunhoComFalhaTambemAlertaNoRodape() {
        let texto = TextosDoRodape.salvamento(.salvo, rascunhoFalhou: true)
        #expect(texto.alerta)
        #expect(texto.texto == "Não foi possível salvar automaticamente")
    }
}
