import CoreGraphics
import Foundation

// `CGImage` é imutável depois de criada, então compartilhá-la entre threads é seguro,
// mas o SDK não a declara `Sendable`.
/// Imagem recém-capturada, em pixels, com a escala do display de origem.
public struct ImagemCapturada: @unchecked Sendable {
    public let imagem: CGImage
    public let escala: Double

    public init(imagem: CGImage, escala: Double) {
        self.imagem = imagem
        self.escala = escala
    }
}

/// Falhas ao capturar a tela.
public enum ErroCaptura: Error, Equatable, Sendable {
    case semPermissao
    case telaNaoEncontrada
    case falhou
}

/// Captura a tela; a implementação real fica em `CaptaSistema`.
public protocol Capturador: Sendable {
    func capturarTela(sobCursor ponto: CGPoint) async throws -> ImagemCapturada
}

extension Documento {
    /// Documento vazio com o tamanho em pixels e a escala da captura.
    /// - Throws: ``ErroDocumento/tamanhoInvalido`` se a escala não for válida.
    public static func novo(de captura: ImagemCapturada) throws -> Documento {
        let documento = novo(
            tamanhoBase: CGSize(width: captura.imagem.width, height: captura.imagem.height),
            escala: captura.escala
        )
        try documento.validar()
        return documento
    }
}
