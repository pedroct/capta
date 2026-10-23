import CoreGraphics
import Foundation

/// Estado do editor como valor: a vista só alimenta eventos e desenha a partir dele. Aqui mora
/// a ferramenta Seleção (seleção, mover, alças, retângulo de seleção, comandos de teclado).
public struct EstadoDoEditor: Equatable, Sendable {
    public internal(set) var ferramenta: Ferramenta
    public internal(set) var tipoForma: TipoForma
    public var selecao: Set<UUID>
    public var memoria: MemoriaDeEstilos
    /// Retângulo do arraste de seleção em curso (pixels do documento), para a vista desenhar.
    public private(set) var retanguloDeSelecao: CGRect?
    /// Gesto do mouse em andamento (botão apertado), ou `nil`.
    private var gesto: Gesto?

    /// Gesto da ferramenta Seleção, com o que for preciso para recalcular a partir do clique.
    private enum Gesto: Equatable, Sendable {
        /// Retângulo de seleção: `anterior` é o que já estava selecionado (com `⇧`).
        case marcando(inicio: CGPoint, anterior: Set<UUID>)
        /// Mover a seleção. `colapsarPara` é o objeto que vira a seleção única se o clique
        /// terminar sem arraste.
        case movendo(inicio: CGPoint, moveu: Bool, colapsarPara: UUID?)
        /// Arrastar uma alça (ou o ponto de giro) do objeto `original`. `folga` é a distância da
        /// alça ao pixel do clique, somada ao cursor para a alça não pular até ele.
        case alca(AlcaArrastada, original: Anotacao, folga: CGVector, comPrevia: Bool)

        var temPrevia: Bool {
            switch self {
            case .marcando: false
            case .movendo(_, let moveu, _): moveu
            case .alca(_, _, _, let comPrevia): comPrevia
            }
        }
    }

    /// A alça sob o clique: qual é, de quem, e onde está.
    private struct AlcaEncontrada {
        var alca: AlcaArrastada
        var objeto: Anotacao
        var posicao: CGPoint
    }

    private enum AlcaArrastada: Equatable, Sendable {
        case redimensionar(AlcaDeObjeto)
        case girar
    }

    /// Deslocamento, em pixels, das cópias de `.duplicar`.
    private static let deslocamentoDaCopia: CGFloat = 10

    public init(memoria: MemoriaDeEstilos) {
        ferramenta = .selecao
        tipoForma = .retangulo
        selecao = []
        self.memoria = memoria
        retanguloDeSelecao = nil
        gesto = nil
    }

    /// Aplica o evento ao estado e devolve o que a sessão deve fazer, se algo.
    public mutating func reduzir(_ evento: EventoDoEditor, contexto: ContextoDoEditor)
        -> AcaoDoEditor?
    {
        switch evento {
        case .escolher(let nova):
            let cancelamento = cancelarGesto()
            ferramenta = nova
            if nova != .selecao { selecao = [] }
            return cancelamento
        case .escolherForma(let tipo):
            let cancelamento = cancelarGesto()
            ferramenta = .forma
            tipoForma = tipo
            selecao = []
            return cancelamento
        case .pressionar(let ponto, let modificadores):
            return pressionar(ponto, modificadores, contexto)
        case .arrastar(let ponto, let modificadores):
            return arrastar(ponto, modificadores, contexto)
        case .soltar(let ponto, let modificadores):
            return soltar(ponto, modificadores, contexto)
        case .esc:
            return esc()
        case .sincronizar:
            let existentes = Set(contexto.documento.objetos.map(\.id))
            selecao.formIntersection(existentes)
            return cancelarGesto(avisando: false)
        case .selecionarTudo:
            selecao = Set(contexto.documento.objetos.map(\.id))
            return nil
        case .excluir, .duplicar, .deslocar:
            return comandar(evento, contexto)
        case .alterarEstilo:
            // Tarefa 7.
            return nil
        }
    }

    // MARK: - Gesto

