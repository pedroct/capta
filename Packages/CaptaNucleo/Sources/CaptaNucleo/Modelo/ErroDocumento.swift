import Foundation

/// Falhas de validação de um ``Documento``.
public enum ErroDocumento: Error, Equatable, Sendable {
    /// Algum número é `NaN` ou infinito.
    case valorNaoFinito
    /// Um valor finito fora da faixa permitida; carrega o nome do campo.
    case valorForaDeFaixa(String)
    /// `tamanhoBase` ou `escala` não positivos.
    case tamanhoInvalido
    /// Recorte vazio ou fora dos limites da imagem base.
    case recorteInvalido
    /// Referência a uma anotação que não existe no documento.
    case objetoInexistente(UUID)
}
