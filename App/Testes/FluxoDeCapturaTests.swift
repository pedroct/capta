import CaptaNucleo
import CoreGraphics
import Foundation
import Testing

@testable import Capta

@Suite("Fluxo de captura")
@MainActor
struct FluxoDeCapturaTests {
    typealias Gravador = @Sendable (ImagemCapturada, Documento, URL, String) async throws -> URL

    static let cursor = CGPoint(x: 120, y: -40)
    static let instante = Date(timeIntervalSince1970: 1_800_000_000)

    /// Gravador que devolve uma URL dentro da pasta sem tocar o disco.
    static let gravadorQueConclui: Gravador = { _, _, pasta, nome in
        pasta.appendingPathComponent("\(nome).capta", isDirectory: true)
    }

    private func captura(escala: Double = 2) throws -> ImagemCapturada {
        ImagemCapturada(imagem: try imagemDeTeste(), escala: escala)
    }

    private func fluxo(
        capturador: CapturadorFalso,
        permissao: PermissaoFalsa = PermissaoFalsa(concedida: true),
        apresentador: ApresentadorFalso,
        defaults: UserDefaults,
        pasta: URL = URL(fileURLWithPath: "/rascunhos", isDirectory: true),
        gravador: @escaping Gravador = FluxoDeCapturaTests.gravadorQueConclui
    ) -> FluxoDeCaptura {
        FluxoDeCaptura(
            capturador: capturador,
            permissao: permissao,
            apresentador: apresentador,
            pastaDeRascunhos: pasta,
            cursor: { Self.cursor },
            agora: { Self.instante },
            defaults: defaults,
            gravadorDeRascunho: gravador,
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa()
        )
    }

    // MARK: - Permissão

    @Test func primeiraCapturaSemPermissaoSolicitaUmaVezEMostraAjuda() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = CapturadorFalso(.success(try captura()))
        let permissao = PermissaoFalsa(concedida: false)
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(
            capturador: capturador,
            permissao: permissao,
            apresentador: apresentador,
            defaults: temporarios.defaults
        )

        await fluxo.capturarTelaInteira()

