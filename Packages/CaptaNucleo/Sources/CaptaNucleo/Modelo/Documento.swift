import CoreGraphics
import Foundation

/// Documento editável: imagem base (só o tamanho) mais a lista de anotações.
///
/// Coordenadas em pixels da imagem base, origem no canto superior esquerdo, Y para baixo.
/// A ordem de ``objetos`` é a ordem das camadas: o último fica por cima.
///
/// Os retângulos das anotações podem estar invertidos (largura ou altura negativa) ou ter
/// tamanho zero; quem consome (renderizador, interface) padroniza com `standardized`.
public struct Documento: Codable, Equatable, Sendable {
    public internal(set) var versaoEsquema: Int
    /// Tamanho da imagem base em pixels.
    public internal(set) var tamanhoBase: CGSize
    public internal(set) var escala: Double
    public internal(set) var recorte: CGRect?
    public internal(set) var objetos: [Anotacao]

    public init(
        versaoEsquema: Int,
        tamanhoBase: CGSize,
        escala: Double,
        recorte: CGRect?,
        objetos: [Anotacao]
    ) {
        self.versaoEsquema = versaoEsquema
        self.tamanhoBase = tamanhoBase
        self.escala = escala
        self.recorte = recorte
        self.objetos = objetos
    }

    /// Documento vazio para uma imagem do tamanho dado.
    public static func novo(tamanhoBase: CGSize, escala: Double) -> Documento {
        Documento(
            versaoEsquema: Esquema.versaoAtual,
            tamanhoBase: tamanhoBase,
            escala: escala,
            recorte: nil,
            objetos: []
        )
    }

    private enum CodingKeys: String, CodingKey {
        case versaoEsquema, tamanhoBase, escala, recorte, objetos
    }

    /// Decodifica e valida; valores inválidos fazem a decodificação lançar ``ErroDocumento``.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        versaoEsquema = try c.decode(Int.self, forKey: .versaoEsquema)
        tamanhoBase = try c.decode(TamanhoJSON.self, forKey: .tamanhoBase).tamanho
        escala = try c.decode(Double.self, forKey: .escala)
        recorte = try c.decodeIfPresent(RetanguloJSON.self, forKey: .recorte)?.retangulo
        objetos = try c.decode([Anotacao].self, forKey: .objetos)
        try validar()
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(versaoEsquema, forKey: .versaoEsquema)
        try c.encode(TamanhoJSON(tamanhoBase), forKey: .tamanhoBase)
        try c.encode(escala, forKey: .escala)
        try c.encodeIfPresent(recorte.map(RetanguloJSON.init), forKey: .recorte)
        try c.encode(objetos, forKey: .objetos)
    }

    /// Confere finitude, faixas e consistência do documento.
    public func validar() throws {
        // Um Documento em memória é sempre da versão atual. As migrações de versões antigas
        // serão escritas junto com a primeira mudança de esquema, antes da decodificação.
        guard versaoEsquema == Esquema.versaoAtual else {
            throw ErroDocumento.valorForaDeFaixa("versaoEsquema")
        }
        try exigirFinitos([tamanhoBase.width, tamanhoBase.height, escala])
        guard tamanhoBase.width > 0, tamanhoBase.height > 0, escala > 0 else {
            throw ErroDocumento.tamanhoInvalido
        }
        if let recorte {
            try exigirFinitos(recorte.numeros)
            let limites = CGRect(origin: .zero, size: tamanhoBase)
            // `width`/`height` e `contains` padronizam o retângulo; o tamanho cru pega o invertido.
            guard recorte.size.width > 0, recorte.size.height > 0, limites.contains(recorte) else {
                throw ErroDocumento.recorteInvalido
            }
        }
        var vistos = Set<UUID>()
        for objeto in objetos {
            guard vistos.insert(objeto.id).inserted else {
                throw ErroDocumento.idDuplicado(objeto.id)
            }
            try objeto.validar()
        }
    }
}

func exigirFinitos(_ valores: [Double]) throws {
    guard valores.allSatisfy(\.isFinite) else { throw ErroDocumento.valorNaoFinito }
}

extension CGRect {
    fileprivate var numeros: [Double] { [origin.x, origin.y, size.width, size.height] }
}

extension CGPoint {
    fileprivate var numeros: [Double] { [x, y] }
}

extension Anotacao {
    /// Confere finitude e faixas da geometria e do estilo.
    func validar() throws {
        try exigirFinitos(geometria.numeros)
        try exigirFinitos([estilo.largura, estilo.opacidade, rotacao])
        let cores = [estilo.cor] + (estilo.preenchimento.map { [$0] } ?? [])
        try exigirFinitos(cores.flatMap { [$0.r, $0.g, $0.b, $0.a] })
        guard estilo.largura >= 0 else { throw ErroDocumento.valorForaDeFaixa("largura") }
        guard (0...1).contains(estilo.opacidade) else {
            throw ErroDocumento.valorForaDeFaixa("opacidade")
        }
        if rotacao != 0 {
            switch geometria {
            case .seta, .linha, .desfoque: throw ErroDocumento.valorForaDeFaixa("rotacao")
            default: break
            }
        }
        if let familia = estilo.familiaFonte,
            familia.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            throw ErroDocumento.valorForaDeFaixa("familiaFonte")
        }
        for cor in cores where !cor.componentes.allSatisfy({ (0...1).contains($0) }) {
            throw ErroDocumento.valorForaDeFaixa("cor")
        }
    }
}

extension CorRGBA {
    fileprivate var componentes: [Double] { [r, g, b, a] }
}

extension Geometria {
    /// Todos os números da geometria, para checagem de finitude.
    fileprivate var numeros: [Double] {
        switch self {
        case .seta(let inicio, let fim), .linha(let inicio, let fim):
            return inicio.numeros + fim.numeros
        case .forma(_, let retangulo), .carimbo(let retangulo, _), .realce(let retangulo):
            return retangulo.numeros
        case .texto(let retangulo, _, let tamanhoFonte, _, _):
            return retangulo.numeros + [tamanhoFonte]
        case .etapa(let centro, let diametro, _):
            return centro.numeros + [diametro]
        case .desfoque(let retangulo, _, let intensidade):
            return retangulo.numeros + [intensidade]
        }
    }
}
