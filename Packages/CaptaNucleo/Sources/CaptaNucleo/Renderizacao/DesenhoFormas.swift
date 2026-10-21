import CoreGraphics
import Foundation

extension Renderizador {
    /// Aplica a largura e o tracejado do estilo ao contexto; `false` se não há traço.
    private func prepararTraco(_ estilo: Estilo, em contexto: CGContext) -> Bool {
        guard estilo.largura > 0, estilo.largura.isFinite else { return false }
        contexto.setStrokeColor(cgCor(estilo.cor))
        contexto.setLineWidth(CGFloat(estilo.largura))
        contexto.setLineCap(.round)
        contexto.setLineJoin(.round)
        if estilo.tracejado {
            let l = CGFloat(estilo.largura)
            contexto.setLineDash(phase: 0, lengths: [l * 3, l * 2])
        } else {
            contexto.setLineDash(phase: 0, lengths: [])
        }
        return true
    }

    private func pintar(
        _ caminho: CGPath,
        estilo: Estilo,
        em contexto: CGContext
    ) {
        if let preenchimento = estilo.preenchimento {
            contexto.setFillColor(cgCor(preenchimento))
            contexto.addPath(caminho)
            contexto.fillPath()
        }
        if prepararTraco(estilo, em: contexto) {
            contexto.addPath(caminho)
            contexto.strokePath()
        }
    }

    func desenharForma(
        _ tipo: TipoForma,
        _ retangulo: CGRect,
        estilo: Estilo,
        em contexto: CGContext
    ) {
        guard let r = retanguloUtil(retangulo) else { return }
        let caminho: CGPath
        switch tipo {
        case .retangulo:
            caminho = CGPath(rect: r, transform: nil)
        case .retanguloArredondado:
            let raio = min(r.width, r.height) * 0.2
            caminho = CGPath(roundedRect: r, cornerWidth: raio, cornerHeight: raio, transform: nil)
        case .elipse:
            caminho = CGPath(ellipseIn: r, transform: nil)
        }
        pintar(caminho, estilo: estilo, em: contexto)
    }

    func desenharLinha(de inicio: CGPoint, ate fim: CGPoint, estilo: Estilo, em contexto: CGContext)
    {
        guard prepararTraco(estilo, em: contexto) else { return }
        contexto.move(to: inicio)
        contexto.addLine(to: fim)
        contexto.strokePath()
    }

    func desenharSeta(de inicio: CGPoint, ate fim: CGPoint, estilo: Estilo, em contexto: CGContext)
    {
        let dx = fim.x - inicio.x
        let dy = fim.y - inicio.y
        let comprimento = hypot(dx, dy)
        // Seta sem comprimento não tem direção: não há o que desenhar (evita NaN).
        guard comprimento.isFinite, comprimento > 0.001 else { return }
        let ux = dx / comprimento
        let uy = dy / comprimento
        let tamanhoCabeca = min(max(CGFloat(estilo.largura) * 4, 10), comprimento)
        let meiaLargura = tamanhoCabeca * 0.5
        let baseCabeca = CGPoint(x: fim.x - ux * tamanhoCabeca, y: fim.y - uy * tamanhoCabeca)

        // Corpo: termina dentro da cabeça para não aparecer na ponta.
        let fimCorpo = CGPoint(
            x: baseCabeca.x + ux * tamanhoCabeca * 0.5,
            y: baseCabeca.y + uy * tamanhoCabeca * 0.5
        )
        desenharLinha(de: inicio, ate: fimCorpo, estilo: estilo, em: contexto)

        // Cabeça: triângulo cheio na mesma cor do traço.
        contexto.setFillColor(cgCor(estilo.cor))
        contexto.move(to: fim)
        contexto.addLine(
            to: CGPoint(x: baseCabeca.x - uy * meiaLargura, y: baseCabeca.y + ux * meiaLargura)
        )
        contexto.addLine(
            to: CGPoint(x: baseCabeca.x + uy * meiaLargura, y: baseCabeca.y - ux * meiaLargura)
        )
        contexto.closePath()
        contexto.fillPath()
    }

    func desenharRealce(_ retangulo: CGRect, estilo: Estilo, em contexto: CGContext) {
        guard let r = retanguloUtil(retangulo) else { return }
        contexto.setFillColor(cgCor(estilo.preenchimento ?? estilo.cor))
        contexto.fill(r)
    }

    func desenharEtapa(
        centro: CGPoint,
        diametro: Double,
        numero: Int?,
        estilo: Estilo,
        em contexto: CGContext
    ) {
        guard diametro.isFinite, diametro > 0, centro.x.isFinite, centro.y.isFinite else { return }
        let d = CGFloat(diametro)
        let area = CGRect(x: centro.x - d / 2, y: centro.y - d / 2, width: d, height: d)
        let fundo = estilo.preenchimento ?? estilo.cor
        contexto.setFillColor(cgCor(fundo))
        contexto.fillEllipse(in: area)
        if prepararTraco(estilo, em: contexto) {
            contexto.strokeEllipse(in: area)
        }
        guard let numero else { return }
        // Branco sobre o fundo; só fundos quase brancos pedem o preto do design system.
        let luminancia = 0.2126 * fundo.r + 0.7152 * fundo.g + 0.0722 * fundo.b
        let corNumero: CorRGBA = luminancia > 0.85 ? .preto : .branco
        desenharLinhaCentrada(
            String(numero),
            em: centro,
            fonte: EstiloDeTexto(
                tamanho: diametro * 0.55,
                negrito: true,
                italico: false,
                cor: corNumero
            ),
            contexto: contexto
        )
    }
}
