import CoreGraphics
import Testing

@testable import Capta

@Suite("Zoom e conversão do canvas")
struct ZoomTests {
    @Test func acimaDe100E150() {
        #expect(Zoom.acima(de: 1) == 1.5)
    }

    @Test func acimaDe400Fica400() {
        #expect(Zoom.acima(de: 4) == 4)
    }

    @Test func abaixoDe25Fica25() {
        #expect(Zoom.abaixo(de: 0.25) == 0.25)
    }

    @Test func abaixoDe100Vai75() {
        #expect(Zoom.abaixo(de: 1) == 0.75)
    }

    @Test func acimaDeValorEntreNiveisVaiAoProximo() {
        #expect(Zoom.acima(de: 0.6) == 0.75)
        #expect(Zoom.abaixo(de: 0.6) == 0.5)
    }

    @Test func ajusteAbaixoDe25NaoSobeAoDiminuirMasSobeAoAumentar() {
        #expect(Zoom.abaixo(de: 0.1) == 0.1)
        #expect(Zoom.acima(de: 0.1) == 0.25)
    }

    @Test func limitadoPrende() {
        #expect(Zoom.limitado(0.01) == 0.25)
        #expect(Zoom.limitado(9) == 4)
        #expect(Zoom.limitado(1.2) == 1.2)
    }

    @Test func limitadoPartindoDeZoomAbaixoDoPisoNaoSobeParaOPiso() {
        // Começou a pinça em 10 % (ajuste de imagem enorme): o piso é o ponto de partida.
        #expect(Zoom.limitado(0.05, partindoDe: 0.1) == 0.1)
        #expect(Zoom.limitado(0.12, partindoDe: 0.1) == 0.12)
        // De 50 % em diante vale o piso de sempre.
        #expect(Zoom.limitado(0.01, partindoDe: 0.5) == 0.25)
        #expect(Zoom.limitado(9, partindoDe: 0.5) == 4)
    }

    @Test func toleranciaEmPontosViraPixelsDeAcordoComOZoom() {
        let afastado = ConversaoDoCanvas(zoom: 0.25, escala: 2)
        let perto = ConversaoDoCanvas(zoom: 4, escala: 2)
        #expect(afastado.pixels(dePontos: 4) == 32)
        #expect(perto.pixels(dePontos: 4) == 2)
    }

    @Test func idaEVoltaDevolveOMesmoPonto() {
        let conversao = ConversaoDoCanvas(zoom: 1.5, escala: 2, origem: CGPoint(x: 10, y: 20))
        let pixel = CGPoint(x: 123, y: 45)
        #expect(conversao.pixel(de: conversao.ponto(de: pixel)) == pixel)
        #expect(conversao.ponto(de: CGPoint(x: 10, y: 20)) == .zero)
    }
}
