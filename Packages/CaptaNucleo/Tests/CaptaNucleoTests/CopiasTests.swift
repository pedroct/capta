import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

@Test func copiasMantemOrdemDasCamadasEDeslocam() throws {
    let a = Anotacao(geometria: .realce(CGRect(x: 0, y: 0, width: 10, height: 10)))
    let b = Anotacao(geometria: .realce(CGRect(x: 20, y: 0, width: 10, height: 10)))
    let c = Anotacao(geometria: .realce(CGRect(x: 40, y: 0, width: 10, height: 10)))
    var s = SessaoEdicao(documento: .novo(tamanhoBase: CGSize(width: 100, height: 100), escala: 1))
    for o in [a, b, c] { try s.aplicar(.adicionar(o)) }
    let novos = [UUID(), UUID()]
    var proximo = 0
    let copias = s.documento.copias(de: [c.id, a.id], deslocamento: CGVector(dx: 10, dy: 10)) {
        defer { proximo += 1 }
        return novos[proximo]
    }
    #expect(copias.map(\.id) == novos)
    #expect(copias[0].geometria == .realce(CGRect(x: 10, y: 10, width: 10, height: 10)))
    #expect(copias[1].geometria == .realce(CGRect(x: 50, y: 10, width: 10, height: 10)))
    #expect(copias[0].estilo == a.estilo)
    let nenhuma = s.documento.copias(de: [UUID()], deslocamento: .zero) { UUID() }
    #expect(nenhuma.isEmpty)
}
