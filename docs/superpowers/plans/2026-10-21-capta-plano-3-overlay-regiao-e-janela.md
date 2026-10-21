# Capta — Plano 3: Overlay de região e janela

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar a captura livre: `⌃⌥C` congela todas as telas, o Pedro escolhe uma região ou uma janela (com mira, dimensões, lupa de pixels, atraso e cursor), e o resultado cai na janela de captura da fatia 3.

**Architecture:** Toda a lógica que não precisa de tela (geometria da seleção, janelas, lupa, contagem, máquina de estados do overlay) vira valor puro em `CaptaNucleo`, com TDD. O protocolo `Capturador` cresce (congelar telas, listar janelas, captura ao vivo de região e de janela) e `CapturadorSC` o implementa na casca. O app ganha janelas de overlay finas que só traduzem eventos para a máquina de estados e desenham o estado, e o `FluxoDeCaptura` ganha o caminho "livre" reaproveitando o fim do caminho da fatia 3.

**Tech Stack:** Swift 6.4 (modo 6), SwiftPM, XcodeGen, Swift Testing, ScreenCaptureKit, AppKit/SwiftUI, Carbon (só `RegisterEventHotKey`).

**Spec:** `docs/superpowers/specs/2026-10-21-capta-overlay-regiao-e-janela-design.md`. Spec de origem: `docs/superpowers/specs/2026-10-20-capta-mvp-design.md` (§4.2, §4.3, §4.8). Padrões: `docs/padroes-stack-swift.md`. Leia os três antes de começar.

## Global Constraints

- macOS **14+**; Swift 6 em modo de linguagem 6; **aviso tratado como erro**; **nenhuma dependência de terceiros**.
- **App Sandbox ligado**; entitlements **só** `app-sandbox` e `files.user-selected.read-write`; **sem rede**, sem conta, sem telemetria; **nenhuma permissão além de Gravação de Tela** (nada de Acessibilidade nem Monitoramento de Entrada: as teclas do overlay chegam pela janela do próprio app).
- `CaptaNucleo` importa só Foundation, CoreGraphics, CoreText, CoreImage, ImageIO e UniformTypeIdentifiers; nunca SwiftUI, AppKit, ScreenCaptureKit ou Vision.
- Coordenadas: o documento e a seleção ficam em **pixels nativos**, origem no canto superior esquerdo, Y para baixo; quadros de tela e de janela ficam em **pontos no espaço global** (origem no topo da tela principal).
- Domínio, comentários, docs e commits em **pt-BR**; sem `!`, `try!` nem IUO em produção. Texto de interface só pelo String Catalog; cor só por `Tema.*`; nada de erro técnico ou em inglês na interface; nada sensível em log.
- TDD: teste que falha primeiro, com Swift Testing. Cobertura do pacote ≥ **98 %** por alvo; **nunca descer um piso**; subir piso vai em commit próprio. Casca sem teste automático entra em `ferramentas/cobertura.exclusoes` com o motivo (só sob `CaptaSistema/Casca/`).
- **`make verificar` passa antes de todo commit.** Comandos sempre pelo `make` (`make test`, `make cobertura-app`). Nunca `swift test` puro, nunca `sudo xcode-select`.
- Commits em Conventional Commits, descrição em pt-BR, autor e committer `Pedro Teixeira <noreply@pedroct.com.br>` (já configurado no repositório), **sem `Co-Authored-By` e sem menção a IA**, nunca `--no-verify`.
- `git push` pede confirmação do Pedro; o passo marcado 🔒 pausa para isso.
- Antes de usar uma API do ScreenCaptureKit, AppKit ou Carbon, conferir a assinatura e o comportamento no SDK do Xcode-beta; o plano nomeia a API, não garante a assinatura.
- Atalhos fixos: `⌃⌥C` (captura livre, código de tecla `8`) e o `⌃⌥F` que já existe. Atraso: nenhum, 3, 5 ou 10 s. Lupa: 8× de ampliação inicial. `Espaço` alterna região e janela; `Esc` cancela; setas movem 1 px nativo e `⇧`+setas 10 px.

## Review Focus

1. **Seleção em tela de escala 1,5 ou com origem negativa, ou arrasto que sai da tela:** o retângulo mostrado e o capturado são os mesmos pixels, e a seleção nunca sai da tela. → Tarefas 2 e 3.
2. **Janelas sobrepostas, ponto sem janela, janela entre duas telas:** realça a mais à frente; a tela da janela é a de maior interseção. → Tarefa 4.
3. **Overlay sem foco, app desativado, telas mudando com o overlay aberto:** o overlay nunca prende o usuário. → Tarefas 1, 7 e 10.
4. **Atraso: janela que some, tela que muda de escala, contagem cancelada, permissão revogada na captura ao vivo:** nada é gravado e o erro é em pt-BR. → Tarefa 12.
5. **Lista de janelas indisponível (modo janela pedido):** abre só em modo região, sem erro. → Tarefa 12.

---

## Mapa de arquivos

```text
Packages/CaptaNucleo/Sources/CaptaNucleo/
  Captura/{DescricaoDeTela,SelecaoDeTela}.swift     (movidos de CaptaSistema; + conversão pixels↔pontos)
  Captura/Captura.swift                             (alterado: Capturador ampliado, ErroCaptura, TelaCongelada)
  Overlay/{SelecaoDeRegiao,Janelas,Lupa,Posicionamento,ContagemRegressiva,EstadoDoOverlay}.swift   (novos)
  Imagem/RecorteDeImagem.swift                      (novo)
Packages/CaptaNucleo/Sources/CaptaSistema/Casca/{CapturadorSC,AtalhoGlobalCarbon}.swift   (alterados)
App/Fontes/Overlay/{JanelaDeOverlay,VistaDoOverlay,GerenciadorDoOverlay,JanelaDaContagem}.swift   (novos)
App/Fontes/Captura/{FluxoDeCaptura,OpcoesLembradas}.swift   (alterado / novo)
App/Fontes/CaptaApp.swift, App/Recursos/Localizable.xcstrings   (menu, atalhos, textos)
docs/verificacao-manual-overlay.md                  (novo)
```

---

## Parte A — Prova de foco (bloqueia o resto do overlay)

### Task 1: Atalho `⌃⌥C` e casca mínima do overlay que fecha com `Esc`

