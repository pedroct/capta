import CaptaNucleo
import SwiftUI

/// O painel de propriedades à direita do canvas: muda com a ferramenta ou a seleção e manda
/// `.alterarEstilo` a cada mudança. Só desenha; o que mostrar vem do `ModeloDoPainel`.
struct PainelDePropriedadesView: View {
    let editor: EditorDaCaptura
    @Environment(\.accessibilityReduceTransparency) private var reduzirTransparencia

    var body: some View {
        let modelo = ModeloDoPainel(estado: editor.estado, documento: editor.captura.documento)
        VStack(alignment: .leading, spacing: Tema.Espaco.e4) {
            Text(modelo.titulo)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let estilo = modelo.estilo {
                controles(modelo, estilo)
            } else {
                Text("Escolha uma ferramenta ou selecione um objeto para editar as propriedades.")
                    .font(.callout)
                    .foregroundStyle(Tema.textoSecundario)
            }
            Spacer(minLength: 0)
        }
        .padding(Tema.Espaco.e4)
        .frame(width: Enquadramento.larguraDoPainel)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Tema.fundoDoPainel(reduzirTransparencia: reduzirTransparencia))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func controles(_ modelo: ModeloDoPainel, _ estilo: Estilo) -> some View {
        secao("Cor") {
            FileiraDeCores(
                selecionada: { PaletaDoEditor.mesmaCor($0, estilo.cor) },
                aoEscolher: { enviar(.cor($0)) }
            )
        }
        if modelo.mostraLargura {
            ControleDeslizante(
                titulo: String(localized: "Largura"),
                valor: estilo.largura,
                intervalo: 0...40,
                passo: 1,
                formato: { String(localized: "\(Int($0)) px") },
                aoConfirmar: { enviar(.largura($0)) }
            )
        }
        ControleDeslizante(
            titulo: String(localized: "Opacidade"),
            valor: estilo.opacidade,
            intervalo: 0...1,
            passo: 0.01,
            formato: { String(localized: "\(Int(($0 * 100).rounded())) %") },
            aoConfirmar: { enviar(.opacidade($0)) }
        )
        if modelo.mostraTracejado {
            Toggle(
                "Tracejado",
                isOn: Binding(
                    get: { estilo.tracejado },
                    set: { enviar(.tracejado($0)) }
                )
            )
            .accessibilityLabel(Text("Tracejado"))
        }
        if modelo.mostraPreenchimento {
            secao("Preenchimento") {
                Button {
                    enviar(.preenchimento(nil))
                } label: {
                    Label(
                        "Sem preenchimento",
                        systemImage: estilo.preenchimento == nil ? "checkmark" : "slash.circle"
                    )
                }
                .accessibilityLabel(Text("Sem preenchimento"))
                .accessibilityAddTraits(estilo.preenchimento == nil ? .isSelected : [])
                FileiraDeCores(
                    selecionada: { cor in
                        estilo.preenchimento.map { PaletaDoEditor.mesmaCor($0, cor) } ?? false
                    },
                    aoEscolher: { enviar(.preenchimento($0)) }
                )
            }
        }
    }

    private func secao<Conteudo: View>(
        _ titulo: LocalizedStringKey,
        @ViewBuilder _ conteudo: () -> Conteudo
    ) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espaco.e2) {
            Text(titulo).font(.subheadline)
            conteudo()
        }
    }

    private func enviar(_ alteracao: AlteracaoDeEstilo) {
        editor.comandar(.alterarEstilo(alteracao))
    }
}

/// Os oito círculos da paleta de anotação; o selecionado ganha o anel de foco.
private struct FileiraDeCores: View {
    let selecionada: (CorRGBA) -> Bool
    let aoEscolher: (CorRGBA) -> Void

    var body: some View {
        HStack(spacing: Tema.Espaco.e1) {
            ForEach(PaletaDoEditor.cores, id: \.nome) { item in
                let marcada = selecionada(item.cor)
                Button {
                    aoEscolher(item.cor)
                } label: {
                    Circle()
                        .fill(item.visual)
                        .overlay(Circle().strokeBorder(Tema.bordaControle, lineWidth: 1))
                        .frame(width: 18, height: 18)
                        .padding(2)
                        .overlay(
                            Circle().strokeBorder(Tema.anelFoco, lineWidth: marcada ? 2 : 0)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.nome))
                .accessibilityAddTraits(marcada ? .isSelected : [])
                .help(item.nome)
            }
        }
    }
}

/// Controle deslizante que só grava ao soltar: arrastar não enche o histórico de passos.
/// Durante o arraste, o valor mostrado é o do rascunho; ajustes sem arraste (teclado,
/// VoiceOver) gravam na hora.
private struct ControleDeslizante: View {
    let titulo: String
    let valor: Double
    let intervalo: ClosedRange<Double>
    let passo: Double
    let formato: (Double) -> String
    let aoConfirmar: (Double) -> Void

    @State private var rascunho: Double?
    @State private var arrastando = false

    var body: some View {
        let exibido = rascunho ?? valor
        VStack(alignment: .leading, spacing: Tema.Espaco.e1) {
            HStack {
                Text(titulo).font(.subheadline)
                Spacer()
                Text(formato(exibido))
                    .monospacedDigit()
                    .foregroundStyle(Tema.textoSecundario)
            }
            Slider(
                value: Binding(
                    get: { exibido },
                    set: { novo in
                        if arrastando { rascunho = novo } else { aoConfirmar(novo) }
                    }
                ),
                in: intervalo,
                step: passo
            ) { editando in
                arrastando = editando
                if !editando, let final = rascunho {
                    rascunho = nil
                    aoConfirmar(final)
                }
            }
            .accessibilityLabel(Text(titulo))
            .accessibilityValue(Text(formato(exibido)))
        }
    }
}
