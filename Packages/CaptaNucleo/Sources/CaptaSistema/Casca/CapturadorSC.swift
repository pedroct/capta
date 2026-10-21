import CaptaNucleo
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Captura telas e janelas com o ScreenCaptureKit (imagem única), sempre sem as janelas do
/// próprio Capta.
///
/// Casca fina, fora do portão de cobertura: só chama a API do sistema. A escolha da tela,
/// o tamanho em pixels, o pedido de região e de janela, a ordem das janelas e o mapeamento de
/// erros ficam em `Captura/` e são testados.
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
            let telas = Self.telas(de: try await Self.conteudo(soNaTela: true))
            guard
                let escolhida = SelecaoDeTela.escolher(entre: telas.map(\.descricao), sob: ponto),
                let filtro = telas.first(where: { $0.descricao == escolhida })?.filtro
            else { throw ErroCaptura.telaNaoEncontrada }
            guard let pixels = escolhida.tamanhoEmPixels else { throw ErroCaptura.falhou }

            let configuracao = Self.configuracao(
                largura: pixels.largura,
                altura: pixels.altura,
                incluirCursor: false
            )
            let imagem = try await SCScreenshotManager.captureImage(
                contentFilter: filtro,
                configuration: configuracao
            )
            return ImagemCapturada(imagem: imagem, escala: escolhida.escala)
        } catch {
            throw MapeadorDeErroDeCaptura.mapear(error)
        }
    }

    public func congelarTelas() async throws -> [TelaCongelada] {
        do {
            let telas = Self.telas(de: try await Self.conteudo(soNaTela: true))
            guard !telas.isEmpty else { throw ErroCaptura.telaNaoEncontrada }
            // Uma tarefa por tela; o índice devolve as imagens na ordem das telas. Se uma
            // falhar, o erro sai do grupo e as demais são canceladas.
            return try await withThrowingTaskGroup(of: (Int, TelaCongelada).self) { grupo in
                for (indice, tela) in telas.enumerated() {
                    grupo.addTask {
                        (indice, try await Self.congelar(tela))
                    }
                }
                var congeladas: [(Int, TelaCongelada)] = []
                for try await congelada in grupo {
                    congeladas.append(congelada)
                }
                return congeladas.sorted { $0.0 < $1.0 }.map(\.1)
            }
        } catch {
            throw MapeadorDeErroDeCaptura.mapear(error)
        }
    }

    public func listarJanelas() async throws -> [JanelaDeTela] {
        do {
            let conteudo = try await Self.conteudo(soNaTela: true)
            let janelas = conteudo.windows
                .filter { !Self.ehDoProprioApp($0) }
                .map(Self.descricao(de:))
            // O ScreenCaptureKit não documenta a ordem de `windows`. A de
            // `CGWindowListCopyWindowInfo` com `optionOnScreenOnly` é documentada como da
            // frente para trás e só lê número, camada e quadro (sem permissão extra); ela
            // ordena a lista. Sem ela, fica a ordem do ScreenCaptureKit.
            let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
            let ordem = GeometriaDeCaptura.idsDeJanelas((info as? [[String: Any]]) ?? [])
            return GeometriaDeCaptura.ordenar(janelas, frenteParaTras: ordem)
        } catch {
            throw MapeadorDeErroDeCaptura.mapear(error)
        }
    }

    public func capturarRegiao(
        em tela: DescricaoDeTela,
        pixels: CGRect,
        incluirCursor: Bool
    ) async throws -> ImagemCapturada {
        do {
            let telas = Self.telas(de: try await Self.conteudo(soNaTela: true))
            let pedido = try GeometriaDeCaptura.pedidoDeRegiao(
                pixels: pixels,
                em: tela,
                atuais: telas.map(\.descricao)
            )
            guard let filtro = telas.first(where: { $0.descricao.id == tela.id })?.filtro else {
                throw ErroCaptura.telaNaoEncontrada
            }
            let configuracao = Self.configuracao(
                largura: pedido.largura,
                altura: pedido.altura,
                incluirCursor: incluirCursor
            )
            // Em pontos, relativo à origem da tela (espaço lógico da tela).
            configuracao.sourceRect = pedido.origem
            let imagem = try await SCScreenshotManager.captureImage(
                contentFilter: filtro,
                configuration: configuracao
            )
            return try ImagemCapturada(imagem: imagem, escala: tela.escala)
                .conferindo(largura: pedido.largura, altura: pedido.altura)
        } catch {
            throw MapeadorDeErroDeCaptura.mapear(error)
        }
    }

    public func capturarJanela(id: UInt32, incluirCursor: Bool) async throws -> ImagemCapturada {
        do {
            // Todas as janelas, não só as visíveis: a escolhida pode ter saído da tela
            // durante o atraso e ainda assim é capturada inteira.
            let conteudo = try await Self.conteudo(soNaTela: false)
            guard
                let alvo = conteudo.windows.first(where: {
                    $0.windowID == id && !Self.ehDoProprioApp($0)
                })
            else { throw ErroCaptura.janelaNaoEncontrada }
            let pedido = try GeometriaDeCaptura.pedidoDeJanela(
                Self.descricao(de: alvo),
                entre: Self.telas(de: conteudo).map(\.descricao)
            )
            let filtro = SCContentFilter(desktopIndependentWindow: alvo)
            let configuracao = Self.configuracao(
                largura: pedido.largura,
                altura: pedido.altura,
                incluirCursor: incluirCursor
            )
            configuracao.ignoreShadowsSingleWindow = true
            // Parte da janela fora da tela não é cortada.
            configuracao.ignoreGlobalClipSingleWindow = true
            let imagem = try await SCScreenshotManager.captureImage(
                contentFilter: filtro,
                configuration: configuracao
            )
            return try ImagemCapturada(imagem: imagem, escala: pedido.escala)
                .conferindo(largura: pedido.largura, altura: pedido.altura)
        } catch {
            throw MapeadorDeErroDeCaptura.mapear(error)
        }
    }

    // MARK: - Apoio

    // O SDK não declara `SCContentFilter` `Sendable`; aqui ele é criado uma vez, nunca
    // alterado e só lido pela tarefa que congela a tela, então passar entre tarefas é seguro.
    /// Uma tela do ScreenCaptureKit com o filtro que exclui o próprio app e a descrição pura.
    private struct Tela: @unchecked Sendable {
        let filtro: SCContentFilter
        let descricao: DescricaoDeTela
    }

    private static func conteudo(soNaTela: Bool) async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: soNaTela)
    }

    /// As telas de `conteudo`, cada uma com um filtro que exclui o próprio app, e não uma
    /// lista de janelas: uma janela do Capta aberta depois da consulta também fica fora.
    /// O PID sempre existe; o bundle id poderia faltar.
    private static func telas(de conteudo: SCShareableContent) -> [Tela] {
        let meuProcesso = ProcessInfo.processInfo.processIdentifier
        let proprio = conteudo.applications.filter { $0.processID == meuProcesso }
        return conteudo.displays.map { tela in
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
            return Tela(filtro: filtro, descricao: descricao)
        }
    }

    /// A tela inteira em pixels nativos, sem cursor, conferida no tamanho esperado.
    private static func congelar(_ tela: Tela) async throws -> TelaCongelada {
        guard let pixels = tela.descricao.tamanhoEmPixels else { throw ErroCaptura.falhou }
        let configuracao = configuracao(
            largura: pixels.largura,
            altura: pixels.altura,
            incluirCursor: false
        )
        let imagem = try await SCScreenshotManager.captureImage(
            contentFilter: tela.filtro,
            configuration: configuracao
        )
        let conferida = try ImagemCapturada(imagem: imagem, escala: tela.descricao.escala)
            .conferindo(largura: pixels.largura, altura: pixels.altura)
        return TelaCongelada(descricao: tela.descricao, imagem: conferida.imagem)
    }

    private static func configuracao(
        largura: Int,
        altura: Int,
        incluirCursor: Bool
    ) -> SCStreamConfiguration {
        let configuracao = SCStreamConfiguration()
        configuracao.width = largura
        configuracao.height = altura
        configuracao.captureResolution = .best
        configuracao.showsCursor = incluirCursor
        return configuracao
    }

    private static func ehDoProprioApp(_ janela: SCWindow) -> Bool {
        janela.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier
    }

    private static func descricao(de janela: SCWindow) -> JanelaDeTela {
        JanelaDeTela(
            id: janela.windowID,
            quadro: janela.frame,
            camada: janela.windowLayer,
            naTela: janela.isOnScreen
        )
    }
}
