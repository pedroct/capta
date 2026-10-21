import CaptaNucleo
import CoreGraphics
import Foundation

/// O que o ScreenCaptureKit precisa para capturar uma região ao vivo.
public struct PedidoDeRegiao: Equatable, Sendable {
    /// Retângulo em pontos relativo à origem da tela (o `sourceRect` da configuração).
    public let origem: CGRect
    /// Tamanho de saída em pixels nativos, igual ao da seleção.
    public let largura: Int
    public let altura: Int
}

/// O que o ScreenCaptureKit precisa para capturar uma janela.
public struct PedidoDeJanela: Equatable, Sendable {
    /// Escala da tela com a maior interseção com a janela.
    public let escala: Double
    /// Tamanho de saída em pixels: quadro × escala, arredondado.
    public let largura: Int
    public let altura: Int
}

/// Contas em volta do ScreenCaptureKit que não precisam de tela nem de permissão: o pedido de
/// região e de janela e a ordem das janelas. A casca (`CapturadorSC`) só monta a chamada.
public enum GeometriaDeCaptura {
    /// Pedido de captura de `pixels` (pixels locais da tela, origem no canto superior
    /// esquerdo) em `tela`. A tela tem de continuar em `atuais` com o mesmo id, o mesmo quadro
    /// e a mesma escala; quem é a principal não importa.
    /// - Throws: ``ErroCaptura/telaNaoEncontrada`` se a tela sumiu, mudou de lugar, de
    ///   resolução ou de escala; ``ErroCaptura/falhou`` se `pixels` não for um retângulo de
    ///   pixels inteiros, com área, dentro da tela.
    public static func pedidoDeRegiao(
        pixels: CGRect,
        em tela: DescricaoDeTela,
        atuais: [DescricaoDeTela]
    ) throws -> PedidoDeRegiao {
        guard
            let atual = atuais.first(where: { $0.id == tela.id }),
            atual.quadro == tela.quadro, atual.escala == tela.escala
        else { throw ErroCaptura.telaNaoEncontrada }
        guard
            let limites = tela.tamanhoEmPixels,
            let esquerda = inteiro(pixels.minX), let topo = inteiro(pixels.minY),
            let largura = inteiro(pixels.width), let altura = inteiro(pixels.height),
            esquerda >= 0, topo >= 0, largura >= 1, altura >= 1,
            esquerda + largura <= limites.largura, topo + altura <= limites.altura
        else { throw ErroCaptura.falhou }
        // O mesmo que `tela.quadroEmPontos(dePixels:)` menos a origem da tela, sem passar
        // pelo espaço global (evita somar e subtrair a origem em ponto flutuante).
        let origem = CGRect(
            x: pixels.minX / tela.escala,
            y: pixels.minY / tela.escala,
            width: pixels.width / tela.escala,
            height: pixels.height / tela.escala
        )
        return PedidoDeRegiao(origem: origem, largura: largura, altura: altura)
    }

    /// Pedido de captura de `janela`: a escala é a da tela escolhida por
    /// `ListaDeJanelas.tela(de:entre:)` (maior interseção) e o tamanho, o quadro vezes essa
    /// escala, arredondado.
    /// - Throws: ``ErroCaptura/telaNaoEncontrada`` se a janela não cruza nenhuma tela;
    ///   ``ErroCaptura/falhou`` se o tamanho não render ao menos um pixel em cada lado.
    public static func pedidoDeJanela(
        _ janela: JanelaDeTela,
        entre telas: [DescricaoDeTela]
    ) throws -> PedidoDeJanela {
        guard let tela = ListaDeJanelas.tela(de: janela, entre: telas) else {
            throw ErroCaptura.telaNaoEncontrada
        }
        guard
            let largura = inteiro((janela.quadro.width * tela.escala).rounded()),
            let altura = inteiro((janela.quadro.height * tela.escala).rounded()),
            largura >= 1, altura >= 1
        else { throw ErroCaptura.falhou }
        return PedidoDeJanela(escala: tela.escala, largura: largura, altura: altura)
    }

    /// Ordena `janelas` pela ordem de empilhamento `frenteParaTras` (ids, a primeira é a mais
    /// à frente). Janela sem posição conhecida vai para o fim, na ordem em que veio; id
    /// repetido vale pela primeira posição.
    public static func ordenar(
        _ janelas: [JanelaDeTela],
        frenteParaTras ids: [UInt32]
    ) -> [JanelaDeTela] {
        var posicao: [UInt32: Int] = [:]
        for (indice, id) in ids.enumerated() where posicao[id] == nil {
            posicao[id] = indice
        }
        // A chave inclui o índice original, então a ordenação é estável.
        return janelas.enumerated()
            .sorted { a, b in
                let chaveA = (posicao[a.element.id] ?? ids.count, a.offset)
                let chaveB = (posicao[b.element.id] ?? ids.count, b.offset)
                return chaveA < chaveB
            }
            .map(\.element)
    }

    /// Ids (`kCGWindowNumber`) das entradas de `CGWindowListCopyWindowInfo`, na ordem da
    /// lista. Entrada sem número, com tipo errado ou fora de `UInt32` é ignorada.
    public static func idsDeJanelas(_ info: [[String: Any]]) -> [UInt32] {
        info.compactMap { entrada in
            (entrada[kCGWindowNumber as String] as? Int).flatMap { UInt32(exactly: $0) }
        }
    }

    /// O valor como `Int` se for um inteiro finito representável.
    private static func inteiro(_ valor: CGFloat) -> Int? {
        Int(exactly: valor)
    }
}
