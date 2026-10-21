import CoreGraphics
import Foundation

/// Exporta o documento como imagem.
public enum Exportador {
    /// Renderiza `documento` sobre `base` (com o recorte, se houver) e codifica em PNG na
    /// escala do documento.
    /// - Throws: os erros do renderizador e de ``CodificadorPNG``.
    public static func png(
        _ documento: Documento,
        base: CGImage,
        renderizador: Renderizador
    ) throws -> Data {
        let imagem = try renderizador.renderizar(documento, base: base)
        return try CodificadorPNG.codificar(imagem, escala: documento.escala)
    }
}

/// Falhas ao entregar o resultado da exportação ao sistema.
public enum ErroExportacao: Error, Equatable, Sendable {
    case falhaAoCopiar
    case falhaAoGravar
}
