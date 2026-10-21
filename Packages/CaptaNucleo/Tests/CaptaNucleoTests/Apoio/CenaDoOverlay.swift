import CoreGraphics

@testable import CaptaNucleo

/// Cena comum dos testes da máquina de estados do overlay: duas telas lado a lado, A
/// (principal, Retina) e B (escala 1), e duas janelas em A, com j1 à frente de j2.
/// As suítes adotam o protocolo para usar os membros sem prefixo e sem nomes globais.
protocol CenaDoOverlay {}

extension CenaDoOverlay {
    var telaA: DescricaoDeTela {
        DescricaoDeTela(
            id: 1,
            quadro: CGRect(x: 0, y: 0, width: 1000, height: 800),
            escala: 2,
            principal: true
        )
    }

    var telaB: DescricaoDeTela {
        DescricaoDeTela(
            id: 2,
            quadro: CGRect(x: 1000, y: 0, width: 1000, height: 800),
            escala: 1,
            principal: false
        )
    }

    var j1: JanelaDeTela {
        JanelaDeTela(
            id: 11,
            quadro: CGRect(x: 100, y: 100, width: 300, height: 300),
            camada: 0,
            naTela: true
        )
    }

    var j2: JanelaDeTela {
        JanelaDeTela(
            id: 12,
            quadro: CGRect(x: 50, y: 50, width: 400, height: 400),
            camada: 0,
            naTela: true
        )
    }

    var opcoes: OpcoesDeCaptura { OpcoesDeCaptura(atraso: .tres, incluirCursor: true) }

    func estado(
        modo: ModoDoOverlay = .regiao,
        telas: [DescricaoDeTela]? = nil,
        janelas: [JanelaDeTela]? = nil,
        ajudaVisivel: Bool = true
    ) -> EstadoDoOverlay {
        .inicial(
            modo: modo,
            telas: telas ?? [telaA, telaB],
            janelas: janelas ?? [j1, j2],
            opcoes: opcoes,
            ajudaVisivel: ajudaVisivel
        )
    }

    func ponto(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    func arrasto(_ de: CGPoint, _ ate: CGPoint) -> [EventoDoOverlay] {
        [.mouseBaixo(de), .mouseArrastou(ate), .mouseSolto(ate)]
    }

    /// Seleção `(20, 20, 100, 60)` em pixels de A, feita pelo arrasto `(10,10)→(60,40)` em pontos.
    func comSelecao() -> EstadoDoOverlay {
        estado().aplicando(arrasto(ponto(10, 10), ponto(60, 40)))
    }
}

extension EstadoDoOverlay {
    /// Aplica os eventos em ordem.
    func aplicando(_ eventos: [EventoDoOverlay]) -> EstadoDoOverlay {
        eventos.reduce(self) { $0.reduzindo($1) }
    }
}
