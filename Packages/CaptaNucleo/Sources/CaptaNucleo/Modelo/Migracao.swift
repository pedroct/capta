/// Migrações do esquema persistido, da versão lida no disco até ``Esquema/versaoAtual``.
///
/// Cada mudança incompatível do esquema acrescenta aqui o seu degrau, com teste.
enum Migracao {
    /// Leva o documento de `versao` até a versão atual.
    ///
    /// Roda antes de `Documento.validar()`, que só aceita a versão atual.
    ///
    /// Degraus:
    /// - v1 → v2: nenhum campo muda; só a versão.
    static func migrar(_ documento: inout Documento, desde versao: Int) {
        documento.versaoEsquema = Esquema.versaoAtual
    }
}
