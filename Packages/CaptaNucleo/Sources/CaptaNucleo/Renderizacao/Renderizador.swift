import CoreGraphics
import CoreImage
import Foundation

/// Compõe a imagem final: a base mais as anotações do documento, na ordem das camadas.
///
/// Usa só Foundation, CoreGraphics e CoreText (parte da família CoreGraphics, sem AppKit).
public struct Renderizador: Sendable {
    let provedorDeSimbolos: (any ProvedorDeSimbolos)?

    public init(provedorDeSimbolos: (any ProvedorDeSimbolos)? = nil) {
        self.provedorDeSimbolos = provedorDeSimbolos
    }

    /// Renderiza o documento sobre `base`.
    ///
    /// A saída é sRGB, 8 bits por componente, `premultipliedLast`, com o tamanho em pixels da base.
    /// Se o documento tem recorte, ele é aplicado por último e define o tamanho da saída.
    /// - Throws: ``ErroDocumento/tamanhoInvalido`` se `base` não tiver o `tamanhoBase` do documento;
    ///   o erro de ``Documento/validar()`` se o documento for inválido;
    ///   ``ErroDocumento/recorteInvalido`` se o recorte não cabe na imagem;
    ///   ``ErroRenderizacao`` se o contexto ou a imagem final não puderam ser criados.
    public func renderizar(_ documento: Documento, base: CGImage) throws -> CGImage {
        let contexto = try novoContexto(para: base)
        try compor(documento, base: base, em: contexto, area: nil)
        guard let imagem = contexto.makeImage() else { throw ErroRenderizacao.falhaAoGerarImagem }
        guard let recorte = documento.recorte else { return imagem }
        // Coordenadas do recorte: pixels da base com origem no topo, as mesmas do `cropping(to:)`.
        // Inalcançável por construção: `Documento.validar()` já exige recorte com área dentro da base; mantido como defesa.
        guard let recortada = imagem.cropping(to: recorte.standardized) else {
            throw ErroDocumento.recorteInvalido
        }
        return recortada
    }

    /// Contexto de composição para `base`: sRGB, 8 bits por componente, `premultipliedLast`,
    /// com o tamanho em pixels da base.
    /// - Throws: ``ErroRenderizacao/falhaAoCriarContexto`` se o contexto não pôde ser criado.
    public func novoContexto(para base: CGImage) throws -> CGContext {
        let contexto = try contextoTransparente(CGSize(width: base.width, height: base.height))
        contexto.interpolationQuality = .high
        return contexto
    }

