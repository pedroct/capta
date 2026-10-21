import CaptaNucleo
import Foundation
import ScreenCaptureKit
import Testing

@testable import CaptaSistema

@Suite("Mapeamento dos erros do ScreenCaptureKit")
struct MapeadorDeErroDeCapturaTests {
    @Test func usuarioNegouViraSemPermissao() {
        let erro = MapeadorDeErroDeCaptura.mapear(
            dominio: SCStreamErrorDomain,
            codigo: SCStreamError.Code.userDeclined.rawValue
        )
        #expect(erro == .semPermissao)
        #expect(SCStreamError.errorDomain == SCStreamErrorDomain)
    }

    @Test(arguments: [
        (SCStreamErrorDomain, SCStreamError.Code.failedToStart.rawValue),
        (SCStreamErrorDomain, SCStreamError.Code.noDisplayList.rawValue),
        (SCStreamErrorDomain, 0),
        (NSCocoaErrorDomain, SCStreamError.Code.userDeclined.rawValue),
        ("", SCStreamError.Code.userDeclined.rawValue),
    ])
    func outrosErrosViramFalhou(dominio: String, codigo: Int) {
        #expect(MapeadorDeErroDeCaptura.mapear(dominio: dominio, codigo: codigo) == .falhou)
    }

    @Test func erroDoSistemaEMapeadoPeloDominioECodigo() {
        #expect(MapeadorDeErroDeCaptura.mapear(SCStreamError(.userDeclined)) == .semPermissao)
        #expect(MapeadorDeErroDeCaptura.mapear(SCStreamError(.failedToStart)) == .falhou)
        #expect(MapeadorDeErroDeCaptura.mapear(CocoaError(.fileNoSuchFile)) == .falhou)
    }

    @Test(arguments: [ErroCaptura.semPermissao, .telaNaoEncontrada, .falhou])
    func erroDeCapturaPassaSemMudar(erro: ErroCaptura) {
        #expect(MapeadorDeErroDeCaptura.mapear(erro) == erro)
    }
}
