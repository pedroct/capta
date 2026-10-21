import CoreGraphics
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
    /// - Throws: ``ErroDocumento/tamanhoInvalido`` se `base` não tiver o `tamanhoBase` do documento.
    public func renderizar(_ documento: Documento, base: CGImage) throws -> CGImage {
        guard base.width == Int(documento.tamanhoBase.width),
            base.height == Int(documento.tamanhoBase.height),
            base.width > 0, base.height > 0
        else { throw ErroDocumento.tamanhoInvalido }

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
        else { throw ErroDocumento.tamanhoInvalido }

        contexto.interpolationQuality = .high
        contexto.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))

        // O documento tem origem no topo: inverte o eixo Y uma única vez, aqui.
        contexto.translateBy(x: 0, y: CGFloat(base.height))
        contexto.scaleBy(x: 1, y: -1)

        for objeto in documento.objetos {
            contexto.saveGState()
            // Camada de transparência: preenchimento e traço compõem juntos e só então
            // recebem a opacidade do objeto.
            contexto.setAlpha(CGFloat(objeto.estilo.opacidade))
            contexto.beginTransparencyLayer(auxiliaryInfo: nil)
            desenhar(objeto, documento: documento, em: contexto)
            contexto.endTransparencyLayer()
            contexto.restoreGState()
        }

        guard let imagem = contexto.makeImage() else { throw ErroDocumento.tamanhoInvalido }
        return imagem
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
        case .desfoque, .carimbo:
            // No-op nesta tarefa: desfoque e carimbo entram na Tarefa 7.
            break
        }
    }
}
