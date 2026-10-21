import CaptaNucleo
import Carbon.HIToolbox
import Foundation

/// Atalho global pelo Carbon (`RegisterEventHotKey`), que não exige permissão de Acessibilidade.
///
/// Casca fina, fora do portão de cobertura: só chama a API do sistema.
///
/// `@unchecked Sendable`: o estado mutável (referência do atalho, do handler e a ação) só é lido ou
/// escrito com `trava` tomada, e o handler do Carbon só toca a ação por `executar()`, que também a toma.
public final class AtalhoGlobalCarbon: AtalhoGlobal, @unchecked Sendable {
    /// Contador de ids de atalho, para cada instância reconhecer só o próprio disparo.
    private nonisolated(unsafe) static var proximoId: UInt32 = 0
    private static let travaDosIds = NSLock()

    private static func novoId() -> UInt32 {
        travaDosIds.lock()
        defer { travaDosIds.unlock() }
        proximoId += 1
        return proximoId
    }

    private let trava = NSLock()
    private let id = AtalhoGlobalCarbon.novoId()
    private var atalho: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var acao: (@Sendable () -> Void)?

    public init() {}

    deinit {
        if let atalho { UnregisterEventHotKey(atalho) }
        if let handler { RemoveEventHandler(handler) }
    }

    public func registrar(
        _ combinacao: CombinacaoDeTeclas,
        acao: @escaping @Sendable () -> Void
    ) throws {
        trava.lock()
        defer { trava.unlock() }
        if let atalho { UnregisterEventHotKey(atalho); self.atalho = nil }

        if handler == nil {
            var tipo = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            var novoHandler: EventHandlerRef?
            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                { _, evento, dados in
                    guard let evento, let dados else { return OSStatus(eventNotHandledErr) }
                    var disparado = EventHotKeyID()
                    let leitura = GetEventParameter(
                        evento,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &disparado
                    )
                    guard leitura == noErr else { return OSStatus(eventNotHandledErr) }
                    let instancia = Unmanaged<AtalhoGlobalCarbon>.fromOpaque(dados)
                        .takeUnretainedValue()
                    guard disparado.id == instancia.id else { return OSStatus(eventNotHandledErr) }
                    instancia.executar()
                    return noErr
                },
                1,
                &tipo,
                Unmanaged.passUnretained(self).toOpaque(),
                &novoHandler
            )
            guard status == noErr else { throw ErroAtalho.falhou }
            handler = novoHandler
        }

        var novoAtalho: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4341_5054), id: id)  // 'CAPT'
        let status = RegisterEventHotKey(
            combinacao.codigoDaTecla,
            combinacao.modificadores.mascaraCarbon,
            id,
            GetApplicationEventTarget(),
            0,
            &novoAtalho
        )
        guard status == noErr else {
            throw status == OSStatus(eventHotKeyExistsErr) ? ErroAtalho.conflito : ErroAtalho.falhou
        }
        atalho = novoAtalho
        self.acao = acao
    }

    fileprivate func executar() {
        trava.lock()
        let corrente = acao
        trava.unlock()
        corrente?()
    }
}
