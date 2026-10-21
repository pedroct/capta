import CoreGraphics

/// Estado do overlay de captura, como valor: a interface só alimenta eventos e desenha a
/// partir dele. Toda a regra (modo, seleção, realce, lupa, ajuda, opções, confirmação e
/// cancelamento) mora em `reduzindo(_:)`.
public struct EstadoDoOverlay: Equatable, Sendable {
    /// Tolerância do teste de acerto da seleção, em pontos (vira pixels pela escala da tela).
    /// Em seleções pequenas cai para um quarto do menor lado, para o meio continuar `.dentro`
    /// e a seleção continuar podendo ser movida.
    public static let toleranciaDeAcerto: CGFloat = 4

    public private(set) var modo: ModoDoOverlay
    public let telas: [DescricaoDeTela]
    /// Janelas selecionáveis, já filtradas, da mais à frente para a mais atrás.
    public let janelas: [JanelaDeTela]
    /// Última posição conhecida do mouse, em pontos globais.
    public private(set) var cursor: CGPoint
    /// Seleção ativa (só no modo região), em pixels nativos da tela dela.
    public private(set) var selecao: SelecaoDeRegiao?
    /// Janela sob o cursor (só no modo janela).
    public private(set) var janelaRealcada: JanelaDeTela?
    public private(set) var lupaLigada: Bool
    public private(set) var ajudaVisivel: Bool
    public private(set) var opcoes: OpcoesDeCaptura
    /// Preenchido uma vez; depois disso todo evento é ignorado.
    public private(set) var resultado: ResultadoDoOverlay?
    /// Gesto do mouse em andamento (botão apertado), ou `nil`.
    private var gesto: Gesto?

    /// Gesto do mouse no modo região. Guarda a tela onde começou, para o arrasto ficar
    /// preso a ela, e o que for preciso para recalcular a partir do clique.
    private enum Gesto: Equatable, Sendable {
        /// Nova seleção: `inicio` em pixels locais (fracionários) da tela.
        case criando(tela: DescricaoDeTela, limites: CGSize, inicio: CGPoint)
        /// Mover `original`: `inicio` é o pixel inteiro sob o clique.
        case movendo(tela: DescricaoDeTela, original: SelecaoDeRegiao, inicio: CGPoint)
        /// Redimensionar `original` pela `alca`. `folga` é a distância da alça ao pixel do
        /// clique, somada ao cursor para a borda não pular até ele.
        case redimensionando(
            tela: DescricaoDeTela,
            original: SelecaoDeRegiao,
            alca: Alca,
            folga: CGPoint
        )
    }

    private init(
        modo: ModoDoOverlay,
        telas: [DescricaoDeTela],
        janelas: [JanelaDeTela],
        opcoes: OpcoesDeCaptura,
        ajudaVisivel: Bool
    ) {
        self.modo = modo
        self.telas = telas
        self.janelas = janelas
        self.cursor = .zero
        self.selecao = nil
        self.janelaRealcada = nil
        self.lupaLigada = false
        self.ajudaVisivel = ajudaVisivel
        self.opcoes = opcoes
        self.resultado = nil
        self.gesto = nil
    }

    /// Estado de abertura. Sem janelas o modo janela não faz sentido e cai para região.
    /// O cursor começa em `.zero`; a interface manda `cursorMoveu` com a posição real ao abrir.
    public static func inicial(
        modo: ModoDoOverlay,
        telas: [DescricaoDeTela],
        janelas: [JanelaDeTela],
        opcoes: OpcoesDeCaptura,
        ajudaVisivel: Bool
    ) -> EstadoDoOverlay {
        var estado = EstadoDoOverlay(
            modo: janelas.isEmpty ? .regiao : modo,
            telas: telas,
            janelas: janelas,
            opcoes: opcoes,
            ajudaVisivel: ajudaVisivel
        )
        estado.moverCursor(para: .zero)
        return estado
    }

