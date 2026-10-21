import Foundation

/// Grava capturas como pacotes `.capta` na pasta de rascunhos.
public enum Rascunho {
    /// `"Captura AAAA-MM-DD às HH.mm.ss"`, sem `DateFormatter` para não depender da localidade.
    public static func nome(para data: Date, fuso: TimeZone = .current) -> String {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = fuso
        let campos: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let c = calendario.dateComponents(campos, from: data)
        func dois(_ valor: Int?) -> String { String(format: "%02d", valor ?? 0) }
        let ano = String(format: "%04d", c.year ?? 0)
        return "Captura \(ano)-\(dois(c.month))-\(dois(c.day)) às "
            + "\(dois(c.hour)).\(dois(c.minute)).\(dois(c.second))"
    }

    /// Grava `captura` e `documento` em `<nome>.capta` (ou `<nome> 2.capta`, `<nome> 3.capta`…
    /// se já existir) dentro de `pasta`, que é criada se faltar. Devolve a URL do pacote.
    ///
    /// Valida o documento e codifica PNG e miniatura antes de tocar o disco.
    public static func gravar(
        _ captura: ImagemCapturada,
        documento: Documento,
        em pasta: URL,
        nome: String
    ) throws -> URL {
        try documento.validar()
        let baseDados = try CodificadorPNG.codificar(captura.imagem, escala: captura.escala)
        let miniatura = try Miniatura.gerar(de: captura.imagem)
        let miniaturaDados = try CodificadorPNG.codificar(miniatura, escala: 1)

        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        let destino = urlLivre(em: pasta, nome: nome)
        try PacoteCapta.gravar(
            documento,
            baseDados: baseDados,
            miniaturaDados: miniaturaDados,
            em: destino
        )
        return destino
    }

    private static func urlLivre(em pasta: URL, nome: String) -> URL {
        let extensao = PacoteCapta.extensao
        var candidato = pasta.appendingPathComponent("\(nome).\(extensao)", isDirectory: true)
        var numero = 2
        while FileManager.default.fileExists(atPath: candidato.path) {
            candidato = pasta.appendingPathComponent(
                "\(nome) \(numero).\(extensao)",
                isDirectory: true
            )
            numero += 1
        }
        return candidato
    }
}
