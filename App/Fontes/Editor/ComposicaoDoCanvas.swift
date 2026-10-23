import CaptaNucleo
import CoreGraphics

/// Mantém a imagem composta (base + anotações) e a atualiza só na área que mudou.
///
/// A primeira chamada compõe tudo; as seguintes recompõem `areaAlterada(desde:)`. Sem mudança,
/// devolve a mesma `CGImage`. Fica na *main actor*: o contexto é mutável e a vista o consome.
@MainActor
final class ComposicaoDoCanvas {
    private let base: CGImage
    private let renderizador: Renderizador
    private let contexto: CGContext
    private var anterior: Documento?
    private var imagem: CGImage?

    init(base: CGImage, renderizador: Renderizador) throws {
        self.base = base
        self.renderizador = renderizador
        contexto = try renderizador.novoContexto(para: base)
    }

    /// A imagem composta de `documento` (sem o recorte, que é aplicado na exibição).
    func atualizar(para documento: Documento) throws -> CGImage {
        let area: CGRect?
        if let anterior, let imagem {
            switch documento.areaAlterada(desde: anterior) {
            case .nada:
                self.anterior = documento
                return imagem
            case .tudo: area = nil
            case .retangulo(let retangulo): area = retangulo
            }
        } else {
            area = nil
        }
        try renderizador.compor(documento, base: base, em: contexto, area: area)
        guard let nova = contexto.makeImage() else { throw ErroRenderizacao.falhaAoCriarContexto }
        anterior = documento
        imagem = nova
        return nova
    }
}
