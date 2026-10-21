import CoreGraphics
import CoreText
import Foundation

/// Fonte do sistema com os traços pedidos; cai na fonte base se o traço não existir.
private func fonte(tamanho: CGFloat, negrito: Bool, italico: Bool) -> CTFont {
    let base =
        CTFontCreateUIFontForLanguage(.system, tamanho, nil)
        // Só roda se a fonte de UI do sistema for nil, o que não dá para provocar em teste.
        ?? CTFontCreateWithName("Helvetica Neue" as CFString, tamanho, nil)
    var traços: CTFontSymbolicTraits = []
    if negrito { traços.insert(.traitBold) }
    if italico { traços.insert(.traitItalic) }
    guard !traços.isEmpty else { return base }
    return CTFontCreateCopyWithSymbolicTraits(base, tamanho, nil, traços, traços) ?? base
}

/// Fonte e cor de um trecho de texto.
struct EstiloDeTexto {
    var tamanho: Double
    var negrito: Bool
    var italico: Bool
    var cor: CorRGBA
}

private func textoAtribuido(_ conteudo: String, _ estilo: EstiloDeTexto) -> NSAttributedString {
    // Chaves do CoreText como strings: evita depender das constantes `CFString` globais.
    let atributos: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String):
            fonte(
                tamanho: CGFloat(estilo.tamanho),
                negrito: estilo.negrito,
                italico: estilo.italico
            ),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): cgCor(estilo.cor),
    ]
    return NSAttributedString(string: conteudo, attributes: atributos)
}

extension Renderizador {
    /// Texto quebrado em linhas dentro de `retangulo` e recortado a ele.
    ///
    /// O contexto chega com o eixo Y já invertido (origem no topo). Aqui o sistema local do
    /// retângulo é invertido de novo, ficando com Y para cima como o CoreText espera, de modo que
    /// os glifos não saem espelhados. Retângulo sem área, fonte inválida ou texto vazio: no-op.
    func desenharTexto(
        _ conteudo: String,
        em retangulo: CGRect,
        fonte estilo: EstiloDeTexto,
        contexto: CGContext
    ) {
        let r = retangulo.standardized
        guard !conteudo.isEmpty, estilo.tamanho.isFinite, estilo.tamanho > 0,
            r.origin.x.isFinite, r.origin.y.isFinite, r.width.isFinite, r.height.isFinite,
            r.width > 0, r.height > 0
        else { return }

        let atribuido = textoAtribuido(conteudo, estilo)
        let montador = CTFramesetterCreateWithAttributedString(atribuido)
        let caminho = CGPath(rect: CGRect(origin: .zero, size: r.size), transform: nil)
        let quadro = CTFramesetterCreateFrame(
            montador,
            CFRange(location: 0, length: 0),
            caminho,
            nil
        )

        contexto.saveGState()
        contexto.clip(to: r)
        contexto.translateBy(x: r.minX, y: r.maxY)
        contexto.scaleBy(x: 1, y: -1)
        contexto.textMatrix = .identity
        CTFrameDraw(quadro, contexto)
        contexto.restoreGState()
    }

    /// Uma linha de texto centralizada em `centro` (usada pelo número da etapa).
    func desenharLinhaCentrada(
        _ conteudo: String,
        em centro: CGPoint,
        fonte estilo: EstiloDeTexto,
        contexto: CGContext
    ) {
        guard !conteudo.isEmpty, estilo.tamanho.isFinite, estilo.tamanho > 0 else { return }
        let atribuido = textoAtribuido(conteudo, estilo)
        let linha = CTLineCreateWithAttributedString(atribuido)
        let limites = CTLineGetBoundsWithOptions(linha, .useGlyphPathBounds)
        guard !limites.isNull, !limites.isEmpty else { return }

        contexto.saveGState()
        contexto.translateBy(x: centro.x, y: centro.y)
        contexto.scaleBy(x: 1, y: -1)
        contexto.textMatrix = .identity
        contexto.textPosition = CGPoint(x: -limites.midX, y: -limites.midY)
        CTLineDraw(linha, contexto)
        contexto.restoreGState()
    }
}
