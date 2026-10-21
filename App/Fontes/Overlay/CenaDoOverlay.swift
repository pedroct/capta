import CaptaNucleo
import CoreGraphics
import Foundation

/// Medidas do overlay, em pontos.
enum MedidasDoOverlay {
    static let ladoDaAlca: CGFloat = 7
    static let espessuraDoContorno: CGFloat = 2
    /// Distância entre um rótulo e o ponto ou a seleção a que ele se refere.
    static let afastamento = CGFloat(Tema.Espaco.e3)
    static let afastamentoDaLupa = CGFloat(Tema.Espaco.e4)
    /// Folga interna dos rótulos (horizontal, vertical).
    static let folgaDoRotulo = CGSize(width: 8, height: 2)
    /// Pixels nativos amostrados por lado (ímpar: o pixel do cursor fica no meio).
    static let ladoDaLupa = 15
    /// Cada pixel nativo vira um quadrado de `ampliacao` pontos.
    static let ampliacao: CGFloat = 8
}

/// Textos do overlay, todos do String Catalog.
enum TextosDoOverlay {
    static var acessibilidade: String { String(localized: "Seleção de captura. Esc cancela.") }

    /// `largura × altura` em pixels nativos.
    /// Sem separador de milhar (`1920 × 1080`), como o token `dimensao`.
    static func dimensoes(_ pixels: CGRect) -> String {
        let largura = String(Int(pixels.width))
        let altura = String(Int(pixels.height))
        return String(localized: "\(largura) × \(altura)")
    }

    /// Coordenada do pixel, `x, y`.
    static func coordenada(_ pixel: CGPoint) -> String {
        let x = String(Int(pixel.x))
        let y = String(Int(pixel.y))
        return String(localized: "\(x), \(y)")
    }

    static func modo(_ modo: ModoDoOverlay) -> String {
        switch modo {
        case .regiao: String(localized: "Região")
        case .janela: String(localized: "Janela")
        }
    }
}

extension DescricaoDeTela {
    /// Ponto global (pontos, origem no topo) para o ponto local da vista desta tela.
    func local(de ponto: CGPoint) -> CGPoint {
        CGPoint(x: ponto.x - quadro.minX, y: ponto.y - quadro.minY)
    }

    /// Ponto local da vista desta tela para o ponto global.
    func global(de ponto: CGPoint) -> CGPoint {
        CGPoint(x: ponto.x + quadro.minX, y: ponto.y + quadro.minY)
    }

    func local(de retangulo: CGRect) -> CGRect {
        retangulo.offsetBy(dx: -quadro.minX, dy: -quadro.minY)
    }

    /// Pixels locais da tela para pontos locais da vista, pela conversão do núcleo.
    func localDePixels(_ pixels: CGRect) -> CGRect {
        local(de: quadroEmPontos(dePixels: pixels))
    }
}

/// O que uma `VistaDoOverlay` desenha, em pontos locais da vista (origem no canto superior
/// esquerdo da tela dela, Y para baixo). Sai só do estado: nenhuma regra de seleção aqui.
struct CenaDoOverlay: Equatable {
    struct Rotulo: Equatable {
        let texto: String
        let quadro: CGRect
    }

    struct Ampliacao: Equatable {
        /// Pixels da imagem congelada mostrados.
        let amostra: CGRect
        /// Área da imagem ampliada.
        let quadro: CGRect
        /// Quadrado do pixel sob o cursor, dentro de `quadro`.
        let pixelSobCursor: CGRect
        let coordenada: Rotulo
    }

    /// Área mostrada sem escurecer (seleção ou janela realçada).
    var furo: CGRect?
    var selecao: CGRect?
    var janela: CGRect?
    /// Linha vertical e horizontal da mira, quando cruzam esta tela.
    var miraX: CGFloat?
    var miraY: CGFloat?
    var dimensoes: Rotulo?
    /// Modo atual junto ao cursor.
    var dica: Rotulo?
    var lupa: Ampliacao?
    /// A tela sob o cursor: só ela mostra a lupa, a dica e os painéis.
    var temOCursor = false

    /// - Parameter medir: tamanho do texto de um rótulo, sem folga.
    init(
        estado: EstadoDoOverlay,
        tela: DescricaoDeTela,
        tamanhoDaImagem: CGSize,
        medir: (String) -> CGSize
    ) {
        let limites = CGRect(origin: .zero, size: tela.quadro.size)
        let cursor = tela.local(de: estado.cursor)
        temOCursor = SelecaoDeTela.escolher(entre: estado.telas, sob: estado.cursor)?.id == tela.id
        (miraX, miraY) = Self.mira(cursor, limites: limites, escala: tela.escala)

        if let selecao = estado.selecao, selecao.telaId == tela.id {
            let retangulo = tela.localDePixels(selecao.pixels)
            self.selecao = retangulo
            furo = retangulo
            let texto = TextosDoOverlay.dimensoes(selecao.pixels)
            dimensoes = Self.rotulo(
                texto,
                junto: CGPoint(x: retangulo.maxX, y: retangulo.maxY),
                limites: limites,
                medir: medir
            )
        }
        if let realcada = estado.janelaRealcada {
            let retangulo = tela.local(de: realcada.quadro)
            let visivel = retangulo.intersection(limites)
            if !visivel.isNull, !visivel.isEmpty {
                janela = retangulo
                furo = visivel
            }
        }
        guard temOCursor else { return }
        if estado.lupaLigada {
            lupa = Self.lupa(
                cursor: cursor,
                tela: tela,
                tamanhoDaImagem: tamanhoDaImagem,
                limites: limites,
                medir: medir
            )
        } else if estado.modo == .janela || estado.selecao == nil {
            dica = Self.rotulo(
                TextosDoOverlay.modo(estado.modo),
                junto: cursor,
                limites: limites,
                medir: medir
            )
        }
    }