    /// Desenha a base e as anotações do documento em `contexto`, sem aplicar o recorte.
    ///
    /// Com `area == nil`, desenha tudo. Com área (pixels do documento, origem no topo), só os
    /// pixels dentro dela são redesenhados: a área é arredondada para fora, limitada à imagem e
    /// ampliada pelos desfoques (veja ``regiaoDeComposicao(_:documento:imagem:)``); o resto do
    /// contexto fica como estava. Só entram os objetos cujos `limites` tocam a área. Área sem
    /// área ou fora da imagem não desenha nada; área com números não finitos desenha tudo.
    /// - Throws: ``ErroDocumento/tamanhoInvalido`` se `base` não tiver o `tamanhoBase` do documento;
    ///   o erro de ``Documento/validar()`` se o documento for inválido;
    ///   ``ErroRenderizacao/contextoIncompativel`` se o contexto não tiver o tamanho da base.
    public func compor(
        _ documento: Documento,
        base: CGImage,
        em contexto: CGContext,
        area: CGRect?
    ) throws {
        // Compara como Double: `Int(...)` de NaN, infinito ou valor enorme encerraria o processo.
        guard Double(base.width) == documento.tamanhoBase.width,
            Double(base.height) == documento.tamanhoBase.height,
            base.width > 0, base.height > 0
        else { throw ErroDocumento.tamanhoInvalido }
        // Documento montado à mão (NaN, recorte fora da base) lança em vez de renderizar em silêncio.
        try documento.validar()
        guard contexto.width == base.width, contexto.height == base.height else {
            throw ErroRenderizacao.contextoIncompativel
        }

        let imagem = CGRect(x: 0, y: 0, width: base.width, height: base.height)
        let alvo = regiaoDeComposicao(area, documento: documento, imagem: imagem)
        guard !alvo.isNull else { return }
        let parcial = alvo != imagem

        contexto.saveGState()
        defer { contexto.restoreGState() }
        // Do documento (origem no topo) para o contexto (origem embaixo). Limpa antes de desenhar
        // a base: uma base translúcida não pode se misturar ao que já estava ali.
        let alvoNoContexto = CGRect(
            x: alvo.minX,
            y: imagem.height - alvo.maxY,
            width: alvo.width,
            height: alvo.height
        )
        contexto.clip(to: alvoNoContexto)
        contexto.clear(alvoNoContexto)
        contexto.interpolationQuality = .high
        contexto.draw(base, in: imagem)

        // O documento tem origem no topo: inverte o eixo Y uma única vez, aqui.
        contexto.translateBy(x: 0, y: imagem.height)
        contexto.scaleBy(x: 1, y: -1)

        // Criado só se houver desfoque, e uma única vez por composição.
        var ciContexto: CIContext?

        // Fora da área, o objeto não pinta nada que vá ser visto: `limites` contém tudo o que ele pinta.
        for objeto in documento.objetos where !parcial || objeto.limites.intersects(alvo) {
            // O desfoque lê o compósito até aqui, então não vai para um bitmap isolado como os
            // outros objetos. O trecho filtrado é desenhado direto e sempre com alfa total:
            // `Estilo.opacidade` é ignorada, senão um desfoque a 30% deixaria 70% do conteúdo
            // sensível visível.
            if case .desfoque(let regiao, let tipo, let intensidade) = objeto.geometria {
                let ci = ciContexto ?? criarContextoCoreImage()
                ciContexto = ci
                contexto.saveGState()
                aplicarDesfoque(
                    regiao: regiao,
                    tipo: tipo,
                    intensidade: intensidade,
                    contexto: contexto,
                    ciContexto: ci
                )
                contexto.restoreGState()
                continue
            }
            desenharIsolado(objeto, documento: documento, em: contexto, imagem: imagem)
        }
    }

    /// Desenha o objeto num bitmap só dele, do tamanho dos `limites` (arredondados para fora e
    /// limitados à imagem), e compõe esse bitmap no contexto com a opacidade do objeto.
    ///
    /// Faz o papel de uma camada de transparência (preenchimento e traço compõem juntos e só
    /// então recebem a opacidade), com uma diferença que a composição por área exige: a camada
    /// do CoreGraphics tem o tamanho do recorte do contexto, e um caminho cortado pelo recorte
    /// sai rasterizado com diferenças de uma unidade na borda antisserrilhada (visto em traço
    /// tracejado). Aqui o bitmap depende só do objeto, então sai igual compondo por área ou tudo;
    /// o recorte só atua na cópia do bitmap, pixel a pixel.
    private func desenharIsolado(
        _ objeto: Anotacao,
        documento: Documento,
        em contexto: CGContext,
        imagem: CGRect
    ) {
        let caixa = objeto.limites.integral.intersection(imagem)
        guard !caixa.isEmpty, let isolado = try? contextoTransparente(caixa.size) else { return }
        isolado.interpolationQuality = .high
        // Documento (origem no topo) para o bitmap: desloca para a caixa e inverte o Y.
        isolado.translateBy(x: -caixa.minX, y: caixa.maxY)
        isolado.scaleBy(x: 1, y: -1)
        isolado.concatenate(objeto.transformacaoDeRotacao)
        desenhar(objeto, documento: documento, em: isolado)
        guard let bitmap = isolado.makeImage() else { return }

        contexto.saveGState()
        contexto.setAlpha(CGFloat(objeto.estilo.opacidade))
        // O contexto tem o Y invertido: desvira localmente para o bitmap não sair de cabeça para baixo.
        contexto.translateBy(x: caixa.minX, y: caixa.maxY)
        contexto.scaleBy(x: 1, y: -1)
        contexto.draw(bitmap, in: CGRect(origin: .zero, size: caixa.size))
        contexto.restoreGState()
    }

