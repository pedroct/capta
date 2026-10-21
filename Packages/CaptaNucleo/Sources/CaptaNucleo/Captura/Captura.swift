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

extension ImagemCapturada {
    /// Devolve a própria imagem se ela tiver exatamente `largura` x `altura` pixels.
    /// - Throws: ``ErroCaptura/tamanhoInesperado`` se o tamanho diferir, mesmo por um pixel.
    public func conferindo(largura: Int, altura: Int) throws -> ImagemCapturada {
        guard imagem.width == largura, imagem.height == altura else {
            throw ErroCaptura.tamanhoInesperado
        }
        return self
    }
}

// `CGImage` é imutável depois de criada, então compartilhá-la entre threads é seguro,
// mas o SDK não a declara `Sendable`.
/// Imagem congelada de uma tela, em pixels nativos, junto da descrição da tela de origem.
public struct TelaCongelada: @unchecked Sendable {
    public let descricao: DescricaoDeTela
    public let imagem: CGImage

    public init(descricao: DescricaoDeTela, imagem: CGImage) {
        self.descricao = descricao
        self.imagem = imagem
    }
}

/// Falhas ao capturar a tela.
public enum ErroCaptura: Error, Equatable, Sendable {
    case semPermissao
    case telaNaoEncontrada
    case janelaNaoEncontrada
    case tamanhoInesperado
    case falhou
}

/// Captura a tela; a implementação real fica em `CaptaSistema`.
public protocol Capturador: Sendable {
    func capturarTela(sobCursor ponto: CGPoint) async throws -> ImagemCapturada

    /// Congela todas as telas, uma imagem em pixels nativos por tela.
    func congelarTelas() async throws -> [TelaCongelada]

    /// Janelas visíveis, já na ordem da frente para trás.
    func listarJanelas() async throws -> [JanelaDeTela]

    /// Captura `pixels` (pixels nativos, origem no canto superior esquerdo da tela) de `tela`.
    /// - Throws: ``ErroCaptura/telaNaoEncontrada`` se a tela atual não for igual a `tela`.
    func capturarRegiao(
        em tela: DescricaoDeTela,
        pixels: CGRect,
        incluirCursor: Bool
    ) async throws -> ImagemCapturada

    /// Captura uma janela pelo `CGWindowID`.
    func capturarJanela(id: UInt32, incluirCursor: Bool) async throws -> ImagemCapturada
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
