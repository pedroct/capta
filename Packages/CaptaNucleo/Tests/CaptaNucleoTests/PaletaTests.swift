import Testing

@testable import CaptaNucleo

private func confere(_ cor: CorRGBA, _ hex: Int, alfa: Double = 1) {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >> 8) & 0xFF) / 255
    let b = Double(hex & 0xFF) / 255
    #expect(abs(cor.r - r) < 1e-9)
    #expect(abs(cor.g - g) < 1e-9)
    #expect(abs(cor.b - b) < 1e-9)
    #expect(abs(cor.a - alfa) < 1e-9)
}

@Test func paletaTemOitoCoresDoTokensNaOrdem() {
    #expect(CorRGBA.paleta.count == 8)
    let hexes = [0xFF3B30, 0xFF9500, 0xFFCC00, 0x34C759, 0x0A84FF, 0xAF52DE, 0x1C1C1E, 0xFFFFFF]
    for (cor, hex) in zip(CorRGBA.paleta, hexes) { confere(cor, hex) }
    confere(.realce, 0xFFD60A, alfa: Double(0x8C) / 255)
}
