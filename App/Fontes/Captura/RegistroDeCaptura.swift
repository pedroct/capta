import CaptaNucleo
import Foundation
import os

/// Registro local do fluxo de captura: só o tipo do erro e a duração, nunca conteúdo ou caminho.
enum RegistroDeCaptura {
    private static let registro = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedroct.capta",
        category: "captura"
    )

    static func falha(_ acao: String, _ erro: any Error) {
        registro.error("\(acao, privacy: .public) falhou: \(tipo(de: erro), privacy: .public)")
    }

    /// Tela inteira: do disparo até a janela da captura abrir.
    static func janelaAberta(apos duracao: Duration) {
        registro.notice("do disparo à janela: \(milissegundos(duracao), privacy: .public) ms")
    }

    /// Captura livre: do disparo até o pedido ao overlay, que abre na hora, no começo de
    /// `SeletorDeCaptura.escolher` (permissão, congelar e listar incluídos).
    static func overlayAberto(apos duracao: Duration) {
        registro.notice("do disparo ao overlay: \(milissegundos(duracao), privacy: .public) ms")
    }

    /// Captura livre: da seleção (ou do fim da contagem) até a janela da captura abrir.
    static func janelaAberta(aposSelecao duracao: Duration) {
        registro.notice("da seleção à janela: \(milissegundos(duracao), privacy: .public) ms")
    }

    /// `ErroCaptura` não carrega dados, então o caso vai junto; dos outros, só o tipo, porque
    /// a descrição pode trazer nome de arquivo ou caminho.
    static func tipo(de erro: any Error) -> String {
        if let erro = erro as? ErroCaptura { return "ErroCaptura.\(erro)" }
        return String(reflecting: type(of: erro))
    }

    private static func milissegundos(_ duracao: Duration) -> Int64 {
        let (segundos, attossegundos) = duracao.components
        return segundos * 1000 + attossegundos / 1_000_000_000_000_000
    }
}
