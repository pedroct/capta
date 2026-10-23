import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

/// Monta um `EditorDaCaptura` sobre uma captura de teste (rascunho falho e salvamento de mentira),
/// com as `UserDefaults` isoladas que o chamador entrega.
@MainActor
func editorDeTeste(
    _ defaults: UserDefaults,
    largura: Int = 200,
    altura: Int = 100,
    escala: Double = 1,
    objetos: [Anotacao] = []
) throws -> EditorDaCaptura {
    let imagem = try imagemDeTeste(largura: largura, altura: altura)
    let aberta = CapturaAberta(
        nome: "teste",
        documento: try Documento.novo(de: ImagemCapturada(imagem: imagem, escala: escala)),
        base: imagem,
        escala: escala,
        rascunho: .falhou,
        renderizador: Renderizador(),
        painel: PainelFalso(destino: nil),
        areaDeTransferencia: AreaDeTransferenciaFalsa(),
        gravadorDeRascunho: { _, _, _, _ in throw ErroDeTeste() },
        salvamento: SalvamentoAutomatico(dormir: { _ in }, gravar: { _, _ in })
    )
    for objeto in objetos { aberta.aplicar(.adicionar(objeto)) }
    return EditorDaCaptura(captura: aberta, memoria: MemoriaLembrada(defaults: defaults))
}

/// Roda `corpo` com um domínio de `UserDefaults` descartável.
@MainActor
func comDefaultsDeTeste(_ corpo: (UserDefaults) throws -> Void) throws {
    let nome = "capta.testes.editor.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: nome))
    defer { defaults.removePersistentDomain(forName: nome) }
    try corpo(defaults)
}

/// Seta de teste com id fixo.
func setaDeTeste(_ id: UUID = UUID(), estilo: Estilo = Estilo()) -> Anotacao {
    Anotacao(
        id: id,
        geometria: .seta(inicio: CGPoint(x: 10, y: 10), fim: CGPoint(x: 80, y: 40)),
        estilo: estilo
    )
}
