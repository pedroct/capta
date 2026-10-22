import CoreGraphics
import CoreImage
import Foundation

/// Compõe a imagem final: a base mais as anotações do documento, na ordem das camadas.
///
/// Usa só Foundation, CoreGraphics e CoreText (parte da família CoreGraphics, sem AppKit).
public struct Renderizador: Sendable {
    let provedorDeSimbolos: (any ProvedorDeSimbolos)?

    public init(provedorDeSimbolos: (any ProvedorDeSimbolos)? = nil) {
        self.provedorDeSimbolos = provedorDeSimbolos
    }

    /// Renderiza o documento sobre `base`.
    ///
    /// A saída é sRGB, 8 bits por componente, `premultipliedLast`, com o tamanho em pixels da base.
    /// Se o documento tem recorte, ele é aplicado por último e define o tamanho da saída.
    /// - Throws: ``ErroDocumento/tamanhoInvalido`` se `base` não tiver o `tamanhoBase` do documento;
    ///   o erro de ``Documento/validar()`` se o documento for inválido;
    ///   ``ErroDocumento/recorteInvalido`` se o recorte não cabe na imagem;
    ///   ``ErroRenderizacao`` se o contexto ou a imagem final não puderam ser criados.
    public func renderizar(_ documento: Documento, base: CGImage) throws -> CGImage {
        // Compara como Double: `Int(...)` de NaN, infinito ou valor enorme encerraria o processo.
        guard Double(base.width) == documento.tamanhoBase.width,
            Double(base.height) == documento.tamanhoBase.height,
            base.width > 0, base.height > 0
        else { throw ErroDocumento.tamanhoInvalido }
        // Documento montado à mão (NaN, recorte fora da base) lança em vez de renderizar em silêncio.
        try documento.validar()

        guard let espaco = CGColorSpace(name: CGColorSpace.sRGB),
            let contexto = CGContext(
                data: nil,
                width: base.width,
                height: base.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: espaco,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { throw ErroRenderizacao.falhaAoCriarContexto }

        contexto.interpolationQuality = .high
        contexto.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))

        // O documento tem origem no topo: inverte o eixo Y uma única vez, aqui.
        contexto.translateBy(x: 0, y: CGFloat(base.height))
        contexto.scaleBy(x: 1, y: -1)

        // Criado só se houver desfoque, e uma única vez por renderização.
        var ciContexto: CIContext?

        for objeto in documento.objetos {
            // O desfoque lê o compósito até aqui; isso não pode acontecer dentro da camada de
            // transparência. O trecho filtrado é desenhado sem camada e sempre com alfa total:
            // `Estilo.opacidade` é ignorada, senão um desfoque a 30% deixaria 70% do conteúdo
            // sensível visível.
            if case .desfoque(let regiao, let tipo, let intensidade) = objeto.geometria {
                let ci = ciContexto ?? criarContextoCoreImage()
                ciContexto = ci
                contexto.saveGState()
                aplicarDesfoque(
                    regiao: regiao,
                    tipo: tipo,
                    intensidade: intensidade,
                    contexto: contexto,
                    ciContexto: ci
                )
                contexto.restoreGState()
                continue
            }
            contexto.saveGState()
            // Camada de transparência: preenchimento e traço compõem juntos e só então
            // recebem a opacidade do objeto.
            contexto.setAlpha(CGFloat(objeto.estilo.opacidade))
            contexto.beginTransparencyLayer(auxiliaryInfo: nil)
            contexto.concatenate(objeto.transformacaoDeRotacao)
            desenhar(objeto, documento: documento, em: contexto)
            contexto.endTransparencyLayer()
            contexto.restoreGState()
        }

        guard let imagem = contexto.makeImage() else { throw ErroRenderizacao.falhaAoGerarImagem }
        guard let recorte = documento.recorte else { return imagem }
        // Coordenadas do recorte: pixels da base com origem no topo, as mesmas do `cropping(to:)`.
        // Inalcançável por construção: `Documento.validar()` já exige recorte com área dentro da base; mantido como defesa.
        guard let recortada = imagem.cropping(to: recorte.standardized) else {
            throw ErroDocumento.recorteInvalido
        }
        return recortada
    }

    private func desenhar(_ objeto: Anotacao, documento: Documento, em contexto: CGContext) {
        let estilo = objeto.estilo
        switch objeto.geometria {
        case .forma(let tipo, let retangulo):
            desenharForma(tipo, retangulo, estilo: estilo, em: contexto)
        case .linha(let inicio, let fim):
            desenharLinha(de: inicio, ate: fim, estilo: estilo, em: contexto)
        case .seta(let inicio, let fim):
            desenharSeta(de: inicio, ate: fim, estilo: estilo, em: contexto)
        case .realce(let retangulo):
            desenharRealce(retangulo, estilo: estilo, em: contexto)
        case .etapa(let centro, let diametro, _):
            desenharEtapa(
                centro: centro,
                diametro: diametro,
                numero: documento.numeroDaEtapa(objeto.id),
                estilo: estilo,
                em: contexto
            )
        case .texto(let retangulo, let conteudo, let tamanhoFonte, let negrito, let italico):
            desenharTexto(
                conteudo,
                em: retangulo,
                fonte: EstiloDeTexto(
                    tamanho: tamanhoFonte,
                    negrito: negrito,
                    italico: italico,
                    cor: estilo.cor
                ),
                contexto: contexto
            )
        case .carimbo(let retangulo, let simbolo):
            desenharCarimbo(simbolo: simbolo, em: retangulo, cor: estilo.cor, contexto: contexto)
        case .desfoque: break  // Tratado em `renderizar`, fora da camada de transparência.
        }
    }
}

extension Anotacao {
    /// Rotação do objeto no sistema do documento: em torno do centro do retângulo (etapa: do
    /// `centro`), matriz de rotação padrão com Y para baixo, então ângulo positivo gira no
    /// sentido horário na tela. Mesma convenção de ``limites``, do acerto e das alças.
    var transformacaoDeRotacao: CGAffineTransform {
        guard rotacao != 0 else { return .identity }
        let centro: CGPoint
        switch geometria {
        case .forma(_, let r), .texto(let r, _, _, _, _), .carimbo(let r, _), .realce(let r),
            .desfoque(let r, _, _):
            let r = r.standardized
            centro = CGPoint(x: r.midX, y: r.midY)
        case .etapa(let c, _, _):
            centro = c
        case .seta, .linha:
            // `Documento.validar()` recusa rotação em seta, linha e desfoque.
            return .identity
        }
        // No contexto já invertido, `rotated(by:)` leva (x, y) a
        // (x·cos − y·sen, x·sen + y·cos) em coordenadas do documento.
        return CGAffineTransform(translationX: centro.x, y: centro.y)
            .rotated(by: CGFloat(rotacao))
            .translatedBy(x: -centro.x, y: -centro.y)
    }
}
