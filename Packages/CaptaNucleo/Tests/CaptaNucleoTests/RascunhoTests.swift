import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import CaptaNucleo

private func novaPastaTemporaria() throws -> URL {
    let pasta = FileManager.default.temporaryDirectory
        .appendingPathComponent("capta-teste-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
    return pasta
}

private func remover(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

private func captura(escala: Double = 2) -> ImagemCapturada {
    ImagemCapturada(
        imagem: imagemSolida(CGSize(width: 40, height: 30), cor: CorRGBA(r: 1, g: 0, b: 0, a: 1)),
        escala: escala
    )
}

private func itens(_ url: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
}

@Test func documentoNasceComPixelsEEscalaDaCaptura() throws {
    let documento = try Documento.novo(de: captura(escala: 2))
    #expect(documento.tamanhoBase == CGSize(width: 40, height: 30))
    #expect(documento.escala == 2)
    #expect(documento.objetos.isEmpty)
}

@Test func escalaInvalidaNaoCriaDocumento() {
    #expect(throws: ErroDocumento.tamanhoInvalido) {
        _ = try Documento.novo(de: captura(escala: 0))
    }
}

@Test func nomeUsaDataEHoraDoFusoDado() throws {
    let utc = try #require(TimeZone(identifier: "UTC"))
    let data = Date(timeIntervalSince1970: 1_792_497_845)  // 2026-10-20 12:04:05 UTC
    #expect(Rascunho.nome(para: data, fuso: utc) == "Captura 2026-10-20 às 12.04.05")
    let saoPaulo = try #require(TimeZone(identifier: "America/Sao_Paulo"))
    #expect(Rascunho.nome(para: data, fuso: saoPaulo) == "Captura 2026-10-20 às 09.04.05")
}

@Test func gravarCriaPastaEPacoteLegivel() throws {
    let raiz = try novaPastaTemporaria()
    defer { remover(raiz) }
    let pasta = raiz.appendingPathComponent("novas/rascunhos", isDirectory: true)
    let c = captura()
    let documento = try Documento.novo(de: c)
    let url = try Rascunho.gravar(c, documento: documento, em: pasta, nome: "Captura X")
    #expect(url.lastPathComponent == "Captura X.capta")

    let lido = try PacoteCapta.ler(de: url)
    #expect(lido.documento.tamanhoBase == CGSize(width: 40, height: 30))
    #expect(lido.documento.escala == 2)
    #expect(lido.documento.objetos.isEmpty)
    let fonte = try #require(CGImageSourceCreateWithData(lido.baseDados as CFData, nil))
    let base = try #require(CGImageSourceCreateImageAtIndex(fonte, 0, nil))
    #expect(base.width == 40 && base.height == 30)
    #expect(lido.miniaturaDados?.isEmpty == false)
}

@Test func nomeRepetidoGanhaSufixoENaoSobrescreve() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let c = captura()
    let documento = try Documento.novo(de: c)
    let a = try Rascunho.gravar(c, documento: documento, em: pasta, nome: "N")
    let b = try Rascunho.gravar(c, documento: documento, em: pasta, nome: "N")
    let d = try Rascunho.gravar(c, documento: documento, em: pasta, nome: "N")
    #expect([a, b, d].map(\.lastPathComponent) == ["N.capta", "N 2.capta", "N 3.capta"])
    #expect(try itens(pasta) == ["N 2.capta", "N 3.capta", "N.capta"])
}

@Test func pastaSemPermissaoDeEscritaLanca() throws {
    try #require(getuid() != 0, "root ignora permissões de pasta")
    let pasta = try novaPastaTemporaria()
    let gerenciador = FileManager.default
    try gerenciador.setAttributes([.posixPermissions: 0o500], ofItemAtPath: pasta.path)
    defer {
        try? gerenciador.setAttributes([.posixPermissions: 0o700], ofItemAtPath: pasta.path)
        remover(pasta)
    }
    let c = captura()
    let documento = try Documento.novo(de: c)
    #expect(throws: (any Error).self) {
        _ = try Rascunho.gravar(c, documento: documento, em: pasta, nome: "N")
    }
}

@Test func escalaInvalidaNaoCriaNada() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let c = captura(escala: 0)
    let documento = Documento.novo(tamanhoBase: CGSize(width: 40, height: 30), escala: 0)
    #expect(throws: (any Error).self) {
        _ = try Rascunho.gravar(c, documento: documento, em: pasta, nome: "N")
    }
    #expect(try itens(pasta).isEmpty)
}

