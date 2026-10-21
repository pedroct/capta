/// Versão do esquema de dados persistido pelo Capta.
public enum Esquema {
    /// Versão atual do esquema, incrementada a cada mudança incompatível.
    ///
    /// Depois do primeiro `.capta` real gravado pelo app, a v1 está congelada; mudança
    /// incompatível sobe `Esquema.versaoAtual` e traz migração com teste. O formato está em
    /// `docs/esquema-capta-v1.md` e o teste `EsquemaV1CongeladoTests` trava o JSON.
    public static let versaoAtual: Int = 1
}
