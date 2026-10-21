import CoreGraphics
import Testing

@testable import CaptaNucleo

@Suite("Máquina de estados do overlay: região")
struct EstadoDoOverlayRegiaoTests: CenaDoOverlay {
    @Test func arrastarEmATelaGeraSelecaoEmPixelsNativos() {
        let final = comSelecao()
        #expect(final.selecao?.pixels == CGRect(x: 20, y: 20, width: 100, height: 60))
        #expect(final.selecao?.telaId == telaA.id)
        #expect(final.selecao?.limites == CGSize(width: 2000, height: 1600))
        #expect(final.resultado == nil)
    }

    @Test func arrastoMostraASelecaoEnquantoArrasta() {
        let meio = estado().aplicando([.mouseBaixo(ponto(10, 10)), .mouseArrastou(ponto(60, 40))])
        #expect(meio.selecao?.pixels == CGRect(x: 20, y: 20, width: 100, height: 60))
        #expect(meio.cursor == ponto(60, 40))
    }

    @Test func arrastoComPontoFracionarioUsaOPixelSobOCursor() {
        let final = estado().aplicando(arrasto(ponto(10.3, 10.3), ponto(60.4, 40.9)))
        #expect(final.selecao?.pixels == CGRect(x: 20, y: 20, width: 100, height: 61))
    }

    @Test func arrastoQueSaiDaTelaFicaPresoNaTelaDeOrigem() {
        let final = estado().aplicando(arrasto(ponto(900, 700), ponto(1500, 900)))
        #expect(final.selecao?.telaId == telaA.id)
        #expect(final.selecao?.pixels == CGRect(x: 1800, y: 1400, width: 200, height: 200))
    }

    @Test func arrastoQueComecaEmBUsaAEscalaDeB() {
        let final = estado().aplicando(arrasto(ponto(1010, 10), ponto(1060, 40)))
        #expect(final.selecao?.telaId == telaB.id)
        #expect(final.selecao?.pixels == CGRect(x: 10, y: 10, width: 50, height: 30))
    }

    @Test func arrastarPorDentroMove() {
        // (35, 25) pt = (70, 50) px: longe das bordas, dentro da seleção.
        let meio = comSelecao().aplicando([
            .mouseBaixo(ponto(35, 25)), .mouseArrastou(ponto(40, 25)),
        ])
        #expect(meio.selecao?.pixels == CGRect(x: 30, y: 20, width: 100, height: 60))
        // O deslocamento conta a partir do clique, não do último evento.
        let final = meio.aplicando([.mouseArrastou(ponto(45, 30)), .mouseSolto(ponto(45, 30))])
        #expect(final.selecao?.pixels == CGRect(x: 40, y: 30, width: 100, height: 60))
        // Solto o botão, arrastar não mexe mais na seleção.
        #expect(final.reduzindo(.mouseArrastou(ponto(300, 300))).selecao == final.selecao)
    }

    @Test func moverFicaPresoNaTelaDaSelecao() {
        let inicio = comSelecao().reduzindo(.mouseBaixo(ponto(35, 25)))
        let esquerda = inicio.reduzindo(.mouseArrastou(ponto(-100, 25)))
        #expect(esquerda.selecao?.pixels == CGRect(x: 0, y: 20, width: 100, height: 60))
        let outraTela = inicio.reduzindo(.mouseArrastou(ponto(1500, 25)))
        #expect(outraTela.selecao?.telaId == telaA.id)
        #expect(outraTela.selecao?.pixels == CGRect(x: 1900, y: 20, width: 100, height: 60))
    }

    @Test func arrastarBordaRedimensiona() {
        // (60, 25) pt = (120, 50) px: em cima da borda direita.
        let final = comSelecao().aplicando(arrasto(ponto(60, 25), ponto(80, 25)))
        #expect(final.selecao?.pixels == CGRect(x: 20, y: 20, width: 140, height: 60))
    }

    @Test func arrastarCantoRedimensionaNosDoisEixos() {
        let final = comSelecao().aplicando(arrasto(ponto(10, 10), ponto(5, 5)))
        #expect(final.selecao?.pixels == CGRect(x: 10, y: 10, width: 110, height: 70))
    }

