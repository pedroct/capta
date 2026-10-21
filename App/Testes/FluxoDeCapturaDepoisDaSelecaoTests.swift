import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

/// Captura livre depois da seleção (spec §4.4): sem atraso, com atraso e as falhas ao vivo.
extension FluxoDeCapturaTests {
    // MARK: - Sem atraso

    @Test func canceladoNaoCapturaNemGravaRascunho() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        let apresentador = ApresentadorFalso()
        let contagem = ContagemFalsa()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: SeletorFalso(.cancelado),
            contagem: contagem,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)

        #expect(apresentador.capturas.isEmpty)
        #expect(apresentador.alertas.isEmpty)
        #expect(apresentador.ajudas == 0)
        #expect(fluxo.gravacaoDoRascunho == nil)
        #expect(await capturador.chamadasDeRegiao.isEmpty)
        #expect(await capturador.chamadasDeJanela.isEmpty)
        #expect(contagem.mostradas.isEmpty)
    }

    @Test func regiaoSemAtrasoRecortaACongeladaEAbreAJanela() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        let apresentador = ApresentadorFalso()
        let contagem = ContagemFalsa()
        let seletor = SeletorFalso(.confirmado(Self.regiao, Self.opcoes(.nenhum, cursor: true)))
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: seletor,
            contagem: contagem,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)
        await fluxo.gravacaoDoRascunho?.value

        let pedido = try #require(seletor.pedidos.first)
        #expect(pedido.telas == [Self.telaA, Self.telaB])
        #expect(pedido.modo == .regiao)
        let aberta = try #require(apresentador.capturas.first)
        #expect(apresentador.capturas.count == 1)
        #expect(aberta.documento.tamanhoBase == CGSize(width: 4, height: 3))
        #expect(aberta.escala == Self.telaA.escala)
        #expect(aberta.base.width == 4 && aberta.base.height == 3)
        #expect(aberta.nome == Rascunho.nome(para: Self.instante))
        let esperado = URL(fileURLWithPath: "/rascunhos", isDirectory: true)
            .appendingPathComponent("\(aberta.nome).capta", isDirectory: true)
        #expect(aberta.rascunho == .gravado(esperado))
        #expect(await capturador.chamadasDeRegiao.isEmpty)
        #expect(await capturador.chamadasDeJanela.isEmpty)
        #expect(contagem.mostradas.isEmpty)
        #expect(apresentador.alertas.isEmpty)
    }

    @Test func regiaoForaDaImagemCongeladaMostraAlerta() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let apresentador = ApresentadorFalso()
        let fora = SelecaoConfirmada.regiao(
            tela: Self.telaA,
            pixels: CGRect(x: 6, y: 4, width: 4, height: 3)
        )
        let fluxo = fluxo(
            capturador: try await capturadorLivre(),
            apresentador: apresentador,
            seletor: SeletorFalso(.confirmado(fora, Self.opcoes(.nenhum))),
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)

        #expect(apresentador.alertas == [.capturaFalhou])
        #expect(apresentador.capturas.isEmpty)
        #expect(fluxo.gravacaoDoRascunho == nil)
    }

    @Test func regiaoDeTelaQueNaoFoiCongeladaMostraAlerta() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let apresentador = ApresentadorFalso()
        let outra = DescricaoDeTela(id: 9, quadro: Self.telaA.quadro, escala: 2, principal: false)
        let fluxo = fluxo(
            capturador: try await capturadorLivre(),
            apresentador: apresentador,
            seletor: SeletorFalso(
                .confirmado(.regiao(tela: outra, pixels: Self.pixels), Self.opcoes(.nenhum))
            ),
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)

        #expect(apresentador.alertas == [.capturaFalhou])
        #expect(apresentador.capturas.isEmpty)
    }

    @Test func janelaSemAtrasoCapturaAJanelaSemCursor() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        let apresentador = ApresentadorFalso()
        let contagem = ContagemFalsa()
        let seletor = SeletorFalso(
            .confirmado(.janela(id: Self.janelaGrande.id), Self.opcoes(.nenhum, cursor: true))
        )
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: seletor,
            contagem: contagem,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .janela)

        let pedido = try #require(seletor.pedidos.first)
        #expect(pedido.modo == .janela)
        #expect(pedido.janelas == [Self.janelaGrande])
        #expect(
            await capturador.chamadasDeJanela
                == [ChamadaDeJanela(id: Self.janelaGrande.id, incluirCursor: false)]
        )
        let aberta = try #require(apresentador.capturas.first)
        #expect(aberta.documento.tamanhoBase == CGSize(width: 12, height: 10))
        #expect(aberta.escala == 1)
        #expect(contagem.mostradas.isEmpty)
        #expect(await capturador.chamadasDeRegiao.isEmpty)
    }

    // MARK: - Com atraso

    @Test func comAtrasoCapturaAoVivoDepoisDaContagem() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        let apresentador = ApresentadorFalso()
        let contagem = ContagemFalsa()
        // A cada pausa, quantas capturas ao vivo já houve.
        let capturasAntesDaPausa = Anotacoes<Int>()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: SeletorFalso(.confirmado(Self.regiao, Self.opcoes(.tres, cursor: true))),
            contagem: contagem,
            defaults: temporarios.defaults,
            pausa: { _ in
                await capturasAntesDaPausa.anotar(await capturador.chamadasDeRegiao.count)
            }
        )

        await fluxo.capturarLivre(modo: .regiao)

        #expect(await capturasAntesDaPausa.valores == [0, 0, 0])
        #expect(
            await capturador.chamadasDeRegiao
                == [ChamadaDeRegiao(tela: Self.telaA, pixels: Self.pixels, incluirCursor: true)]
        )
        #expect(contagem.mostradas.map(\.segundos) == [3])
        #expect(contagem.mostradas.map(\.tela) == [Self.telaA])
        #expect(contagem.atualizacoes == [3, 2, 1])
        #expect(!contagem.visivel)
        let aberta = try #require(apresentador.capturas.first)
        #expect(aberta.documento.tamanhoBase == CGSize(width: 4, height: 3))
        #expect(aberta.escala == 2)
        #expect(apresentador.alertas.isEmpty)
    }

    @Test func janelaComAtrasoMostraAContagemNaTelaDaJanelaECapturaAoVivo() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        let apresentador = ApresentadorFalso()
        let contagem = ContagemFalsa()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: SeletorFalso(
                .confirmado(.janela(id: Self.janelaGrande.id), Self.opcoes(.cinco, cursor: true))
            ),
            contagem: contagem,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .janela)

        #expect(contagem.mostradas.map(\.tela) == [Self.telaB])
        #expect(contagem.atualizacoes == [5, 4, 3, 2, 1])
        #expect(
            await capturador.chamadasDeJanela
                == [ChamadaDeJanela(id: Self.janelaGrande.id, incluirCursor: true)]
        )
        #expect(apresentador.capturas.count == 1)
    }

    /// Uma janela que não está na lista (não deveria acontecer) mostra a contagem na principal.
    @Test func janelaForaDaListaMostraAContagemNaTelaPrincipal() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let contagem = ContagemFalsa()
        let fluxo = fluxo(
            capturador: try await capturadorLivre(),
            apresentador: ApresentadorFalso(),
            seletor: SeletorFalso(.confirmado(.janela(id: 99), Self.opcoes(.tres))),
            contagem: contagem,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .janela)

        #expect(contagem.mostradas.map(\.tela) == [Self.telaA])
    }

    // Sem o comportamento esperado o teste ficaria preso na pausa; o limite o faz falhar.
    @Test(.timeLimit(.minutes(1))) func contagemCanceladaNaoCapturaNada() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let entrou = Portao()
        let capturador = try await capturadorLivre()
        let apresentador = ApresentadorFalso()
        let contagem = ContagemFalsa()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: SeletorFalso(.confirmado(Self.regiao, Self.opcoes(.cinco))),
            contagem: contagem,
            defaults: temporarios.defaults,
            pausa: { _ in
                await entrou.abrir()
                try await Task.sleep(for: .seconds(3600))
            }
        )

        let tarefa = Task { await fluxo.capturarLivre(modo: .regiao) }
        await entrou.esperar()
        // O que a janelinha faz no Esc ou no clique.
        fluxo.cancelarContagem()
        await tarefa.value

        #expect(await capturador.chamadasDeRegiao.isEmpty)
        #expect(apresentador.capturas.isEmpty)
        #expect(apresentador.alertas.isEmpty)
        #expect(apresentador.ajudas == 0)
        #expect(fluxo.gravacaoDoRascunho == nil)
        #expect(!contagem.visivel)
    }

    // MARK: - Falhas da captura ao vivo

    @Test func janelaQueSomeDuranteOAtrasoMostraAlertaENaoGravaNada() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        await capturador.programar(janela: .failure(.janelaNaoEncontrada))
        let apresentador = ApresentadorFalso()
        let contagem = ContagemFalsa()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: SeletorFalso(
                .confirmado(.janela(id: Self.janelaGrande.id), Self.opcoes(.tres))
            ),
            contagem: contagem,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .janela)

        #expect(await capturador.chamadasDeJanela.count == 1)
        #expect(apresentador.alertas == [.capturaFalhou])
        #expect(apresentador.capturas.isEmpty)
        #expect(apresentador.ajudas == 0)
        #expect(fluxo.gravacaoDoRascunho == nil)
        #expect(!contagem.visivel)
    }

    @Test func telaQueMudouDuranteOAtrasoMostraAlerta() async throws {
        try await capturaAoVivoQueFalhaMostraAlerta(.failure(.telaNaoEncontrada))
    }

    @Test func tamanhoInesperadoMostraAlerta() async throws {
        try await capturaAoVivoQueFalhaMostraAlerta(.failure(.tamanhoInesperado))
    }

    /// O fluxo confere o tamanho de novo: a imagem tem de ter os pixels da seleção.
    @Test func imagemAoVivoDeOutroTamanhoMostraAlerta() async throws {
        let errada = ImagemCapturada(imagem: try imagemDeTeste(largura: 5, altura: 3), escala: 2)
        try await capturaAoVivoQueFalhaMostraAlerta(.success(errada))
    }

    /// Sem pixels inteiros não há como conferir o tamanho: nem chega a capturar.
    @Test func regiaoComPixelsFracionariosMostraAlertaSemCapturar() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        let apresentador = ApresentadorFalso()
        let fracionaria = SelecaoConfirmada.regiao(
            tela: Self.telaA,
            pixels: CGRect(x: 2, y: 1, width: 3.5, height: 3)
        )
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: SeletorFalso(.confirmado(fracionaria, Self.opcoes(.tres))),
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)

        #expect(await capturador.chamadasDeRegiao.isEmpty)
        #expect(apresentador.alertas == [.capturaFalhou])
        #expect(apresentador.capturas.isEmpty)
    }

    @Test func permissaoRevogadaNaCapturaAoVivoMostraAjuda() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        await capturador.programar(regiao: .failure(.semPermissao))
        let permissao = PermissaoFalsa(concedida: true)
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(
            capturador: capturador,
            permissao: permissao,
            apresentador: apresentador,
            seletor: SeletorFalso(.confirmado(Self.regiao, Self.opcoes(.tres))),
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)

        #expect(apresentador.ajudas == 1)
        #expect(apresentador.alertas.isEmpty)
        #expect(apresentador.capturas.isEmpty)
        #expect(permissao.solicitacoes == 0)
        #expect(fluxo.gravacaoDoRascunho == nil)
    }

    private func capturaAoVivoQueFalhaMostraAlerta(
        _ resultado: Result<ImagemCapturada, ErroCaptura>
    ) async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = try await capturadorLivre()
        await capturador.programar(regiao: resultado)
        let apresentador = ApresentadorFalso()
        let contagem = ContagemFalsa()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            seletor: SeletorFalso(.confirmado(Self.regiao, Self.opcoes(.tres))),
            contagem: contagem,
            defaults: temporarios.defaults
        )

        await fluxo.capturarLivre(modo: .regiao)

        #expect(await capturador.chamadasDeRegiao.count == 1)
        #expect(apresentador.alertas == [.capturaFalhou])
        #expect(apresentador.capturas.isEmpty)
        #expect(apresentador.ajudas == 0)
        #expect(fluxo.gravacaoDoRascunho == nil)
        #expect(!contagem.visivel)
    }

}
