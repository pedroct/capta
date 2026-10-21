import CoreGraphics
import Foundation

/// Posição desejada de um objeto na ordem das camadas.
public enum Ordem: Equatable, Sendable {
    case paraFrente
    case paraTras
    case umNivelAcima
    case umNivelAbaixo
}

/// Uma operação de edição sobre um ``Documento``.
public enum Edicao: Sendable {
    case adicionar(Anotacao)
    case remover(Set<UUID>)
    /// Troca a anotação de mesmo `id`, mantendo a posição nas camadas e a ordem de criação.
    case substituir(Anotacao)
    case mover(Set<UUID>, deslocamento: CGVector)
    case reordenar(UUID, Ordem)
    case definirRecorte(CGRect?)
    /// Só vale para anotações `.etapa`; para qualquer outra lança `valorForaDeFaixa("etapa")`.
    case definirReinicioDeEtapa(UUID, Bool)
}

extension Documento {
    /// Aplica a edição neste documento (já copiado pelo chamador); a validação fica com quem chama.
    mutating func aplicarSemValidar(_ edicao: Edicao) throws {
        switch edicao {
        case .adicionar(let anotacao):
            var nova = anotacao
            nova.ordem = proximaOrdem
            proximaOrdem += 1
            objetos.append(nova)
        case .remover(let ids):
            try exigirExistentes(ids)
            objetos.removeAll { ids.contains($0.id) }
        case .substituir(let anotacao):
            let posicao = try indice(de: anotacao.id)
            var nova = anotacao
            nova.ordem = objetos[posicao].ordem
            objetos[posicao] = nova
        case .mover(let ids, let deslocamento):
            try exigirExistentes(ids)
            for posicao in objetos.indices where ids.contains(objetos[posicao].id) {
                objetos[posicao].geometria = objetos[posicao].geometria.deslocada(por: deslocamento)
            }
        case .reordenar(let id, let ordem):
            reordenar(try indice(de: id), ordem)
        case .definirRecorte(let recorte):
            self.recorte = recorte
        case .definirReinicioDeEtapa(let id, let reinicia):
            let posicao = try indice(de: id)
            guard case .etapa(let centro, let diametro, _) = objetos[posicao].geometria else {
                throw ErroDocumento.valorForaDeFaixa("etapa")
            }
            objetos[posicao].geometria = .etapa(
                centro: centro,
                diametro: diametro,
                reiniciaSequencia: reinicia
            )
        }
    }

    private func indice(de id: UUID) throws -> Int {
        guard let posicao = objetos.firstIndex(where: { $0.id == id }) else {
            throw ErroDocumento.objetoInexistente(id)
        }
        return posicao
    }

    private func exigirExistentes(_ ids: Set<UUID>) throws {
        let existentes = Set(objetos.map(\.id))
        // Ordena para o erro ser determinístico quando mais de um id não existe.
        if let faltante = ids.subtracting(existentes).sorted(by: { $0.uuidString < $1.uuidString })
            .first
        {
            throw ErroDocumento.objetoInexistente(faltante)
        }
    }

    private mutating func reordenar(_ posicao: Int, _ ordem: Ordem) {
        let destino: Int
        switch ordem {
        case .paraFrente: destino = objetos.count - 1
        case .paraTras: destino = 0
        case .umNivelAcima: destino = min(posicao + 1, objetos.count - 1)
        case .umNivelAbaixo: destino = max(posicao - 1, 0)
        }
        guard destino != posicao else { return }
        objetos.insert(objetos.remove(at: posicao), at: destino)
    }
}

extension Geometria {
    fileprivate func deslocada(por d: CGVector) -> Geometria {
        func ponto(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + d.dx, y: p.y + d.dy) }
        func retangulo(_ r: CGRect) -> CGRect { r.offsetBy(dx: d.dx, dy: d.dy) }
        switch self {
        case .seta(let inicio, let fim): return .seta(inicio: ponto(inicio), fim: ponto(fim))
        case .linha(let inicio, let fim): return .linha(inicio: ponto(inicio), fim: ponto(fim))
        case .forma(let tipo, let r): return .forma(tipo, retangulo(r))
        case .texto(let r, let conteudo, let tamanho, let negrito, let italico):
            return .texto(
                retangulo(r),
                conteudo: conteudo,
                tamanhoFonte: tamanho,
                negrito: negrito,
                italico: italico
            )
        case .etapa(let centro, let diametro, let reinicia):
            return .etapa(centro: ponto(centro), diametro: diametro, reiniciaSequencia: reinicia)
        case .carimbo(let r, let simbolo): return .carimbo(retangulo(r), simbolo: simbolo)
        case .realce(let r): return .realce(retangulo(r))
        case .desfoque(let r, let tipo, let intensidade):
            return .desfoque(retangulo(r), tipo, intensidade: intensidade)
        }
    }
}