Spec §4.9: se o teclado não chegar ao overlay num app de barra de menus, o overlay prende o usuário. Provar isso primeiro, com o disparo por atalho global (app inativo).

**Files:**
- Modify: `Packages/CaptaNucleo/Sources/CaptaNucleo/Exportacao/ProtocolosDeSistema.swift` (+ `CombinacaoDeTeclas.capturaLivre`), `Packages/CaptaNucleo/Sources/CaptaSistema/Casca/AtalhoGlobalCarbon.swift`, `App/Fontes/CaptaApp.swift`
- Create: `App/Fontes/Overlay/JanelaDeOverlay.swift`, `App/Fontes/Overlay/GerenciadorDoOverlay.swift`
- Test: `Packages/CaptaNucleo/Tests/CaptaNucleoTests/ExportadorTests.swift` ou arquivo novo `CombinacaoDeTeclasTests.swift`

**Interfaces:**
- Produces: `CombinacaoDeTeclas.capturaLivre` (`codigoDaTecla: 8`, `[.controle, .opcao]`); `JanelaDeOverlay: NSPanel` (sem borda, `canBecomeKey == true`, nível acima da barra de menus, em todos os Spaces e sobre apps em tela cheia); `@MainActor final class GerenciadorDoOverlay { func abrir(aoFechar: @escaping @MainActor () -> Void); func fechar() }` — uma `JanelaDeOverlay` escura por `NSScreen`; `Esc` fecha; perder a ativação do app fecha; clicar em qualquer janela do overlay devolve o foco. (A assinatura de `abrir` muda na Tarefa 10.)

- [ ] **Step 1: Teste que falha** (`CombinacaoDeTeclasTests`): `capturaLivreEControleOpcaoC` → `codigoDaTecla == 8`, `modificadores == [.controle, .opcao]`; `capturaLivreDifereDaTelaInteira` → `capturaLivre != capturarTelaInteira`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL (símbolo não definido).
- [ ] **Step 3: Implementar** `capturaLivre`. Em `AtalhoGlobalCarbon`, hoje cada instância ignora qual atalho disparou (o handler chama `executar()` para qualquer `kEventHotKeyPressed`): com duas instâncias, `⌃⌥C` rodaria as duas ações. Dar a cada instância um `id` próprio (contador estático protegido por trava) no `EventHotKeyID`, ler o `EventHotKeyID` do evento com `GetEventParameter` e só executar se o id for o da instância, devolvendo `eventNotHandledErr` nos outros.
- [ ] **Step 4: Implementar a casca mínima** (`JanelaDeOverlay`, `GerenciadorDoOverlay`) e ligar em `CaptaApp`: uma segunda `AtalhoGlobalCarbon` para `.capturaLivre` que chama `GerenciadorDoOverlay.abrir`; falha de registro marca o aviso no menu (uma flag por atalho em `EstadoDoMenu`). Provisório: o overlay só mostra um painel escuro por tela. Ativar o app (`NSApp.activate`) ao abrir; observar a desativação (`NSApplication.didResignActiveNotification`) e fechar.
- [ ] **Step 5: Rodar:** `make verificar` → Expected: PASS. Commit (`feat(app): adiciona o atalho de captura livre e a casca do overlay`).
- [ ] **Step 6: 🔒 Pedir ao Pedro** para rodar `make app && open build/Capta.app` e conferir: `⌃⌥C` cobre todas as telas, inclusive barra de menus e Dock; `Esc` fecha na hora (com o app inativo antes do atalho); clicar em outro app ou usar `⌘Tab` fecha o overlay; `⌃⌥F` ainda captura sem disparar o overlay, e `⌃⌥C` não dispara a captura da tela inteira; com um app em tela cheia e com outro Space, o overlay aparece e fecha. **Se o `Esc` falhar, parar e voltar ao Pedro: é bloqueante (spec §4.9).** Registrar o resultado no status do plano.

---

## Parte B — Núcleo (lógica pura, TDD)

### Task 2: Tela e conversão entre pontos e pixels no núcleo

`DescricaoDeTela` e `SelecaoDeTela` hoje estão em `CaptaSistema`, mas a máquina de estados do núcleo precisa deles.

**Files:**
- Move: `Packages/CaptaNucleo/Sources/CaptaSistema/Captura/SelecaoDeTela.swift` → `Packages/CaptaNucleo/Sources/CaptaNucleo/Captura/SelecaoDeTela.swift` (mesma API pública); `Tests/CaptaSistemaTests/SelecaoDeTelaTests.swift` → `Tests/CaptaNucleoTests/`
- Modify: `Packages/CaptaNucleo/Sources/CaptaSistema/Casca/CapturadorSC.swift` (só o que o `import CaptaNucleo` já cobre)
- Test: `Packages/CaptaNucleo/Tests/CaptaNucleoTests/ConversaoDeTelaTests.swift`

**Interfaces:**
- Produces, em extensão de `DescricaoDeTela`:
  - `func pixelLocal(dePonto ponto: CGPoint) -> CGPoint` — `(ponto - quadro.origin) * escala`, sem arredondar.
  - `func pixels(dePontos retangulo: CGRect) -> CGRect` — converte e **arredonda cada lado ao pixel mais próximo**, origem local da tela.
  - `func quadroEmPontos(dePixels pixels: CGRect) -> CGRect` — inverso, no espaço global.
  - `var limitesEmPixels: CGSize?` — `tamanhoEmPixels` como `CGSize`.

- [ ] **Step 1: Mover** os dois tipos e o teste existente; `make test` → Expected: PASS (refatoração sem mudança de comportamento).
- [ ] **Step 2: Testes que falham** (`ConversaoDeTelaTests`), com `DescricaoDeTela(id: 1, quadro: CGRect(x: -1440, y: 0, width: 1440, height: 900), escala: 2, principal: false)`:
  - `pixelLocalDePontoEmTelaComOrigemNegativa`: ponto `(-1439.5, 10.25)` → `(1, 20.5)`.
  - `quadroEmPontosEPixelsSaoInversosEmEscalasComunsDeTodoRetanguloInteiro`: para escalas `1`, `1.5`, `2`, `3` e todo retângulo de pixels inteiro com origem e lados de 0 a 20 (lados ≥ 1), `pixels(dePontos: quadroEmPontos(dePixels: r)) == r`.
  - `meioPontoArredondaParaOPixelMaisProximo`: escala 2, retângulo em pontos `(10.25, 10.25, 5, 5)` → pixels `(20, 20, 10, 10)` relativos à origem da tela.
  - `limitesEmPixelsDevolveNilParaQuadroInvalido`.
