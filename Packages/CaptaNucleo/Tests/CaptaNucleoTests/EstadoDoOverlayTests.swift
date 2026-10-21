import CoreGraphics
import Testing

@testable import CaptaNucleo

@Suite("Máquina de estados do overlay: janela")
struct EstadoDoOverlayJanelaTests: CenaDoOverlay {
    @Test func cursorSobreJanelaRealcaAMaisAFrente() {
        let inicial = estado(modo: .janela)
        #expect(inicial.reduzindo(.cursorMoveu(ponto(200, 200))).janelaRealcada == j1)
        #expect(inicial.reduzindo(.cursorMoveu(ponto(60, 60))).janelaRealcada == j2)
    }

    @Test func cliqueNaJanelaConfirmaNaHora() {
        let final = estado(modo: .janela).reduzindo(.mouseBaixo(ponto(200, 200)))
        #expect(final.resultado == .confirmado(.janela(id: j1.id), opcoes))
    }

    @Test func cliqueForaDeJanelaNaoConfirma() {
        let final = estado(modo: .janela).reduzindo(.mouseBaixo(ponto(700, 700)))
        #expect(final.resultado == nil)
        #expect(final.janelaRealcada == nil)
        #expect(final.reduzindo(.mouseArrastou(ponto(800, 700))).selecao == nil)
    }

    @Test func enterConfirmaARealcada() {
        let final = estado(modo: .janela).aplicando([.cursorMoveu(ponto(60, 60)), .tecla(.enter)])
        #expect(final.resultado == .confirmado(.janela(id: j2.id), opcoes))
    }

    @Test func enterSemRealceNaoFazNada() {
        let semRealce = estado(modo: .janela).reduzindo(.cursorMoveu(ponto(700, 700)))
        #expect(semRealce.reduzindo(.tecla(.enter)) == semRealce)
    }

    @Test func cursorForaDeJanelaLimpaORealce() {
        let final = estado(modo: .janela).aplicando([
            .cursorMoveu(ponto(200, 200)), .cursorMoveu(ponto(700, 700)),
        ])
        #expect(final.janelaRealcada == nil)
    }

    @Test func arrastarNoModoJanelaAtualizaORealce() {
        let final = estado(modo: .janela).aplicando([
            .mouseBaixo(ponto(700, 700)), .mouseArrastou(ponto(200, 200)),
        ])
        #expect(final.janelaRealcada == j1)
        #expect(final.resultado == nil)
    }

    @Test func noModoRegiaoNaoHaRealce() {
        #expect(estado().reduzindo(.cursorMoveu(ponto(200, 200))).janelaRealcada == nil)
    }
}

@Suite("Máquina de estados do overlay: modo e teclas")
struct EstadoDoOverlayTeclasTests: CenaDoOverlay {
    @Test func inicialComecaLimpo() {
        let inicial = estado(ajudaVisivel: false)
        #expect(inicial.modo == .regiao)
        #expect(inicial.telas == [telaA, telaB])
        #expect(inicial.janelas == [j1, j2])
        #expect(inicial.selecao == nil)
        #expect(inicial.janelaRealcada == nil)
        #expect(inicial.lupaLigada == false)
        #expect(inicial.ajudaVisivel == false)
        #expect(inicial.opcoes == opcoes)
        #expect(inicial.resultado == nil)
    }

    @Test func espacoAlternaERegiaoEJanela() {
        let janela = comSelecao().aplicando([.cursorMoveu(ponto(200, 200)), .tecla(.espaco)])
        #expect(janela.modo == .janela)
        #expect(janela.selecao == nil)
        // Ao entrar no modo janela já realça a janela sob o cursor.
        #expect(janela.janelaRealcada == j1)
        let regiao = janela.reduzindo(.tecla(.espaco))
        #expect(regiao.modo == .regiao)
        #expect(regiao.janelaRealcada == nil)
        #expect(regiao.selecao == nil)
    }

    @Test func espacoSemJanelasNaoMudaDeModo() {
        let inicial = estado(janelas: [])
        #expect(inicial.reduzindo(.tecla(.espaco)).modo == .regiao)
    }

    @Test func espacoDuranteOArrastoEIgnorado() {
        let meio = estado().aplicando([.mouseBaixo(ponto(10, 10)), .mouseArrastou(ponto(60, 40))])
        #expect(meio.reduzindo(.tecla(.espaco)) == meio)
    }

    @Test func inicialComModoJanelaESemJanelasCaiParaRegiao() {
        #expect(estado(modo: .janela, janelas: []).modo == .regiao)
        #expect(estado(modo: .janela).modo == .janela)
    }

