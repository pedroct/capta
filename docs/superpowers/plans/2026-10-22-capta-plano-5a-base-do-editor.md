# Capta — Plano 5a: base do editor

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar a janela de resultado por um editor de verdade, com canvas e zoom, seleção (mover, redimensionar, girar, excluir, duplicar), desfazer e refazer, as ferramentas Seta, Linha, Forma e Realce com propriedades e memória por ferramenta, salvamento automático no rascunho e o submenu "Capturas recentes" para reabrir capturas.

**Architecture:** Toda regra que não precisa de tela vira valor puro em `CaptaNucleo` com TDD: esquema v2 e migração, `Edicao.lote`, limites e acerto, alças, área a redesenhar, o renderizador com área suja, a máquina de estados do editor (`EstadoDoEditor.reduzir`, no estilo do `EstadoDoOverlay`) e a listagem das capturas recentes. O app ganha uma casca fina: a `CapturaAberta` passa a ter uma `SessaoEdicao` e um salvamento automático, um `EditorDaCaptura` liga a máquina de estados ao documento, uma vista AppKit desenha o canvas e traduz os eventos, e a `JanelaDoEditorView` (SwiftUI) substitui a `JanelaDeCapturaView`.

**Tech Stack:** Swift 6.4 (modo 6), SwiftPM, XcodeGen, Swift Testing, CoreGraphics/CoreImage/CoreText/ImageIO, AppKit/SwiftUI.

**Spec:** `docs/superpowers/specs/2026-10-22-capta-editor-design.md` (§4.1–4.4, §4.8, §4.9, §4.10, §4.12, §4.13, §5, §6, §7 item 1). Spec de origem: `docs/superpowers/specs/2026-10-20-capta-mvp-design.md`. Padrões: `docs/padroes-stack-swift.md`. Esquema atual: `docs/esquema-capta-v1.md`. Protótipo: página "MVP · Plano 3 — Editor" de https://claude.ai/artifact/QMAPkACqr3PNQw5SRQuW4W (telas "captura aberta" e "seta e propriedades"). Leia a spec e os padrões antes de começar.

## Global Constraints

- macOS **14+**; Swift 6 em modo de linguagem 6; **aviso tratado como erro**; **nenhuma dependência de terceiros**.
- **App Sandbox ligado**; entitlements **só** `app-sandbox` e `files.user-selected.read-write`; **sem rede**, sem conta, sem telemetria, **nenhuma permissão nova**.
- `CaptaNucleo` importa só Foundation, CoreGraphics, CoreText, CoreImage, ImageIO e UniformTypeIdentifiers; nunca SwiftUI, AppKit, ScreenCaptureKit ou Vision.
- Coordenadas do documento: **pixels da imagem base**, origem no canto superior esquerdo, Y para baixo. O renderizador inverte o eixo uma vez.
- `Documento.validar()` roda em toda edição, no decode e antes de gravar ou renderizar. **`base.png` nunca é regravado** depois da captura; o editor só regrava `documento.json` e `miniatura.png`.
- **Não existe estado "não salvo":** fechar a janela ou sair nunca pergunta nada e nunca perde a última edição.
- **Um renderizador só:** o canvas e copiar/salvar PNG usam o mesmo código de desenho.
- Domínio, comentários, docs e commits em **pt-BR**; sem `!`, `try!` nem IUO em produção. Texto de interface só pelo String Catalog; cor de controle só por `Tema.*`; cores de anotação são as `anotacao-*` (iguais nos dois temas); cores da marca nunca na interface; nada de erro técnico ou em inglês na interface.
- TDD: teste que falha primeiro, com Swift Testing. Cobertura do pacote ≥ **98 %** por alvo; **nunca descer um piso**; subir piso vai em commit próprio. Casca do pacote sem teste entra em `ferramentas/cobertura.exclusoes`; casca do app, no registro novo da Tarefa 9.
- **`make verificar` passa antes de todo commit.** Comandos sempre pelo `make` (`make test`, `make cobertura-app`). Nunca `swift test` puro, nunca `sudo xcode-select`.
- Commits em Conventional Commits, descrição em pt-BR, autor e committer `Pedro Teixeira <noreply@pedroct.com.br>`, **sem `Co-Authored-By` e sem menção a IA**, nunca `--no-verify`. `git push` pede confirmação do Pedro (passo 🔒).
- Antes de usar uma API de AppKit ou SwiftUI, conferir a assinatura e o comportamento no SDK do Xcode-beta; o plano nomeia a API, não garante a assinatura.
- Valores fixos deste plano: salvamento ~**2 s** depois da última edição; zoom de **25 a 400 %** nos níveis `25, 50, 75, 100, 150, 200, 300, 400`; tolerância de acerto **4 pt** de tela; alça de **8 pt**; alça de giro a **20 pt** acima do objeto; setas movem **1 px** do documento (`⇧` = **10 px**); duplicar desloca **10 px**; **10** capturas recentes.

**Desvio da spec, combinado com a §4.9:** a spec põe "esquema v2 completo" no 5a. Este plano sobe a versão para 2 e cria a migração, mas **não** acrescenta campos que só os planos 5b e 5c usam (callout, caneta e cor do texto no 5b; grupo, bloqueio, orientação e fator de saída no 5c). Cada plano acrescenta os seus no lugar, todos opcionais e com padrão, o que a §4.9 permite até o congelamento no fim do 5c. Assim nenhum dado entra no arquivo antes de existir a interface que o usa.

## Review Focus

1. **⌘Q ou fechar a janela com um salvamento pendente ou em curso:** a última edição está no disco e o app só encerra depois de gravar. → Tarefa 10.
2. **Desfazer, refazer ou trocar de ferramenta no meio de um arrasto, ou desfazer a criação do objeto selecionado:** nenhuma prévia fantasma fica na tela e a seleção não aponta para objeto que sumiu. → Tarefas 6 e 11.
3. **Clicar em objeto fino (linha de 1 px) com zoom de 25 % e de 400 %:** acerta com a mesma folga em pontos de tela. → Tarefa 11.
4. **Capturas recentes: pacote corrompido, de versão mais nova, apagado depois de o menu abrir, ou já aberto numa janela:** alerta curto em pt-BR ou a janela existente vem para a frente; o pacote não é alterado. → Tarefa 13.
5. **Mover um objeto que está embaixo de um desfoque, ou mover o próprio desfoque:** o canvas redesenhado por área fica pixel a pixel igual ao render inteiro. → Tarefa 5.

---

## Mapa de arquivos

```text
Packages/CaptaNucleo/Sources/CaptaNucleo/
  Esquema.swift                         (mod) versão 2, versão mínima legível
  Modelo/Migracao.swift                 (novo) v1 → v2
  Modelo/Documento.swift                (mod) decode aceita 1...atual e migra
  Modelo/Cor.swift                      (mod) paleta completa e realce
  Edicao/Edicao.swift                   (mod) .lote, Equatable, `deslocada` interna
  Edicao/SessaoEdicao.swift             (mod) simular
  Editor/Copias.swift                   (novo) cópias para duplicar
  Editor/Limites.swift                  (novo) limites, acerto, seleção por retângulo
  Editor/Alcas.swift                    (novo) alças, redimensionar, girar
  Editor/AreaAlterada.swift             (novo) o que redesenhar entre dois documentos
  Editor/MemoriaDeEstilos.swift         (novo) estilo lembrado por ferramenta
  Editor/EstadoDoEditor.swift           (novo) máquina de estados do editor
  Editor/EventosDoEditor.swift          (novo) Ferramenta, eventos, ações, contexto
  Renderizacao/Renderizador.swift       (mod) compor com área suja
  Renderizacao/DesenhoFormas.swift      (mod) tamanho da cabeça da seta compartilhado
  Renderizacao/Desfoque.swift           (mod) margem de leitura
  Captura/CapturasRecentes.swift        (novo) listar pacotes recentes
  Imagem/CodificadorPNG.swift           (mod) decodificar
App/Fontes/
  Captura/CapturaAberta.swift           (mod) sessão, desfazer, salvamento
  Editor/SalvamentoAutomatico.swift     (novo)
  Editor/EditorDaCaptura.swift          (novo) liga EstadoDoEditor à captura
  Editor/MemoriaLembrada.swift          (novo) MemoriaDeEstilos no UserDefaults
  Editor/Zoom.swift                     (novo) níveis e conversão tela ↔ documento
  Editor/ComposicaoDoCanvas.swift       (novo) bitmap da composição atualizado por área
  Editor/VistaDoCanvas.swift            (novo) NSView do canvas (casca)
  Editor/JanelaDoEditorView.swift       (novo) barra, canvas, painel, rodapé (substitui JanelaDeCapturaView)
  Editor/PainelDePropriedadesView.swift (novo)
  Janelas/JanelaDeCapturaView.swift     (removido)
  Janelas/GerenciadorDeJanelas.swift    (mod) editor, salvar ao fechar, trazer para a frente
  Captura/FluxoDeCaptura.swift          (mod) abrir recente
  Captura/Apresentador.swift            (mod) mensagem nova, trazer para a frente
  Menu/EstadoDoMenu.swift               (mod) recentes
  DelegadoDoApp.swift                   (novo) salvar tudo antes de encerrar
  CaptaApp.swift                        (mod) submenu e delegado
ferramentas/cobertura-app.exclusoes     (novo)
ferramentas/pisos.py, cobertura_app.sh  (mod)
docs/esquema-capta-v2.md                (novo)
docs/verificacao-manual-editor.md       (novo)
```

