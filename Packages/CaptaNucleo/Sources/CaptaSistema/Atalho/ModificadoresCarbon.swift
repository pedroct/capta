import CaptaNucleo
import Carbon.HIToolbox

extension Modificadores {
    /// Máscara de modificadores no formato do Carbon (`RegisterEventHotKey`).
    var mascaraCarbon: UInt32 {
        var mascara: UInt32 = 0
        if contains(.controle) { mascara |= UInt32(controlKey) }
        if contains(.opcao) { mascara |= UInt32(optionKey) }
        if contains(.comando) { mascara |= UInt32(cmdKey) }
        if contains(.shift) { mascara |= UInt32(shiftKey) }
        return mascara
    }
}