    @Test func fConfirmaATelaSobOCursor() {
        let esperado = ResultadoDoOverlay.confirmado(
            .regiao(tela: telaB, pixels: CGRect(x: 0, y: 0, width: 1000, height: 800)),
            opcoes
        )
        for modo in [ModoDoOverlay.regiao, .janela] {
            let final = estado(modo: modo).aplicando([.cursorMoveu(ponto(1500, 400)), .tecla(.f)])
            #expect(final.resultado == esperado)
        }
        let emA = estado().aplicando([.cursorMoveu(ponto(10, 10)), .tecla(.f)])
        #expect(
            emA.resultado
                == .confirmado(
                    .regiao(tela: telaA, pixels: CGRect(x: 0, y: 0, width: 2000, height: 1600)),
                    opcoes
                )
        )
    }

    @Test func fSemTelasNaoFazNada() {
        let semTelas = estado(telas: [])
        #expect(semTelas.reduzindo(.tecla(.f)) == semTelas)
    }

    @Test func mLigaEDesligaALupa() {
        let ligada = estado().reduzindo(.tecla(.m))
        #expect(ligada.lupaLigada)
        #expect(ligada.reduzindo(.tecla(.m)).lupaLigada == false)
    }

    @Test func hAlternaAAjuda() {
        let oculta = estado(ajudaVisivel: true).reduzindo(.tecla(.h))
        #expect(oculta.ajudaVisivel == false)
        #expect(oculta.reduzindo(.tecla(.h)).ajudaVisivel)
    }

    @Test func escCancela() {
        #expect(comSelecao().reduzindo(.tecla(.esc)).resultado == .cancelado)
        #expect(estado(modo: .janela).reduzindo(.tecla(.esc)).resultado == .cancelado)
    }
}

@Suite("Máquina de estados do overlay: segurança e opções")
struct EstadoDoOverlaySegurancaTests: CenaDoOverlay {
    @Test func telasMudaramCancela() {
        #expect(comSelecao().reduzindo(.telasMudaram).resultado == .cancelado)
    }

    @Test func perdeuAtivacaoCancela() {
        #expect(comSelecao().reduzindo(.perdeuAtivacao).resultado == .cancelado)
    }

    @Test func eventosDepoisDoResultadoSaoIgnorados() {
        let eventos: [EventoDoOverlay] = [
            .cursorMoveu(ponto(200, 200)),
            .mouseBaixo(ponto(35, 25)),
            .mouseArrastou(ponto(500, 500)),
            .mouseSolto(ponto(500, 500)),
            .tecla(.esc), .tecla(.f), .tecla(.espaco), .tecla(.enter), .tecla(.m), .tecla(.h),
            .tecla(.seta(.direita, grande: true)),
            .opcoesMudaram(OpcoesDeCaptura(atraso: .dez, incluirCursor: false)),
            .telasMudaram,
            .perdeuAtivacao,
        ]
        let confirmado = comSelecao().reduzindo(.tecla(.enter))
        let cancelado = comSelecao().reduzindo(.tecla(.esc))
        for final in [confirmado, cancelado] {
            #expect(final.resultado != nil)
            for evento in eventos {
                #expect(final.reduzindo(evento) == final)
            }
        }
    }

    @Test func opcoesMudaramTrocaAsOpcoes() {
        let novas = OpcoesDeCaptura(atraso: .dez, incluirCursor: false)
        let final = comSelecao().aplicando([.opcoesMudaram(novas), .tecla(.enter)])
        #expect(final.opcoes == novas)
        #expect(
            final.resultado
                == .confirmado(
                    .regiao(tela: telaA, pixels: CGRect(x: 20, y: 20, width: 100, height: 60)),
                    novas
                )
        )
    }

    @Test func incluirCursorFicaGuardadoSemAtraso() {
        let semAtraso = OpcoesDeCaptura(atraso: .nenhum, incluirCursor: true)
        let final = estado().reduzindo(.opcoesMudaram(semAtraso))
        #expect(final.opcoes.atraso == .nenhum)
        #expect(final.opcoes.incluirCursor)
        let confirmado = final.aplicando([.cursorMoveu(ponto(1500, 400)), .tecla(.f)])
        #expect(
            confirmado.resultado
                == .confirmado(
                    .regiao(tela: telaB, pixels: CGRect(x: 0, y: 0, width: 1000, height: 800)),
                    semAtraso
                )
        )
    }
}
