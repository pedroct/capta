import CaptaNucleo
import CaptaSistema
import SwiftUI

/// Janela de uma captura: a imagem renderizada, a alternância de exibição e a barra de ações.
struct JanelaDeCapturaView: View {
    let captura: CapturaAberta
    let mostrarAlerta: @MainActor (MensagemDeErro) -> Void

    @State private var modo: ModoDeExibicao = .ajustar
    @State private var imagem: CGImage?
    @State private var confirmacao: String?
    @Environment(\.accessibilityReduceTransparency) private var reduzirTransparencia

    var body: some View {
        VStack(spacing: 0) {
            barra
            area
        }
        .background(Tema.superficieCanvas)
        .task { renderizarUmaVez() }
        .onChange(of: captura.aviso) { _, aviso in
            if let aviso { AccessibilityNotification.Announcement(aviso.texto).post() }
        }
    }

    private var barra: some View {
        HStack(spacing: Tema.Espaco.e2) {
            Button("Copiar") { copiar() }
                .keyboardShortcut("c")
                .accessibilityLabel(Text("Copiar"))
            Button("Salvar como PNG…") { salvar { await captura.salvarPNG() } }
                .accessibilityLabel(Text("Salvar como PNG…"))
            Button("Salvar como Capta…") { salvar { await captura.salvarCapta() } }
                .disabled(!captura.podeSalvarCapta)
                .accessibilityLabel(Text("Salvar como Capta…"))
            Spacer()
            if let aviso = captura.aviso {
                // Aviso discreto (spec §4.5): fica na barra, sem interromper o trabalho.
                Label(aviso.texto, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(Tema.textoSecundario)
                    .lineLimit(2)
                    .help(aviso.texto)
                    .accessibilityLabel(Text(aviso.texto))
            }
            if let confirmacao {
                Text(confirmacao)
                    .foregroundStyle(Tema.textoSecundario)
                    .accessibilityLabel(Text(confirmacao))
            }
            Button(modo == .ajustar ? "Tamanho real" : "Ajustar à janela") {
                modo = modo == .ajustar ? .tamanhoReal : .ajustar
            }
            .accessibilityLabel(Text(modo == .ajustar ? "Tamanho real" : "Ajustar à janela"))
        }
        .padding(Tema.Espaco.e3)
        .background(Tema.fundoDoPainel(reduzirTransparencia: reduzirTransparencia))
    }

    private var area: some View {
        GeometryReader { geometria in
            let exibida = imagem ?? captura.base
            let pontos = CGSize(
                width: Double(exibida.width) / captura.escala,
                height: Double(exibida.height) / captura.escala
            )
            let escala = Enquadramento.escala(
                imagem: pontos,
                area: geometria.size,
                modo: modo
            )
            ScrollView([.horizontal, .vertical]) {
                Image(exibida, scale: 1, label: Text("Captura de tela"))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: pontos.width * escala, height: pontos.height * escala)
                    .frame(
                        minWidth: geometria.size.width,
                        minHeight: geometria.size.height
                    )
            }
        }
    }

    /// O renderizador roda uma vez por documento; até lá a base (igual, sem anotações) aparece.
    private func renderizarUmaVez() {
        guard imagem == nil else { return }
        let renderizador = Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF())
        do {
            imagem = try renderizador.renderizar(captura.documento, base: captura.base)
        } catch {
            RegistroDeCaptura.falha("renderizar", error)
            mostrarAlerta(.capturaFalhou)
        }
    }

    private func copiar() {
        tratar(captura.copiar(), confirmacao: String(localized: "Copiado"))
    }

    private func salvar(_ acao: @escaping @MainActor () async -> ResultadoDeAcao) {
        Task {
            tratar(await acao(), confirmacao: String(localized: "Salvo"))
        }
    }

    private func tratar(_ resultado: ResultadoDeAcao, confirmacao texto: String) {
        switch resultado {
        case .concluido:
            confirmacao = texto
            AccessibilityNotification.Announcement(texto).post()
            Task {
                try? await Task.sleep(for: .seconds(2))
                if confirmacao == texto { confirmacao = nil }
            }
        case .cancelado:
            break
        case .falhou(let mensagem):
            mostrarAlerta(mensagem)
        }
    }
}
