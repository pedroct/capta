import CaptaNucleo
import CoreGraphics
import Foundation
import SwiftUI

/// Nomes (já traduzidos) das ferramentas, das formas e dos tipos de objeto, para a barra, o
/// título do painel e o anúncio do VoiceOver.
enum NomesDoEditor {
    /// As formas do menu da barra, na ordem em que aparecem.
    static let formas: [TipoForma] = [.retangulo, .retanguloArredondado, .elipse]

    static func ferramenta(_ ferramenta: Ferramenta) -> String {
        switch ferramenta {
        case .selecao: String(localized: "Seleção")
        case .seta: String(localized: "Seta")
        case .linha: String(localized: "Linha")
        case .forma: String(localized: "Forma")
        case .realce: String(localized: "Realce")
        }
    }

    static func tipoDeForma(_ tipo: TipoForma) -> String {
        switch tipo {
        case .retangulo: String(localized: "Retângulo")
        case .retanguloArredondado: String(localized: "Retângulo arredondado")
        case .elipse: String(localized: "Elipse")
        }
    }

    /// O nome do tipo de um objeto selecionado.
    static func tipo(de geometria: Geometria) -> String {
        switch geometria {
        case .seta: ferramenta(.seta)
        case .linha: ferramenta(.linha)
        case .forma: ferramenta(.forma)
        case .realce: ferramenta(.realce)
        default: String(localized: "Objeto")
        }
    }

    /// O que o VoiceOver anuncia quando a ferramenta muda: para a forma, o tipo escolhido.
    static func anuncio(de estado: EstadoDoEditor) -> String {
        estado.ferramenta == .forma
            ? tipoDeForma(estado.tipoForma) : ferramenta(estado.ferramenta)
    }
}

/// Uma cor da paleta de anotação: o valor gravado no documento, o token da interface e o nome.
struct CorDaPaleta {
    let cor: CorRGBA
    let visual: Color
    let nome: String
}

/// As oito cores do painel, na ordem de `CorRGBA.paleta` e dos tokens `anotacao-*`.
enum PaletaDoEditor {
    static let cores: [CorDaPaleta] = [
        CorDaPaleta(
            cor: .vermelho,
            visual: Tema.Anotacao.vermelho,
            nome: String(localized: "Vermelho")
        ),
        CorDaPaleta(
            cor: .laranja,
            visual: Tema.Anotacao.laranja,
            nome: String(localized: "Laranja")
        ),
        CorDaPaleta(
            cor: .amarelo,
            visual: Tema.Anotacao.amarelo,
            nome: String(localized: "Amarelo")
        ),
        CorDaPaleta(cor: .verde, visual: Tema.Anotacao.verde, nome: String(localized: "Verde")),
        CorDaPaleta(cor: .azul, visual: Tema.Anotacao.azul, nome: String(localized: "Azul")),
        CorDaPaleta(cor: .roxo, visual: Tema.Anotacao.roxo, nome: String(localized: "Roxo")),
        CorDaPaleta(cor: .preto, visual: Tema.Anotacao.preto, nome: String(localized: "Preto")),
        CorDaPaleta(cor: .branco, visual: Tema.Anotacao.branco, nome: String(localized: "Branco")),
    ]

    /// Mesma cor, sem olhar o alfa (o realce guarda a cor da paleta com o alfa do token).
    static func mesmaCor(_ a: CorRGBA, _ b: CorRGBA) -> Bool {
        a.r == b.r && a.g == b.g && a.b == b.b
    }
}

/// Texto do estado do salvamento no rodapé; `alerta` pede o ícone de aviso.
struct TextoDoSalvamento: Equatable {
    let texto: String
    let alerta: Bool
}

/// Os textos do rodapé: zoom, tamanho de saída e estado do salvamento.
enum TextosDoRodape {
    /// `1` vira "100 %". Arredonda para o inteiro mais próximo.
    static func zoom(_ zoom: Double) -> String {
        String(localized: "\(Int((zoom * 100).rounded())) %")
    }

    /// Tamanho da imagem que sai (com o recorte, se houver) e a escala: "1600 × 900 @2x".
    static func tamanhoDeSaida(_ documento: Documento) -> String {
        let tamanho = documento.recorte?.standardized.size ?? documento.tamanhoBase
        let escala = documento.escala.formatted(.number.precision(.fractionLength(0...1)))
        // Texto, não número: o formato numérico do sistema agruparia os milhares ("1.600").
        let largura = String(Int(tamanho.width))
        let altura = String(Int(tamanho.height))
        return String(localized: "\(largura) × \(altura) @\(escala)x")
    }

    static func salvamento(
        _ estado: EstadoDoSalvamento,
        rascunhoFalhou: Bool = false
    ) -> TextoDoSalvamento {
        if rascunhoFalhou || estado == .falhou {
            return TextoDoSalvamento(
                texto: String(localized: "Não foi possível salvar automaticamente"),
                alerta: true
            )
        }
        switch estado {
        case .salvo:
            return TextoDoSalvamento(
                texto: String(localized: "Salvo automaticamente"),
                alerta: false
            )
        case .pendente, .salvando:
            return TextoDoSalvamento(texto: String(localized: "Salvando…"), alerta: false)
        case .falhou:
            // Já tratado acima; o `switch` precisa ser exaustivo.
            return TextoDoSalvamento(
                texto: String(localized: "Não foi possível salvar automaticamente"),
                alerta: true
            )
        }
    }
}
