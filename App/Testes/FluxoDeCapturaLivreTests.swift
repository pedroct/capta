import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

/// Captura livre (overlay de região e janela, com e sem atraso), na mesma suíte do fluxo.
extension FluxoDeCapturaTests {
    /// Tela Retina: 4 x 3 pontos, 8 x 6 pixels.
    static let telaA = DescricaoDeTela(
        id: 1,
        quadro: CGRect(x: 0, y: 0, width: 4, height: 3),
        escala: 2,
        principal: true
    )
    /// Tela comum à direita: 100 x 80 pontos e pixels.
    static let telaB = DescricaoDeTela(
        id: 2,
        quadro: CGRect(x: 4, y: 0, width: 100, height: 80),
        escala: 1,
        principal: false
    )
    /// Seleção na `telaA`, em pixels nativos.
    static let pixels = CGRect(x: 2, y: 1, width: 4, height: 3)
    /// Janela comum, inteira na `telaB`.
    static let janelaGrande = JanelaDeTela(
        id: 42,
        quadro: CGRect(x: 10, y: 10, width: 60, height: 50),
        camada: 0,
        naTela: true
    )
    /// Pequena demais para o modo janela.
    static let janelaPequena = JanelaDeTela(
        id: 7,
        quadro: CGRect(x: 10, y: 10, width: 20, height: 20),
        camada: 0,
        naTela: true
    )

    static func opcoes(_ atraso: Atraso, cursor: Bool = false) -> OpcoesDeCaptura {
        OpcoesDeCaptura(atraso: atraso, incluirCursor: cursor)
    }

    static var regiao: SelecaoConfirmada { .regiao(tela: telaA, pixels: pixels) }

    /// Capturador com as duas telas congeladas e as janelas listadas.
    func capturadorLivre(
        janelas: Result<[JanelaDeTela], ErroCaptura> = .success([janelaGrande, janelaPequena])
    ) async throws -> CapturadorFalso {
        let capturador = CapturadorFalso(.success(try captura()))
        let telas = [
            TelaCongelada(descricao: Self.telaA, imagem: try imagemDeTeste(largura: 8, altura: 6)),
            TelaCongelada(
                descricao: Self.telaB,
                imagem: try imagemDeTeste(largura: 100, altura: 80)
            ),
        ]
        await capturador.programar(
            congelar: .success(telas),
            janelas: janelas,
            regiao: .success(
                ImagemCapturada(imagem: try imagemDeTeste(largura: 4, altura: 3), escala: 2)
            ),
            janela: .success(
                ImagemCapturada(imagem: try imagemDeTeste(largura: 12, altura: 10), escala: 1)
            )
        )
        return capturador
    }

    // MARK: - Permissão e disparos

    @Test func semPermissaoMostraAjudaENaoAbreOOverlay() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        let permissao = PermissaoFalsa(concedida: false)
        let apresentador = ApresentadorFalso()
        let seletor = SeletorFalso()
        let fluxo = fluxo(
            capturador: capturador,
            permissao: permissao,
            apresentador: apresentador,
            seletor: seletor,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)

