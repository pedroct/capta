import CoreGraphics
import Foundation
import Testing

@testable import CaptaNucleo

private func anotacao(_ x: Double = 0) -> Anotacao {
    Anotacao(geometria: .realce(CGRect(x: x, y: 0, width: 10, height: 10)))
}

private func vazio() -> Documento {
    .novo(tamanhoBase: CGSize(width: 100, height: 100), escala: 1)
}

@Test func loteDeDuasEdicoesDesfazNumPassoSo() throws {
    let a = anotacao()
    var s = SessaoEdicao(documento: vazio())
    try s.aplicar(.lote([.adicionar(a), .mover([a.id], deslocamento: CGVector(dx: 5, dy: 0))]))
    #expect(
        s.documento.objetos.first?.geometria == .realce(CGRect(x: 5, y: 0, width: 10, height: 10))
    )
    let desfez = s.desfazer()
    #expect(desfez)
    #expect(s.documento == vazio())
    #expect(!s.podeDesfazer)
}

@Test func loteInvalidoNaoMudaNada() throws {
    let a = anotacao()
    var s = SessaoEdicao(documento: vazio())
    try s.aplicar(.adicionar(a))
    let antes = s.documento
    let inexistente = UUID()
    #expect(throws: ErroDocumento.objetoInexistente(inexistente)) {
        try s.aplicar(
            .lote([.mover([a.id], deslocamento: CGVector(dx: 1, dy: 1)), .remover([inexistente])])
        )
    }
    #expect(s.documento == antes)
    let desfez = s.desfazer()
    #expect(desfez)
    #expect(!s.podeDesfazer)
}

@Test func loteVazioNaoCriaEntrada() throws {
    var s = SessaoEdicao(documento: vazio())
    try s.aplicar(.lote([]))
    #expect(!s.podeDesfazer)
    #expect(s.documento == vazio())
}

@Test func loteAninhadoAplicaEmOrdem() throws {
    let a = anotacao()
    let b = anotacao(50)
    var s = SessaoEdicao(documento: vazio())
    try s.aplicar(.lote([.adicionar(a), .lote([.adicionar(b), .remover([a.id])])]))
    #expect(s.documento.objetos.map(\.id) == [b.id])
    let desfez = s.desfazer()
    #expect(desfez)
    #expect(!s.podeDesfazer)
}

@Test func simularNaoTocaHistorico() throws {
    let a = anotacao()
    var s = SessaoEdicao(documento: vazio())
    try s.aplicar(.adicionar(a))
    let antes = s.documento
    let simulado = try s.simular(.mover([a.id], deslocamento: CGVector(dx: 3, dy: 4)))
    #expect(simulado.objetos.first?.geometria == .realce(CGRect(x: 3, y: 4, width: 10, height: 10)))
    #expect(s.documento == antes)
    let desfez = s.desfazer()
    #expect(desfez)
    #expect(!s.podeDesfazer)
}

@Test func simularInvalidoLanca() {
    let s = SessaoEdicao(documento: vazio())
    let id = UUID()
    #expect(throws: ErroDocumento.objetoInexistente(id)) { try s.simular(.remover([id])) }
}
