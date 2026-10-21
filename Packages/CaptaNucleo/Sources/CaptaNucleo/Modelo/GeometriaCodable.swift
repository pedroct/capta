import CoreGraphics

/// `Codable` explícito: o JSON do esquema v1 é `{"tipo": ..., <chaves do tipo>}`.
extension Geometria: Codable {
    private enum Tipo: String, Codable {
        case seta, linha, forma, texto, etapa, carimbo, realce, desfoque
    }

    private enum CodingKeys: String, CodingKey {
        case tipo, inicio, fim, forma, retangulo, conteudo, tamanhoFonte, negrito, italico
        case centro, diametro, reiniciaSequencia, simbolo, tipoDesfoque, intensidade
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func ponto(_ chave: CodingKeys) throws -> CGPoint {
            try c.decode(PontoJSON.self, forKey: chave).ponto
        }
        func retangulo() throws -> CGRect {
            try c.decode(RetanguloJSON.self, forKey: .retangulo).retangulo
        }
        switch try c.decode(Tipo.self, forKey: .tipo) {
        case .seta:
            self = .seta(inicio: try ponto(.inicio), fim: try ponto(.fim))
        case .linha:
            self = .linha(inicio: try ponto(.inicio), fim: try ponto(.fim))
        case .forma:
            self = .forma(try c.decode(TipoForma.self, forKey: .forma), try retangulo())
        case .texto:
            self = .texto(
                try retangulo(),
                conteudo: try c.decode(String.self, forKey: .conteudo),
                tamanhoFonte: try c.decode(Double.self, forKey: .tamanhoFonte),
                negrito: try c.decode(Bool.self, forKey: .negrito),
                italico: try c.decode(Bool.self, forKey: .italico)
            )
        case .etapa:
            self = .etapa(
                centro: try ponto(.centro),
                diametro: try c.decode(Double.self, forKey: .diametro),
                reiniciaSequencia: try c.decode(Bool.self, forKey: .reiniciaSequencia)
            )
        case .carimbo:
            self = .carimbo(try retangulo(), simbolo: try c.decode(String.self, forKey: .simbolo))
        case .realce:
            self = .realce(try retangulo())
        case .desfoque:
            self = .desfoque(
                try retangulo(),
                try c.decode(TipoDesfoque.self, forKey: .tipoDesfoque),
                intensidade: try c.decode(Double.self, forKey: .intensidade)
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .seta(let inicio, let fim):
            try c.encode(Tipo.seta, forKey: .tipo)
            try c.encode(PontoJSON(inicio), forKey: .inicio)
            try c.encode(PontoJSON(fim), forKey: .fim)
        case .linha(let inicio, let fim):
            try c.encode(Tipo.linha, forKey: .tipo)
            try c.encode(PontoJSON(inicio), forKey: .inicio)
            try c.encode(PontoJSON(fim), forKey: .fim)
        case .forma(let forma, let retangulo):
            try c.encode(Tipo.forma, forKey: .tipo)
            try c.encode(forma, forKey: .forma)
            try c.encode(RetanguloJSON(retangulo), forKey: .retangulo)
        case .texto(let retangulo, let conteudo, let tamanhoFonte, let negrito, let italico):
            try c.encode(Tipo.texto, forKey: .tipo)
            try c.encode(RetanguloJSON(retangulo), forKey: .retangulo)
            try c.encode(conteudo, forKey: .conteudo)
            try c.encode(tamanhoFonte, forKey: .tamanhoFonte)
            try c.encode(negrito, forKey: .negrito)
            try c.encode(italico, forKey: .italico)
        case .etapa(let centro, let diametro, let reiniciaSequencia):
            try c.encode(Tipo.etapa, forKey: .tipo)
            try c.encode(PontoJSON(centro), forKey: .centro)
            try c.encode(diametro, forKey: .diametro)
            try c.encode(reiniciaSequencia, forKey: .reiniciaSequencia)
        case .carimbo(let retangulo, let simbolo):
            try c.encode(Tipo.carimbo, forKey: .tipo)
            try c.encode(RetanguloJSON(retangulo), forKey: .retangulo)
            try c.encode(simbolo, forKey: .simbolo)
        case .realce(let retangulo):
            try c.encode(Tipo.realce, forKey: .tipo)
            try c.encode(RetanguloJSON(retangulo), forKey: .retangulo)
        case .desfoque(let retangulo, let tipoDesfoque, let intensidade):
            try c.encode(Tipo.desfoque, forKey: .tipo)
            try c.encode(RetanguloJSON(retangulo), forKey: .retangulo)
            try c.encode(tipoDesfoque, forKey: .tipoDesfoque)
            try c.encode(intensidade, forKey: .intensidade)
        }
    }
}