        #expect(permissao.solicitacoes == 1)
        #expect(apresentador.ajudas == 1)
        #expect(apresentador.capturas.isEmpty)
        #expect(apresentador.alertas.isEmpty)
        #expect(await capturador.pontos.isEmpty)
        #expect(temporarios.defaults.bool(forKey: "permissaoJaSolicitada"))
    }

    @Test func tentarDeNovoSemPermissaoNaoSolicitaDeNovo() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = CapturadorFalso(.success(try captura()))
        let permissao = PermissaoFalsa(concedida: false)
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(
            capturador: capturador,
            permissao: permissao,
            apresentador: apresentador,
            defaults: temporarios.defaults
        )

        await fluxo.capturarTelaInteira()
        await fluxo.capturarTelaInteira()
        // Outra instância com os mesmos ajustes (o app reaberto) também não pede de novo.
        let reaberto = self.fluxo(
            capturador: capturador,
            permissao: permissao,
            apresentador: apresentador,
            defaults: temporarios.defaults
        )
        await reaberto.capturarTelaInteira()

        #expect(permissao.solicitacoes == 1)
        #expect(apresentador.ajudas == 3)
        #expect(apresentador.capturas.isEmpty)
        #expect(await capturador.pontos.isEmpty)
    }

    @Test func permissaoRevogadaNoMeioViraAjuda() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let capturador = CapturadorFalso(.failure(.semPermissao))
        let permissao = PermissaoFalsa(concedida: true)
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(
            capturador: capturador,
            permissao: permissao,
            apresentador: apresentador,
            defaults: temporarios.defaults
        )

        await fluxo.capturarTelaInteira()

        #expect(await capturador.pontos == [Self.cursor])
        #expect(apresentador.ajudas == 1)
        #expect(apresentador.alertas.isEmpty)
        #expect(apresentador.capturas.isEmpty)
        #expect(permissao.solicitacoes == 0)
    }

    @Test(arguments: [ErroCaptura.falhou, .telaNaoEncontrada])
    func outroErroMostraAlertaEPermanceSemJanela(erro: ErroCaptura) async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(
            capturador: CapturadorFalso(.failure(erro)),
            apresentador: apresentador,
            defaults: temporarios.defaults
        )

        await fluxo.capturarTelaInteira()

        #expect(apresentador.alertas == [.capturaFalhou])
        #expect(apresentador.capturas.isEmpty)
        #expect(apresentador.ajudas == 0)
    }

    @Test func escalaInvalidaNaCapturaMostraAlerta() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(
            capturador: CapturadorFalso(.success(try captura(escala: 0))),
            apresentador: apresentador,
            defaults: temporarios.defaults
        )

        await fluxo.capturarTelaInteira()

        #expect(apresentador.alertas == [.capturaFalhou])
        #expect(apresentador.capturas.isEmpty)
    }

    // MARK: - Disparos repetidos

    // Sem o comportamento esperado o teste ficaria preso no portão; o limite o faz falhar.
    @Test(.timeLimit(.minutes(1))) func dispararDuasVezesCapturaUmaVez() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let portao = Portao()
        let capturador = CapturadorFalso(.success(try captura()), portao: portao)
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(
            capturador: capturador,
            apresentador: apresentador,
            defaults: temporarios.defaults
        )

        let primeira = Task { await fluxo.capturarTelaInteira() }
        await portao.aguardarAlguemPreso()

        // Com a primeira presa no capturador, a segunda volta na hora sem capturar.
        await fluxo.capturarTelaInteira()
        #expect(await capturador.pontos.count == 1)
        #expect(apresentador.capturas.isEmpty)

        await portao.abrir()
        await primeira.value
        #expect(await capturador.pontos.count == 1)
        #expect(apresentador.capturas.count == 1)

        // Terminada a captura, um novo disparo volta a capturar.
        await fluxo.capturarTelaInteira()
        #expect(await capturador.pontos.count == 2)
        #expect(apresentador.capturas.count == 2)
    }

    // MARK: - Rascunho

    // Sem o comportamento esperado o teste ficaria preso no portão; o limite o faz falhar.
    @Test(.timeLimit(.minutes(1))) func janelaAbreAntesDeTerminarAGravacao() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let portao = Portao()
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(
            capturador: CapturadorFalso(.success(try captura())),
            apresentador: apresentador,
            defaults: temporarios.defaults,
            gravador: { captura, documento, pasta, nome in
                await portao.esperar()
                return try await Self.gravadorQueConclui(captura, documento, pasta, nome)
            }
        )

        await fluxo.capturarTelaInteira()

        let aberta = try #require(apresentador.capturas.first)
        #expect(apresentador.capturas.count == 1)
        #expect(aberta.rascunho == .gravando)
        #expect(!aberta.podeSalvarCapta)
        #expect(aberta.nome == Rascunho.nome(para: Self.instante))
        #expect(aberta.escala == 2)
        #expect(aberta.documento.tamanhoBase == CGSize(width: 8, height: 6))

        await portao.abrir()
        await fluxo.gravacaoDoRascunho?.value
        let esperado = URL(fileURLWithPath: "/rascunhos", isDirectory: true)
            .appendingPathComponent("\(aberta.nome).capta", isDirectory: true)
        #expect(aberta.rascunho == .gravado(esperado))
        #expect(aberta.podeSalvarCapta)
        #expect(apresentador.alertas.isEmpty)
    }

    /// O aviso é discreto (spec §4.5): vira estado da captura, mostrado na barra da janela,
    /// e não um alerta.
    @Test func falhaNoRascunhoAtualizaOEstadoEAvisaNaJanelaSemAlerta() async throws {
        let temporarios = try DefaultsTemporarios()
        defer { temporarios.remover() }
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(
            capturador: CapturadorFalso(.success(try captura())),
            apresentador: apresentador,
            defaults: temporarios.defaults,
            gravador: { _, _, _, _ in throw ErroDeTeste() }
        )

        await fluxo.capturarTelaInteira()
        await fluxo.gravacaoDoRascunho?.value

        let aberta = try #require(apresentador.capturas.first)
        #expect(aberta.rascunho == .falhou)
        #expect(aberta.podeSalvarCapta)
        #expect(aberta.aviso == .rascunhoNaoGuardado)
        #expect(apresentador.alertas.isEmpty)
    }

    @Test func gravadorPadraoGravaORascunhoNaPasta() async throws {
        let temporarios = try DefaultsTemporarios()
        let pasta = try PastaTemporaria()
        defer {
            temporarios.remover()
            pasta.remover()
        }
        let rascunhos = pasta.url.appendingPathComponent("Capturas", isDirectory: true)
        let apresentador = ApresentadorFalso()
        let fluxo = FluxoDeCaptura(
            capturador: CapturadorFalso(.success(try captura())),
            permissao: PermissaoFalsa(concedida: true),
            apresentador: apresentador,
            pastaDeRascunhos: rascunhos,
            agora: { Self.instante },
            defaults: temporarios.defaults,
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa()
        )

        await fluxo.capturarTelaInteira()
        await fluxo.gravacaoDoRascunho?.value

        let aberta = try #require(apresentador.capturas.first)
        let esperado = rascunhos.appendingPathComponent(
            "\(Rascunho.nome(para: Self.instante)).capta",
            isDirectory: true
        )
        #expect(aberta.rascunho == .gravado(esperado))
        let conteudo = try PacoteCapta.ler(de: esperado)
        #expect(conteudo.documento == aberta.documento)
    }
}
