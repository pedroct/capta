import CaptaNucleo
import SwiftUI

/// A janela do editor: barra de ferramentas, canvas, painel de propriedades e rodapé.
///
/// Só monta a tela. A regra mora no `EditorDaCaptura` e no núcleo; os textos e o que o painel
/// mostra vêm de `ApresentacaoDoEditor` e `ModeloDoPainel`; a confirmação da barra, de
/// `AcoesDaBarra`.
struct JanelaDoEditorView: View {
    let editor: EditorDaCaptura
    let mostrarAlerta: @MainActor (MensagemDeErro) -> Void

    @State private var acoes: AcoesDaBarra
    @Environment(\.accessibilityReduceTransparency) private var reduzirTransparencia

    init(editor: EditorDaCaptura, mostrarAlerta: @escaping @MainActor (MensagemDeErro) -> Void) {
        self.editor = editor
        self.mostrarAlerta = mostrarAlerta
        _acoes = State(initialValue: AcoesDaBarra(mostrarAlerta: mostrarAlerta))
    }

    private var captura: CapturaAberta { editor.captura }

    var body: some View {
        VStack(spacing: 0) {
            barra
                .frame(height: Enquadramento.alturaDasFerramentas)
                .background(Tema.fundoDoPainel(reduzirTransparencia: reduzirTransparencia))
            Divider()
            HStack(spacing: 0) {
                CanvasDoEditor(editor: editor)
                    .background(Tema.superficieCanvas)
                Divider()
                PainelDePropriedadesView(editor: editor)
            }
            Divider()
            rodape
                .frame(height: Enquadramento.alturaDoRodape)
                .background(Tema.fundoDoPainel(reduzirTransparencia: reduzirTransparencia))
        }
        .background(Tema.superficieJanela)
        .background(atalhos)
        .onDisappear { acoes.cancelar() }
        .onChange(of: NomesDoEditor.anuncio(de: editor.estado)) { _, nome in
            AccessibilityNotification.Announcement(nome).post()
        }
        .onChange(of: captura.aviso) { _, aviso in
            if let aviso { AccessibilityNotification.Announcement(aviso.texto).post() }
        }
    }

    // MARK: Barra

