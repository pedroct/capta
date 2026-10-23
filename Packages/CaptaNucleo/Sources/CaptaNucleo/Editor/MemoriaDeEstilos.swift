/// Último estilo usado em cada ferramenta de desenho. Aqui só o tipo e os padrões; a Tarefa 7
/// acrescenta o acesso por ferramenta e a persistência.
public struct MemoriaDeEstilos: Equatable, Sendable {
    public var seta: Estilo
    public var linha: Estilo
    public var forma: Estilo
    public var realce: Estilo

    public init(
        seta: Estilo = Estilo(),
        linha: Estilo = Estilo(),
        forma: Estilo = Estilo(),
        realce: Estilo = Estilo(cor: .realce, largura: 0)
    ) {
        self.seta = seta
        self.linha = linha
        self.forma = forma
        self.realce = realce
    }
}
