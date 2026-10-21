import AppKit

/// Enquanto houver janela aberta o Capta aparece no Dock; sem janela, volta a ser só barra de menus.
enum PoliticaDeAtivacao {
    static func para(janelasAbertas: Int) -> NSApplication.ActivationPolicy {
        janelasAbertas == 0 ? .accessory : .regular
    }

    /// Política para as janelas que o app acompanha: as de captura e a de ajuda, se aberta.
    static func para(janelasDeCaptura: Int, ajudaAberta: Bool) -> NSApplication.ActivationPolicy {
        para(janelasAbertas: janelasDeCaptura + (ajudaAberta ? 1 : 0))
    }
}