    private var barra: some View {
        HStack(spacing: Tema.Espaco.e1) {
            botaoDeFerramenta(.selecao, simbolo: "cursorarrow")
            botaoDeFerramenta(.seta, simbolo: "arrow.up.right")
            botaoDeFerramenta(.linha, simbolo: "line.diagonal")
            menuDeForma
            botaoDeFerramenta(.realce, simbolo: "highlighter")
            Divider().frame(height: 20).padding(.horizontal, Tema.Espaco.e1)
            Button {
                editor.desfazer()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .keyboardShortcut("z")
            .disabled(!captura.podeDesfazer)
            .help(Text("Desfazer"))
            .accessibilityLabel(Text("Desfazer"))
            Button {
                editor.refazer()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!captura.podeRefazer)
            .help(Text("Refazer"))
            .accessibilityLabel(Text("Refazer"))
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
            if let confirmacao = acoes.confirmacao {
                Text(confirmacao)
                    .foregroundStyle(Tema.textoSecundario)
                    .accessibilityLabel(Text(confirmacao))
            }
            Menu {
                Button("Salvar como PNG…") {
                    acoes.executar(confirmacao: salvo) { await captura.salvarPNG() }
                }
                .accessibilityLabel(Text("Salvar como PNG…"))
                Button("Salvar como Capta…") {
                    acoes.executar(confirmacao: salvo) { await captura.salvarCapta() }
                }
                .disabled(!captura.podeSalvarCapta)
                .accessibilityLabel(Text("Salvar como Capta…"))
            } label: {
                Text("Exportar")
            }
            .fixedSize()
            .accessibilityLabel(Text("Exportar"))
            Button("Copiar") {
                acoes.executar(confirmacao: copiado) { await captura.copiar() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("c")
            .accessibilityLabel(Text("Copiar"))
        }
        .padding(.horizontal, Tema.Espaco.e3)
    }

    private var copiado: String { String(localized: "Copiado") }
    private var salvo: String { String(localized: "Salvo") }

    private func botaoDeFerramenta(_ ferramenta: Ferramenta, simbolo: String) -> some View {
        let nome = NomesDoEditor.ferramenta(ferramenta)
        let ativa = editor.estado.ferramenta == ferramenta
        return Button {
            editor.comandar(.escolher(ferramenta))
        } label: {
            Image(systemName: simbolo).modifier(DestaqueDaFerramenta(ativa: ativa))
        }
        .buttonStyle(.plain)
        .help(nome)
        .accessibilityLabel(Text(nome))
        .accessibilityAddTraits(ativa ? .isSelected : [])
    }

    /// Forma: clicar escolhe a ferramenta com a última forma; o menu troca o tipo.
    private var menuDeForma: some View {
        let ativa = editor.estado.ferramenta == .forma
        let nome = NomesDoEditor.ferramenta(.forma)
        return Menu {
            ForEach(NomesDoEditor.formas, id: \.self) { tipo in
                Button {
                    editor.comandar(.escolherForma(tipo))
                } label: {
                    Label(
                        NomesDoEditor.tipoDeForma(tipo),
                        systemImage: simbolo(da: tipo)
                    )
                }
            }
        } label: {
            Image(systemName: simbolo(da: editor.estado.tipoForma))
                .modifier(DestaqueDaFerramenta(ativa: ativa))
        } primaryAction: {
            editor.comandar(.escolherForma(editor.estado.tipoForma))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize()
        .help(nome)
        .accessibilityLabel(Text(nome))
        .accessibilityAddTraits(ativa ? .isSelected : [])
    }

    private func simbolo(da tipo: TipoForma) -> String {
        switch tipo {
        case .retangulo: "rectangle"
        case .retanguloArredondado: "app"
        case .elipse: "oval"
        }
    }

    // MARK: Rodapé

    private var rodape: some View {
        let salvamento = TextosDoRodape.salvamento(
            captura.estadoDoSalvamento,
            rascunhoFalhou: captura.aviso != nil
        )
        return HStack(spacing: Tema.Espaco.e3) {
            menuDeZoom
            Spacer()
            Text(TextosDoRodape.tamanhoDeSaida(captura.documento))
                .monospacedDigit()
                .foregroundStyle(Tema.textoSecundario)
                .accessibilityLabel(Text(TextosDoRodape.tamanhoDeSaida(captura.documento)))
            Spacer()
            Label(
                salvamento.texto,
                systemImage: salvamento.alerta ? "exclamationmark.triangle" : "checkmark.circle"
            )
            .font(.callout)
            .foregroundStyle(Tema.textoSecundario)
            .labelStyle(.titleAndIcon)
            .accessibilityLabel(Text(salvamento.texto))
        }
        .font(.callout)
        .padding(.horizontal, Tema.Espaco.e3)
    }

    private var menuDeZoom: some View {
        Menu {
            ForEach(Zoom.niveis, id: \.self) { nivel in
                let marcado = editor.modoDeZoom == .manual && editor.zoom == nivel
                Button {
                    editor.definirZoom(nivel)
                } label: {
                    if marcado {
                        Label(TextosDoRodape.zoom(nivel), systemImage: "checkmark")
                    } else {
                        Text(TextosDoRodape.zoom(nivel))
                    }
                }
            }
            Divider()
            Button("Ajustar à janela") { editor.ajustarAJanela() }
            Button("Tamanho real") { editor.tamanhoReal() }
        } label: {
            Text(TextosDoRodape.zoom(editor.zoom)).monospacedDigit()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(Text("Zoom"))
        .accessibilityLabel(Text("Zoom"))
        .accessibilityValue(Text(TextosDoRodape.zoom(editor.zoom)))
    }

    // MARK: Atalhos

    /// Atalhos de teclado da janela, sem aparecer: o app não tem barra de menus própria. Valem
    /// com a janela ativa, esteja o foco no canvas ou nos controles.
    private var atalhos: some View {
        Group {
            Button("Selecionar tudo") { editor.selecionarTudo() }
                .keyboardShortcut("a")
            Button("Duplicar") { editor.duplicar() }
                .keyboardShortcut("d")
            Button("Ajustar à janela") { editor.ajustarAJanela() }
                .keyboardShortcut("9")
            Button("Tamanho real") { editor.tamanhoReal() }
                .keyboardShortcut("0")
            Button("Aumentar o zoom") { editor.aumentarZoom() }
                .keyboardShortcut("+")
            Button("Aumentar o zoom") { editor.aumentarZoom() }
                .keyboardShortcut("=")
            Button("Diminuir o zoom") { editor.diminuirZoom() }
                .keyboardShortcut("-")
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}

/// Aparência de um botão de ferramenta: o ativo ganha o fundo de destaque.
private struct DestaqueDaFerramenta: ViewModifier {
    let ativa: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .foregroundStyle(ativa ? Tema.destaque : Tema.texto)
            .frame(width: 32, height: 28)
            .background {
                if ativa {
                    RoundedRectangle(cornerRadius: Tema.Raio.controle).fill(Tema.destaqueFundo)
                }
            }
            .contentShape(Rectangle())
    }
}
