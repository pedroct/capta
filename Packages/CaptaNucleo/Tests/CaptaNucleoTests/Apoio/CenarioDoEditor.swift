import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

// Cenário comum dos testes do editor: A (1) e B (2), 100x100, lado a lado.

func idDoEditor(_ n: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, n))
}

func realceDoEditor(_ n: UInt8, _ r: CGRect) -> Anotacao {
    Anotacao(id: idDoEditor(n), geometria: .realce(r))
}

/// A (1) em 100...200 e B (2) em 300...400, ambos 100x100, ao lado um do outro.
let anotacaoA = realceDoEditor(1, CGRect(x: 100, y: 100, width: 100, height: 100))
let anotacaoB = realceDoEditor(2, CGRect(x: 300, y: 100, width: 100, height: 100))

func documentoDoEditor(_ anotacoes: [Anotacao]) throws -> Documento {
    var sessao = SessaoEdicao(
        documento: .novo(tamanhoBase: CGSize(width: 1000, height: 1000), escala: 1)
    )
    for anotacao in anotacoes { try sessao.aplicar(.adicionar(anotacao)) }
    return sessao.documento
}

func contextoDoEditor(_ doc: Documento, novosIds: [UUID] = []) -> ContextoDoEditor {
    var fila = novosIds
    return ContextoDoEditor(
        documento: doc,
        tolerancia: 4,
        distanciaDoGiro: 20,
        novoId: { fila.isEmpty ? UUID() : fila.removeFirst() }
    )
}

func editorCom(selecao: Set<UUID> = []) -> EstadoDoEditor {
    var estado = EstadoDoEditor(memoria: MemoriaDeEstilos())
    estado.selecao = selecao
    return estado
}

func pontoDoEditor(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