---

### Task 1: Esquema v2 e migração da v1

**Files:**
- Modify: `Packages/CaptaNucleo/Sources/CaptaNucleo/Esquema.swift`, `Modelo/Documento.swift`, `CLAUDE.md` (seção "Estado e próximos passos")
- Create: `Packages/CaptaNucleo/Sources/CaptaNucleo/Modelo/Migracao.swift`, `Packages/CaptaNucleo/Tests/CaptaNucleoTests/Apoio/JsonEsquemaV2.swift`, `Tests/CaptaNucleoTests/EsquemaV2Tests.swift`, `docs/esquema-capta-v2.md`
- Modify (testes): `EsquemaTests.swift`, `EsquemaV1CongeladoTests.swift` (vira leitura da v1), `PacoteCaptaTests.swift`, `VersaoEsquemaPacoteTests.swift` (literais `"versaoEsquema" : 1` passam a usar `Esquema.versaoAtual`)

**Interfaces:**
- Produces: `Esquema.versaoAtual == 2`; `Esquema.versaoMinimaLegivel == 1`; `enum Migracao { static func migrar(_ documento: inout Documento, desde versao: Int) }` (interno). `Documento.init(from:)` lê `versaoEsquema`; se `versaoMinimaLegivel <= v < versaoAtual`, migra antes de `validar()`; fora disso deixa como está, e `validar()` lança `valorForaDeFaixa("versaoEsquema")` como hoje. A migração v1 → v2 só troca a versão (nenhum campo muda nesta versão).

- [ ] **Step 1: Testes que falham**
  - `EsquemaTests.versaoAtualDoEsquemaEDois`: `#expect(Esquema.versaoAtual == 2)` e `#expect(Esquema.versaoMinimaLegivel == 1)`.
  - `EsquemaV1CongeladoTests` (renomear a suíte para "Leitura do esquema v1"): `jsonV1DeReferenciaDecodificaMigrado`: decodificar `jsonEsquemaV1DeReferencia` dá o documento completo do teste com `versaoEsquema == 2` e os demais campos iguais. Remover `documentoCompletoTemJsonDeReferencia` (a v1 não é mais gravada); o literal v1 fica intacto.
  - `EsquemaV2Tests.documentoCompletoTemJsonDeReferenciaV2`: o mesmo documento completo codifica exatamente para `jsonEsquemaV2DeReferencia` (o literal da v1 com `"versaoEsquema" : 2`); e `jsonV2DecodificaDeVolta`. Comentário no topo: a v2 só congela no fim do Plano 5c (spec §4.9); até lá, quem acrescenta campo atualiza este literal no mesmo commit.
  - `PacoteCaptaTests.lerPacoteV1MigraEAtualizarGravaV2`: gravar um pacote, trocar no `documento.json` a versão por `1`, `ler` devolve `versaoEsquema == 2`; `atualizar` com esse documento grava `"versaoEsquema" : 2` e não toca `base.png` (bytes e data de modificação).
  - `VersaoEsquemaPacoteTests`: versão `3` no disco → `ErroPacote.versaoMaisNova(3)`; `0` e `-1` continuam `ErroDocumento.valorForaDeFaixa("versaoEsquema")`.
- [ ] **Step 2: Rodar** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** a versão e a migração. Comentário de `Esquema.versaoAtual`: v1 congelada (`docs/esquema-capta-v1.md`), v2 em `docs/esquema-capta-v2.md`, congela no fim do Plano 5c.
- [ ] **Step 4: Escrever `docs/esquema-capta-v2.md`** no formato da v1: as mesmas tabelas, `versaoEsquema` = 2, uma seção "Migração" (v1 → v2: só a versão) e uma "Regra de congelamento" (muda no lugar até o fim do Plano 5c; depois, mudança incompatível sobe para 3 com migração e teste). Em `docs/esquema-capta-v1.md`, uma linha no topo apontando para a v2. Em `CLAUDE.md`, trocar a frase "Antes de qualquer app gravar `.capta`, fechar o esquema v1…" por: "Esquema em v2 (`docs/esquema-capta-v2.md`), que muda no lugar até o fim do Plano 5c e então congela."
- [ ] **Step 5: Rodar** `make verificar` → Expected: PASS. Commit (`feat(nucleo): sobe o esquema para v2 com migração da v1`).

### Task 2: Paleta, `Edicao.lote`, simular e cópias

**Files:**
- Modify: `Modelo/Cor.swift`, `Edicao/Edicao.swift`, `Edicao/SessaoEdicao.swift`
- Create: `Editor/Copias.swift`
- Test: `Tests/CaptaNucleoTests/PaletaTests.swift`, `EdicaoLoteTests.swift`, `CopiasTests.swift`