    /// O estado depois de `evento`. Função pura; depois de `resultado != nil` devolve `self`.
    public func reduzindo(_ evento: EventoDoOverlay) -> EstadoDoOverlay {
        guard resultado == nil else { return self }
        var novo = self
        switch evento {
        case .cursorMoveu(let ponto):
            novo.moverCursor(para: ponto)
        case .mouseBaixo(let ponto):
            novo.apertar(em: ponto)
        case .mouseArrastou(let ponto):
            novo.arrastar(ate: ponto)
        case .mouseSolto(let ponto):
            novo.arrastar(ate: ponto)
            novo.gesto = nil
        case .tecla(let tecla):
            novo.apertar(tecla)
        case .opcoesMudaram(let opcoes):
            novo.opcoes = opcoes
        case .telasMudaram, .perdeuAtivacao:
            novo.resultado = .cancelado
        }
        return novo
    }

    // MARK: - Mouse

    /// Atualiza o cursor e, no modo janela, a janela realçada. Não mexe na seleção.
    private mutating func moverCursor(para ponto: CGPoint) {
        cursor = ponto
        janelaRealcada = modo == .janela ? ListaDeJanelas.sob(ponto, em: janelas) : nil
    }

    private mutating func apertar(em ponto: CGPoint) {
        moverCursor(para: ponto)
        switch modo {
        case .janela:
            if let janela = janelaRealcada { confirmar(.janela(id: janela.id)) }
        case .regiao:
            gesto = gestoIniciado(em: ponto)
            if case .criando = gesto { selecao = nil }
        }
    }

    /// O gesto que um clique em `ponto` começa: mover ou redimensionar a seleção ativa se o
    /// clique cair nela (na mesma tela), senão uma seleção nova na tela sob o ponto.
    private func gestoIniciado(em ponto: CGPoint) -> Gesto? {
        guard let tela = SelecaoDeTela.escolher(entre: telas, sob: ponto) else { return nil }
        let local = tela.pixelLocal(dePonto: ponto)
        if let selecao, selecao.telaId == tela.id {
            let tolerancia = Self.tolerancia(para: selecao, escala: tela.escala)
            let pixel = CGPoint(x: local.x.rounded(.down), y: local.y.rounded(.down))
            switch selecao.acerto(em: local, tolerancia: tolerancia) {
            case .dentro:
                return .movendo(tela: tela, original: selecao, inicio: pixel)
            case .borda(let alca):
                let folga = Self.folga(da: alca, em: selecao.pixels, clique: pixel)
                return .redimensionando(tela: tela, original: selecao, alca: alca, folga: folga)
            case .fora:
                break
            }
        }
        guard let limites = tela.limitesEmPixels else { return nil }
        return .criando(tela: tela, limites: limites, inicio: local)
    }

    private mutating func arrastar(ate ponto: CGPoint) {
        moverCursor(para: ponto)
        switch gesto {
        case .none:
            break
        case .criando(let tela, let limites, let inicio):
            selecao = SelecaoDeRegiao.arrasto(
                telaId: tela.id,
                limites: limites,
                de: inicio,
                ate: tela.pixelLocal(dePonto: ponto)
            )
        case .movendo(let tela, let original, let inicio):
            let local = tela.pixelLocal(dePonto: ponto)
            selecao = original.movida(
                dx: Self.inteiro(local.x.rounded(.down) - inicio.x),
                dy: Self.inteiro(local.y.rounded(.down) - inicio.y)
            )
        case .redimensionando(let tela, let original, let alca, let folga):
            let local = tela.pixelLocal(dePonto: ponto)
            let alvo = CGPoint(
                x: local.x.rounded(.down) + folga.x,
                y: local.y.rounded(.down) + folga.y
            )
            selecao = original.redimensionada(alca: alca, para: alvo)
        }
    }

    // MARK: - Teclado

