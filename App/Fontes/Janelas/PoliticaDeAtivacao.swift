import AppKit

/// Enquanto houver janela aberta o Capta aparece no Dock; sem janela, volta a ser só barra de menus.
enum PoliticaDeAtivacao {
    static func para(janelasAbertas: Int) -> NSApplication.ActivationPolicy {
        janelasAbertas == 0 ? .accessory : .regular
    }
}
