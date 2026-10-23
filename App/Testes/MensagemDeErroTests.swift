import Testing

@testable import Capta

@Suite("Textos das mensagens de erro")
struct MensagemDeErroTests {
    @Test(arguments: [
        (MensagemDeErro.capturaFalhou, "Não foi possível capturar a tela."),
        (.naoFoiPossivelCopiar, "Não foi possível copiar a imagem."),
        (.naoFoiPossivelSalvar, "Não foi possível salvar o arquivo."),
        (.naoFoiPossivelAbrir, "Não foi possível abrir a captura."),
        (
            .rascunhoNaoGuardado,
            "A captura não foi guardada. Copiar e salvar continuam funcionando."
        ),
    ])
    func cadaMensagemTemOTextoDoCatalogo(mensagem: MensagemDeErro, texto: String) {
        #expect(mensagem.texto == texto)
    }
}
