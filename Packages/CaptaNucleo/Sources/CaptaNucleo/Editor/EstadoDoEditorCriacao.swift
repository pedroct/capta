import CoreGraphics
import Foundation

/// Criação de seta, linha, forma e realce arrastando na imagem.
extension EstadoDoEditor {
    /// O objeto em criação, do `inicio` ao `ponto`, com o estilo lembrado da ferramenta.
    /// `⇧` prende a seta e a linha em múltiplos de 45° e faz a forma virar quadrado.
    func criada(id: UUID, de inicio: CGPoint, ate ponto: CGPoint, shift: Bool) -> Anotacao {
        let estilo = memoria[ferramenta]
        switch ferramenta {
        case .seta, .linha:
            let base: Geometria =
                ferramenta == .seta
                ? .seta(inicio: inicio, fim: inicio) : .linha(inicio: inicio, fim: inicio)
            // A alça do fim já sabe prender o ângulo (Tarefa 4).
            return Anotacao(id: id, geometria: base, estilo: estilo)
                .arrastando(.fim, ate: ponto, restrito: shift)
        case .forma:
            let canto = shift ? Self.quadrado(de: inicio, ate: ponto) : ponto
            return Anotacao(
                id: id,
                geometria: .forma(tipoForma, GestoDoEditor.retangulo(inicio, canto)),
                estilo: estilo
            )
        case .realce, .selecao:
            // `.selecao` não cria; o gesto de criação só nasce nas outras ferramentas.
            return Anotacao(
                id: id,
                geometria: .realce(GestoDoEditor.retangulo(inicio, ponto)),
                estilo: estilo
            )
        }
    }

    /// Soltar: arraste curto demais não cria nada; senão grava e seleciona o novo objeto.
    mutating func concluirCriacao(
        id: UUID,
        inicio: CGPoint,
        _ ponto: CGPoint,
        _ shift: Bool,
        _ contexto: ContextoDoEditor
    ) -> AcaoDoEditor? {
        guard hypot(ponto.x - inicio.x, ponto.y - inicio.y) >= contexto.tolerancia else {
            return .cancelarPrevia
        }
        selecao = [id]
        return .aplicar(.adicionar(criada(id: id, de: inicio, ate: ponto, shift: shift)))
    }

    /// Canto oposto de um quadrado cujo lado é o maior dos deslocamentos, na direção do cursor.
    private static func quadrado(de inicio: CGPoint, ate ponto: CGPoint) -> CGPoint {
        let dx = ponto.x - inicio.x
        let dy = ponto.y - inicio.y
        let lado = max(abs(dx), abs(dy))
        return CGPoint(
            x: inicio.x + (dx < 0 ? -lado : lado),
            y: inicio.y + (dy < 0 ? -lado : lado)
        )
    }
}