- [ ] **Step 3: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 4: Implementar** as extensões em `SelecaoDeTela.swift`.
- [ ] **Step 5: Rodar:** `make verificar` → Expected: PASS. Commit (`refactor(nucleo): leva a descrição de tela para o núcleo e converte pontos e pixels`).

### Task 3: Seleção de região

**Files:**
- Create: `Packages/CaptaNucleo/Sources/CaptaNucleo/Overlay/SelecaoDeRegiao.swift`
- Test: `Packages/CaptaNucleo/Tests/CaptaNucleoTests/SelecaoDeRegiaoTests.swift`

**Interfaces:**
- Produces:
  - `enum Alca: Equatable, Sendable { case cima, baixo, esquerda, direita, cantoSuperiorEsquerdo, cantoSuperiorDireito, cantoInferiorEsquerdo, cantoInferiorDireito }`
  - `enum Acerto: Equatable, Sendable { case fora, dentro, borda(Alca) }`
  - `struct SelecaoDeRegiao: Equatable, Sendable { let telaId: UInt32; let pixels: CGRect; let limites: CGSize }` — `pixels` sempre inteiro, dentro de `(0,0,limites)`, com lados ≥ 1.
  - `static func arrasto(telaId: UInt32, limites: CGSize, de: CGPoint, ate: CGPoint) -> SelecaoDeRegiao?` — pontos em pixels locais (fracionários); qualquer direção; `floor` nas duas pontas; limita à tela; `nil` se a largura ou a altura ficar 0.
  - `static func telaInteira(telaId: UInt32, limites: CGSize) -> SelecaoDeRegiao`
  - `func movida(dx: Int, dy: Int) -> SelecaoDeRegiao` (presa à tela) · `func redimensionada(alca: Alca, para ponto: CGPoint) -> SelecaoDeRegiao` (a borda oposta fica fixa; ao cruzar, inverte; lado mínimo 1; presa à tela) · `func acerto(em ponto: CGPoint, tolerancia: CGFloat) -> Acerto` (cantos antes de bordas, bordas antes de dentro).

- [ ] **Step 1: Testes que falham** (tela `limites = 100×80`):
  - `arrastoEmQualquerDirecaoDaOMesmoRetangulo`: `de (10,10) ate (30,20)` e o inverso → `pixels == (10,10,20,10)`; `de (30,10) ate (10,20)` → `(10,10,20,10)`.
  - `arrastoComPontoFracionarioUsaFloor`: `de (10.9,10.9) ate (30.2,20.7)` → `(10,10,20,10)`.
  - `arrastoSaindoDaTelaFicaPresoNasBordas`: `de (90,70) ate (150,200)` → `(90,70,10,10)`; `de (-5,-5) ate (10,10)` → `(0,0,10,10)`.
  - `arrastoSemAreaDevolveNil`: `de (10,10) ate (10,30)` → `nil`; `de (10,10) ate (10,10)` → `nil`.
  - `movidaFicaPresaNaTela`: `(10,10,20,20)` `.movida(dx: -50, dy: 100)` → `(0,60,20,20)`.
  - `redimensionarMantemAOutraBordaFixa`: `(10,10,20,20)` alça `.direita` para `x=40.4` → `(10,10,30,20)`.
  - `redimensionarAlemDaBordaOpostaInverte`: `(10,10,20,20)` alça `.direita` para `x=5` → `(5,10,5,20)`; alça `.cantoSuperiorEsquerdo` para `(35,35)` → `(30,30,5,5)`.
  - `redimensionarNuncaDaLadoMenorQueUm`: alça `.direita` para `x=10` → largura `1`.
  - `acertoPrefereCantoDepoisBordaDepoisDentro` (seleção `(10,10,20,20)`, tolerância 3): `(10,10)` → `.borda(.cantoSuperiorEsquerdo)`; `(10,20)` → `.borda(.esquerda)`; `(12,12)` → `.borda(.cantoSuperiorEsquerdo)`; `(20,20)` → `.dentro`; `(50,50)` → `.fora`.
  - `telaInteiraCobreTodaATela`: `pixels == (0,0,100,80)`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** com aritmética inteira depois do `floor`; o redimensionar normaliza as duas pontas como o arrasto.
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS. Commit (`feat(nucleo): adiciona a seleção de região em pixels`).

### Task 4: Janelas selecionáveis

**Files:**
- Create: `Packages/CaptaNucleo/Sources/CaptaNucleo/Overlay/Janelas.swift`
- Test: `Packages/CaptaNucleo/Tests/CaptaNucleoTests/JanelasTests.swift`

**Interfaces:**
- Consumes: `DescricaoDeTela` (Tarefa 2).
- Produces: `struct JanelaDeTela: Equatable, Sendable { let id: UInt32; let quadro: CGRect; let camada: Int; let naTela: Bool }` (`quadro` em pontos globais). `enum ListaDeJanelas`:
  - `static func selecionaveis(_ janelas: [JanelaDeTela], tamanhoMinimo: CGFloat) -> [JanelaDeTela]` — fica quem tem `camada == 0`, `naTela` e os dois lados ≥ `tamanhoMinimo`; preserva a ordem (a primeira é a mais à frente).
  - `static func sob(_ ponto: CGPoint, em janelas: [JanelaDeTela]) -> JanelaDeTela?` — a primeira da lista que contém o ponto (borda esquerda/superior inclusivas).
  - `static func tela(de janela: JanelaDeTela, entre telas: [DescricaoDeTela]) -> DescricaoDeTela?` — maior área de interseção com `quadro`; empate: a tela que contém o canto superior esquerdo; sem interseção: `nil`.

