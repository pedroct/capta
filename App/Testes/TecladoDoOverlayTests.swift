import AppKit
import CaptaNucleo
import Testing

@testable import Capta

@Suite("Teclado do overlay")
struct TecladoDoOverlayTests {
    private static let semModificador: NSEvent.ModifierFlags = []

    @Test(arguments: [
        (UInt16(53), TeclaDoOverlay.esc),
        (36, .enter),
        (76, .enter),
        (49, .espaco),
        (123, .seta(.esquerda, grande: false)),
        (124, .seta(.direita, grande: false)),
        (125, .seta(.baixo, grande: false)),
        (126, .seta(.cima, grande: false)),
    ])
    func teclasEspeciaisPeloCodigo(codigo: UInt16, esperada: TeclaDoOverlay) {
        #expect(TeclaDoOverlay.de(codigo: codigo, caracteres: nil, modificadores: []) == esperada)
    }

    @Test func setaComShiftEGrande() {
        let tecla = TeclaDoOverlay.de(codigo: 126, caracteres: nil, modificadores: [.shift])
        #expect(tecla == .seta(.cima, grande: true))
    }

    @Test func setaAceitaAsFlagsDeTecladoNumericoEFuncao() {
        let tecla = TeclaDoOverlay.de(
            codigo: 123,
            caracteres: nil,
            modificadores: [.numericPad, .function]
        )
        #expect(tecla == .seta(.esquerda, grande: false))
    }

    @Test(arguments: [("f", TeclaDoOverlay.f), ("F", .f), ("m", .m), ("M", .m), ("h", .h)])
    func letrasPeloCaractere(caractere: String, esperada: TeclaDoOverlay) {
        // Código qualquer: vale o caractere do layout (Dvorak, AZERTY...).
        #expect(TeclaDoOverlay.de(codigo: 0, caracteres: caractere, modificadores: []) == esperada)
    }

    @Test func letraLatinaQueNaoEDoOverlayNaoCaiNoCodigo() {
        // No AZERTY, o código 46 (M no ANSI) é a vírgula: não pode virar `M`.
        #expect(TeclaDoOverlay.de(codigo: 46, caracteres: ",", modificadores: []) == nil)
        #expect(TeclaDoOverlay.de(codigo: 3, caracteres: "u", modificadores: []) == nil)
    }

    @Test(arguments: [(UInt16(3), TeclaDoOverlay.f), (46, .m), (4, .h)])
    func layoutNaoLatinoUsaOCodigoANSI(codigo: UInt16, esperada: TeclaDoOverlay) {
        #expect(TeclaDoOverlay.de(codigo: codigo, caracteres: "ж", modificadores: []) == esperada)
        #expect(TeclaDoOverlay.de(codigo: codigo, caracteres: nil, modificadores: []) == esperada)
    }

    @Test(arguments: [NSEvent.ModifierFlags.command, .control, .option])
    func comandoControleOuOpcaoNaoSaoDoOverlay(modificador: NSEvent.ModifierFlags) {
        #expect(TeclaDoOverlay.de(codigo: 53, caracteres: nil, modificadores: modificador) == nil)
        #expect(TeclaDoOverlay.de(codigo: 3, caracteres: "f", modificadores: modificador) == nil)
    }

    @Test func outraTeclaNaoEDoOverlay() {
        #expect(TeclaDoOverlay.de(codigo: 0, caracteres: "a", modificadores: []) == nil)
        #expect(TeclaDoOverlay.de(codigo: 999, caracteres: nil, modificadores: []) == nil)
    }

    @Test func soOComandoDeixaATeclaPassar() {
        #expect(TeclaDoOverlay.deixaPassar(modificadores: [.command]))
        #expect(TeclaDoOverlay.deixaPassar(modificadores: [.command, .shift]))
        #expect(!TeclaDoOverlay.deixaPassar(modificadores: []))
        #expect(!TeclaDoOverlay.deixaPassar(modificadores: [.shift, .option]))
    }
}
