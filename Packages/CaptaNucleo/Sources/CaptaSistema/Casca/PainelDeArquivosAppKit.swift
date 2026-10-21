import AppKit
import CaptaNucleo
import UniformTypeIdentifiers

/// Painel de salvar do sistema (`NSSavePanel`).
///
/// Casca fina, fora do portão de cobertura: só chama a API do sistema.
@MainActor
public struct PainelDeArquivosAppKit: PainelDeArquivos {
    public init() {}

    /// Devolve a URL escolhida ou `nil` se o usuário cancelou.
    public func escolherDestino(nomeSugerido: String, extensao: String) async -> URL? {
        let painel = NSSavePanel()
        painel.nameFieldStringValue = "\(nomeSugerido).\(extensao)"
        painel.canCreateDirectories = true
        // A declaração do tipo `.capta` só entra no Info.plist depois; sem ela, só sugere a extensão.
        let identificador = extensao == "capta" ? "com.pedroct.capta.documento" : nil
        if let tipo = identificador.flatMap({ UTType($0) }) ?? UTType(filenameExtension: extensao) {
            painel.allowedContentTypes = [tipo]
        }
        let resposta = await painel.begin()
        return resposta == .OK ? painel.url : nil
    }
}