- [ ] **Step 1: Testes que falham:**
  - `selecionaveisDescartaCamadaDeSistemaForaDaTelaEPequenas`: janelas com `camada` 0, 25 (Dock), 0 com `naTela: false`, 0 de `30×500` e `tamanhoMinimo: 40` → só a primeira fica.
  - `selecionaveisPreservaAOrdemDeEmpilhamento`.
  - `sobDevolveAJanelaMaisAFrenteEmSobreposicao`: duas janelas sobrepostas, a primeira da lista vence; ponto na parte só da segunda devolve a segunda.
  - `sobSemJanelaDevolveNil`; `sobNaBordaDireitaNaoContem` (borda direita/inferior exclusivas).
  - `telaDaJanelaEscolheAMaiorInterseccao`: janela com 70 % na tela B → B; `empateUsaACantoSuperiorEsquerdo`; `janelaForaDeTodasDevolveNil`; tela com origem negativa.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS. Commit (`feat(nucleo): adiciona a lista de janelas selecionáveis`).

### Task 5: Lupa, posicionamento e recorte da imagem congelada

**Files:**
- Create: `Packages/CaptaNucleo/Sources/CaptaNucleo/Overlay/Lupa.swift`, `Overlay/Posicionamento.swift`, `Imagem/RecorteDeImagem.swift`
- Test: `Tests/CaptaNucleoTests/{LupaTests,PosicionamentoTests,RecorteDeImagemTests}.swift`

**Interfaces:**
- Produces:
  - `enum Lupa { static func amostra(em centro: CGPoint, lado: Int, imagem: CGSize) -> CGRect }` — retângulo `lado×lado` em pixels centrado em `floor(centro)`, **deslocado para caber** na imagem; se a imagem for menor que `lado`, o retângulo é a imagem inteira.
  - `enum Posicionamento { static func origem(junto ponto: CGPoint, tamanho: CGSize, dentro limites: CGRect, afastamento: CGFloat) -> CGPoint }` — canto inferior direito do ponto; troca para a esquerda e/ou para cima quando não couber; nunca sai de `limites`. Serve à lupa, ao texto das dimensões e à ajuda.
  - `enum RecorteDeImagem { static func recortar(_ imagem: CGImage, pixels: CGRect) -> CGImage? }` — `nil` se o retângulo for vazio ou sair da imagem; pixel `(0,0)` da saída é o pixel `(x,y)` da base.

- [ ] **Step 1: Testes que falham:**
  - Lupa: `amostraNoMeioFicaCentrada` (centro `(50,50)`, lado 15, imagem 100×100 → `(43,43,15,15)`); `amostraNosQuatroCantosFicaDentro` (centro `(0,0)`, `(99,99)`, `(0,99)`, `(99,0)` → origem `(0,0)`/`(85,85)`/`(0,85)`/`(85,0)`); `imagemMenorQueOLadoDevolveAImagemInteira` (imagem 10×10, lado 15 → `(0,0,10,10)`).
  - Posicionamento: `preferePerToDoPontoAbaixoEADireita`; `trocaParaEsquerdaNaBordaDireita`; `trocaParaCimaNaBordaInferior`; `naoSaiDosLimitesComTamanhoMaiorQueOEspaco`.
  - Recorte (base 100×100 em xadrez de 2 px): `recorteTemOTamanhoPedidoEPixelCorrespondente` (`(10,10,30,20)` → 30×20 e pixel `(0,0)` igual ao `(10,10)` da base); `recorteForaOuVazioDevolveNil`; `recorteParcialmenteForaDevolveNil`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** (`CGImage.cropping(to:)` no recorte).
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS. Commit (`feat(nucleo): adiciona lupa, posicionamento e recorte da imagem congelada`).

### Task 6: Contagem regressiva

**Files:**
- Create: `Packages/CaptaNucleo/Sources/CaptaNucleo/Overlay/ContagemRegressiva.swift`
- Test: `Packages/CaptaNucleo/Tests/CaptaNucleoTests/ContagemRegressivaTests.swift`

**Interfaces:**
- Produces: `enum Atraso: Int, CaseIterable, Sendable { case nenhum = 0, tres = 3, cinco = 5, dez = 10 }` · `struct ContagemRegressiva: Sendable { init(segundos: Int, pausa: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }); func executar(aCadaSegundo: @escaping @Sendable (Int) -> Void) async -> Bool }` — chama `aCadaSegundo(n)` com `n` de `segundos` até `1` e devolve `true` ao fim; devolve `false`, sem chamar mais nada, se a `Task` for cancelada.

- [ ] **Step 1: Testes que falham** (pausa falsa que registra as durações): `contaDeNAUmEDevolveTrue` (`segundos: 3` → `[3,2,1]`, `true`, três pausas de 1 s); `cancelarNoMeioDevolveFalseESeParaDeChamar` (cancela a `Task` na segunda pausa → `false`, observador recebeu `[3,2]` no máximo); `zeroSegundosDevolveTrueSemChamar`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS. Commit (`feat(nucleo): adiciona a contagem regressiva do atraso`).

### Task 7: Máquina de estados do overlay

**Files:**
- Create: `Packages/CaptaNucleo/Sources/CaptaNucleo/Overlay/EstadoDoOverlay.swift`
- Test: `Packages/CaptaNucleo/Tests/CaptaNucleoTests/EstadoDoOverlayTests.swift`

**Interfaces:**
- Consumes: `SelecaoDeRegiao`, `Alca`, `Acerto` (T3), `ListaDeJanelas`, `JanelaDeTela` (T4), `DescricaoDeTela` e conversões (T2), `Atraso` (T6).
- Produces:
  - `enum ModoDoOverlay { case regiao, janela }` · `struct OpcoesDeCaptura: Equatable, Sendable { var atraso: Atraso; var incluirCursor: Bool }`.
  - `enum SelecaoConfirmada: Equatable, Sendable { case regiao(tela: DescricaoDeTela, pixels: CGRect); case janela(id: UInt32) }` · `enum ResultadoDoOverlay: Equatable, Sendable { case confirmado(SelecaoConfirmada, OpcoesDeCaptura); case cancelado }`.
  - `enum TeclaDoOverlay: Equatable, Sendable { case esc, f, espaco, enter, m, h; case seta(Direcao, grande: Bool) }` (`Direcao`: `.cima, .baixo, .esquerda, .direita`).
  - `enum EventoDoOverlay: Equatable, Sendable { case cursorMoveu(CGPoint); case mouseBaixo(CGPoint); case mouseArrastou(CGPoint); case mouseSolto(CGPoint); case tecla(TeclaDoOverlay); case opcoesMudaram(OpcoesDeCaptura); case telasMudaram; case perdeuAtivacao }` (pontos em pontos globais).
  - `struct EstadoDoOverlay: Equatable, Sendable { modo, telas: [DescricaoDeTela], janelas: [JanelaDeTela] (já filtradas), cursor: CGPoint, selecao: SelecaoDeRegiao?, janelaRealcada: JanelaDeTela?, lupaLigada: Bool, ajudaVisivel: Bool, opcoes: OpcoesDeCaptura, resultado: ResultadoDoOverlay? }`; `static func inicial(modo:telas:janelas:opcoes:ajudaVisivel:) -> EstadoDoOverlay` (sem janelas, `modo` cai para `.regiao`); `func reduzindo(_ evento: EventoDoOverlay) -> EstadoDoOverlay`. Depois de `resultado != nil`, todo evento é ignorado.

