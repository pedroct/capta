import AppKit
import CaptaNucleo
import Testing

@testable import Capta

@MainActor
@Suite("Janela da contagem", .serialized)
struct JanelaDaContagemTests {
    private static let tela = DescricaoDeTela(
        id: 1,
        quadro: CGRect(x: 100, y: 0, width: 800, height: 600),
        escala: 2,
        principal: false
    )

    private final class Cancelamentos {
        var total = 0
        var anuncios: [String] = []
    }

    private func janela(_ atalho: AtalhoFalso, _ registro: Cancelamentos) -> JanelaDaContagem {
        JanelaDaContagem(
            atalhoDeEsc: atalho,
            alturaDaPrincipal: { 900 },
            anunciar: { registro.anuncios.append($0) },
            aoCancelar: { registro.total += 1 }
        )
    }

    @Test func textosDaContagem() {
        #expect(JanelaDaContagem.numero(3) == "3")
        #expect(JanelaDaContagem.numero(-2) == "0")
        #expect(JanelaDaContagem.anuncio(5) == "Captura em 5 segundos. Esc cancela.")
        #expect(JanelaDaContagem.anuncio(1) == "Captura em 1 segundo. Esc cancela.")
    }

    @Test func quadroFicaNoTopoCentradoNaTelaDaSelecao() {
        let quadro = JanelaDaContagem.quadro(
            tamanho: CGSize(width: 120, height: 80),
            naTela: Self.tela,
            alturaDaPrincipal: 900
        )
        #expect(quadro.midX == 500)
        // Topo da tela (y = 0 no núcleo) é y = 900 no AppKit, menos a margem.
        #expect(quadro.maxY == 900 - JanelaDaContagem.margemDoTopo)
        #expect(quadro.size == CGSize(width: 120, height: 80))
    }

    @Test func mostrarRegistraEscAnunciaEAtualizaTexto() throws {
        let atalho = AtalhoFalso()
        let registro = Cancelamentos()
        let j = janela(atalho, registro)
        j.mostrar(segundos: 3, naTela: Self.tela)
        #expect(j.visivel)
        #expect(atalho.combinacoes.count == 1)
        #expect(atalho.combinacoes.first?.codigoDaTecla == GerenciadorDoOverlay.codigoDoEsc)
        #expect(j.numeroExibido == "3")
        #expect(registro.anuncios == ["Captura em 3 segundos. Esc cancela."])
        j.atualizar(2)
        #expect(j.numeroExibido == "2")
        #expect(registro.anuncios.last == "Captura em 2 segundos. Esc cancela.")
        j.fechar()
        #expect(!j.visivel)
        #expect(atalho.liberacoes == 1)
    }

    @Test func painelUsaOMesmoNivelDoOverlay() {
        let j = janela(AtalhoFalso(), Cancelamentos())
        #expect(j.nivelDoPainel == nil)
        j.mostrar(segundos: 3, naTela: Self.tela)
        #expect(j.nivelDoPainel == .popUpMenu)
        #expect(j.nivelDoPainel == JanelaDeOverlay.nivel)
        j.fechar()
        #expect(j.nivelDoPainel == nil)
    }

    @Test func fecharDuasVezesLiberaUmaVezSo() {
        let atalho = AtalhoFalso()
        let j = janela(atalho, Cancelamentos())
        j.mostrar(segundos: 3, naTela: Self.tela)
        j.fechar()
        j.fechar()
        #expect(atalho.liberacoes == 1)
    }

    @Test func fecharSemMostrarNaoLibera() {
        let atalho = AtalhoFalso()
        let j = janela(atalho, Cancelamentos())
        j.fechar()
        #expect(atalho.liberacoes == 0)
    }

    @Test func mostrarDeNovoSemFecharNaoRegistraDuasVezes() {
        let atalho = AtalhoFalso()
        let j = janela(atalho, Cancelamentos())
        j.mostrar(segundos: 3, naTela: Self.tela)
        j.mostrar(segundos: 5, naTela: Self.tela)
        #expect(atalho.combinacoes.count == 1)
        #expect(j.numeroExibido == "5")
        j.fechar()
        #expect(atalho.liberacoes == 1)
    }

    @Test func atualizarForaDaContagemNaoFazNada() {
        let registro = Cancelamentos()
        let j = janela(AtalhoFalso(), registro)
        j.atualizar(2)
        #expect(registro.anuncios.isEmpty)
        #expect(!j.visivel)
    }

    @Test func escGlobalFechaELibera() async {
        let atalho = AtalhoFalso()
        let registro = Cancelamentos()
        let j = janela(atalho, registro)
        j.mostrar(segundos: 3, naTela: Self.tela)
        atalho.acao?()
        for _ in 0..<1000 where j.visivel { await Task.yield() }
        #expect(!j.visivel)
        #expect(registro.total == 1)
        #expect(atalho.liberacoes == 1)
    }

    @Test func cliqueCancelaUmaVezELibera() {
        let atalho = AtalhoFalso()
        let registro = Cancelamentos()
        let j = janela(atalho, registro)
        j.mostrar(segundos: 3, naTela: Self.tela)
        j.cancelar()
        j.cancelar()
        #expect(registro.total == 1)
        #expect(!j.visivel)
        #expect(atalho.liberacoes == 1)
    }

    @Test func falhaNoRegistroDoEscMantemAContagemECliqueCancela() {
        let atalho = AtalhoFalso()
        atalho.erro = .falhou
        let registro = Cancelamentos()
        let j = janela(atalho, registro)
        j.mostrar(segundos: 3, naTela: Self.tela)
        #expect(j.visivel)
        j.cancelar()
        #expect(registro.total == 1)
        #expect(!j.visivel)
    }
}