**Interfaces:**
- Produces:
  - `CorRGBA.laranja` (#FF9500), `.verde` (#34C759), `.azul` (#0A84FF), `.roxo` (#AF52DE), `.realce` (#FFD60A com alfa `0x8C/255`); `static let paleta: [CorRGBA]` = `[vermelho, laranja, amarelo, verde, azul, roxo, preto, branco]` (ordem do `tokens.json`).
  - `Edicao: Equatable`; `case lote([Edicao])` — aplica em ordem sobre a mesma cópia; `SessaoEdicao.aplicar(.lote(...))` valida uma vez e cria **uma** entrada no histórico; lote vazio ou que não muda nada não cria entrada.
  - `SessaoEdicao.simular(_ edicao: Edicao) throws -> Documento` — aplica e valida numa cópia, sem tocar documento nem histórico (para a prévia de um arrasto).
  - `Geometria.deslocada(por:)` passa de `fileprivate` a interna.
  - `extension Documento { public func copias(de ids: Set<UUID>, deslocamento: CGVector, novoId: () -> UUID) -> [Anotacao] }` — cópias na ordem das camadas, geometria deslocada, id novo; ids inexistentes são ignorados.

- [ ] **Step 1: Testes que falham**
  - `paletaTemOitoCoresDoTokensNaOrdem`: cada cor da `paleta` e `.realce` com os componentes dos hex acima (tolerância `1e-9`).
  - `loteDeDuasEdicoesDesfazNumPassoSo`: `lote([.adicionar(a), .mover([a.id], (5, 0))])` → um `desfazer()` volta ao documento vazio; `podeDesfazer == false`.
  - `loteInvalidoNaoMudaNada`: lote cujo segundo item remove id inexistente lança `objetoInexistente` e documento e histórico ficam iguais.
  - `loteVazioNaoCriaEntrada`; `loteAninhadoAplicaEmOrdem`.
  - `simularNaoTocaHistorico`: depois de `simular`, `documento` e `podeDesfazer` iguais; o devolvido contém a edição.
  - `copiasMantemOrdemDasCamadasEDeslocam`: documento com `a`, `b`, `c`; `copias(de: [c.id, a.id], deslocamento: (10, 10))` devolve `[a', c']` (ordem das camadas), com os ids do `novoId` na sequência e as geometrias deslocadas 10 px; `copias` de id inexistente devolve `[]`.
- [ ] **Step 2: Rodar** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** `make verificar` → Expected: PASS. Commit (`feat(nucleo): adiciona lote de edições, simulação e cópias`).

### Task 3: Limites, acerto e seleção por retângulo

**Files:**
- Create: `Editor/Limites.swift`
- Modify: `Renderizacao/DesenhoFormas.swift` (extrair `func tamanhoDaCabeca(largura: Double, comprimento: CGFloat) -> CGFloat`, o mesmo cálculo de hoje, usado pelo desenho e pelos limites)
- Test: `Tests/CaptaNucleoTests/LimitesTests.swift`, `AcertoTests.swift`

**Interfaces:**
- Produces:
  - `extension Anotacao { public var limites: CGRect }` — retângulo padronizado, alinhado aos eixos, em pixels do documento, que contém tudo o que o renderizador pinta do objeto: seta e linha = caixa dos dois pontos ampliada por `largura/2` (seta: pelo maior entre `largura/2` e metade de `tamanhoDaCabeca`); forma = retângulo ampliado por `largura/2`; etapa = círculo de `diametro` mais `largura/2`; texto, carimbo, realce e desfoque = o retângulo. Com `rotacao != 0`, a caixa dos quatro cantos girados em torno do centro.
  - `extension Documento { public func objeto(em ponto: CGPoint, tolerancia: CGFloat) -> UUID?; public func objetos(tocando retangulo: CGRect) -> [UUID]; public func limites(de ids: Set<UUID>) -> CGRect? }`
  - Regras do acerto (de cima para baixo, o primeiro que acerta): seta e linha = distância ao segmento ≤ `largura/2 + tolerancia`; forma **sem** preenchimento = distância ao contorno ≤ `largura/2 + tolerancia`; forma **com** preenchimento, etapa, texto, carimbo, realce e desfoque = dentro da forma ampliada por `tolerancia`. Com rotação, o ponto vai antes para o referencial do objeto. `objetos(tocando:)` devolve, na ordem das camadas, os que têm `limites` que intersectam o retângulo padronizado.

- [ ] **Step 1: Testes que falham** (`LimitesTests`, `AcertoTests`):
  - `limitesDaSetaIncluemACabeca`: seta `(0,0)→(100,0)`, largura 4 → cabeça 16 → limites `(-8, -8, 116, 16)`.
  - `limitesDaFormaGirada90GrausTrocamOsLados`: retângulo `(0,0,100,20)`, largura 0, `rotacao = .pi/2` → `(40, -40, 20, 100)` (tolerância `1e-9`).
  - `limitesDaEtapaSomamMeioTraco`; `limitesDeRetanguloInvertidoSaemPadronizados`.
  - `acertoPegaOObjetoDeCima`: dois retângulos preenchidos sobrepostos → o último da lista.
  - `formaSemPreenchimentoSoAcertaNoContorno`: retângulo `(0,0,100,100)` largura 2, tolerância 4: `(50,50)` → nil; `(2,50)` → acerta; `(106,50)` → nil.
  - `linhaFinaAcertaComATolerancia`: linha largura 1 de `(0,0)` a `(100,0)`, tolerância 4: `(50, 4.4)` acerta, `(50, 4.6)` não.
  - `acertoEmTextoGirado`: texto girado 90° acerta num ponto que só está dentro depois da rotação.
  - `objetosTocandoDevolveNaOrdemDasCamadas`; `limitesDeIdsVaziosENil`.
- [ ] **Step 2: Rodar** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** `make verificar` → Expected: PASS. Commit (`feat(nucleo): adiciona limites e acerto das anotações`).

### Task 4: Alças, redimensionar e girar

**Files:**
- Create: `Editor/Alcas.swift`
- Test: `Tests/CaptaNucleoTests/AlcasTests.swift`

**Interfaces:**
- Produces (o nome `Alca` já existe no overlay):
  - `public enum AlcaDeObjeto: Hashable, Sendable { case inicio, fim; case canto(CantoDoObjeto); case borda(BordaDoObjeto) }`, `public enum CantoDoObjeto: Hashable, Sendable { case superiorEsquerdo, superiorDireito, inferiorEsquerdo, inferiorDireito }`, `public enum BordaDoObjeto: Hashable, Sendable { case superior, inferior, esquerda, direita }`.
  - `extension Anotacao`:
    - `public func alcas() -> [AlcaDeObjeto: CGPoint]` — seta e linha: `inicio`, `fim`; forma, realce, desfoque, texto e carimbo: 4 cantos e 4 bordas (meio de cada lado), girados com o objeto; etapa: 4 cantos do quadrado do círculo.
    - `public var aceitaRotacao: Bool` — forma, texto, carimbo, realce, etapa (a mesma regra de `validar()`).
    - `public func pontoDeGiro(distancia: CGFloat) -> CGPoint?` — meio da borda superior, afastado `distancia` para fora, girado; `nil` se não aceita rotação.
    - `public func arrastando(_ alca: AlcaDeObjeto, ate ponto: CGPoint, restrito: Bool) -> Anotacao` — o canto ou a borda oposta fica parada **no mundo**, também com rotação; pode inverter o retângulo (o modelo aceita, quem consome padroniza). `restrito`: em seta e linha prende o ângulo em múltiplos de 45°; nos cantos mantém a proporção. Carimbo e etapa mantêm a proporção sempre (etapa muda o `diametro`).
    - `public func girando(ate ponto: CGPoint, restrito: Bool) -> Anotacao` — `rotacao` = ângulo do centro até o ponto, medido para que o ponto de giro fique sob o cursor; `restrito` prende em múltiplos de 15°; sem efeito em quem não aceita rotação.

- [ ] **Step 1: Testes que falham:**
  - `alcasDaLinhaSaoOsDoisPontos`; `alcasDoRetanguloSaoOito`; `alcasDaFormaGiradaGiramJunto` (forma `(0,0,100,20)` girada 90°: o canto superior esquerdo vai para `(60, -40)`).
  - `arrastarCantoMantemOpostoParado`: retângulo `(10,10,100,50)`, canto inferior direito até `(200,100)` → `(10,10,190,90)`.
  - `arrastarCantoDeFormaGiradaMantemOpostoNoMundo`: forma girada 90°; depois de arrastar um canto, a posição no mundo do canto oposto é a mesma de antes (tolerância `1e-9`).
  - `arrastarBordaSoMexeUmLado`; `arrastarAlemDoOpostoInverte`.
  - `cantoRestritoMantemProporcao`: `(0,0,100,50)`, canto inferior direito até `(300, 60)` com restrito → `(0,0,300,150)` (vale o eixo que cresceu mais, aqui o x, e a proporção 2:1 fica).
  - `setaRestritaPrendeEm45Graus`: seta de `(0,0)`, fim arrastado até `(100, 10)` com restrito → fim em `(hypot(100, 10), 0)`: o ângulo vai ao múltiplo de 45° mais próximo e o comprimento do arrasto se mantém.
  - `etapaRedimensionaPeloDiametro`; `carimboSempreProporcional`.
  - `girarPoeOPontoDeGiroNaDirecaoDoCursor`: forma centrada em `(0,0)`, cursor em `(100, 0)` → `rotacao == .pi/2` e o `pontoDeGiro` do resultado fica na semirreta do centro ao cursor.
  - `girarPrendeEm15Graus`: cursor a 50° (sentido horário a partir de "para cima") com restrito → `rotacao == 45 × .pi / 180`.
  - `girarSetaNaoMudaNada`; `pontoDeGiroDaLinhaENil`.
- [ ] **Step 2: Rodar** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar.** Com rotação: levar o ponto ao referencial local (rotação inversa em torno do centro), redimensionar no local, recalcular o centro para o oposto voltar ao mesmo ponto do mundo.
- [ ] **Step 4: Rodar** `make verificar` → Expected: PASS. Commit (`feat(nucleo): adiciona alças, redimensionar e girar anotações`).

### Task 5: Renderizador com rotação e área suja

Hoje o renderizador **ignora** `Anotacao.rotacao`: o esquema guarda o campo, mas nada o desenha. Como girar pela alça entra neste plano, esta tarefa começa por isso.

**Files:**
- Modify: `Renderizacao/Renderizador.swift`, `Renderizacao/Desfoque.swift`, `Renderizacao/Utilitarios.swift` (caso novo de erro)
- Create: `Editor/AreaAlterada.swift`
- Test: `Tests/CaptaNucleoTests/RenderizadorAreaSujaTests.swift`, `AreaAlteradaTests.swift`

**Interfaces:**
- Produces:
  - **Rotação no desenho:** cada objeto com `rotacao != 0` (forma, texto, carimbo, realce, etapa) é desenhado girado em torno do centro do seu retângulo (etapa: do `centro`), com a matriz de rotação padrão aplicada às coordenadas do documento (Y para baixo, então ângulo positivo = sentido horário na tela). É a mesma convenção que `limites`, o acerto e as alças (Tarefas 3 e 4) usam.
  - `Renderizador.novoContexto(para base: CGImage) throws -> CGContext` — sRGB, 8 bits, `premultipliedLast`, tamanho da base (o mesmo de hoje).
  - `Renderizador.compor(_ documento: Documento, base: CGImage, em contexto: CGContext, area: CGRect?) throws` — desenha base e anotações em `contexto` (do `novoContexto`), **sem** aplicar o recorte; `area == nil` desenha tudo; com área, recorta o desenho a ela, desenhando só os objetos cujos `limites` a intersectam e só a parte da base dentro dela. **Amplia a área sozinho** para cada desfoque cuja região ampliada pela margem de leitura a intersecta, repetindo até estabilizar (um desfoque lê o compósito abaixo dele além da própria região). Contexto de outro tamanho lança `ErroRenderizacao.contextoIncompativel`.
  - `func margemDeLeitura(tipo: TipoDesfoque, intensidade: Double) -> CGFloat` em `Desfoque.swift`: borrar = `ceil(3 × min(intensidade, 100))`; pixelizar = `ceil(max(min(intensidade, 100), 1))`.
  - `renderizar(_:base:)` passa a ser `novoContexto` + `compor(area: nil)` + recorte, com o mesmo resultado de hoje.
  - `public enum AreaASerRedesenhada: Equatable, Sendable { case nada, tudo, retangulo(CGRect) }`; `extension Documento { public func areaAlterada(desde anterior: Documento) -> AreaASerRedesenhada }` — `tudo` se mudou `tamanhoBase` ou `escala`; `nada` se os objetos são iguais (mudança só de recorte é `nada`: o recorte é aplicado na exibição); senão a união dos `limites` antigos e novos dos objetos que entraram, saíram, mudaram (geometria, estilo, rotação), mudaram de posição relativa nas camadas, ou são etapas cujo `rotuloDaEtapa` mudou.

- [ ] **Step 1: Testes que falham** (imagem de 200×120 com o gerador de `Apoio/Pixels.swift`):
  - `renderizarContinuaIgual`: os testes de renderizador existentes passam sem mudança.
  - `formaGirada90GrausPintaOndeOsLimitesDizem`: retângulo preenchido `(50,50,100,20)` girado `.pi/2` → pixel `(100, 20)` pintado, pixel `(60, 60)` não; e todo pixel pintado fica dentro de `limites`.
  - `realceGiradoETextoGiradoTambemGiram` (um pixel conferido em cada).
  - `comporPorAreaIgualAoRenderInteiro`: compor o documento A inteiro; aplicar `.mover` de um retângulo; `compor(B, area: areaAlterada)` no mesmo contexto → `makeImage()` pixel a pixel igual a `renderizar(B)` (sem recorte).
  - `moverObjetoEmbaixoDeDesfoqueIgualAoRenderInteiro`: objeto parcialmente sob um desfoque `borrar` 10; mover o objeto → igual ao render inteiro. O mesmo com `pixelizar` 8 e movendo o **próprio** desfoque.
  - `contextoDeOutroTamanhoLanca`.
  - `areaAlteradaDeMoverEUniaoAntesEDepois`; `areaAlteradaSoDeRecorteENada`; `areaAlteradaDeEscalaETudo`; `removerEtapaIncluiAsQueRenumeram`: três etapas, remover a primeira → a área cobre as outras duas; `reordenarIncluiOsQueTrocaram`.
- [ ] **Step 2: Rodar** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** `make verificar` → Expected: PASS. Dois commits: (`fix(nucleo): desenha a rotação das anotações`) e (`feat(nucleo): compõe o documento por área suja`).

### Task 6: Máquina de estados do editor — seleção e gestos

**Files:**
- Create: `Editor/EventosDoEditor.swift`, `Editor/EstadoDoEditor.swift`, `Editor/MemoriaDeEstilos.swift` (só o tipo e os padrões; o uso é da Tarefa 7)
- Test: `Tests/CaptaNucleoTests/EstadoDoEditorSelecaoTests.swift`

**Interfaces:**
- Produces:
  - `public enum Ferramenta: String, Codable, CaseIterable, Sendable { case selecao, seta, linha, forma, realce }` (5b acrescenta as outras).
  - `public struct Modificadores: OptionSet, Equatable, Sendable { static let shift }` (só o `⇧` por ora).
  - `public enum EventoDoEditor: Equatable, Sendable { case escolher(Ferramenta); case escolherForma(TipoForma); case pressionar(CGPoint, Modificadores); case arrastar(CGPoint, Modificadores); case soltar(CGPoint, Modificadores); case esc; case selecionarTudo; case excluir; case duplicar; case deslocar(CGVector); case alterarEstilo(AlteracaoDeEstilo); case sincronizar }` — pontos em pixels do documento.
  - `public enum AlteracaoDeEstilo: Equatable, Sendable { case cor(CorRGBA); case largura(Double); case opacidade(Double); case tracejado(Bool); case preenchimento(CorRGBA?) }`.
  - `public enum AcaoDoEditor: Equatable, Sendable { case aplicar(Edicao); case previa(Edicao); case cancelarPrevia }`.
  - `public struct ContextoDoEditor { public var documento: Documento; public var tolerancia: CGFloat; public var distanciaDoGiro: CGFloat; public var novoId: () -> UUID }` — tolerância e distância já em pixels do documento.
  - `public struct EstadoDoEditor: Equatable, Sendable` com `ferramenta`, `tipoForma` (padrão `.retangulo`), `selecao: Set<UUID>`, `memoria: MemoriaDeEstilos`, `retanguloDeSelecao: CGRect?` (o arraste de seleção em curso, para a vista desenhar), `init(memoria: MemoriaDeEstilos)` e `public mutating func reduzir(_ evento: EventoDoEditor, contexto: ContextoDoEditor) -> AcaoDoEditor?`.
- Regras da ferramenta Seleção (cada uma vira teste):
  - Pressionar numa alça do único objeto selecionado (distância ≤ tolerância; o ponto de giro conta para quem aceita rotação) começa a arrastar a alça; arrastar → `.previa(.substituir(objeto.arrastando/girando))`; soltar → `.aplicar` da mesma edição, ou `nil` se não mudou.
  - Pressionar num objeto: com `⇧` alterna-o na seleção; sem `⇧`, se ele não está selecionado vira a seleção única; se já está, a seleção fica (para arrastar vários). Arrastar → `.previa(.mover(selecao, delta))`, e com `⇧` o delta fica só no eixo dominante. Soltar sem ter movido, sem `⇧`, numa seleção múltipla → a seleção vira só aquele objeto; soltar sem mover → `nil`.
  - Pressionar no vazio: sem `⇧` limpa a seleção; arrastar atualiza `retanguloDeSelecao`; soltar → seleção = `objetos(tocando:)` (unida à anterior com `⇧`), `retanguloDeSelecao = nil`.
  - `.esc` com gesto em curso → `.cancelarPrevia` e nada mais; sem gesto → limpa a seleção.
  - `.excluir` → `.aplicar(.remover(selecao))` e seleção vazia; `nil` sem seleção. `.duplicar` → `.aplicar(.lote(copias.map(.adicionar)))` com deslocamento 10 px e seleção = ids novos. `.deslocar(v)` → `.aplicar(.mover(selecao, v))`. `.selecionarTudo` → todos os ids. `.sincronizar` → tira da seleção os ids que não existem mais e cancela o gesto (`.cancelarPrevia` se havia prévia).
  - `.escolher(f)` cancela o gesto (`.cancelarPrevia` se havia prévia); escolher uma ferramenta de criação limpa a seleção; escolher `.selecao` a mantém.

- [ ] **Step 1: Testes que falham** — um por regra acima, com ids fixos e `tolerancia = 4`, `distanciaDoGiro = 20`; mais: `pressionarEmAlcaTemPrioridadeSobreOutroObjeto`; `eventosDeArrastoSemPressionarSaoIgnorados`.
- [ ] **Step 2: Rodar** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar.** Gesto privado como no `EstadoDoOverlay` (enum com o que precisa para recalcular a partir do clique).
- [ ] **Step 4: Rodar** `make verificar` → Expected: PASS. Commit (`feat(nucleo): adiciona a máquina de estados do editor com seleção`).

### Task 7: Máquina de estados do editor — criação e estilos

**Files:**
- Modify: `Editor/EstadoDoEditor.swift`, `Editor/MemoriaDeEstilos.swift`
- Test: `Tests/CaptaNucleoTests/EstadoDoEditorCriacaoTests.swift`, `MemoriaDeEstilosTests.swift`

**Interfaces:**
- Produces:
  - `public struct MemoriaDeEstilos: Codable, Equatable, Sendable { public subscript(ferramenta: Ferramenta) -> Estilo { get set }; public static let padrao: MemoriaDeEstilos; public static func ferramenta(de geometria: Geometria) -> Ferramenta? }` — padrões: seta `Estilo(cor: .vermelho, largura: 6)`; linha `Estilo(cor: .vermelho, largura: 4)`; forma `Estilo(cor: .vermelho, largura: 4)` sem preenchimento; realce `Estilo(cor: .realce, largura: 0)`; seleção `Estilo()`. Codifica como dicionário por `rawValue`; ferramenta ausente ou chave desconhecida no JSON → padrão daquela ferramenta (nunca lança por isso).
  - `extension EstadoDoEditor { public func estiloExibido(em documento: Documento) -> Estilo? }` — um selecionado: o estilo dele; vários: o do primeiro na ordem das camadas; nenhum com ferramenta de criação: `memoria[ferramenta]`; nenhum com Seleção: `nil` (o painel mostra a dica do protótipo).
- Regras (cada uma vira teste):
  - Ferramenta de criação, pressionar fora de uma alça do único selecionado: começa a criar com `novoId()` chamado **uma vez**; arrastar → `.previa(.adicionar(a))` com o estilo `memoria[ferramenta]`: seta/linha de `inicio` ao ponto (`⇧` prende em 45°, como a Tarefa 4); forma de `inicio` ao ponto com `tipoForma` (`⇧` = quadrado); realce = retângulo. Soltar com distância do início **< tolerância** → `.cancelarPrevia` e nada criado; senão `.aplicar(.adicionar(a))` e seleção = `[a.id]`; a ferramenta continua a mesma.
  - Ferramenta de criação, pressionar numa alça do único selecionado: arrasta a alça como na Seleção.
  - `.alterarEstilo(x)` com seleção: `.aplicar(.lote(substituir…))` mudando só aquele campo em cada selecionado, e o mesmo campo em `memoria[ferramenta(de: geometria)]` de cada tipo selecionado. Sem seleção: muda só `memoria[ferramenta]` e devolve `nil`. `.opacidade` fica em 0…1, `.largura` ≥ 0 (valores fora são limitados, não lançam).
  - Para o realce, `.cor(c)` grava `c` com o alfa de `.realce` (`0x8C/255`), para continuar translúcido.

- [ ] **Step 1: Testes que falham** — um por regra; mais `memoriaDecodificaJsonSemUmaFerramenta`, `memoriaIgnoraChaveDesconhecida`, `memoriaFazIdaEVolta`.
- [ ] **Step 2: Rodar** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** `make verificar` → Expected: PASS. Commit (`feat(nucleo): cria seta, linha, forma e realce e lembra o estilo por ferramenta`).

### Task 8: Capturas recentes no núcleo e PNG de volta

**Files:**
- Create: `Captura/CapturasRecentes.swift`
- Modify: `Imagem/CodificadorPNG.swift`
- Test: `Tests/CaptaNucleoTests/CapturasRecentesTests.swift`, `ImagemTests.swift`

**Interfaces:**
- Produces:
  - `public struct CapturaRecente: Equatable, Sendable { public let url: URL; public let nome: String; public let modificadaEm: Date }` — `nome` = nome do pacote sem `.capta`.
  - `public enum CapturasRecentes { public static let limitePadrao = 10; public static func listar(em pasta: URL, limite: Int = limitePadrao) throws -> [CapturaRecente] }` — só pastas com extensão `capta` que não começam com `.`; data = modificação do `documento.json` (pacote sem ele fica de fora); mais nova primeiro, empate pelo nome; pasta inexistente → `[]`.
  - `CodificadorPNG.decodificar(_ dados: Data) throws -> CGImage` — ImageIO; dados vazios ou que não são imagem lançam `ErroImagem.falhaAoDecodificar` (caso novo no `ErroImagem` que já existe).

- [ ] **Step 1: Testes que falham** (pasta temporária, datas ajustadas com `FileManager.setAttributes`):
  - `listaOsMaisRecentesPrimeiro`; `respeitaOLimite` (12 pacotes, limite 10 → 10); `ignoraOcultosETemporarios` (`.Captura x.capta.tmp-UUID`, `.oculto.capta`); `ignoraOQueNaoECapta` (pasta `x`, arquivo `y.capta`); `pacoteSemDocumentoFicaDeFora`; `pastaInexistenteDevolveVazio`; `empateOrdenaPeloNome`.
  - `codificarEDecodificarFazIdaEVolta` (tamanho e um pixel conferido); `decodificarDadosInvalidosLanca`.
- [ ] **Step 2: Rodar** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** `make verificar` → Expected: PASS. Commit (`feat(nucleo): lista as capturas recentes e decodifica PNG`).

### Task 9: Registro de exclusões da cobertura do app

**Files:**
- Create: `ferramentas/cobertura-app.exclusoes`
- Modify: `ferramentas/pisos.py` (`ler_exclusoes` ganha o parâmetro `prefixo`), `ferramentas/cobertura.sh` (passa `Packages/CaptaNucleo/Sources/CaptaSistema/Casca/`), `ferramentas/cobertura_app.sh` (lê o registro; `EXCLUSOES_APP=<arquivo>` sobrescreve), `ferramentas/cobertura.pisos` (comentário do `App=`)

**Interfaces:**
- Produces: o formato de `cobertura.exclusoes` (`caminho | motivo`, `#` comenta), com prefixo obrigatório `App/Fontes/`, motivo obrigatório, arquivo inexistente ou duplicado falha o portão. Os listados saem da conta do `App=` e do XML do Sonar e aparecem em "Fora da conta" no resumo, como no pacote. `CaptaApp.swift` continua fora pela regra que já existe.

- [ ] **Step 1: Criar o registro vazio** (só o cabeçalho com as regras); as Tarefas 11 e 12 acrescentam `VistaDoCanvas.swift`, `JanelaDoEditorView.swift` e `PainelDePropriedadesView.swift` com o motivo.
- [ ] **Step 2: Conferir o portão** com arquivos temporários na pasta de rascunho da sessão: `EXCLUSOES_APP=<sem motivo> make cobertura-app` → falha com "exclusão inválida"; `<caminho fora de App/Fontes/>` → falha; `<arquivo inexistente>` → falha; registro vazio → PASS com o mesmo total de hoje.
- [ ] **Step 3: Rodar** `make verificar` e `make cobertura-app` → Expected: PASS. Commit próprio (`build: adiciona o registro de exclusões da cobertura do app`).

### Task 10: Captura com sessão de edição e salvamento automático

**Files:**
- Modify: `App/Fontes/Captura/CapturaAberta.swift`, `App/Fontes/Captura/FluxoDeCaptura.swift`, `App/Fontes/Janelas/GerenciadorDeJanelas.swift`, `App/Fontes/CaptaApp.swift`
- Create: `App/Fontes/Editor/SalvamentoAutomatico.swift`, `App/Fontes/DelegadoDoApp.swift`
- Test: `App/Testes/SalvamentoAutomaticoTests.swift`, `App/Testes/CapturaAbertaTests.swift` (ampliar), `App/Testes/GerenciadorDeJanelasTests.swift` (ampliar), `App/Testes/DublesDeCaptura.swift` (relógio falso)

**Interfaces:**
- Produces:
  - `enum EstadoDoSalvamento: Equatable { case salvo, pendente, salvando, falhou }`.
  - `@MainActor final class SalvamentoAutomatico { typealias Gravador = @Sendable (Documento, URL) async throws -> Void; init(atraso: Duration = .seconds(2), dormir: @escaping @Sendable (Duration) async throws -> Void, gravar: @escaping Gravador); private(set) var estado: EstadoDoSalvamento; func agendar(_ documento: Documento, em url: URL); func salvarAgora() async }` — cada `agendar` reinicia a espera; ao fim grava o **último** documento agendado; nunca duas gravações ao mesmo tempo (a nova espera a em curso); `salvarAgora` cancela a espera, grava o pendente se houver e espera a em curso terminar; falha → `estado = .falhou` e o próximo `agendar` tenta de novo.
  - `CapturaAberta` (mantém o que tem): `private(set) var sessao: SessaoEdicao`; `var documento: Documento { sessao.documento }`; `var podeDesfazer`, `var podeRefazer`; `@discardableResult func aplicar(_ edicao: Edicao) -> Bool` (inválida: registro, `false`, nada muda); `func desfazer()`, `func refazer()`; `func salvarAgora() async`; `var estadoDoSalvamento: EstadoDoSalvamento`. Toda mudança do documento agenda o salvamento quando o rascunho está `.gravado(url)`; se está `.gravando`, agenda assim que virar `.gravado`; se está `.falhou`, o primeiro salvamento tenta criar o rascunho de novo com `Rascunho.gravar` e o documento atual (spec §4.8), e o aviso continua se falhar. Copiar e salvar PNG/Capta passam a usar o documento atual.
  - Gravador padrão (fora da *main actor*): renderiza, `Miniatura.gerar`, `CodificadorPNG.codificar(escala: 1)` e `PacoteCapta.atualizar(documento, miniaturaDados:, em:)`.
  - `GerenciadorDeJanelas`: guarda a `CapturaAberta` de cada janela; `windowWillClose` dispara `salvarAgora()` (a `Task` segura a captura até terminar); `func salvarTodas() async`. `DelegadoDoApp: NSObject, NSApplicationDelegate` com `applicationShouldTerminate` → `.terminateLater` e `NSApp.reply(toApplicationShouldTerminate: true)` depois de `salvarTodas()`; ligado em `CaptaApp` por `@NSApplicationDelegateAdaptor` (conferir no SDK como entregar o gerenciador ao delegado).

- [ ] **Step 1: Testes que falham** (relógio falso: `dormir` que só retorna quando o teste avança):
  - `agendarVariasVezesGravaSoOUltimo`; `esperaOAtrasoAntesDeGravar`; `salvarAgoraGravaOPendenteSemEsperar`; `salvarAgoraEsperaAGravacaoEmCurso`; `gravacoesNuncaSeSobrepoem`; `falhaMudaOEstadoEOProximoAgendarTentaDeNovo`.
  - `CapturaAberta`: `aplicarInvalidaNaoMudaNadaNemAgenda`; `desfazerERefazerAgendam`; `edicaoDuranteGravandoSalvaQuandoORascunhoTerminar`; `rascunhoQueFalhouERecriadoNoPrimeiroSalvamento`; `copiarUsaODocumentoAtual` (o PNG copiado tem a anotação recém-aplicada).
  - `GerenciadorDeJanelas`: `fecharAJanelaSalvaOPendente`; `salvarTodasEsperaTodas`.
- [ ] **Step 2: Rodar** `make cobertura-app` → Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** `make verificar` e `make cobertura-app` → Expected: PASS. Commit (`feat(app): salva sozinho o rascunho e desfaz e refaz na captura`).

### Task 11: Canvas — zoom, composição e vista

**Files:**
- Create: `App/Fontes/Editor/Zoom.swift`, `App/Fontes/Editor/ComposicaoDoCanvas.swift`, `App/Fontes/Editor/EditorDaCaptura.swift`, `App/Fontes/Editor/MemoriaLembrada.swift`, `App/Fontes/Editor/VistaDoCanvas.swift`
- Modify: `ferramentas/cobertura-app.exclusoes` (`VistaDoCanvas.swift`, motivo: eventos de mouse, teclado e gesto e desenho AppKit, coberto pela lista manual; a regra mora no núcleo e no `EditorDaCaptura`)
- Test: `App/Testes/ZoomTests.swift`, `ComposicaoDoCanvasTests.swift`, `EditorDaCapturaTests.swift`, `MemoriaLembradaTests.swift`

**Interfaces:**
- Produces:
  - `enum Zoom { static let niveis: [Double] = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4]; static func acima(de atual: Double) -> Double; static func abaixo(de atual: Double) -> Double; static func limitado(_ valor: Double) -> Double }` — 100 % = a imagem em pontos (pixels ÷ escala), como o `Enquadramento` de hoje; "ajustar" usa `Enquadramento.escala(..., modo: .ajustar)` e pode ficar abaixo de 25 % numa imagem enorme.
  - `struct ConversaoDoCanvas: Equatable { init(zoom: Double, escala: Double, origem: CGPoint = .zero); func pixel(de ponto: CGPoint) -> CGPoint; func ponto(de pixel: CGPoint) -> CGPoint; func pixels(dePontos: CGFloat) -> CGFloat }` — `origem` é o canto do recorte (zero nesta fatia; o 5b o usa).
  - `@MainActor final class ComposicaoDoCanvas { init(base: CGImage, renderizador: Renderizador) throws; func atualizar(para documento: Documento) throws -> CGImage }` — a primeira chamada compõe tudo; as seguintes usam `areaAlterada(desde:)` e `compor(area:)`; `nada` devolve a imagem anterior sem recompor.
  - `@MainActor @Observable final class EditorDaCaptura { init(captura: CapturaAberta, memoria: MemoriaLembrada, novoId: @escaping () -> UUID = UUID.init); let captura; private(set) var estado: EstadoDoEditor; private(set) var previa: Documento?; var documentoExibido: Documento { previa ?? captura.documento }; var zoom: Double; func tratar(_ evento: EventoDoEditor, conversao: ConversaoDoCanvas); func desfazer(); func refazer() }` — `tratar` monta o `ContextoDoEditor` com `tolerancia = conversao.pixels(dePontos: 4)` e `distanciaDoGiro = conversao.pixels(dePontos: 20)`; `.previa(e)` → `previa = try? captura.sessao.simular(e)`; `.aplicar(e)` → `captura.aplicar(e)` e `previa = nil`; `.cancelarPrevia` → `previa = nil`; toda mudança de `estado.memoria` grava na `MemoriaLembrada`. `desfazer`/`refazer` mandam `.sincronizar` depois.
  - `@MainActor final class MemoriaLembrada { init(defaults: UserDefaults); var memoria: MemoriaDeEstilos }` — chave `editor.memoriaDeEstilos`, JSON; ausente ou ilegível → `.padrao`.
  - `VistaDoCanvas: NSView` (vertical invertido) dentro de um `NSScrollView`, por `NSViewRepresentable` (`CanvasDoEditor`): desenha a imagem da `ComposicaoDoCanvas` no zoom, contorno da seleção, alças de 8 pt, ponto de giro e o retângulo de seleção com `Tema.Overlay.destaque`; mouse → `.pressionar/.arrastar/.soltar` com `⇧`; `magnify(with:)` muda o zoom; teclas: `Esc`, setas (`⇧` = 10 px), `⌫`/`⌦` excluir, `V` Seleção, `A` Seta, `L` Linha, `R` Forma, `H` Realce. Pede o primeiro respondedor ao abrir.

- [ ] **Step 1: Testes que falham:**
  - `Zoom`: `acimaDe100E150`, `acimaDe400Fica400`, `abaixoDe25Fica25`, `acimaDeValorEntreNiveisVaiAoProximo` (0.6 → 0.75), `limitadoPrende`.
  - `ConversaoDoCanvas`: escala 2, zoom 0.25 → `pixels(dePontos: 4) == 32`; zoom 4 → `2`; `pixel(de: ponto(de: p)) == p`.
  - `ComposicaoDoCanvas`: `atualizarComMudancaPequenaIgualAoRenderInteiro`; `semMudancaDevolveAMesmaImagem` (mesmo objeto `CGImage`, `===`).
  - `EditorDaCaptura`: `arrastarCriaPreviaESoltarAplica` (uma entrada no desfazer); `escNoMeioDoArrastoTiraAPrevia`; `desfazerNoMeioDoArrastoTiraAPreviaESincroniza`; `desfazerACriacaoTiraOObjetoDaSelecao`; `trocarDeFerramentaNoMeioDoArrastoCancela`; `cliqueEmLinhaFinaComZoom25E400Acerta` (linha de 1 px; clique a 3 pt da linha acerta nos dois zooms, a 5 pt não); `alterarEstiloGravaNaMemoriaLembrada`.
  - `MemoriaLembrada`: `semValorDevolvePadrao`, `valorIlegivelDevolvePadrao`, `gravaEle`.
- [ ] **Step 2: Rodar** `make cobertura-app` → Expected: FAIL.
- [ ] **Step 3: Implementar** (a vista por último, sem lógica além da tradução de eventos e do desenho).
- [ ] **Step 4: Rodar** `make verificar` e `make cobertura-app` → Expected: PASS. Commit (`feat(app): adiciona o canvas do editor com zoom e seleção`).

### Task 12: Janela do editor

**Files:**
- Create: `App/Fontes/Editor/JanelaDoEditorView.swift`, `App/Fontes/Editor/PainelDePropriedadesView.swift`
- Delete: `App/Fontes/Janelas/JanelaDeCapturaView.swift` (a barra de ações, o aviso, a confirmação e a alternância de exibição passam para a janela nova)
- Modify: `App/Fontes/Janelas/GerenciadorDeJanelas.swift` (`mostrarCaptura` monta `EditorDaCaptura` e `JanelaDoEditorView`; `Enquadramento.alturaDaBarra` passa a somar barra e rodapé), `App/Fontes/Janelas/Enquadramento.swift`, `App/Recursos/Localizable.xcstrings`, `ferramentas/cobertura-app.exclusoes` (as duas views, motivo: layout SwiftUI sem asserção; a lógica está no `EditorDaCaptura` e no núcleo)
- Test: `App/Testes/GerenciadorDeJanelasTests.swift` (a janela abre com o editor), `App/Testes/EditorDaCapturaTests.swift` (ações dos atalhos)

**Interfaces:**
- Consumes: `EditorDaCaptura`, `CapturaAberta` (Tarefas 10 e 11), `CorRGBA.paleta` e `Tema.Anotacao.*` na **mesma ordem**.
- Produces (como no protótipo "captura aberta" e "seta e propriedades"):
  - **Barra:** Seleção, Seta, Linha, Forma (menu com retângulo, retângulo arredondado, elipse), Realce · Desfazer (`⌘Z`), Refazer (`⇧⌘Z`) · à direita **Exportar ▾** (Salvar como PNG…, Salvar como Capta…) e **Copiar** (botão principal, `⌘C`, copia a imagem renderizada). O aviso de rascunho não guardado e a confirmação "Copiado"/"Salvo" continuam como hoje.
  - **Painel** (largura 232 pt): título "Propriedades · " seguido do nome da ferramenta ou do tipo selecionado; Cor (8 círculos da paleta); Largura (controle deslizante 0–40 px, valor em `px`); Opacidade (0–100 %); Tracejado (seta, linha, forma); Preenchimento (forma: "Sem preenchimento" + paleta); realce só com cor e opacidade. Sem seleção e com Seleção ativa: a dica do protótipo. Cada mudança manda `.alterarEstilo`.
  - **Rodapé:** zoom em % (menu com os níveis, "Ajustar à janela" `⌘9`, "Tamanho real" `⌘0`; `⌘+`/`⌘-`), tamanho `L × A @Nx` da saída e o estado do salvamento ("Salvo automaticamente", "Salvando…", ou o aviso).
  - Menu de comandos com `⌘A` (selecionar tudo) e `⌘D` (duplicar). Todo controle com rótulo de acessibilidade; VoiceOver anuncia a ferramenta escolhida.

- [ ] **Step 1: Testes que falham:** `mostrarCapturaAbreAJanelaComOEditor` (a `NSWindow` tem `NSHostingController<JanelaDoEditorView>`); `fecharAJanelaDoEditorSalva`; no `EditorDaCaptura`, `duplicarPeloComandoSelecionaAsCopias` e `selecionarTudoPeloComando`.
- [ ] **Step 2: Rodar** `make cobertura-app` → Expected: FAIL.
- [ ] **Step 3: Implementar**, textos no String Catalog, cores por `Tema.*`.
- [ ] **Step 4: Rodar** `make verificar` e `make cobertura-app` → Expected: PASS. Commit (`feat(app): troca a janela de resultado pelo editor`).

### Task 13: Capturas recentes no menu

**Files:**
- Modify: `App/Fontes/Menu/EstadoDoMenu.swift`, `App/Fontes/CaptaApp.swift`, `App/Fontes/Captura/FluxoDeCaptura.swift`, `App/Fontes/Captura/Apresentador.swift`, `App/Fontes/Janelas/GerenciadorDeJanelas.swift`
- Test: `App/Testes/FluxoDeCapturaRecentesTests.swift`, `App/Testes/MenuEFiacaoTests.swift` (ampliar), `App/Testes/MensagemDeErroTests.swift` (ampliar)

**Interfaces:**
- Consumes: `CapturasRecentes.listar`, `PacoteCapta.ler`, `CodificadorPNG.decodificar` (Tarefa 8).
- Produces:
  - `MensagemDeErro.naoFoiPossivelAbrir` → "Não foi possível abrir a captura."
  - `Apresentador.trazerParaFrente(_ url: URL) -> Bool` — `true` se havia janela daquele pacote e ela veio para a frente.
  - `FluxoDeCaptura.abrirRecente(_ url: URL) async` — se `trazerParaFrente` → fim; senão lê o pacote e decodifica a base **fora da *main actor***, monta a `CapturaAberta` com `rascunho: .gravado(url)`, nome = nome do pacote, escala = `documento.escala`, e mostra; qualquer erro (corrompido, versão mais nova, apagado) → registro e alerta `.naoFoiPossivelAbrir`, sem escrever nada no pacote.
  - `EstadoDoMenu.recentes: [CapturaRecente]` e `func atualizarRecentes(em pasta: URL)`; no `CaptaApp`, `Menu("Capturas recentes")` entre os itens de captura e "Sair", com um botão por captura e "Nenhuma captura" desabilitado se vazio. A lista é relida a cada abertura do menu; conferir no SDK se o conteúdo do `MenuBarExtra` é reavaliado ao abrir e, se não for, atualizar depois de cada rascunho gravado, salvamento e abertura do app.

- [ ] **Step 1: Testes que falham:** `abrirRecenteMostraOEditorComORascunhoGravado`; `abrirRecenteJaAbertoTrazParaAFrenteSemOutraJanela`; `abrirRecenteCorrompidoAlertaENaoTocaOPacote` (bytes e datas iguais); `abrirRecenteDeVersaoMaisNovaAlerta`; `abrirRecenteApagadoAlerta`; `abrirRecenteV1MigraEOProximoSalvamentoGravaV2`; `atualizarRecentesPreencheOEstado`; texto da mensagem nova.
- [ ] **Step 2: Rodar** `make cobertura-app` → Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** `make verificar` e `make cobertura-app` → Expected: PASS. Commit (`feat(app): reabre capturas recentes pelo menu`).

### Task 14: Fechamento — lista manual, desempenho, piso e verificação com o Pedro

**Files:**
- Create: `docs/verificacao-manual-editor.md`
- Modify: `ferramentas/cobertura.pisos` (`App=`, em commit próprio), este plano (status ao fim)

- [ ] **Step 1: Escrever `docs/verificacao-manual-editor.md`**, um item marcável por linha: cada ferramenta (seta, linha, as três formas, realce) com mouse e trackpad e com `⇧`; mover, redimensionar, girar, excluir, duplicar e setas; seleção por retângulo e com `⇧`; desfazer e refazer de cada gesto num passo só; zoom 25 % e 400 %, pinça, `⌘0`, `⌘9`, em tela Retina e 1x; propriedades e memória por ferramenta depois de reabrir o app; salvar ao fechar e com `⌘Q` logo depois de uma edição (reabrir e conferir); Capturas recentes (abrir, abrir a mesma de novo, abrir uma v1 gravada antes desta fatia, apagar uma pelo Finder com o menu aberto); copiar e salvar PNG com anotações e conferir no Preview; tema escuro e Reduzir transparência; VoiceOver na barra e no painel; desempenho: arrastar um objeto numa captura 5K com 30 objetos e 2 desfoques, medindo com Instruments ou o registro (meta 60 fps, medir sem prometer; abaixo disso, registrar o número no status, sem bloquear).
- [ ] **Step 2: Rodar `make cobertura-app`**, anotar o valor de `App/Fontes` e ajustar `App=` (não desce; sobe só em commit próprio, `test(app): sobe o piso de cobertura do app`).
- [ ] **Step 3: Rodar `make verificar` e `make cobertura-app`** → Expected: PASS. Commit (`docs: adiciona a lista de verificação manual do editor`).
- [ ] **Step 4: 🔒 Pedir ao Pedro** para rodar `make app && open build/Capta.app` e percorrer a lista; registrar as falhas no status deste plano.
- [ ] **Step 5: 🔒 `git push`** só depois da confirmação; conferir `gh run list --limit 1` → `success`; se o piso do app medido na CI for menor que o local, ajustar `App=` ao da CI em commit próprio.

---

## Auto-revisão

- **Cobertura da spec (Plano 5a, §7 item 1):** esquema v2 e migração (T1, com o desvio declarado acima); `Edicao.lote` (T2); limites, acerto e alças (T3, T4); renderizador com área suja (T5); janela do editor no lugar da de resultado (T12); canvas com zoom (T11); Seleção com mover, redimensionar, girar, excluir e duplicar (T4, T6, T11); desfazer e refazer (T2, T10, T11); salvar sozinho, inclusive ao fechar, ao sair e com rascunho que falhou (T10); Capturas recentes (T8, T13); Seta, Linha, Forma e Realce com propriedades e memória por ferramenta (T7, T12); registro de exclusões do app antes do canvas (T9); lista manual e desempenho (T14). **Fica para o 5b e o 5c, de propósito:** texto, callout, caneta, etapa, carimbo, desfoque e recorte como ferramentas; ponta, fonte, alinhamento e rótulo no painel; copiar e colar objetos; ordem das camadas e alinhar na interface; agrupar, bloquear, achatar; girar, espelhar e redimensionar a imagem; Tab entre objetos.
- **Consistência de tipos:** `Edicao` (com `.lote`), `SessaoEdicao.simular`, `AlcaDeObjeto`, `Ferramenta`, `EventoDoEditor`, `AcaoDoEditor`, `ContextoDoEditor`, `EstadoDoEditor`, `MemoriaDeEstilos`, `AreaASerRedesenhada`, `CapturaRecente`, `SalvamentoAutomatico`, `EstadoDoSalvamento`, `ConversaoDoCanvas`, `ComposicaoDoCanvas` e `EditorDaCaptura` têm a mesma assinatura entre a tarefa que os define e as que os usam.
- **Escolhas do plano que a spec deixou ao construtor:** atalhos de letra `V A L R H`, `⌘9` e `⌘0` (como no Preview); padrões de estilo por ferramenta; forma sem preenchimento só acerta no contorno; criação abaixo da tolerância é descartada; a ferramenta continua ativa depois de criar; a composição do canvas é um bitmap do tamanho da base atualizado por área.

---

## Status

Tarefas 1 a 14 (passos 1 a 3) concluídas na branch `plano-5a-editor`. **Pendentes do Pedro:** passo 4 (rodar `make app && open build/Capta.app` e percorrer `docs/verificacao-manual-editor.md`, registrando aqui as falhas e o número de desempenho) e passo 5 (`git push`, conferir `gh run list --limit 1` e, se o piso do app medido na CI for menor que o local, ajustar `App=` em commit próprio).

**Números:** pacote com 452 testes em 33 suítes passando; cobertura do pacote acima do piso de 98 % (`CaptaNucleo` e `CaptaSistema` em 99,4 % na tarefa 12); `make cobertura-app` mede 94,1 % (2529/2688 linhas), e o piso `App=` subiu de 89 para 93 (folga de 1 ponto, provisório até a CI medir). Desempenho (5K, 30 objetos, 2 desfoques): ainda não medido, depende do passo 4.

**Decisões e desvios que vale conhecer:**

- Commits sem `Co-Authored-By` e sem menção a IA, com o autor do projeto, como manda o `CLAUDE.md`; trabalho num worktree fora da `main`; passos 🔒 não executados por agentes.
- Esquema v2 e migração na tarefa 1, com o desvio declarado no início do plano.
- Renderizador (T5): bitmap por objeto recortado nos limites em vez de camada de transparência, para manter a igualdade de pixels; número de etapa com 3 ou mais dígitos pode ser cortado (o 5b trata a etapa).
- Acerto (T11): a tolerância de 5 pt do plano era aritmeticamente inconsistente com o acerto do núcleo (a meia espessura do traço soma 1 a 2 pt na tela); valeu o teste de 3 pt acerta e 7 pt erra, independente do zoom.
- Gesto (T6/T7): o colapso da seleção ao soltar é decidido por `moveu`, não pelo deslocamento final; só afeta arrastar para fora e voltar ao ponto exato.
- Fechamento sem perda (T10/T13): as bordas de "última edição perdida" (⌘Q durante o rascunho inicial, rascunho que falha, `salvarCapta` com flush falho) foram tratadas na tarefa 13.
- A janela do editor ficou mais larga que o brief pedia (inclui o painel de 232 pt); atalhos de zoom e seleção vivem em botões invisíveis porque o app não tem menu próprio.
- Capturas recentes: plano B implementado (a lista é relida depois do rascunho, a cada salvamento e ao iniciar), porque a reavaliação do `MenuBarExtra` ao abrir não foi confirmada; abrir uma recente não muda a ordem.

**Revisão final:** a onda de correções da revisão final corrigiu a corrida ao reabrir uma recente enquanto a janela fechada ainda grava (`aguardarFechamentos`) e a memória de estilos sobrescrita por cópias velhas com várias janelas (grava só quando o evento a muda); também alargou a folga das alças para cobrir o quadrado de 8 pt, contou a metade de fora do traço no acerto de forma preenchida e cobriu o cancelamento da prévia de criação. Os menores da tarefa 11 (renderizador compartilhado, estado de composição velho, constante do giro e mutação do zoom de layout) e os comandos de teclado no meio do arraste (o `EstadoDoEditor` cancela o gesto) já estão resolvidos. Recomendado: um menu Comandos para os atalhos antes da ferramenta de texto do 5b, e um teste de igualdade de pixels com intensidade 100 do desfoque antes da ferramenta de desfoque do 5c.

**Menores adiados (para o 5b/5c ou limpeza):** seta e linha ignoram a rotação em limites e acerto; elipse com acerto aproximado; três cópias da matemática de rotação (Alças, Limites, distância do giro); sliders sem prévia ao vivo; `compor` engole falha de alocação com `try?`; `salvarAgora` espera sem limite se um gravador de rascunho nunca terminar; helpers de teste do esquema v2 emprestados do v1 congelado; extensão `.capta` comparada com diferença de caixa e pacotes por link simbólico ignorados no registro de recentes; `GerenciadorDeJanelas` com 79 % de cobertura (alertas e reinício, já sem teste antes).