Regras: no modo região, `mouseBaixo` dentro de uma seleção ativa em `.dentro` ou `.borda` inicia mover/redimensionar (`mouseArrastou` aplica, `mouseSolto` termina), fora começa nova seleção; o arrasto fica preso à tela onde começou; no modo janela, `cursorMoveu` atualiza `janelaRealcada` por `ListaDeJanelas.sob`, `mouseBaixo` sobre uma janela confirma na hora, `enter` confirma a realçada; `f` confirma `telaInteira` da tela sob o cursor (`SelecaoDeTela.escolher`) nos dois modos; `espaco` alterna o modo (descarta a seleção ao ir para janela; só se houver janelas); setas só movem uma seleção ativa (1 ou 10 px); `enter` sem seleção ou realce não faz nada; `esc`, `telasMudaram` e `perdeuAtivacao` produzem `.cancelado`; `opcoesMudaram` troca as opções (o `incluirCursor` fica guardado mesmo com `atraso == .nenhum`).

- [ ] **Step 1: Testes que falham** (duas telas: A `(0,0,1000,800)` escala 2 principal, B `(1000,0,1000,800)` escala 1; janelas j1 `(100,100,300,300)` à frente de j2 `(50,50,400,400)`):
  - Região: `arrastarEmATelaGeraSelecaoEmPixelsNativos` (A: arrasto `(10,10)`→`(60,40)` → `pixels == (20,20,100,60)`); `arrastoQueSaiDaTelaFicaPresoNaTelaDeOrigem` (começa em A, termina em B → seleção termina na borda de A); `arrastarPorDentroMove`; `arrastarBordaRedimensiona`; `clicarForaComecaNovaSelecao`; `setaMoveUmPixelEComShiftDez`; `setaSemSelecaoNaoFazNada`; `enterConfirmaARegiaoComAsOpcoes`; `enterSemSelecaoNaoConfirma`.
  - Janela: `cursorSobreJanelaRealcaAMaisAFrente`; `cliqueNaJanelaConfirmaNaHora`; `enterConfirmaARealcada`; `cursorForaDeJanelaLimpaORealce`.
  - Modo e teclas: `espacoAlternaERegiaoEJanela`; `espacoSemJanelasNaoMudaDeModo`; `inicialComModoJanelaESemJanelasCaiParaRegiao`; `fConfirmaATelaSobOCursor` (cursor em B → `.regiao(tela: B, pixels: (0,0,1000,800))`); `mLigaEDesligaALupa`; `hAlternaAAjuda`; `escCancela`.
  - Segurança (Review Focus 3): `telasMudaramCancela`; `perdeuAtivacaoCancela`; `eventosDepoisDoResultadoSaoIgnorados`.
  - Opções: `opcoesMudaramTrocaAsOpcoes`; `incluirCursorFicaGuardadoSemAtraso`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** `reduzindo` como função pura sobre `self`, delegando a geometria às tarefas 2 a 4.
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS, cobertura ≥ 98 % em `CaptaNucleo`. Commit (`feat(nucleo): adiciona a máquina de estados do overlay`).

### Task 8: Contrato de captura ampliado

**Files:**
- Modify: `Packages/CaptaNucleo/Sources/CaptaNucleo/Captura/Captura.swift`, `Packages/CaptaNucleo/Sources/CaptaSistema/Casca/CapturadorSC.swift` (só o que for preciso para compilar: os métodos novos lançam `ErroCaptura.falhou` até a Tarefa 9), `App/Testes/DublesDeCaptura.swift`
- Test: `Packages/CaptaNucleo/Tests/CaptaNucleoTests/CapturaTests.swift`

**Interfaces:**
- Produces:
  - `struct TelaCongelada: @unchecked Sendable { let descricao: DescricaoDeTela; let imagem: CGImage }`
  - `ErroCaptura` ganha `.janelaNaoEncontrada` e `.tamanhoInesperado`.
  - `Capturador` ganha: `func congelarTelas() async throws -> [TelaCongelada]` · `func listarJanelas() async throws -> [JanelaDeTela]` (já na ordem da frente para trás) · `func capturarRegiao(em tela: DescricaoDeTela, pixels: CGRect, incluirCursor: Bool) async throws -> ImagemCapturada` (falha com `.telaNaoEncontrada` se a tela atual não for igual a `tela`) · `func capturarJanela(id: UInt32, incluirCursor: Bool) async throws -> ImagemCapturada`.
  - `extension ImagemCapturada { func conferindo(largura: Int, altura: Int) throws -> ImagemCapturada }` — `.tamanhoInesperado` se a imagem não tiver exatamente esse tamanho.
  - `func capturarTela(sobCursor:)` continua como está.

- [ ] **Step 1: Testes que falham:** `conferindoAceitaOTamanhoExato`; `conferindoRecusaUmPixelADiferenca` (largura +1 e altura −1, cada uma) → `ErroCaptura.tamanhoInesperado`; `telaCongeladaGuardaDescricaoEImagem`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** os tipos e estender o dublê de `App/Testes/DublesDeCaptura.swift` com resultados programáveis para os quatro métodos novos e registro das chamadas (tela, pixels, `incluirCursor`).
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS. Commit (`feat(nucleo): amplia o contrato de captura para região, janela e telas congeladas`).

---

## Parte C — Sistema