    @Test func redimensionarAlemDaBordaOpostaInverte() {
        let final = comSelecao().aplicando(arrasto(ponto(60, 25), ponto(5, 25)))
        #expect(final.selecao?.pixels == CGRect(x: 10, y: 20, width: 10, height: 60))
    }

    @Test func pegarABordaComFolgaNaoFazASelecaoPular() {
        // (61, 25) pt = (122, 50) px: 2 px fora da borda direita, ainda dentro da tolerância.
        let clique = comSelecao().aplicando([
            .mouseBaixo(ponto(61, 25)), .mouseSolto(ponto(61, 25)),
        ])
        #expect(clique.selecao?.pixels == CGRect(x: 20, y: 20, width: 100, height: 60))
        // A borda anda o mesmo que o cursor (20 px), sem saltar até ele.
        let arrastada = comSelecao().aplicando(arrasto(ponto(61, 25), ponto(71, 25)))
        #expect(arrastada.selecao?.pixels == CGRect(x: 20, y: 20, width: 120, height: 60))
    }

    @Test func toleranciaDeAcertoEDeQuatroPontos() {
        #expect(EstadoDoOverlay.toleranciaDeAcerto == 4)
        // Em A (escala 2) são 8 px: 8 px fora da borda direita ainda a pega...
        let naBorda = comSelecao().aplicando(arrasto(ponto(64, 25), ponto(74, 25)))
        #expect(naBorda.selecao?.pixels == CGRect(x: 20, y: 20, width: 120, height: 60))
        // ...e 10 px fora já começa uma seleção nova.
        let fora = comSelecao().aplicando(arrasto(ponto(65, 25), ponto(75, 35)))
        #expect(fora.selecao?.pixels == CGRect(x: 130, y: 50, width: 20, height: 20))
    }

    @Test func selecaoPequenaAindaTemDentroParaMover() {
        // 4 × 4 px: a tolerância cai para um quarto do menor lado (1 px) e o meio fica `.dentro`.
        let pequena = estado().aplicando(arrasto(ponto(10, 10), ponto(12, 12)))
        #expect(pequena.selecao?.pixels == CGRect(x: 20, y: 20, width: 4, height: 4))
        let movida = pequena.aplicando(arrasto(ponto(11, 11), ponto(13, 11)))
        #expect(movida.selecao?.pixels == CGRect(x: 24, y: 20, width: 4, height: 4))
    }

    @Test func clicarForaComecaNovaSelecao() {
        let final = comSelecao().aplicando(arrasto(ponto(200, 200), ponto(210, 220)))
        #expect(final.selecao?.pixels == CGRect(x: 400, y: 400, width: 20, height: 40))
    }

    @Test func clicarForaSemArrastarDescartaASelecao() {
        let final = comSelecao().aplicando([
            .mouseBaixo(ponto(200, 200)), .mouseSolto(ponto(200, 200)),
        ])
        #expect(final.selecao == nil)
    }

    @Test func cliqueEmOutraTelaComecaNovaSelecaoNela() {
        // Seleção de A encostada na borda direita; 0,5 pt dentro de B ficaria a 1 px dessa
        // borda se fosse convertido pela escala de A.
        let encostada = estado().aplicando(arrasto(ponto(900, 10), ponto(1000, 40)))
        #expect(encostada.selecao?.pixels == CGRect(x: 1800, y: 20, width: 200, height: 60))
        let final = encostada.aplicando(arrasto(ponto(1000.5, 25), ponto(1100, 100)))
        #expect(final.selecao?.telaId == telaB.id)
        #expect(final.selecao?.pixels == CGRect(x: 0, y: 25, width: 100, height: 75))
    }

    @Test func cursorMoveuDuranteOArrastoSoMoveOCursor() {
        let meio = estado().aplicando([.mouseBaixo(ponto(10, 10)), .mouseArrastou(ponto(60, 40))])
        let depois = meio.reduzindo(.cursorMoveu(ponto(300, 300)))
        #expect(depois.cursor == ponto(300, 300))
        #expect(depois.selecao == meio.selecao)
    }

    @Test func arrastarSemBotaoBaixoSoMoveOCursor() {
        let final = estado().aplicando([.mouseArrastou(ponto(5, 5)), .mouseSolto(ponto(6, 6))])
        #expect(final.cursor == ponto(6, 6))
        #expect(final.selecao == nil)
    }

