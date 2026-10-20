import AppKit
import SwiftUI

@main
struct CaptaApp: App {
    var body: some Scene {
        MenuBarExtra("Capta", image: "GlifoMenu") {
            Button("Sair do Capta") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