### Task 9: `CapturadorSC` com telas congeladas, janelas e captura ao vivo

**Files:**
- Modify: `Packages/CaptaNucleo/Sources/CaptaSistema/Casca/CapturadorSC.swift`; `Packages/CaptaNucleo/Sources/CaptaSistema/Captura/MapeadorDeErroDeCaptura.swift` (se faltar mapeamento)
- Test: `Packages/CaptaNucleo/Tests/CaptaSistemaTests/MapeadorDeErroDeCapturaTests.swift` (o que for lógica pura)

**Interfaces:**
- Consumes: contrato da Tarefa 8; `ListaDeJanelas.selecionaveis` (T4).
- Produces (casca, fora do portão, já listada em `cobertura.exclusoes`): as quatro funções do protocolo. Comportamento fixo pela spec:
  - `congelarTelas`: uma imagem por tela em pixels nativos, **em paralelo**, com o próprio app excluído (`excludingApplications` pelo PID, como já faz `capturarTela`).
  - `listarJanelas`: janelas de `SCShareableContent` com `quadro`, `camada` (`windowLayer`), `naTela` (`isOnScreen`) e a ordem de empilhamento da frente para trás; exclui as do próprio app; **não filtra** (o filtro é de `ListaDeJanelas`).
  - `capturarRegiao`: confere que a tela atual é igual a `tela` (senão `.telaNaoEncontrada`); `sourceRect` = `tela.quadroEmPontos(dePixels: pixels)` relativo à tela; `width`/`height` da configuração = pixels do retângulo; `showsCursor = incluirCursor`; confere o resultado com `conferindo(largura:altura:)`.
  - `capturarJanela`: filtro `desktopIndependentWindow` da janela de `id` (senão `.janelaNaoEncontrada`), sem sombra (`ignoreShadowsSingleWindow`), `showsCursor = incluirCursor`, escala = a da tela de `ListaDeJanelas.tela(de:entre:)`, tamanho em pixels = quadro × escala arredondado.
  - Erros passam por `MapeadorDeErroDeCaptura.mapear`.

- [ ] **Step 1: Teste que falha** (pura): um caso novo em `MapeadorDeErroDeCapturaTests` só se algum código de erro do ScreenCaptureKit passar a ter mapeamento novo; senão, nenhum teste novo (a casca vai para a lista manual).
- [ ] **Step 2: Implementar** as quatro funções conferindo as assinaturas no SDK (`SCStreamConfiguration.sourceRect`, `ignoreShadowsSingleWindow`, `SCContentFilter(desktopIndependentWindow:)`).
- [ ] **Step 3: Rodar:** `make verificar` → Expected: PASS (casca fora do portão). Commit (`feat(sistema): captura telas congeladas, janelas e região ou janela ao vivo`).

---

## Parte D — Overlay e fluxo

### Task 10: Overlay completo sobre a máquina de estados

**Files:**
- Modify: `App/Fontes/Overlay/{JanelaDeOverlay,GerenciadorDoOverlay}.swift`, `App/Recursos/Localizable.xcstrings`
- Create: `App/Fontes/Overlay/VistaDoOverlay.swift`
- Test: `App/Testes/GerenciadorDoOverlayTests.swift`

**Interfaces:**
- Consumes: `EstadoDoOverlay`, `EventoDoOverlay`, `ResultadoDoOverlay` (T7); `TelaCongelada` (T8); `Lupa`, `Posicionamento` (T5).
- Produces:
  - `protocol SeletorDeCaptura { @MainActor func escolher(telas: [TelaCongelada], janelas: [JanelaDeTela], modo: ModoDoOverlay, opcoes: OpcoesDeCaptura, ajudaVisivel: Bool) async -> ResultadoDoOverlay }` — o fluxo depende dele; `GerenciadorDoOverlay` o implementa (substitui `abrir(aoFechar:)` da Tarefa 1).
  - `@MainActor final class GerenciadorDoOverlay: SeletorDeCaptura` — abre uma `JanelaDeOverlay` por tela com a `VistaDoOverlay` correspondente; mantém **um** `EstadoDoOverlay` e a ele aplica os eventos de todas as vistas; fecha todas as janelas ao receber `resultado`; observa `NSApplication.didChangeScreenParametersNotification` (`telasMudaram`) e a desativação do app (`perdeuAtivacao`).
  - `VistaDoOverlay: NSView` — desenha só a partir do estado: imagem congelada da tela escurecida e a seleção sem escurecer; mira nas duas direções em todas as telas; dimensões `largura × altura` (pixels) junto à seleção, posicionadas por `Posicionamento`; contorno e clareamento da janela realçada; alças da seleção; lupa 8× com grade e coordenadas do pixel, lida da imagem congelada e posicionada por `Lupa`/`Posicionamento`; painel de ajuda no canto inferior esquerdo (teclas da spec §4.2, ocultável); barra curta com atraso e *incluir cursor* (o cursor desabilitado, mostrando o valor guardado, quando `atraso == .nenhum`, com a explicação em pt-BR). Converte mouse, teclado e mudanças das opções em `EventoDoOverlay`. Cursor do mouse vira mira. *Reduzir transparência* deixa o escurecimento e os painéis opacos; *Reduzir movimento* sem animação; rótulo de acessibilidade "Seleção de captura. Esc cancela."

- [ ] **Step 1: Testes que falham** (`GerenciadorDoOverlayTests`, no host de testes do app, com telas e janelas falsas): `escolherRetornaOResultadoDaMaquinaEFechaAsJanelas` (injeta eventos por um ponto de entrada interno e confere que `escolher` retorna e que nenhuma janela de overlay sobra aberta); `escCancelaEFecha`; `telasMudaremCancela`; `perderAAtivacaoCancela`; `umaJanelaDeOverlayPorTela`.
- [ ] **Step 2: Rodar:** `make cobertura-app` → Expected: FAIL.
- [ ] **Step 3: Implementar** as três peças. Textos só pelo String Catalog; cores só por `Tema.*` (acrescentar tokens ao `docs/design-system/tokens.json` e a `Tema` só se faltar algum, com `make tokens` verde).
- [ ] **Step 4: Rodar:** `make verificar` e `make cobertura-app` → Expected: PASS. Commit (`feat(app): adiciona o overlay de região e janela`).

