import CaptaNucleo
import CoreGraphics
import Foundation
import Observation

/// Uma captura aberta numa janela: a imagem em memória, o documento e o estado do rascunho.
///
/// Copiar e salvar PNG funcionam desde o primeiro instante; salvar como Capta espera o rascunho.
@MainActor
@Observable
final class CapturaAberta {
    /// Situação do pacote de rascunho, que é gravado em paralelo à abertura da janela.
    enum EstadoRascunho: Equatable {
        case gravando
        case gravado(URL)
        case falhou
    }

    let nome: String
    let documento: Documento
    let base: CGImage
    let escala: Double
    var rascunho: EstadoRascunho

    /// Enquanto o rascunho grava, salvar como Capta fica indisponível.
    var podeSalvarCapta: Bool { rascunho != .gravando }

    private let renderizador: Renderizador
    private let painel: any PainelDeArquivos
    private let areaDeTransferencia: any AreaDeTransferencia

    init(
        nome: String,
        documento: Documento,
        base: CGImage,
        escala: Double,
        rascunho: EstadoRascunho,
        renderizador: Renderizador,
        painel: any PainelDeArquivos,
        areaDeTransferencia: any AreaDeTransferencia
    ) {
        self.nome = nome
        self.documento = documento
        self.base = base
        self.escala = escala
        self.rascunho = rascunho
        self.renderizador = renderizador
        self.painel = painel
        self.areaDeTransferencia = areaDeTransferencia
    }

    /// Põe a imagem renderizada, em PNG, na área de transferência.
    func copiar() -> ResultadoDeAcao {
        do {
            let dados = try Exportador.png(documento, base: base, renderizador: renderizador)
            try areaDeTransferencia.copiarPNG(dados)
            return .concluido
        } catch {
            RegistroDeCaptura.falha("copiar", error)
            return .falhou(.naoFoiPossivelCopiar)
        }
    }

    /// Grava a imagem renderizada, em PNG, no destino escolhido no painel.
    func salvarPNG() async -> ResultadoDeAcao {
        guard let destino = await painel.escolherDestino(nomeSugerido: nome, extensao: "png")
        else { return .cancelado }
        let documento = documento
        let base = imagemEnviavel
        let renderizador = renderizador
        return await salvar("salvarPNG") {
            let dados = try Exportador.png(documento, base: base.imagem, renderizador: renderizador)
            try dados.write(to: destino, options: .atomic)
        }
    }

    /// Exporta uma cópia `.capta`: do rascunho, se já foi gravado; senão, da imagem em memória.
    func salvarCapta() async -> ResultadoDeAcao {
        guard
            let destino = await painel.escolherDestino(
                nomeSugerido: nome,
                extensao: PacoteCapta.extensao
            )
        else { return .cancelado }
        switch rascunho {
        case .gravado(let origem):
            return await salvar("salvarCapta") {
                try PacoteCapta.copiar(de: origem, para: destino)
            }
        case .gravando, .falhou:
            let documento = documento
            let base = imagemEnviavel
            return await salvar("salvarCapta") {
                let baseDados = try CodificadorPNG.codificar(base.imagem, escala: base.escala)
                let miniatura = try Miniatura.gerar(de: base.imagem)
                let miniaturaDados = try CodificadorPNG.codificar(miniatura, escala: 1)
                try PacoteCapta.gravar(
                    documento,
                    baseDados: baseDados,
                    miniaturaDados: miniaturaDados,
                    em: destino
                )
            }
        }
    }

    /// A base empacotada para atravessar para fora da *main actor* (a `CGImage` é imutável).
    private var imagemEnviavel: ImagemCapturada {
        ImagemCapturada(imagem: base, escala: escala)
    }

    /// Roda a gravação fora da *main actor*, para codificar e escrever sem travar a janela.
    private func salvar(
        _ acao: String,
        _ trabalho: @escaping @Sendable () throws -> Void
    ) async -> ResultadoDeAcao {
        do {
            try await Task.detached(priority: .userInitiated, operation: trabalho).value
            return .concluido
        } catch {
            RegistroDeCaptura.falha(acao, error)
            return .falhou(.naoFoiPossivelSalvar)
        }
    }
}
