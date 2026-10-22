import CoreGraphics
import Foundation

/// O que precisa ser recomposto depois de uma edição.
public enum AreaASerRedesenhada: Equatable, Sendable {
    /// Nada mudou na imagem composta.
    case nada
    /// A imagem inteira (mudou o tamanho da base ou a escala).
    case tudo
    /// Só este retângulo, em pixels do documento. Os desfoques que leem em volta dele são
    /// tratados por `Renderizador.compor`, que amplia a área sozinho.
    case retangulo(CGRect)
}

extension Documento {
    /// Área da imagem composta que muda de `anterior` para este documento.
    ///
    /// `tudo` se mudou `tamanhoBase` ou `escala`; `nada` se os objetos são iguais (mudança só do
    /// recorte também é `nada`: o recorte é aplicado na exibição). Senão, a união dos `limites`
    /// antigos e novos dos objetos que entraram, saíram ou mudaram (geometria, estilo, rotação),
    /// dos que mudaram de posição relativa nas camadas e das etapas cujo rótulo mudou.
    public func areaAlterada(desde anterior: Documento) -> AreaASerRedesenhada {
        guard tamanhoBase == anterior.tamanhoBase, escala == anterior.escala else { return .tudo }
        guard objetos != anterior.objetos else { return .nada }

        let antigos = Dictionary(uniqueKeysWithValues: anterior.objetos.map { ($0.id, $0) })
        let novos = Dictionary(uniqueKeysWithValues: objetos.map { ($0.id, $0) })
        var area: CGRect?
        func incluir(_ objeto: Anotacao) {
            area = area.map { $0.union(objeto.limites) } ?? objeto.limites
        }

        for objeto in anterior.objetos where novos[objeto.id] == nil { incluir(objeto) }
        for objeto in objetos {
            guard let antigo = antigos[objeto.id] else {
                incluir(objeto)
                continue
            }
            if antigo.geometria != objeto.geometria || antigo.estilo != objeto.estilo
                || antigo.rotacao != objeto.rotacao
                || etapaMudouDeRotulo(objeto, antes: anterior)
            {
                incluir(antigo)
                incluir(objeto)
            }
        }

        // Posição relativa: compara só a sequência dos que existem nos dois, para que entrar ou
        // sair um objeto não conte como troca dos outros. Quem muda de índice nessa sequência
        // entra na área; num par que trocou de ordem pelo menos um muda, e a sobreposição dos
        // dois está dentro dos limites de cada um.
        let comunsAntes = anterior.objetos.filter { novos[$0.id] != nil }
        let comunsDepois = objetos.filter { antigos[$0.id] != nil }
        for (antigo, objeto) in zip(comunsAntes, comunsDepois) where antigo.id != objeto.id {
            incluir(antigo)
            incluir(objeto)
        }

        return area.map { .retangulo($0) } ?? .nada
    }

    /// `true` se `objeto` é etapa e o texto exibido dela mudou (renumeração). Só é chamada com
    /// geometria igual nos dois documentos, então a etapa existe nos dois.
    private func etapaMudouDeRotulo(_ objeto: Anotacao, antes anterior: Documento) -> Bool {
        guard case .etapa = objeto.geometria else { return false }
        return rotuloDaEtapa(objeto.id) != anterior.rotuloDaEtapa(objeto.id)
    }
}