    /// Encerra o gesto em curso. Devolve `.cancelarPrevia` se havia prévia na tela (ou sempre,
    /// com `avisando`, que é o caso do Esc).
    private mutating func cancelarGesto(avisando: Bool = false) -> AcaoDoEditor? {
        defer {
            gesto = nil
            retanguloDeSelecao = nil
        }
        guard let gesto else { return nil }
        return (avisando || gesto.temPrevia) ? .cancelarPrevia : nil
    }

    private mutating func esc() -> AcaoDoEditor? {
        if gesto != nil { return cancelarGesto(avisando: true) }
        selecao = []
        return nil
    }

    // MARK: - Mouse

    private mutating func pressionar(
        _ ponto: CGPoint,
        _ modificadores: Modificadores,
        _ contexto: ContextoDoEditor
    ) -> AcaoDoEditor? {
        let cancelamento = cancelarGesto()
        guard ferramenta == .selecao else { return cancelamento }
        let shift = modificadores.contains(.shift)
        if let achada = alcaSob(ponto, contexto) {
            let folga = CGVector(dx: achada.posicao.x - ponto.x, dy: achada.posicao.y - ponto.y)
            gesto = .alca(achada.alca, original: achada.objeto, folga: folga, comPrevia: false)
        } else if let alvo = contexto.documento.objeto(
            em: ponto,
            tolerancia: contexto.tolerancia
        ) {
            pressionar(objeto: alvo, em: ponto, shift: shift)
        } else {
            if !shift { selecao = [] }
            gesto = .marcando(inicio: ponto, anterior: selecao)
        }
        return cancelamento
    }

    private mutating func pressionar(objeto alvo: UUID, em ponto: CGPoint, shift: Bool) {
        if shift {
            guard selecao.insert(alvo).inserted else {
                selecao.remove(alvo)
                return
            }
            gesto = .movendo(inicio: ponto, moveu: false, colapsarPara: nil)
        } else if selecao.contains(alvo) {
            // Já selecionado: mantém a seleção para arrastar vários; soltar sem mover colapsa.
            gesto = .movendo(inicio: ponto, moveu: false, colapsarPara: alvo)
        } else {
            selecao = [alvo]
            gesto = .movendo(inicio: ponto, moveu: false, colapsarPara: nil)
        }
    }

    /// A alça (ou o ponto de giro) do único objeto selecionado sob o ponto, a mais próxima.
    private func alcaSob(
        _ ponto: CGPoint,
        _ contexto: ContextoDoEditor
    ) -> AlcaEncontrada? {
        guard selecao.count == 1, let id = selecao.first,
            let objeto = contexto.documento.objetos.first(where: { $0.id == id })
        else { return nil }
        // Ordem fixa: empates (objeto sem área) resolvem sempre do mesmo jeito.
        let ordem: [AlcaDeObjeto] = [
            .inicio, .fim, .canto(.superiorEsquerdo), .canto(.superiorDireito),
            .canto(.inferiorEsquerdo), .canto(.inferiorDireito),
            .borda(.superior), .borda(.inferior), .borda(.esquerda), .borda(.direita),
        ]
        let posicoes = objeto.alcas()
        var candidatas: [(AlcaArrastada, CGPoint)] = ordem.compactMap { alca in
            posicoes[alca].map { (.redimensionar(alca), $0) }
        }
        if let giro = objeto.pontoDeGiro(distancia: contexto.distanciaDoGiro) {
            candidatas.append((.girar, giro))
        }
        var melhor: AlcaEncontrada?
        var menor = CGFloat.infinity
        for (alca, posicao) in candidatas {
            let distancia = hypot(posicao.x - ponto.x, posicao.y - ponto.y)
            guard distancia <= contexto.tolerancia else { continue }
            if distancia < menor {
                menor = distancia
                melhor = AlcaEncontrada(alca: alca, objeto: objeto, posicao: posicao)
            }
        }
        return melhor
    }