    /// Retângulos que mudam de uma cena para outra: invalidar os da cena velha e os da nova
    /// redesenha só o necessário.
    var areasDeDesenho: [CGRect] {
        let alcas = MedidasDoOverlay.ladoDaAlca + MedidasDoOverlay.espessuraDoContorno
        var areas: [CGRect] = []
        if let miraX { areas.append(CGRect(x: miraX - 2, y: -1e5, width: 5, height: 2e5)) }
        if let miraY { areas.append(CGRect(x: -1e5, y: miraY - 2, width: 2e5, height: 5)) }
        if let selecao { areas.append(selecao.insetBy(dx: -alcas, dy: -alcas)) }
        if let janela { areas.append(janela.insetBy(dx: -3, dy: -3)) }
        if let furo { areas.append(furo) }
        for rotulo in [dimensoes, dica].compactMap({ $0 }) {
            areas.append(rotulo.quadro.insetBy(dx: -2, dy: -2))
        }
        if let lupa {
            areas.append(lupa.quadro.union(lupa.coordenada.quadro).insetBy(dx: -2, dy: -2))
        }
        return areas
    }

    // MARK: - Partes

    /// Linhas da mira no pixel do cursor, se o cursor cruza esta tela em cada eixo.
    private static func mira(
        _ cursor: CGPoint,
        limites: CGRect,
        escala: Double
    ) -> (CGFloat?, CGFloat?) {
        func linha(_ valor: CGFloat, ate maximo: CGFloat) -> CGFloat? {
            guard valor.isFinite, valor >= 0, valor < maximo else { return nil }
            return (valor * escala).rounded(.down) / escala
        }
        return (linha(cursor.x, ate: limites.width), linha(cursor.y, ate: limites.height))
    }

    /// Rótulo com folga, junto a `ponto` e dentro de `limites`, em pontos inteiros.
    private static func rotulo(
        _ texto: String,
        junto ponto: CGPoint,
        limites: CGRect,
        medir: (String) -> CGSize
    ) -> Rotulo {
        let tamanho = tamanhoDoRotulo(texto, medir: medir)
        let origem = Posicionamento.origem(
            junto: ponto,
            tamanho: tamanho,
            dentro: limites,
            afastamento: MedidasDoOverlay.afastamento
        )
        return Rotulo(texto: texto, quadro: CGRect(origin: inteiro(origem), size: tamanho))
    }

    private static func tamanhoDoRotulo(_ texto: String, medir: (String) -> CGSize) -> CGSize {
        let medida = medir(texto)
        let folga = MedidasDoOverlay.folgaDoRotulo
        return CGSize(
            width: (medida.width + 2 * folga.width).rounded(.up),
            height: (medida.height + 2 * folga.height).rounded(.up)
        )
    }

    /// Lupa com a amostra de `Lupa.amostra` em volta do pixel do cursor e a coordenada embaixo.
    private static func lupa(
        cursor: CGPoint,
        tela: DescricaoDeTela,
        tamanhoDaImagem: CGSize,
        limites: CGRect,
        medir: (String) -> CGSize
    ) -> Ampliacao? {
        let ponto = tela.pixelLocal(dePonto: tela.global(de: cursor))
        // Sem posição do cursor não há pixel a mostrar (e `Int(nan)` derrubaria o app).
        guard ponto.x.isFinite, ponto.y.isFinite else { return nil }
        let amostra = Lupa.amostra(
            em: ponto,
            lado: MedidasDoOverlay.ladoDaLupa,
            imagem: tamanhoDaImagem
        )
        guard !amostra.isEmpty else { return nil }
        let pixel = CGPoint(
            x: min(max(ponto.x.rounded(.down), 0), tamanhoDaImagem.width - 1),
            y: min(max(ponto.y.rounded(.down), 0), tamanhoDaImagem.height - 1)
        )
        let ampliacao = MedidasDoOverlay.ampliacao
        let imagem = CGSize(
            width: amostra.width * ampliacao,
            height: amostra.height * ampliacao
        )
        let texto = TextosDoOverlay.coordenada(pixel)
        let rotulo = tamanhoDoRotulo(texto, medir: medir)
        let total = CGSize(
            width: max(imagem.width, rotulo.width),
            height: imagem.height + rotulo.height
        )
        let origem = inteiro(
            Posicionamento.origem(
                junto: cursor,
                tamanho: total,
                dentro: limites,
                afastamento: MedidasDoOverlay.afastamentoDaLupa
            )
        )
        let quadro = CGRect(origin: origem, size: imagem)
        return Ampliacao(
            amostra: amostra,
            quadro: quadro,
            pixelSobCursor: CGRect(
                x: origem.x + (pixel.x - amostra.minX) * ampliacao,
                y: origem.y + (pixel.y - amostra.minY) * ampliacao,
                width: ampliacao,
                height: ampliacao
            ),
            coordenada: Rotulo(
                texto: texto,
                quadro: CGRect(
                    x: origem.x,
                    y: quadro.maxY,
                    width: total.width,
                    height: rotulo.height
                )
            )
        )
    }

    private static func inteiro(_ ponto: CGPoint) -> CGPoint {
        CGPoint(x: ponto.x.rounded(.down), y: ponto.y.rounded(.down))
    }
}
