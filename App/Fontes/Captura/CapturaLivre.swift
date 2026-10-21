import CaptaNucleo
import CoreGraphics

/// Os passos da captura livre que não guardam estado: congelar e listar, esperar o overlay e
/// capturar o que foi escolhido (spec §4.1, §4.2 e §4.4). O ``FluxoDeCaptura`` cuida do resto:
/// disparo, permissão, contagem, erros e janela.
@MainActor
struct CapturaLivre {
    /// Lado mínimo, em pontos, de uma janela que o modo janela oferece (spec §4.2).
    static let tamanhoMinimoDeJanela: CGFloat = 40

    /// O que a captura precisa do overlay. As imagens congeladas morrem com a escolha; só fica a
    /// da tela da região, e só quando é ela que vai virar o documento (sem atraso).
    struct Escolha {
        let selecao: SelecaoConfirmada
        let opcoes: OpcoesDeCaptura
        /// Onde a contagem aparece: a tela da região ou a da janela.
        let telaDaContagem: DescricaoDeTela
        let congelada: CGImage?
    }

    let capturador: any Capturador
    let seletor: any SeletorDeCaptura
    let opcoes: OpcoesLembradas

    /// Congela, lista as janelas e espera o overlay, com as opções e a ajuda lembradas. Grava as
    /// opções confirmadas. `nil` quando o overlay é cancelado.
    /// - Parameter aoAbrir: roda logo antes de pedir o overlay (o registro de duração).
    func escolher(modo: ModoDoOverlay, aoAbrir: () -> Void) async throws -> Escolha? {
        let telas = try await capturador.congelarTelas()
        let descricoes = telas.map(\.descricao)
        guard let principal = descricoes.first(where: \.principal) ?? descricoes.first else {
            throw ErroCaptura.telaNaoEncontrada
        }
        // Sem a lista, o overlay abre só no modo região, sem erro (spec §4.2).
        let todas = (try? await capturador.listarJanelas()) ?? []
        let janelas = ListaDeJanelas.selecionaveis(todas, tamanhoMinimo: Self.tamanhoMinimoDeJanela)
        aoAbrir()
        let resultado = await seletor.escolher(
            telas: telas,
            janelas: janelas,
            modo: janelas.isEmpty ? .regiao : modo,
            opcoes: opcoes.opcoes,
            ajudaVisivel: opcoes.ajudaVisivel
        )
        guard case .confirmado(let selecao, let escolhidas) = resultado else { return nil }
        opcoes.opcoes = escolhidas
        switch selecao {
        case .regiao(let tela, _):
            let congelada =
                escolhidas.atraso == .nenhum
                ? telas.first { $0.descricao == tela }?.imagem : nil
            return Escolha(
                selecao: selecao,
                opcoes: escolhidas,
                telaDaContagem: tela,
                congelada: congelada
            )
        case .janela(let id):
            let tela = janelas.first { $0.id == id }
                .flatMap { ListaDeJanelas.tela(de: $0, entre: descricoes) }
            return Escolha(
                selecao: selecao,
                opcoes: escolhidas,
                telaDaContagem: tela ?? principal,
                congelada: nil
            )
        }
    }

    /// Região: recorte da imagem congelada, com a escala da tela. Janela: a própria janela, sem
    /// cursor (a congelada nasce sem ele, e sem atraso o controle fica desabilitado).
    func capturarSemAtraso(_ escolha: Escolha) async throws -> ImagemCapturada {
        switch escolha.selecao {
        case .regiao(let tela, let pixels):
            guard let congelada = escolha.congelada else { throw ErroCaptura.telaNaoEncontrada }
            guard let recorte = RecorteDeImagem.recortar(congelada, pixels: pixels) else {
                throw ErroCaptura.falhou
            }
            return ImagemCapturada(imagem: recorte, escala: tela.escala)
        case .janela(let id):
            return try await capturador.capturarJanela(id: id, incluirCursor: false)
        }
    }

    /// Captura de novo, ao vivo, a mesma região ou a mesma janela. A região tem de voltar com
    /// exatamente os pixels da seleção (spec §4.9).
    func capturarAoVivo(
        _ selecao: SelecaoConfirmada,
        incluirCursor: Bool
    ) async throws -> ImagemCapturada {
        switch selecao {
        case .regiao(let tela, let pixels):
            guard let largura = Int(exactly: pixels.width), let altura = Int(exactly: pixels.height)
            else { throw ErroCaptura.tamanhoInesperado }
            return try await capturador.capturarRegiao(
                em: tela,
                pixels: pixels,
                incluirCursor: incluirCursor
            ).conferindo(largura: largura, altura: altura)
        case .janela(let id):
            return try await capturador.capturarJanela(id: id, incluirCursor: incluirCursor)
        }
    }
}
