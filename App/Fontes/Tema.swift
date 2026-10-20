import AppKit
import SwiftUI

/// Tokens visuais do Capta (fonte da verdade: `docs/design-system/tokens.json`).
/// É o único arquivo da interface que pode nomear cor; o resto do app usa `Tema.*`.
/// Cores da marca (`marca-*`) não entram aqui: ficam só no ícone.
enum Tema {
    // Texto e superfícies seguem as cores semânticas do macOS.
    static let texto = Color(nsColor: .labelColor)
    static let textoSecundario = Color(nsColor: .secondaryLabelColor)
    static let superficieJanela = Color(nsColor: .windowBackgroundColor)

    // Vêm do catálogo de cores (valores exatos, claro e escuro).
    static let superficieCanvas = Color("SuperficieCanvas")
    static let bordaControle = Color("BordaControle")

    // O destaque real é a cor que a pessoa escolhe nos Ajustes do Sistema.
    static let destaque = Color.accentColor
    static let anelFoco = Color.accentColor
    static let destaqueFundo = Color(
        nsColor: NSColor(name: nil) { aparencia in
            let escuro = aparencia.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor.controlAccentColor.withAlphaComponent(escuro ? 0.24 : 0.16)
        }
    )
    static let sobreDestaque = Color(
        nsColor: NSColor(name: nil) { aparencia in
            let escuro = aparencia.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return escuro ? NSColor(srgbRed: 0.039, green: 0.039, blue: 0.039, alpha: 1) : .white
        }
    )

    /// Vidro das barras e painéis, sempre sobre `superficieJanela`.
    static let superficiePainel: Material = .regularMaterial

    /// Com "Reduzir transparência" ligado, troca o vidro por uma superfície opaca.
    static func fundoDoPainel(reduzirTransparencia: Bool) -> AnyShapeStyle {
        reduzirTransparencia ? AnyShapeStyle(superficieJanela) : AnyShapeStyle(superficiePainel)
    }

    /// Paleta de anotação: pertence à imagem, igual nos dois temas.
    enum Anotacao {
        static let vermelho = Color("AnotacaoVermelho")
        static let laranja = Color("AnotacaoLaranja")
        static let amarelo = Color("AnotacaoAmarelo")
        static let verde = Color("AnotacaoVerde")
        static let azul = Color("AnotacaoAzul")
        static let roxo = Color("AnotacaoRoxo")
        static let preto = Color("AnotacaoPreto")
        static let branco = Color("AnotacaoBranco")
        static let realce = Color("AnotacaoRealce")
    }

    /// Espaçamentos em pontos.
    enum Espaco {
        static let e1 = 4.0
        static let e2 = 8.0
        static let e3 = 12.0
        static let e4 = 16.0
        static let e6 = 24.0
        static let e8 = 32.0
    }

    /// Raios de canto em pontos.
    enum Raio {
        static let controle = 6.0
        static let cartao = 10.0
        static let painel = 14.0
        static let janela = 16.0
    }
}