        #expect(permissao.solicitacoes == 1)
        #expect(apresentador.ajudas == 1)
        #expect(apresentador.alertas.isEmpty)
        #expect(await capturador.congelamentos == 0)
        #expect(await capturador.listagensDeJanelas == 0)
        #expect(seletor.pedidos.isEmpty)
    }

    // Sem o comportamento esperado o teste ficaria preso no portão; o limite o faz falhar.
    @Test(.timeLimit(.minutes(1))) func disparoDuranteSelecaoEhIgnorado() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let portao = Portao()
        let capturador = try await capturadorLivre()
        let seletor = SeletorFalso(.cancelado, portao: portao)
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: ApresentadorFalso(),
            seletor: seletor,
            defaults: temporarios.defaults
        )

        let primeira = Task { await fluxo.capturarLivre(modo: .regiao) }
        await portao.aguardarAlguemPreso()

        // Com o overlay aberto, outro disparo (livre ou de tela inteira) volta sem fazer nada.
        await fluxo.capturarLivre(modo: .janela)
        await fluxo.capturarTelaInteira()
        #expect(await capturador.congelamentos == 1)
        #expect(await capturador.pontos.isEmpty)
        #expect(seletor.pedidos.count == 1)

        await portao.abrir()
        await primeira.value

        // Fechado o overlay, um novo disparo volta a abri-lo.
        await fluxo.capturarLivre(modo: .regiao)
        #expect(await capturador.congelamentos == 2)
        #expect(seletor.pedidos.count == 2)
    }

    // Sem o comportamento esperado o teste ficaria preso no portão; o limite o faz falhar.
    @Test(.timeLimit(.minutes(1))) func disparoDuranteContagemEhIgnorado() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let portao = Portao()
        let capturador = try await capturadorLivre()
        let apresentador = ApresentadorFalso()
        let seletor = SeletorFalso(.confirmado(Self.regiao, Self.opcoes(.tres)))
        let contagem = ContagemFalsa()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: seletor,
            contagem: contagem,
            defaults: temporarios.defaults,
            pausa: { _ in await portao.esperar() }
        )

        let primeira = Task { await fluxo.capturarLivre(modo: .regiao) }
        await portao.aguardarAlguemPreso()

        await fluxo.capturarLivre(modo: .regiao)
        await fluxo.capturarTelaInteira()
        #expect(await capturador.congelamentos == 1)
        #expect(await capturador.pontos.isEmpty)
        #expect(await capturador.chamadasDeRegiao.isEmpty)
        #expect(seletor.pedidos.count == 1)
        #expect(contagem.mostradas.count == 1)
        // O disparo ignorado não fecha a contagem que está correndo.
        #expect(contagem.visivel)
        #expect(contagem.fechamentos == 0)

        await portao.abrir()
        await primeira.value
        #expect(await capturador.chamadasDeRegiao.count == 1)
        #expect(apresentador.capturas.count == 1)
    }

    // MARK: - Congelar e listar

    @Test func listaDeJanelasIndisponivelAbreSoNoModoRegiao() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let apresentador = ApresentadorFalso()
        let seletor = SeletorFalso()
        let fluxo = fluxo(
            capturador: try await capturadorLivre(janelas: .failure(.falhou)),
            apresentador: apresentador,
            seletor: seletor,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .janela)

        let pedido = try #require(seletor.pedidos.first)
        #expect(pedido.modo == .regiao)
        #expect(pedido.janelas.isEmpty)
        #expect(pedido.telas == [Self.telaA, Self.telaB])
        #expect(apresentador.alertas.isEmpty)
    }

    @Test func semJanelaSelecionavelAbreSoNoModoRegiao() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let seletor = SeletorFalso()
        let fluxo = fluxo(
            capturador: try await capturadorLivre(janelas: .success([Self.janelaPequena])),
            apresentador: ApresentadorFalso(),
            seletor: seletor,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .janela)

        let pedido = try #require(seletor.pedidos.first)
        #expect(pedido.modo == .regiao)
        #expect(pedido.janelas.isEmpty)
    }

    @Test(arguments: [
        Result<[TelaCongelada], ErroCaptura>.failure(.falhou), .failure(.telaNaoEncontrada),
        .success([]),
    ])
    func falhaAoCongelarMostraAlertaENaoAbreOOverlay(
        congelar: Result<[TelaCongelada], ErroCaptura>
    ) async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        await capturador.programar(congelar: congelar)
        let apresentador = ApresentadorFalso()
        let seletor = SeletorFalso()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: seletor,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)

        #expect(apresentador.alertas == [.capturaFalhou])
        #expect(apresentador.ajudas == 0)
        #expect(seletor.pedidos.isEmpty)
        #expect(await capturador.listagensDeJanelas == 0)
    }

    @Test func permissaoRevogadaAoCongelarMostraAjuda() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        await capturador.programar(congelar: .failure(.semPermissao))
        let apresentador = ApresentadorFalso()
        let seletor = SeletorFalso()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: seletor,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)

        #expect(apresentador.ajudas == 1)
        #expect(apresentador.alertas.isEmpty)
        #expect(seletor.pedidos.isEmpty)
    }

    // MARK: - Opções e regressão

    @Test func opcoesEscolhidasFicamLembradas() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let lembradas = OpcoesLembradas(defaults: temporarios.defaults)
        lembradas.ajudaVisivel = false
        let escolhidas = Self.opcoes(.cinco, cursor: true)
        let seletor = SeletorFalso(.confirmado(Self.regiao, escolhidas))
        let fluxo = fluxo(
            capturador: try await capturadorLivre(),
            apresentador: ApresentadorFalso(),
            seletor: seletor,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)
        seletor.resultado = .cancelado
        await fluxo.capturarLivre(modo: .regiao)

        #expect(seletor.pedidos.map(\.opcoes) == [Self.opcoes(.nenhum), escolhidas])
        #expect(seletor.pedidos.map(\.ajudaVisivel) == [false, false])
        #expect(lembradas.opcoes == escolhidas)
    }

    @Test func capturarTelaInteiraContinuaIgual() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        let apresentador = ApresentadorFalso()
        let seletor = SeletorFalso()
        let contagem = ContagemFalsa()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: seletor,
            contagem: contagem,
            defaults: temporarios.defaults
        )

        await fluxo.capturarTelaInteira()
        await fluxo.gravacaoDoRascunho?.value

        #expect(await capturador.pontos == [Self.cursor])
        #expect(await capturador.congelamentos == 0)
        #expect(await capturador.listagensDeJanelas == 0)
        #expect(await capturador.chamadasDeRegiao.isEmpty)
        #expect(seletor.pedidos.isEmpty)
        #expect(contagem.mostradas.isEmpty)
        #expect(contagem.fechamentos == 0)
        let aberta = try #require(apresentador.capturas.first)
        #expect(apresentador.capturas.count == 1)
        #expect(aberta.documento.tamanhoBase == CGSize(width: 8, height: 6))
        #expect(aberta.escala == 2)
        #expect(aberta.nome == Rascunho.nome(para: Self.instante))
        let esperado = URL(fileURLWithPath: "/rascunhos", isDirectory: true)
            .appendingPathComponent("\(aberta.nome).capta", isDirectory: true)
        #expect(aberta.rascunho == .gravado(esperado))
        #expect(apresentador.alertas.isEmpty)
    }

    // MARK: - Toda saída fecha a contagem

    enum SaidaDoFluxo: CaseIterable, Sendable {
        case confirmada, overlayCancelado, contagemCancelada, erro, tarefaCancelada
    }

    // Sem o comportamento esperado o teste ficaria preso na pausa; o limite o faz falhar.
    @Test(.timeLimit(.minutes(1)), arguments: SaidaDoFluxo.allCases)
    func todaSaidaFechaAContagem(saida: SaidaDoFluxo) async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        if saida == .erro { await capturador.programar(regiao: .failure(.falhou)) }
        let apresentador = ApresentadorFalso()
        let contagem = ContagemFalsa()
        let entrou = Portao()
        let presa = saida == .contagemCancelada || saida == .tarefaCancelada
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: SeletorFalso(
                saida == .overlayCancelado
                    ? .cancelado : .confirmado(Self.regiao, Self.opcoes(.tres))
            ),
            contagem: contagem,
            defaults: temporarios.defaults,
            pausa: { _ in
                guard presa else { return }
                await entrou.abrir()
                try await Task.sleep(for: .seconds(3600))
            }
        )

        let tarefa = Task { await fluxo.capturarLivre(modo: .regiao) }
        if presa {
            await entrou.esperar()
            if saida == .contagemCancelada { fluxo.cancelarContagem() } else { tarefa.cancel() }
        }
        await tarefa.value

        #expect(contagem.fechamentos >= 1)
        #expect(!contagem.visivel)
        #expect(apresentador.capturas.count == (saida == .confirmada ? 1 : 0))
        #expect(apresentador.alertas == (saida == .erro ? [.capturaFalhou] : []))
    }
}
