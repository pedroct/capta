#!/usr/bin/env swift
// Gera o AppIcon (16 a 1024 px, @1x/@2x) e o glifo da barra de menus a partir dos SVGs da marca.
// O NSImage do macOS desenha SVG nativamente; nenhuma ferramenta externa é necessária.
// Uso: swift ferramentas/gerar_icone.swift   (na raiz do repositório)
import AppKit

let raiz = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let marca = raiz.appendingPathComponent("docs/design-system/assets/Marca")
let catalogo = raiz.appendingPathComponent("App/Recursos/Assets.xcassets")

func falhar(_ mensagem: String) -> Never {
    FileHandle.standardError.write(Data("gerar_icone: \(mensagem)\n".utf8))
    exit(1)
}

func carregar(_ nome: String) -> NSImage {
    guard let imagem = NSImage(contentsOf: marca.appendingPathComponent(nome)) else {
        falhar("não consegui ler \(nome)")
    }
    return imagem
}

/// Desenha o SVG num bitmap com exatamente `pixels` x `pixels` (sem escala de tela).
func renderizar(_ imagem: NSImage, pixels: Int) -> Data {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let contexto = NSGraphicsContext(bitmapImageRep: rep)
    else { falhar("não consegui criar o bitmap de \(pixels) px") }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = contexto
    contexto.imageInterpolation = .high
    imagem.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        falhar("não consegui codificar o PNG de \(pixels) px")
    }
    return png
}

func escrever(_ dados: Data, em url: URL) {
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try dados.write(to: url)
    } catch { falhar("\(url.path): \(error.localizedDescription)") }
}

func escreverJSON(_ objeto: [String: Any], em url: URL) {
    guard
        let dados = try? JSONSerialization.data(
            withJSONObject: objeto, options: [.prettyPrinted, .sortedKeys])
    else { falhar("JSON inválido para \(url.lastPathComponent)") }
    escrever(dados + Data("\n".utf8), em: url)
}

let autor: [String: Any] = ["author": "xcode", "version": 1]

// AppIcon: 10 tamanhos.
let icone = carregar("capta-icone-app.svg")
let appIcon = catalogo.appendingPathComponent("AppIcon.appiconset")
var imagensIcone: [[String: Any]] = []
for ponto in [16, 32, 128, 256, 512] {
    for escala in [1, 2] {
        let arquivo = "icone_\(ponto)x\(ponto)@\(escala)x.png"
        escrever(renderizar(icone, pixels: ponto * escala), em: appIcon.appendingPathComponent(arquivo))
        imagensIcone.append([
            "filename": arquivo, "idiom": "mac",
            "scale": "\(escala)x", "size": "\(ponto)x\(ponto)",
        ])
    }
}
escreverJSON(["images": imagensIcone, "info": autor], em: appIcon.appendingPathComponent("Contents.json"))

// Glifo da barra de menus: imagem-modelo (template), 18 pt em @1x/@2x.
let glifo = carregar("capta-simbolo-barra-de-menus.svg")
let conjunto = catalogo.appendingPathComponent("GlifoMenu.imageset")
var imagensGlifo: [[String: Any]] = []
for escala in [1, 2] {
    let arquivo = "glifo_menu@\(escala)x.png"
    escrever(renderizar(glifo, pixels: 18 * escala), em: conjunto.appendingPathComponent(arquivo))
    imagensGlifo.append(["filename": arquivo, "idiom": "universal", "scale": "\(escala)x"])
}
escreverJSON(
    [
        "images": imagensGlifo, "info": autor,
        "properties": ["template-rendering-intent": "template"],
    ], em: conjunto.appendingPathComponent("Contents.json"))

print("gerar_icone: ok (AppIcon com \(imagensIcone.count) imagens, GlifoMenu)")
