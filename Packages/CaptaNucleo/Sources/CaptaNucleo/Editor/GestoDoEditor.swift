import CoreGraphics
import Foundation

/// Gesto do mouse em andamento (botão apertado), com o que for preciso para recalcular a
/// partir do clique.
enum GestoDoEditor: Equatable, Sendable {
    /// Retângulo de seleção: `anterior` é o que já estava selecionado (com `⇧`).
    case marcando(inicio: CGPoint, anterior: Set<UUID>)
    /// Mover a seleção. `moveu`: o cursor já se afastou do clique alguma vez. `comPrevia`: há
    /// prévia na tela agora. `colapsarPara` é o objeto que vira a seleção única se o clique
    /// terminar sem arraste.
    case movendo(inicio: CGPoint, moveu: Bool, comPrevia: Bool, colapsarPara: UUID?)
    /// Arrastar uma alça (ou o ponto de giro) do objeto `original`. `folga` é a distância da
    /// alça ao pixel do clique, somada ao cursor para a alça não pular até ele.
    case alca(AlcaArrastada, original: Anotacao, folga: CGVector, comPrevia: Bool)
    /// Criar o objeto `id` com a ferramenta ativa, a partir de `inicio`.
    case criando(id: UUID, inicio: CGPoint, comPrevia: Bool)

    var temPrevia: Bool {
        switch self {
        case .marcando: false
        case .movendo(_, _, let comPrevia, _): comPrevia
        case .alca(_, _, _, let comPrevia): comPrevia
        case .criando(_, _, let comPrevia): comPrevia
        }
    }
}

/// A alça sob o clique: qual é, de quem, e onde está.
struct AlcaEncontrada {
    var alca: AlcaArrastada
    var objeto: Anotacao
    var posicao: CGPoint
}

enum AlcaArrastada: Equatable, Sendable {
    case redimensionar(AlcaDeObjeto)
    case girar
}

extension GestoDoEditor {
    static func retangulo(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y).standardized
    }

    /// Deslocamento do clique até o ponto; com `restrito`, só no eixo dominante.
    static func delta(de inicio: CGPoint, ate ponto: CGPoint, restrito: Bool) -> CGVector {
        var dx = ponto.x - inicio.x
        var dy = ponto.y - inicio.y
        if restrito {
            if abs(dx) >= abs(dy) { dy = 0 } else { dx = 0 }
        }
        return CGVector(dx: dx, dy: dy)
    }

    static func editada(
        _ original: Anotacao,
        _ alca: AlcaArrastada,
        _ cursor: CGPoint,
        _ folga: CGVector,
        _ restrito: Bool
    ) -> Anotacao {
        let ponto = CGPoint(x: cursor.x + folga.dx, y: cursor.y + folga.dy)
        switch alca {
        case .redimensionar(let alca):
            return original.arrastando(alca, ate: ponto, restrito: restrito)
        case .girar: return original.girando(ate: ponto, restrito: restrito)
        }
    }
}
