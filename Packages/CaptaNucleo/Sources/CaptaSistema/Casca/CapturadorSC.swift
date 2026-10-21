import CaptaNucleo
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Captura a tela inteira com o ScreenCaptureKit (imagem única, sem cursor e sem as janelas do
/// próprio Capta).
///
/// Casca fina, fora do portão de cobertura: só chama a API do sistema. A escolha da tela,
/// o tamanho em pixels e o mapeamento de erros ficam em `Captura/` e são testados.
public struct CapturadorSC: Capturador {
    public init() {}

    /// Posição do cursor no espaço global do CoreGraphics (origem no canto superior esquerdo
    /// da tela principal), o mesmo do `frame` das telas do ScreenCaptureKit. Não usa
    /// `NSEvent.mouseLocation`, que tem origem embaixo. Sem evento, devolve um ponto não
    /// finito, que ``SelecaoDeTela`` trata como a tela principal.
    public static func posicaoDoCursor() -> CGPoint {
        CGEvent(source: nil)?.location ?? CGPoint(x: CGFloat.nan, y: .nan)
    }

    public func capturarTela(sobCursor ponto: CGPoint) async throws -> ImagemCapturada {
        do {
            let conteudo = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            // Exclui o próprio app, e não uma lista de janelas: uma janela do Capta aberta depois
            // da consulta também fica fora. O PID sempre existe; o bundle id poderia faltar.
            let meuProcesso = ProcessInfo.processInfo.processIdentifier
            let proprio = conteudo.applications.filter { $0.processID == meuProcesso }
            let telas = conteudo.displays.map { tela in
                let filtro = SCContentFilter(
                    display: tela,
                    excludingApplications: proprio,
                    exceptingWindows: []
                )
                let descricao = DescricaoDeTela(
                    id: tela.displayID,
                    quadro: tela.frame,
                    escala: Double(filtro.pointPixelScale),
                    principal: tela.displayID == CGMainDisplayID()
                )
                return (filtro: filtro, descricao: descricao)
            }
            guard
                let escolhida = SelecaoDeTela.escolher(entre: telas.map(\.descricao), sob: ponto),
                let filtro = telas.first(where: { $0.descricao == escolhida })?.filtro
            else { throw ErroCaptura.telaNaoEncontrada }
            guard let pixels = escolhida.tamanhoEmPixels else { throw ErroCaptura.falhou }

            let configuracao = SCStreamConfiguration()
            configuracao.width = pixels.largura
            configuracao.height = pixels.altura
            configuracao.captureResolution = .best
            configuracao.showsCursor = false
            let imagem = try await SCScreenshotManager.captureImage(
                contentFilter: filtro,
                configuration: configuracao
            )
            return ImagemCapturada(imagem: imagem, escala: escolhida.escala)
        } catch {
            throw MapeadorDeErroDeCaptura.mapear(error)
        }
    }
}
