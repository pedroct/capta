import SwiftUI

/// Ajuda para conceder a permissão de Gravação de Tela.
struct JanelaDeAjudaView: View {
    let modelo: AjudaDePermissaoModelo
    let abrirConfiguracoes: @MainActor () -> Void
    let tentarDeNovo: @MainActor () -> Void
    let reiniciar: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espaco.e4) {
            Text("Permissão de Gravação de Tela")
                .font(.headline)
                .foregroundStyle(Tema.texto)
                .accessibilityAddTraits(.isHeader)
            Text(
                "Para capturar a tela, o Capta precisa da permissão de Gravação de Tela. Nada sai do seu Mac."
            )
            .foregroundStyle(Tema.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Tema.Espaco.e2) {
                Button("Abrir Configurações do Sistema") { abrirConfiguracoes() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel(Text("Abrir Configurações do Sistema"))
                Button("Tentar de novo") { tentarDeNovo() }
                    .accessibilityLabel(Text("Tentar de novo"))
                if modelo.mostraReiniciar {
                    Button("Reiniciar o Capta") { reiniciar() }
                        .accessibilityLabel(Text("Reiniciar o Capta"))
                }
            }
        }
        .padding(Tema.Espaco.e6)
        .frame(width: 520, alignment: .leading)
        .background(Tema.superficieJanela)
    }
}
