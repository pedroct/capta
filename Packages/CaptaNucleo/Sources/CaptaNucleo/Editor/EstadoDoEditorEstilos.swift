import CoreGraphics
import Foundation

/// Estilo exibido na barra de propriedades e alterações vindas dela.
extension EstadoDoEditor {
    /// Um selecionado: o estilo dele; vários: o do primeiro na ordem das camadas; nenhum com
    /// ferramenta de criação: o lembrado da ferramenta; nenhum com Seleção: `nil` (o painel
    /// mostra a dica).
    public func estiloExibido(em documento: Documento) -> Estilo? {
        if let primeiro = documento.objetos.first(where: { selecao.contains($0.id) }) {
            return primeiro.estilo
        }
        return ferramenta == .selecao ? nil : memoria[ferramenta]
    }

    /// Com seleção: muda só aquele campo em cada selecionado (um passo no histórico) e na
    /// memória de cada tipo selecionado. Sem seleção: muda só a memória da ferramenta ativa.
    mutating func alterarEstilo(_ alteracao: AlteracaoDeEstilo, em documento: Documento)
        -> AcaoDoEditor?
    {
        let alvos = documento.objetos.filter { selecao.contains($0.id) }
        guard !alvos.isEmpty else {
            if ferramenta != .selecao {
                memoria[ferramenta] = memoria[ferramenta].alterado(
                    alteracao,
                    doRealce: ferramenta == .realce
                )
            }
            return nil
        }
        var edicoes: [Edicao] = []
        for var alvo in alvos {
            let realce = MemoriaDeEstilos.ferramenta(de: alvo.geometria) == .realce
            alvo.estilo = alvo.estilo.alterado(alteracao, doRealce: realce)
            edicoes.append(.substituir(alvo))
            if let tipo = MemoriaDeEstilos.ferramenta(de: alvo.geometria) {
                memoria[tipo] = memoria[tipo].alterado(alteracao, doRealce: realce)
            }
        }
        return .aplicar(.lote(edicoes))
    }
}

extension Estilo {
    /// Aplica a alteração a um campo só. Opacidade fica em 0…1 e largura em ≥ 0 (limitadas, sem
    /// lançar). No realce, a cor mantém o alfa do token para continuar translúcida.
    func alterado(_ alteracao: AlteracaoDeEstilo, doRealce: Bool) -> Estilo {
        var novo = self
        switch alteracao {
        case .cor(let cor):
            novo.cor = cor
            if doRealce { novo.cor.a = CorRGBA.realce.a }
        case .largura(let largura): novo.largura = max(0, largura)
        case .opacidade(let opacidade): novo.opacidade = min(max(0, opacidade), 1)
        case .tracejado(let ligado): novo.tracejado = ligado
        case .preenchimento(let cor): novo.preenchimento = cor
        }
        return novo
    }
}
