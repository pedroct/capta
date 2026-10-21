import Foundation
import Testing

@testable import CaptaSistema

@Suite("Atalhos para as Configurações do Sistema")
struct ConfiguracoesDoSistemaTests {
    @Test func urlAbreOPainelDeGravacaoDeTela() {
        let url = ConfiguracoesDoSistema.urlGravacaoDeTela
        #expect(url.scheme == "x-apple.systempreferences")
        #expect(url.absoluteString.hasSuffix("com.apple.preference.security?Privacy_ScreenCapture"))
        #expect(url.query == "Privacy_ScreenCapture")
    }
}
