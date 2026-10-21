import AppKit
import CaptaNucleo
import CoreGraphics

/// Provedor de símbolos do sistema (SF Symbols) para os carimbos.
///
/// Fica em `CaptaSistema` porque usa AppKit; o núcleo só conhece o protocolo.
public struct ProvedorDeSimbolosSF: ProvedorDeSimbolos {
    public init() {}

    /// Renderiza o símbolo em `lado` x `lado` pixels, tingido com `cor` (sRGB).
    /// Devolve `nil` para nome desconhecido ou `lado` inválido.
    public func imagem(simbolo: String, lado: Double, cor: CorRGBA) -> CGImage? {
        guard lado.isFinite, lado >= 1, lado <= 4096 else { return nil }
        let pixels = Int(lado.rounded())
        guard
            let original = NSImage(systemSymbolName: simbolo, accessibilityDescription: nil),
            let espaco = CGColorSpace(name: CGColorSpace.sRGB),
            let contexto = CGContext(
                data: nil,
                width: pixels,
                height: pixels,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: espaco,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        let configuracao = NSImage.SymbolConfiguration(pointSize: lado * 0.8, weight: .regular)
        let simboloConfigurado = original.withSymbolConfiguration(configuracao) ?? original
        let tamanho = simboloConfigurado.size
        guard tamanho.width > 0, tamanho.height > 0 else { return nil }
        // Ajusta o símbolo ao quadrado, centralizado e sem distorcer.
        let escala = min(lado / tamanho.width, lado / tamanho.height)
        let destino = CGRect(
            x: (lado - tamanho.width * escala) / 2,
            y: (lado - tamanho.height * escala) / 2,
            width: tamanho.width * escala,
            height: tamanho.height * escala
        )

        let grafico = NSGraphicsContext(cgContext: contexto, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = grafico
        simboloConfigurado.draw(in: destino)
        NSGraphicsContext.restoreGraphicsState()

        // Tinge: mantém só a forma (alfa) do símbolo e pinta com a cor pedida.
        contexto.setBlendMode(.sourceIn)
        contexto.setFillColor(
            CGColor(
                colorSpace: espaco,
                components: [CGFloat(cor.r), CGFloat(cor.g), CGFloat(cor.b), CGFloat(cor.a)]
            ) ?? CGColor(gray: 0, alpha: 1)
        )
        contexto.fill(CGRect(x: 0, y: 0, width: lado, height: lado))
        return contexto.makeImage()
    }
}