    private mutating func arrastar(
        _ ponto: CGPoint,
        _ modificadores: Modificadores,
        _ contexto: ContextoDoEditor
    ) -> AcaoDoEditor? {
        let shift = modificadores.contains(.shift)
        switch gesto {
        case nil:
            return nil
        case .marcando(let inicio, _):
            retanguloDeSelecao = Self.retangulo(inicio, ponto)
            return nil
        case .movendo(let inicio, let moveu, let colapsar):
            let delta = Self.delta(de: inicio, ate: ponto, restrito: shift)
            gesto = .movendo(inicio: inicio, moveu: moveu || delta != .zero, colapsarPara: colapsar)
            return .previa(.mover(selecao, deslocamento: delta))
        case .alca(let alca, let original, let folga, _):
            gesto = .alca(alca, original: original, folga: folga, comPrevia: true)
            return .previa(.substituir(Self.editada(original, alca, ponto, folga, shift)))
        }
    }

    private mutating func soltar(
        _ ponto: CGPoint,
        _ modificadores: Modificadores,
        _ contexto: ContextoDoEditor
    ) -> AcaoDoEditor? {
        let shift = modificadores.contains(.shift)
        guard let atual = gesto else { return nil }
        gesto = nil
        switch atual {
        case .marcando(let inicio, let anterior):
            let area = Self.retangulo(inicio, ponto)
            retanguloDeSelecao = nil
            // `intersects` é falso para retângulo sem área: clique ou linha não seleciona nada.
            let tocados =
                area.width > 0 && area.height > 0
                ? Set(contexto.documento.objetos(tocando: area)) : []
            selecao = anterior.union(tocados)
            return nil
        case .movendo(let inicio, let moveu, let colapsar):
            if !moveu, let colapsar { selecao = [colapsar] }
            let delta = Self.delta(de: inicio, ate: ponto, restrito: shift)
            guard delta != .zero else { return moveu ? .cancelarPrevia : nil }
            return .aplicar(.mover(selecao, deslocamento: delta))
        case .alca(let alca, let original, let folga, let comPrevia):
            let nova = Self.editada(original, alca, ponto, folga, shift)
            guard nova != original else { return comPrevia ? .cancelarPrevia : nil }
            return .aplicar(.substituir(nova))
        }
    }
}

extension EstadoDoEditor {
    private static func retangulo(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y).standardized
    }

    /// Deslocamento do clique até o ponto; com `restrito`, só no eixo dominante.
    private static func delta(de inicio: CGPoint, ate ponto: CGPoint, restrito: Bool) -> CGVector {
        var dx = ponto.x - inicio.x
        var dy = ponto.y - inicio.y
        if restrito {
            if abs(dx) >= abs(dy) { dy = 0 } else { dx = 0 }
        }
        return CGVector(dx: dx, dy: dy)
    }

    private static func editada(
        _ original: Anotacao,
        _ alca: AlcaArrastada,
        _ cursor: CGPoint,
        _ folga: CGVector,
        _ restrito: Bool
    ) -> Anotacao {
        let ponto = CGPoint(x: cursor.x + folga.dx, y: cursor.y + folga.dy)
        switch alca {
        case .redimensionar(let alca):
            return original.arrastando(alca, ate: ponto, restrito: restrito)
        case .girar: return original.girando(ate: ponto, restrito: restrito)
        }
    }

    // MARK: - Comandos

    private mutating func comandar(_ evento: EventoDoEditor, _ contexto: ContextoDoEditor)
        -> AcaoDoEditor?
    {
        guard !selecao.isEmpty else { return nil }
        switch evento {
        case .excluir:
            let ids = selecao
            selecao = []
            return .aplicar(.remover(ids))
        case .duplicar:
            let copia = CGVector(dx: Self.deslocamentoDaCopia, dy: Self.deslocamentoDaCopia)
            let copias = contexto.documento.copias(
                de: selecao,
                deslocamento: copia,
                novoId: contexto.novoId
            )
            guard !copias.isEmpty else { return nil }
            selecao = Set(copias.map(\.id))
            return .aplicar(.lote(copias.map(Edicao.adicionar)))
        case .deslocar(let vetor):
            return .aplicar(.mover(selecao, deslocamento: vetor))
        default:
            return nil
        }
    }
}
