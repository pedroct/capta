/// Falhas ao gravar, atualizar ou ler um pacote `.capta`.
public enum ErroPacote: Error, Equatable, Sendable {
    /// Falta uma parte obrigatória do pacote; carrega o nome do item (ou da pasta, se ela não existe).
    case arquivoAusente(String)
    /// `documento.json` truncado, malformado ou sem `versaoEsquema`.
    case jsonInvalido
    /// O arquivo foi gravado por uma versão mais nova do Capta; carrega a versão encontrada.
    case versaoMaisNova(Int)
    /// Dados de imagem vazios (na gravação ou em `base.png` lido do disco).
    case dadosVazios
    /// Gravação sem substituição e já existe algo no destino; o destino ficou intacto.
    case destinoJaExiste
}
