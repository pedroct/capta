import CaptaNucleo
import Foundation
import Testing

@testable import Capta

/// Data para onde os testes levam os arquivos do pacote, para a comparação de datas valer.
let dataAntigaDosPacotes = Date(timeIntervalSince1970: 1_000)

/// Cópia de arquivo no pacote: nome, bytes e data de modificação.
struct MarcaDeArquivo: Equatable {
    let nome: String
    let dados: Data
    let data: Date
}

struct AberturaDePacote {
    let apresentador: ApresentadorFalso
    let pacote: URL
    let antes: [MarcaDeArquivo]
    let pasta: PastaTemporaria
}

/// Pacotes `.capta` em disco e um fluxo para abri-los, nos testes das capturas recentes.
@MainActor
protocol PacotesRecentesDeTeste {}

extension PacotesRecentesDeTeste {
    func marcas(_ pacote: URL) throws -> [MarcaDeArquivo] {
        try FileManager.default.contentsOfDirectory(atPath: pacote.path).sorted().map { nome in
            let arquivo = pacote.appendingPathComponent(nome)
            let data = try FileManager.default.attributesOfItem(atPath: arquivo.path)[
                .modificationDate
            ]
            return MarcaDeArquivo(
                nome: nome,
                dados: try Data(contentsOf: arquivo),
                data: try #require(data as? Date)
            )
        }
    }

    /// Grava um pacote de 8 x 6 pixels, escala 2, e põe as datas no passado.
    func pacote(nome: String = "Captura antiga", em pasta: URL) throws -> URL {
        let imagem = ImagemCapturada(imagem: try imagemDeTeste(), escala: 2)
        let url = try Rascunho.gravar(
            imagem,
            documento: try Documento.novo(de: imagem),
            em: pasta,
            nome: nome
        )
        try fixarDatas(url)
        return url
    }

    func fixarDatas(_ pacote: URL) throws {
        for nome in try FileManager.default.contentsOfDirectory(atPath: pacote.path) {
            try FileManager.default.setAttributes(
                [.modificationDate: dataAntigaDosPacotes],
                ofItemAtPath: pacote.appendingPathComponent(nome).path
            )
        }
    }

    func reescrever(_ pacote: URL, documento transformar: (String) -> String) throws {
        let json = pacote.appendingPathComponent("documento.json")
        let texto = try String(contentsOf: json, encoding: .utf8)
        try Data(transformar(texto).utf8).write(to: json)
        try fixarDatas(pacote)
    }

    func fluxo(
        apresentador: ApresentadorFalso,
        defaults: UserDefaults,
        pasta: URL,
        aoMudarRecentes: @escaping @MainActor () -> Void = {}
    ) -> FluxoDeCaptura {
        FluxoDeCaptura(
            capturador: CapturadorFalso(.failure(.falhou)),
            permissao: PermissaoFalsa(concedida: true),
            apresentador: apresentador,
            seletor: SeletorFalso(),
            contagem: ContagemFalsa(),
            opcoes: OpcoesLembradas(defaults: defaults),
            pastaDeRascunhos: pasta,
            agora: { Date(timeIntervalSince1970: 1_800_000_000) },
            defaults: defaults,
            painel: PainelFalso(destino: nil),
            areaDeTransferencia: AreaDeTransferenciaFalsa(),
            aoMudarRecentes: aoMudarRecentes
        )
    }

    func abrirComPacote(_ preparar: (URL) throws -> URL) async throws -> AberturaDePacote {
        let pasta = try PastaTemporaria()
        let url = try preparar(pasta.url)
        let antes = try marcas(url)
        let defaults = try DefaultsTemporarios()
        defer { defaults.remover() }
        let apresentador = ApresentadorFalso()
        let fluxo = fluxo(apresentador: apresentador, defaults: defaults.defaults, pasta: pasta.url)
        await fluxo.abrirRecente(url)
        return AberturaDePacote(apresentador: apresentador, pacote: url, antes: antes, pasta: pasta)
    }
}

/// Quantas vezes o fluxo avisou que a lista de recentes mudou.
@MainActor
final class Contador {
    var vezes = 0
}