    /// Retângulo a recompor, em pixels inteiros do documento; `.null` se não há o que desenhar.
    ///
    /// Sem área (ou com números não finitos), é a imagem inteira. Com área, é a área arredondada
    /// para fora e limitada à imagem, ampliada por cada desfoque cuja região de leitura (a
    /// região mais a ``margemDeLeitura(tipo:intensidade:)``) a toca: se algo mudou ali, a saída do
    /// desfoque muda, e para redesenhá-la o compósito embaixo dele precisa estar certo em toda a
    /// região de leitura, não só na área. Ampliar pode alcançar outro desfoque, por isso repete
    /// até estabilizar. Desfoque sem efeito (sem área ou intensidade não positiva) não amplia.
    func regiaoDeComposicao(_ area: CGRect?, documento: Documento, imagem: CGRect) -> CGRect {
        guard let area else { return imagem }
        let pedida = area.standardized
        guard pedida.origin.x.isFinite, pedida.origin.y.isFinite, pedida.width.isFinite,
            pedida.height.isFinite
        else { return imagem }
        var alvo = pedida.integral.intersection(imagem)
        guard !alvo.isNull, alvo.width > 0, alvo.height > 0 else { return .null }

        let leituras: [CGRect] = documento.objetos.compactMap { objeto in
            guard case .desfoque(let regiao, let tipo, let intensidade) = objeto.geometria,
                intensidade > 0, let r = retanguloUtil(regiao)
            else { return nil }
            let margem = margemDeLeitura(tipo: tipo, intensidade: intensidade)
            let leitura = r.insetBy(dx: -margem, dy: -margem).integral.intersection(imagem)
            return leitura.isEmpty ? nil : leitura
        }
        var mudou = true
        while mudou {
            mudou = false
            for leitura in leituras where leitura.intersects(alvo) && !alvo.contains(leitura) {
                alvo = alvo.union(leitura)
                mudou = true
            }
        }
        return alvo
    }

    private func desenhar(_ objeto: Anotacao, documento: Documento, em contexto: CGContext) {
        let estilo = objeto.estilo
        switch objeto.geometria {
        case .forma(let tipo, let retangulo):
            desenharForma(tipo, retangulo, estilo: estilo, em: contexto)
        case .linha(let inicio, let fim):
            desenharLinha(de: inicio, ate: fim, estilo: estilo, em: contexto)
        case .seta(let inicio, let fim):
            desenharSeta(de: inicio, ate: fim, estilo: estilo, em: contexto)
        case .realce(let retangulo):
            desenharRealce(retangulo, estilo: estilo, em: contexto)
        case .etapa(let centro, let diametro, _):
            desenharEtapa(
                centro: centro,
                diametro: diametro,
                numero: documento.numeroDaEtapa(objeto.id),
                estilo: estilo,
                em: contexto
            )
        case .texto(let retangulo, let conteudo, let tamanhoFonte, let negrito, let italico):
            desenharTexto(
                conteudo,
                em: retangulo,
                fonte: EstiloDeTexto(
                    tamanho: tamanhoFonte,
                    negrito: negrito,
                    italico: italico,
                    cor: estilo.cor
                ),
                contexto: contexto
            )
        case .carimbo(let retangulo, let simbolo):
            desenharCarimbo(simbolo: simbolo, em: retangulo, cor: estilo.cor, contexto: contexto)
        case .desfoque: break  // Tratado em `renderizar`, fora da camada de transparência.
        }
    }
}

extension Anotacao {
    /// Rotação do objeto no sistema do documento: em torno do centro do retângulo (etapa: do
    /// `centro`), matriz de rotação padrão com Y para baixo, então ângulo positivo gira no
    /// sentido horário na tela. Mesma convenção de ``limites``, do acerto e das alças.
    var transformacaoDeRotacao: CGAffineTransform {
        guard rotacao != 0 else { return .identity }
        let centro: CGPoint
        switch geometria {
        case .forma(_, let r), .texto(let r, _, _, _, _), .carimbo(let r, _), .realce(let r),
            .desfoque(let r, _, _):
            let r = r.standardized
            centro = CGPoint(x: r.midX, y: r.midY)
        case .etapa(let c, _, _):
            centro = c
        case .seta, .linha:
            // `Documento.validar()` recusa rotação em seta, linha e desfoque.
            return .identity
        }
        // No contexto já invertido, `rotated(by:)` leva (x, y) a
        // (x·cos − y·sen, x·sen + y·cos) em coordenadas do documento.
        return CGAffineTransform(translationX: centro.x, y: centro.y)
            .rotated(by: CGFloat(rotacao))
            .translatedBy(x: -centro.x, y: -centro.y)
    }
}
