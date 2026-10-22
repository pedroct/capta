import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Limite superior do raio (borrar) e da escala (pixelizar): mesmo teto do CoreImage.
private let intensidadeMaxima: Double = 100

/// Quanto o desfoque lê além da própria região, em pixels: o filtro olha o compósito em volta
/// para calcular a borda. Borrar: três raios (o alcance prático do gaussiano), `ceil(3 × raio)`.
/// Pixelizar: um bloco (o centro de um bloco da borda pode cair fora da região), `ceil(escala)`.
/// Raio e escala com os mesmos limites que o filtro aplica.
func margemDeLeitura(tipo: TipoDesfoque, intensidade: Double) -> CGFloat {
    switch tipo {
    case .borrar: return CGFloat(ceil(3 * min(intensidade, intensidadeMaxima)))
    case .pixelizar: return CGFloat(ceil(max(min(intensidade, intensidadeMaxima), 1)))
    }
}

extension Renderizador {
    /// Aplica o desfoque sobre o que já foi composto em `contexto`.
    ///
    /// Tira uma cópia do compósito até aqui, filtra com CoreImage e devolve só o trecho
    /// `região ∩ imagem` (arredondado para pixels inteiros, para fora). Região sem área, fora da
    /// imagem ou intensidade não positiva/não finita: no-op.
    func aplicarDesfoque(
        regiao: CGRect,
        tipo: TipoDesfoque,
        intensidade: Double,
        contexto: CGContext,
        ciContexto: CIContext
    ) {
        guard intensidade.isFinite, intensidade > 0, let r = retanguloUtil(regiao) else { return }
        let limites = CGRect(x: 0, y: 0, width: contexto.width, height: contexto.height)
        let interno = r.intersection(limites)
        guard !interno.isNull else { return }
        let alvo = interno.integral.intersection(limites)
        guard !alvo.isNull, alvo.width >= 1, alvo.height >= 1,
            let instantaneo = contexto.makeImage()
        else { return }

        // CoreImage tem origem embaixo: inverte o Y da região contra a altura da imagem.
        let alvoCI = CGRect(
            x: alvo.minX,
            y: limites.height - alvo.maxY,
            width: alvo.width,
            height: alvo.height
        )
        // Borda estendida: o filtro lê além da imagem sem escurecer nem ficar transparente.
        let entrada = CIImage(cgImage: instantaneo).clampedToExtent()
        guard let saida = filtrar(entrada, tipo: tipo, intensidade: intensidade, origem: alvoCI),
            let espaco = CGColorSpace(name: CGColorSpace.sRGB),
            let remendo = ciContexto.createCGImage(
                saida.cropped(to: alvoCI),
                from: alvoCI,
                format: .RGBA8,
                colorSpace: espaco
            )
        else { return }

        contexto.saveGState()
        contexto.clip(to: alvo)
        // O contexto tem o Y invertido: desvira localmente para a imagem não sair de cabeça para baixo.
        contexto.translateBy(x: alvo.minX, y: alvo.maxY)
        contexto.scaleBy(x: 1, y: -1)
        contexto.draw(remendo, in: CGRect(origin: .zero, size: alvo.size))
        contexto.restoreGState()
    }

    private func filtrar(
        _ entrada: CIImage,
        tipo: TipoDesfoque,
        intensidade: Double,
        origem: CGRect
    ) -> CIImage? {
        let valor = Float(min(intensidade, intensidadeMaxima))
        switch tipo {
        case .borrar:
            let filtro = CIFilter.gaussianBlur()
            filtro.inputImage = entrada
            filtro.radius = valor
            return filtro.outputImage
        case .pixelizar:
            let filtro = CIFilter.pixellate()
            filtro.inputImage = entrada
            filtro.scale = max(valor, 1)
            // Blocos alinhados ao canto da região, não a um ponto arbitrário da imagem.
            filtro.center = CGPoint(x: origem.minX, y: origem.minY)
            return filtro.outputImage
        }
    }
}

/// Cria o `CIContext` do renderizador (calculado em sRGB, como a saída).
func criarContextoCoreImage() -> CIContext {
    guard let espaco = CGColorSpace(name: CGColorSpace.sRGB) else { return CIContext() }
    return CIContext(options: [.workingColorSpace: espaco, .outputColorSpace: espaco])
}