### Task 11: Opções lembradas e janelinha da contagem

**Files:**
- Create: `App/Fontes/Captura/OpcoesLembradas.swift`, `App/Fontes/Overlay/JanelaDaContagem.swift`
- Modify: `App/Recursos/Localizable.xcstrings`
- Test: `App/Testes/OpcoesLembradasTests.swift`

**Interfaces:**
- Produces: `struct OpcoesLembradas { init(defaults: UserDefaults); var opcoes: OpcoesDeCaptura { get nonmutating set }; var ajudaVisivel: Bool { get nonmutating set } }` — chaves `atraso`, `incluirCursor`, `ajudaVisivel` em `UserDefaults`; padrões `.nenhum`, `false`, `true`; valor inválido de atraso volta ao padrão. `protocol ApresentadorDaContagem { @MainActor func mostrar(segundos: Int, naTela tela: DescricaoDeTela); @MainActor func atualizar(_ segundos: Int); @MainActor func fechar() }`; `GerenciadorDoOverlay` também o implementa (ou uma classe própria `JanelaDaContagem`): janelinha pequena no topo da tela da seleção, com o número e "Esc cancela", anunciada pelo VoiceOver, sem animação com *Reduzir movimento*; `Esc` ou clique nela cancelam (callback `aoCancelar`).

- [ ] **Step 1: Testes que falham:** `padroesSemNadaGravado`; `gravaELeAtrasoECursorEntreInstancias`; `atrasoInvalidoVoltaAoPadrao`; `incluirCursorFicaGuardadoComAtrasoNenhum`; `ajudaVisivelPadraoVerdadeiroELembraAEscolha`.
- [ ] **Step 2: Rodar:** `make cobertura-app` → Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar:** `make verificar` e `make cobertura-app` → Expected: PASS. Commit (`feat(app): lembra atraso, cursor e ajuda e adiciona a contagem regressiva`).

### Task 12: Fluxo da captura livre

**Files:**
- Modify: `App/Fontes/Captura/FluxoDeCaptura.swift`, `App/Testes/FluxoDeCapturaTests.swift`, `App/Testes/DublesDeCaptura.swift`

**Interfaces:**
- Consumes: `Capturador` ampliado (T8), `SeletorDeCaptura` (T10), `OpcoesLembradas` e `ApresentadorDaContagem` (T11), `RecorteDeImagem` (T5), `ContagemRegressiva` (T6), `ListaDeJanelas` (T4).
- Produces: `FluxoDeCaptura.init` ganha `seletor: any SeletorDeCaptura`, `contagem: any ApresentadorDaContagem` e `opcoes: OpcoesLembradas`; `func capturarLivre(modo: ModoDoOverlay) async`. O fim do caminho da fatia 3 (do `Documento.novo(de:)` até `mostrarCaptura` e `gravarRascunho`) vira um método privado compartilhado por `capturarTelaInteira` e `capturarLivre`.

Sequência (spec §4.1): disparo sem captura nem seleção em andamento → permissão (mesmo tratamento) → `congelarTelas()` → `listarJanelas()` (se falhar: janelas `[]`, `modo` cai para região, sem erro) → `seletor.escolher(...)`; `.cancelado` termina sem rascunho; `.confirmado(seleção, opções)` grava as opções em `OpcoesLembradas`; **sem atraso**: região = `RecorteDeImagem` da tela congelada nos pixels da seleção (escala da tela), janela = `capturarJanela(id:incluirCursor: false)`; **com atraso**: o seletor já fechou, `contagem.mostrar`, `ContagemRegressiva`, e ao fim `capturarRegiao(em:pixels:incluirCursor:)` ou `capturarJanela(id:incluirCursor:)` ao vivo; cancelar a contagem termina sem rascunho. Erros: `.semPermissao` → ajuda de permissão; qualquer outro → alerta `capturaFalhou`.

- [ ] **Step 1: Testes que falham** (`FluxoDeCapturaTests`, com capturador, seletor, contagem e pausa falsos):
  - `semPermissaoMostraAjudaENaoAbreOOverlay`; `disparoDuranteSelecaoEhIgnorado` e `disparoDuranteContagemEhIgnorado`.
  - `canceladoNaoCapturaNemGravaRascunho`.
  - `regiaoSemAtrasoRecortaACongeladaEAbreAJanela` (documento com o tamanho do recorte e a escala da tela; nenhuma chamada a `capturarRegiao`); `janelaSemAtrasoCapturaAJanelaSemCursor`.
  - `comAtrasoCapturaAoVivoDepoisDaContagem` (`capturarRegiao` chamado uma vez, com `incluirCursor` das opções, só depois do último segundo); `contagemCanceladaNaoCapturaNada`.
  - Review Focus 4: `janelaQueSomeDuranteOAtrasoMostraAlertaENaoGravaNada` (`janelaNaoEncontrada`); `telaQueMudouDuranteOAtrasoMostraAlerta` (`telaNaoEncontrada`); `tamanhoInesperadoMostraAlerta`; `permissaoRevogadaNaCapturaAoVivoMostraAjuda`.
  - Review Focus 5: `listaDeJanelasIndisponivelAbreSoNoModoRegiao` (o seletor recebe `modo == .regiao` e `janelas == []`, sem alerta).
  - `falhaAoCongelarMostraAlertaENaoAbreOOverlay`.
  - `opcoesEscolhidasFicamLembradas`; `capturarTelaInteiraContinuaIgual` (regressão da fatia 3).
- [ ] **Step 2: Rodar:** `make cobertura-app` → Expected: FAIL.
- [ ] **Step 3: Implementar** `capturarLivre` e extrair o fim compartilhado; o registro de duração ("do disparo à janela") também cobre o caminho livre, medido do disparo até a abertura do overlay e da seleção até a janela, em duas linhas distintas.
- [ ] **Step 4: Rodar:** `make verificar` e `make cobertura-app` → Expected: PASS. Commit (`feat(app): adiciona o fluxo de captura livre com atraso`).

### Task 13: Menu, atalhos e fiação

**Files:**
- Modify: `App/Fontes/CaptaApp.swift`, `App/Recursos/Localizable.xcstrings`; remover a ligação provisória da Tarefa 1.