@Test func escalaInvalidaNaoCriaPastaInexistente() throws {
    let raiz = try novaPastaTemporaria()
    defer { remover(raiz) }
    let pasta = raiz.appendingPathComponent("nova", isDirectory: true)
    let documento = Documento.novo(tamanhoBase: CGSize(width: 40, height: 30), escala: 0)
    #expect(throws: (any Error).self) {
        _ = try Rascunho.gravar(captura(escala: 0), documento: documento, em: pasta, nome: "N")
    }
    #expect(!FileManager.default.fileExists(atPath: pasta.path))
}

@Test func gravarSemSubstituirNaoToscaPacoteExistente() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let c = captura()
    let documento = try Documento.novo(de: c)
    let destino = pasta.appendingPathComponent("N.capta", isDirectory: true)
    let base = Data([1, 2, 3])
    let miniatura = Data([4, 5])
    try PacoteCapta.gravar(documento, baseDados: base, miniaturaDados: miniatura, em: destino)

    #expect(throws: ErroPacote.destinoJaExiste) {
        try PacoteCapta.gravar(
            documento,
            baseDados: Data([9, 9]),
            miniaturaDados: Data([8]),
            em: destino,
            substituir: false
        )
    }
    let lido = try PacoteCapta.ler(de: destino)
    #expect(lido.baseDados == base)
    #expect(lido.miniaturaDados == miniatura)
    #expect(lido.documento == documento)
    #expect(try itens(pasta) == ["N.capta"])
}

@Test func duasGravacoesComOMesmoNomeProduzemPacotesDistintos() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let vermelha = captura()
    let azul = ImagemCapturada(
        imagem: imagemSolida(CGSize(width: 40, height: 30), cor: CorRGBA(r: 0, g: 0, b: 1, a: 1)),
        escala: 2
    )
    let docVermelha = try Documento.novo(de: vermelha)
    let docAzul = try Documento.novo(de: azul)
    let a = try Rascunho.gravar(vermelha, documento: docVermelha, em: pasta, nome: "N")
    let b = try Rascunho.gravar(azul, documento: docAzul, em: pasta, nome: "N")
    #expect(a != b)
    let lidoA = try PacoteCapta.ler(de: a)
    let lidoB = try PacoteCapta.ler(de: b)
    #expect(lidoA.baseDados != lidoB.baseDados)
    #expect(lidoA.baseDados == (try CodificadorPNG.codificar(vermelha.imagem, escala: 2)))
    #expect(lidoB.baseDados == (try CodificadorPNG.codificar(azul.imagem, escala: 2)))
}

/// Escritor falso que lança `destinoJaExiste` nas primeiras `colisoes` chamadas e anota os destinos.
private final class EscritorComColisoes: @unchecked Sendable {
    private let trava = NSLock()
    private var restantes: Int
    private(set) var destinos: [URL] = []

    init(colisoes: Int) { restantes = colisoes }

    func escrever(_ destino: URL) throws {
        trava.lock()
        defer { trava.unlock() }
        destinos.append(destino)
        if restantes > 0 {
            restantes -= 1
            throw ErroPacote.destinoJaExiste
        }
    }
}

@Test func colisaoNoPassoFinalTentaOProximoSufixo() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let escritor = EscritorComColisoes(colisoes: 2)
    let c = captura()

    let url = try Rascunho.gravar(
        c,
        documento: try Documento.novo(de: c),
        em: pasta,
        nome: "Captura",
        tentativas: Rascunho.Tentativas(limite: 10) { _, _, _, destino in
            try escritor.escrever(destino)
        }
    )

    // Duas colisões: tenta "Captura", "Captura 2" e só então grava em "Captura 3".
    #expect(
        escritor.destinos.map(\.lastPathComponent) == [
            "Captura.capta", "Captura 2.capta", "Captura 3.capta",
        ]
    )
    #expect(url.lastPathComponent == "Captura 3.capta")
}

@Test func colisaoSemFimDesisteAposOLimiteDeTentativas() throws {
    let pasta = try novaPastaTemporaria()
    defer { remover(pasta) }
    let escritor = EscritorComColisoes(colisoes: .max)
    let c = captura()

    #expect(throws: ErroPacote.destinoJaExiste) {
        _ = try Rascunho.gravar(
            c,
            documento: try Documento.novo(de: c),
            em: pasta,
            nome: "Captura",
            tentativas: Rascunho.Tentativas(limite: 3) { _, _, _, destino in
                try escritor.escrever(destino)
            }
        )
    }
    #expect(escritor.destinos.count == 3)
}