    private mutating func apertar(_ tecla: TeclaDoOverlay) {
        switch tecla {
        case .esc:
            resultado = .cancelado
        case .f:
            confirmarTelaInteira()
        case .espaco:
            if gesto == nil { alternarModo() }
        case .enter:
            confirmarAtual()
        case .m:
            lupaLigada.toggle()
        case .h:
            ajudaVisivel.toggle()
        case .seta(let direcao, let grande):
            if gesto == nil { moverSelecao(para: direcao, passo: grande ? 10 : 1) }
        }
    }

    /// Setas só movem uma seleção ativa; sem seleção não fazem nada.
    private mutating func moverSelecao(para direcao: Direcao, passo: Int) {
        guard let atual = selecao else { return }
        switch direcao {
        case .cima: selecao = atual.movida(dx: 0, dy: -passo)
        case .baixo: selecao = atual.movida(dx: 0, dy: passo)
        case .esquerda: selecao = atual.movida(dx: -passo, dy: 0)
        case .direita: selecao = atual.movida(dx: passo, dy: 0)
        }
    }

    /// Região para janela só se houver janelas, descartando a seleção; janela para região
    /// limpa o realce.
    private mutating func alternarModo() {
        switch modo {
        case .regiao:
            guard !janelas.isEmpty else { return }
            modo = .janela
            selecao = nil
        case .janela:
            modo = .regiao
        }
        moverCursor(para: cursor)
    }

    // MARK: - Confirmação

    private mutating func confirmar(_ escolha: SelecaoConfirmada) {
        resultado = .confirmado(escolha, opcoes)
    }

    /// `Enter`: a seleção ativa no modo região ou a janela realçada no modo janela.
    private mutating func confirmarAtual() {
        switch modo {
        case .regiao:
            guard let selecao, let tela = telas.first(where: { $0.id == selecao.telaId })
            else { return }
            confirmar(.regiao(tela: tela, pixels: selecao.pixels))
        case .janela:
            guard let janela = janelaRealcada else { return }
            confirmar(.janela(id: janela.id))
        }
    }

    /// `F`: a tela inteira sob o cursor, nos dois modos.
    private mutating func confirmarTelaInteira() {
        guard
            let tela = SelecaoDeTela.escolher(entre: telas, sob: cursor),
            let limites = tela.limitesEmPixels
        else { return }
        let inteira = SelecaoDeRegiao.telaInteira(telaId: tela.id, limites: limites)
        confirmar(.regiao(tela: tela, pixels: inteira.pixels))
    }

    // MARK: - Geometria auxiliar

    /// `toleranciaDeAcerto` em pixels da tela, limitada a um quarto do menor lado da seleção.
    private static func tolerancia(para selecao: SelecaoDeRegiao, escala: Double) -> CGFloat {
        let menorLado = min(selecao.pixels.width, selecao.pixels.height)
        return min(toleranciaDeAcerto * escala, menorLado / 4)
    }

    /// Distância do pixel do clique até a borda (ou o canto) que a alça arrasta; no eixo que
    /// a alça não mexe, 0. Somada ao cursor, mantém a borda parada enquanto ele não se mexe.
    private static func folga(da alca: Alca, em pixels: CGRect, clique: CGPoint) -> CGPoint {
        let x: CGFloat
        switch alca {
        case .esquerda, .cantoSuperiorEsquerdo, .cantoInferiorEsquerdo: x = pixels.minX - clique.x
        case .direita, .cantoSuperiorDireito, .cantoInferiorDireito: x = pixels.maxX - clique.x
        case .cima, .baixo: x = 0
        }
        let y: CGFloat
        switch alca {
        case .cima, .cantoSuperiorEsquerdo, .cantoSuperiorDireito: y = pixels.minY - clique.y
        case .baixo, .cantoInferiorEsquerdo, .cantoInferiorDireito: y = pixels.maxY - clique.y
        case .esquerda, .direita: y = 0
        }
        return CGPoint(x: x, y: y)
    }

    /// Deslocamento inteiro saturado em ±10⁹ (NaN vira 0), para não estourar `Int`.
    private static func inteiro(_ valor: CGFloat) -> Int {
        guard !valor.isNaN else { return 0 }
        return Int(min(max(valor, -1e9), 1e9))
    }
}
