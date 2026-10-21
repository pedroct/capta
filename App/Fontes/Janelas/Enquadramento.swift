import CoreGraphics

/// Como a imagem se acomoda na janela de captura.
enum ModoDeExibicao {
    case ajustar
    case tamanhoReal
}

/// Escala de exibição da imagem na área disponível.
enum Enquadramento {
    /// `tamanhoReal` é sempre 1. `ajustar` é o menor entre 1 e a razão que cabe na área: reduz
    /// quando não cabe e nunca amplia. Com lado zero na imagem ou na área, devolve 1.
    /// `imagem` está em pontos (pixels ÷ escala da captura).
    static func escala(imagem: CGSize, area: CGSize, modo: ModoDeExibicao) -> CGFloat {
        guard modo == .ajustar else { return 1 }
        guard imagem.width > 0, imagem.height > 0, area.width > 0, area.height > 0 else {
            return 1
        }
        return min(1, area.width / imagem.width, area.height / imagem.height)
    }
}