    @Test func setaMoveUmPixelEComShiftDez() {
        let base = comSelecao()
        let casos: [(TeclaDoOverlay, CGRect)] = [
            (.seta(.direita, grande: false), CGRect(x: 21, y: 20, width: 100, height: 60)),
            (.seta(.esquerda, grande: false), CGRect(x: 19, y: 20, width: 100, height: 60)),
            (.seta(.baixo, grande: false), CGRect(x: 20, y: 21, width: 100, height: 60)),
            (.seta(.cima, grande: false), CGRect(x: 20, y: 19, width: 100, height: 60)),
            (.seta(.direita, grande: true), CGRect(x: 30, y: 20, width: 100, height: 60)),
            (.seta(.esquerda, grande: true), CGRect(x: 10, y: 20, width: 100, height: 60)),
            (.seta(.baixo, grande: true), CGRect(x: 20, y: 30, width: 100, height: 60)),
            (.seta(.cima, grande: true), CGRect(x: 20, y: 10, width: 100, height: 60)),
        ]
        for (tecla, esperado) in casos {
            #expect(base.reduzindo(.tecla(tecla)).selecao?.pixels == esperado)
        }
        // Presa à tela: de 20 px, 10 + 10 + 10 para a esquerda param no 0.
        let presa = base.aplicando(
            Array(repeating: .tecla(.seta(.esquerda, grande: true)), count: 3)
        )
        #expect(presa.selecao?.pixels == CGRect(x: 0, y: 20, width: 100, height: 60))
    }

    @Test func setaSemSelecaoNaoFazNada() {
        let inicial = estado()
        #expect(inicial.reduzindo(.tecla(.seta(.cima, grande: false))) == inicial)
        #expect(inicial.reduzindo(.tecla(.seta(.direita, grande: true))) == inicial)
    }

    @Test func setaDuranteOArrastoEIgnorada() {
        let meio = estado().aplicando([.mouseBaixo(ponto(10, 10)), .mouseArrastou(ponto(60, 40))])
        #expect(meio.reduzindo(.tecla(.seta(.direita, grande: false))) == meio)
    }

    @Test func enterConfirmaARegiaoComAsOpcoes() {
        let final = comSelecao().reduzindo(.tecla(.enter))
        #expect(
            final.resultado
                == .confirmado(
                    .regiao(tela: telaA, pixels: CGRect(x: 20, y: 20, width: 100, height: 60)),
                    opcoes
                )
        )
    }

    @Test func enterSemSelecaoNaoConfirma() {
        let inicial = estado()
        #expect(inicial.reduzindo(.tecla(.enter)) == inicial)
        let descartada = comSelecao().aplicando([
            .mouseBaixo(ponto(200, 200)), .mouseSolto(ponto(200, 200)), .tecla(.enter),
        ])
        #expect(descartada.resultado == nil)
    }

    @Test func enterDuranteOArrastoConfirmaOQueEstaNaTela() {
        let final = estado().aplicando([
            .mouseBaixo(ponto(10, 10)), .mouseArrastou(ponto(60, 40)), .tecla(.enter),
        ])
        #expect(
            final.resultado
                == .confirmado(
                    .regiao(tela: telaA, pixels: CGRect(x: 20, y: 20, width: 100, height: 60)),
                    opcoes
                )
        )
    }

    @Test func telaSemPixelsNaoComecaSelecao() {
        let vazia = DescricaoDeTela(id: 9, quadro: .zero, escala: 2, principal: true)
        let final = estado(telas: [vazia]).aplicando(arrasto(ponto(0, 0), ponto(10, 10)))
        #expect(final.selecao == nil)
        #expect(final.reduzindo(.tecla(.f)).resultado == nil)
    }

    @Test func pontosNaoFinitosNaoQuebramOMovimento() {
        let final = comSelecao().aplicando([
            .mouseBaixo(ponto(35, 25)), .mouseArrastou(ponto(.nan, .infinity)),
        ])
        #expect(final.selecao?.pixels == CGRect(x: 20, y: 1540, width: 100, height: 60))
    }
}