**Interfaces:**
- Consumes: `FluxoDeCaptura.capturarLivre(modo:)` (T12); `CombinacaoDeTeclas.capturaLivre` (T1).
- Produces: menu com *Capturar região* (`⌃⌥C`, `modo: .regiao`), *Capturar janela* (`modo: .janela`), *Capturar tela inteira* (`⌃⌥F`, como hoje) e *Sair do Capta*; `⌃⌥C` chama `capturarLivre(modo: .regiao)`; `EstadoDoMenu` ganha uma flag por atalho e o menu mostra "Atalho indisponível" ao lado do item cujo registro falhou; `janelas.tentarDeNovo` segue refazendo a captura da tela inteira. O `GerenciadorDoOverlay` é injetado em `FluxoDeCaptura` como `seletor` e `contagem`.

- [ ] **Step 1: Teste que falha** (`CaptaTests`, onde já houver teste da fiação; senão, só a flag): `estadoDoMenuMarcaCadaAtalhoIndisponivelSeparadamente`.
- [ ] **Step 2: Rodar:** `make cobertura-app` → Expected: FAIL.
- [ ] **Step 3: Implementar** a fiação.
- [ ] **Step 4: Rodar:** `make verificar` e `make cobertura-app` → Expected: PASS. Commit (`feat(app): liga o menu e o atalho da captura livre`).

### Task 14: Verificação manual e fechamento

**Files:**
- Create: `docs/verificacao-manual-overlay.md`
- Modify: `ferramentas/cobertura.pisos` (linha `App=`, em commit próprio), `ferramentas/cobertura.exclusoes` (se a casca ganhar arquivo), este plano (status ao fim)

- [ ] **Step 1: Escrever `docs/verificacao-manual-overlay.md`** com um item marcável por linha, no formato da lista da fatia 3: overlay cobre barra de menus e Dock; `Esc` em todos os estados (antes de arrastar, com seleção, com a lupa, no modo janela, na contagem); uma, duas e três telas, escalas mistas, tela acima ou à esquerda da principal; app em tela cheia e outro Space; região sem atraso sai **exatamente** o que foi visto (conferir por pixel no Preview, também numa tela de escala não inteira); a região não passa para outra tela; ajuste de bordas, mover e setas (1 px e `⇧` 10 px); dimensões em pixels corretas; lupa nos quatro cantos da tela e a 8× com grade; `H` oculta e lembra a ajuda; `Espaço` alterna; janela com parte coberta sai inteira, sem sombra, na escala certa; janela entre duas telas; `F` captura a tela sob o cursor; menu de aplicativo capturado por região com atraso de 3 s; contagem visível, fora da imagem, `Esc` cancela; cursor aparece só com atraso e o controle explica sem atraso; janela que fecha durante a contagem mostra alerta; desconectar um monitor com o overlay aberto cancela; `⌃⌥C` em conflito com outro app mostra "Atalho indisponível" e o menu funciona; `⌃⌥C` e `⌃⌥F` não se confundem; nenhuma permissão nova pedida; VoiceOver lê o rótulo e a contagem; *Reduzir transparência* e *Reduzir movimento*; o menu da barra não aparece na imagem congelada; tempo do atalho ao overlay (alvo < 500 ms, ler o log; medir com uma e com três telas, e conferir o uso de memória do Capta com três telas).
- [ ] **Step 2: Rodar `make cobertura-app`**, anotar o valor medido de `App/Fontes` e ajustar `App=` (o piso é provisório; vale o menor entre CI e local), em commit próprio (`test(app): ajusta o piso de cobertura do app`).
- [ ] **Step 3: Rodar `make verificar` e `make cobertura-app`** → Expected: PASS; commit da lista (`docs: adiciona a lista de verificação manual do overlay`).
- [ ] **Step 4: 🔒 Pedir ao Pedro** para percorrer a lista (`make app && open build/Capta.app`, com duas telas para os itens de várias telas) e registrar as falhas como pendências no status deste plano.
- [ ] **Step 5: 🔒 `git push`** só depois da confirmação do Pedro; conferir `gh run list --limit 1` → `success`; se o piso do app medido na CI for menor que o local, baixar `App=` ao valor da CI em commit próprio.

---

## Auto-revisão

- **Cobertura da spec:** §4.1 fluxo → T12; §4.2 congelar e listar → T4, T8, T9; §4.3 overlay (modos, região, janela, mira, lupa, teclas, ajuda, barra de opções, foco, telas mudando) → T1, T3, T4, T5, T7, T10, T11; §4.4 captura (recorte da congelada, janela, atraso, contagem, `F`) → T5, T6, T9, T12; §4.5 atalhos e menu → T1, T13; §4.6 permissão → T12; §4.7 acessibilidade e aparência → T10, T11, T14; §4.8 núcleo → T2 a T7; §4.9 (foco, pixel exato, tela da janela, cursor lembrado, `F`) → T1, T3, T4, T7, T8, T12; §5 erros → T12; §6 testes e lista manual → T14.
- **Escolha do plano que a spec deixou ao construtor:** a prova de foco vem primeiro (T1), porque a spec a trata como bloqueante e o resto do overlay não vale se ela falhar; `DescricaoDeTela` e `SelecaoDeTela` sobem para o núcleo (T2) para a máquina de estados os usar; a seleção é guardada em pixels inteiros e a conversão arredonda ao pixel mais próximo (T2, T3), o que torna o retângulo mostrado idêntico ao capturado; `AtalhoGlobalCarbon` ganha um id por instância (T1), porque hoje o handler dispara todas as ações registradas.
- **Consistência de tipos:** `DescricaoDeTela`, `SelecaoDeRegiao`, `Alca`, `Acerto`, `JanelaDeTela`, `ListaDeJanelas`, `Atraso`, `OpcoesDeCaptura`, `EstadoDoOverlay`, `EventoDoOverlay`, `ResultadoDoOverlay`, `SelecaoConfirmada`, `TelaCongelada`, `SeletorDeCaptura`, `ApresentadorDaContagem`, `OpcoesLembradas` mantêm a mesma assinatura entre as tarefas que os definem e as que os usam.
- **Risco aberto:** a prova de foco (T1, passo 6) só o Pedro confirma, com tela real; as tarefas 2 a 9 não dependem dela e podem andar antes, mas a 10 em diante esperam o resultado.
