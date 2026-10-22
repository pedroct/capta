/// Versão do esquema de dados persistido pelo Capta.
public enum Esquema {
    /// Versão atual do esquema, incrementada a cada mudança incompatível.
    ///
    /// A v1 está congelada (`docs/esquema-capta-v1.md`) e só é lida, com migração. A v2 está em
    /// `docs/esquema-capta-v2.md` e muda no lugar até o fim do Plano 5c, quando congela.
    public static let versaoAtual: Int = 2

    /// Menor versão que o app ainda sabe ler; as anteriores à atual passam por ``Migracao``.
    public static let versaoMinimaLegivel: Int = 1
}
