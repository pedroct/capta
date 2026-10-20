# Capta — Plano 1: Esqueleto e Núcleo do Documento

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ter o repositório `capta` funcionando com portão de qualidade (`make verificar`), um app vazio de barra de menus sob sandbox, CI, e o **núcleo do documento** completo e testado: modelo de anotações, edição com desfazer/refazer, renderizador único e arquivo `.capta`.

**Architecture:** Três camadas (`Capta` UI → `CaptaSistema` adaptadores → `CaptaNucleo` regra pura). O núcleo é um pacote SwiftPM local sem UI; o app é um projeto Xcode gerado por XcodeGen. O estado do documento é um valor (`struct`); a edição aplica comandos puros e guarda *snapshots* para desfazer/refazer; um único renderizador (CoreGraphics + CoreImage) serve a tela e a exportação.

**Tech Stack:** Swift 6.4 (modo 6, tools 6.2), SwiftPM, XcodeGen, Swift Testing, swift-format, SwiftLint, CoreGraphics/CoreImage/ImageIO, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-20-capta-mvp-design.md` (fatias 1 e 2 da seção 8). Padrões: `docs/padroes-stack-swift.md`. Leia os dois antes de começar.

## Global Constraints

- macOS **14+**; Swift 6 em modo de linguagem 6; **aviso tratado como erro** em todos os alvos.
- **Nenhuma dependência de terceiros.** Licença **MIT**, titular Pedro Teixeira. Repositório **público**: nenhum segredo, certificado ou perfil no Git.
- **App Sandbox ligado**; **sem rede** (nenhum entitlement `network.client`); sem conta, login, licença ou telemetria.
- `CaptaNucleo` importa **só** Foundation, CoreGraphics, CoreImage, ImageIO, UniformTypeIdentifiers. Nunca SwiftUI, AppKit, ScreenCaptureKit ou Vision. Protocolos do sistema ficam no núcleo; implementações em `CaptaSistema`.
- Domínio em **pt-BR**, termos de framework em inglês; comentários e docs em pt-BR. Sem `!`, `try!` nem IUO em produção (em teste, `URL(string: "literal")!` é aceito).
- Texto de interface só pelo String Catalog; **cor só por token** (`Tema.*`); nada copiado do Snagit.
- **Design system:** `docs/design-system/` é a fonte dos tokens (superfícies e texto acompanham o macOS; **destaque = cor do sistema**; **cores da marca nunca na interface**). Claro e escuro sempre; "Reduzir transparência" troca o vidro por superfície opaca.
- **`make verificar` passa antes de todo commit.** Commits em Conventional Commits com descrição em pt-BR; cada commit termina com `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Identidade git local ao repositório: `Pedro Teixeira <5846288+pedroct@users.noreply.github.com>`.
- Todo comando de build usa `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` (o `Makefile` define sozinho). Nunca rodar `sudo xcode-select`.
- **Instalar software (XcodeGen) e fazer `git push` exigem confirmação do Pedro no momento.** Os passos marcados 🔒 pedem pausa para confirmar.
- **Sistema de coordenadas do documento:** pixels da **imagem base**, origem no **canto superior esquerdo**, eixo Y para baixo. O renderizador faz a inversão para o CoreGraphics.

## Review Focus

Entradas e falhas que a spec implica e nenhuma tarefa exercitaria sozinha; cada uma tem teste na tarefa dona:

1. **Texto estranho** (vazio, muito longo, emoji, árabe/hebraico) em objeto de texto: renderiza sem travar e sem escapar do retângulo. → Tarefa 6.
2. **Desfoque e recorte fora dos limites** (parcial, totalmente fora, tamanho zero, retângulo invertido): sem *crash*; trecho em limites é tratado; o resto é ignorado ou rejeitado com erro tipado. → Tarefas 5 e 7.
3. **Pacote `.capta` danificado** (JSON truncado, sem `base.png`, `versaoEsquema` de versão futura, falha no meio da gravação): erro tipado; **nunca** apaga ou sobrescreve o arquivo bom. → Tarefa 8.
4. **Valores não finitos ou fora de faixa** (NaN, ∞, opacidade fora de 0…1, tamanho negativo) vindos de arquivo editado à mão. → Tarefa 4.
5. **Etapas:** zero etapas, excluir a do meio (renumera), reiniciar a sequência, desfazer a exclusão (volta a numeração). → Tarefa 5.

---

## Mapa de arquivos

```text
capta/
├── LICENSE, README.md, .gitignore, .swift-format, .swiftlint.yml, Makefile
├── project.yml, project.local.yml.example
├── .github/workflows/ci.yml
├── docs/ (padroes-stack-swift.md, superpowers/{specs,plans}/)
├── ferramentas/
│   ├── hooks/{pre-commit,commit-msg,pre-push}
│   ├── conferir_tokens.sh
│   ├── conferir_entitlements.sh
│   └── empacotar.sh
├── App/
│   ├── Capta.entitlements, Info.plist
│   ├── Fontes/{CaptaApp.swift, Tema.swift}
│   └── Recursos/{Assets.xcassets, Localizable.xcstrings}
└── Packages/CaptaNucleo/
    ├── Package.swift, Tests/.swiftlint.yml
    ├── Sources/CaptaNucleo/
    │   ├── Esquema.swift                      # versão do esquema
    │   ├── Modelo/{Cor.swift, Estilo.swift, Geometria.swift, Anotacao.swift, Documento.swift, ErroDocumento.swift}
    │   ├── Edicao/{Edicao.swift, SessaoEdicao.swift, Etapas.swift}
    │   ├── Renderizacao/{Renderizador.swift, DesenhoFormas.swift, DesenhoTexto.swift, Desfoque.swift, ProvedorDeSimbolos.swift}
    │   └── Pacote/{PacoteCapta.swift, ErroPacote.swift}
    ├── Sources/CaptaSistema/ProvedorDeSimbolosSF.swift
    └── Tests/CaptaNucleoTests/{EsquemaTests, ModeloTests, EdicaoTests, EtapasTests, RenderizadorFormasTests, RenderizadorTextoTests, RenderizadorRecorteDesfoqueTests, PacoteCaptaTests, Apoio/Pixels.swift}
```

---

### Task 1: Repositório, portão de qualidade e ganchos

**Files:**
- Create: `LICENSE`, `README.md`, `.gitignore`, `.swift-format`, `.swiftlint.yml`, `Makefile`, `ferramentas/hooks/{pre-commit,commit-msg,pre-push}`, `Packages/CaptaNucleo/Package.swift`, `Packages/CaptaNucleo/Tests/.swiftlint.yml`, `Packages/CaptaNucleo/Sources/CaptaNucleo/Esquema.swift`, `Packages/CaptaNucleo/Sources/CaptaSistema/Vazio.swift`
- Copy into repo: `docs/padroes-stack-swift.md`, `docs/superpowers/specs/2026-10-20-capta-mvp-design.md`, este plano, e a pasta `docs/design-system/` inteira (tokens, README, ativos da marca, componentes)
- Test: `Packages/CaptaNucleo/Tests/CaptaNucleoTests/EsquemaTests.swift`

**Interfaces:**
- Produces: `public enum Esquema { public static let versaoAtual: Int }` (valor `1`); alvos `make lint`, `make test`, `make verificar` (nesta tarefa: `lint` + `test`).

- [ ] **Step 1: 🔒 Clonar** `https://github.com/pedroct/capta.git` em `/Volumes/DOCK/Projetos/pessoal/capta` (confirmar o caminho com o Pedro), configurar `user.name`/`user.email` locais, `git branch -M main`.
- [ ] **Step 2: Criar `LICENSE` (MIT, "Copyright (c) 2026 Pedro Teixeira"), `README.md` (o que é, status, `make verificar`), `.gitignore`, `.swift-format`, `.swiftlint.yml` e `Tests/.swiftlint.yml` exatamente como nas seções 6 do padrão; copiar os três documentos para `docs/`.** Na tabela de toolchain do padrão, trocar "commitlint" por "script `ferramentas/hooks/commit-msg`" (validação por expressão regular, sem Node).
- [ ] **Step 3: Escrever o teste que falha** em `EsquemaTests.swift`:

```swift
import Testing
@testable import CaptaNucleo

@Test func versaoAtualDoEsquemaEUm() {
    #expect(Esquema.versaoAtual == 1)
}
```

- [ ] **Step 4: Rodar e ver falhar:** `make test` → Expected: erro de compilação "cannot find 'Esquema' in scope".
- [ ] **Step 5: Criar `Package.swift` (modelo da seção 6), `Esquema.swift` e `CaptaSistema/Vazio.swift`** (um `enum` vazio documentado, só para o alvo compilar).
- [ ] **Step 6: Criar o `Makefile`** com `format`, `lint`, `test`, `verificar` (`lint test`) e o `DEVELOPER_DIR` automático da seção 6; **os ganchos**: `pre-commit` roda `make lint`; `commit-msg` rejeita mensagem fora de `^(feat|fix|refactor|test|docs|chore|perf|ci|build|revert)(\([a-z0-9-]+\))?!?: .+`; `pre-push` roda `make verificar`; ativar com `git config core.hooksPath ferramentas/hooks`.
- [ ] **Step 7: Verificar:** `make verificar` → Expected: lint sem violações e `1 test passed`. Teste do gancho: `echo "lixo" | ferramentas/hooks/commit-msg /dev/stdin` → Expected: código de saída ≠ 0; com `feat(nucleo): adiciona esquema` → 0.
- [ ] **Step 8: Commit** (`chore: inicia repositório com portão de qualidade`), incluindo todos os arquivos acima.
- [ ] **Step 9: 🔒 `git push -u origin main`** após confirmação do Pedro.

---

### Task 2: App vazio de barra de menus sob sandbox

**Files:**
- Create: `project.yml`, `project.local.yml.example`, `App/Capta.entitlements`, `App/Info.plist`, `App/Fontes/CaptaApp.swift`, `App/Fontes/Tema.swift`, `App/Recursos/Assets.xcassets` (cores `SuperficieCanvas` e `BordaControle`, claro e escuro; as nove cores `Anotacao*`; `AppIcon` e o ícone do menu), `App/Recursos/Localizable.xcstrings` (pt-BR), `ferramentas/gerar_icone.swift`, `ferramentas/conferir_entitlements.sh`, `ferramentas/conferir_tokens.sh`, `ferramentas/empacotar.sh`
- Modify: `Makefile` (`gerar`, `build`, `tokens`, `entitlements`, `app`; `verificar` passa a incluir `build tokens entitlements`)

**Interfaces:**
- Consumes: `make lint`/`test` da Tarefa 1.
- Produces: alvo Xcode `Capta` (depende dos produtos `CaptaNucleo` e `CaptaSistema`); `CaptaApp` com `MenuBarExtra` (ícone do menu em imagem-modelo) contendo o item "Sair do Capta"; `enum Tema` (nomes em `docs/design-system/tokens.json`, sem acento) com:
  - `static let texto, textoSecundario, superficieJanela, superficieCanvas, bordaControle, destaque, destaqueFundo, sobreDestaque, anelFoco: Color` — os três primeiros vêm de `NSColor` semântico; `destaque` e `anelFoco` são `Color.accentColor`; `destaqueFundo` é `destaque` a 16 % (claro) / 24 % (escuro); `sobreDestaque` branco (claro) / quase preto (escuro); `superficieCanvas` e `bordaControle` vêm do catálogo.
  - `static let superficiePainel: Material` (`.regularMaterial`) e `static func fundoDoPainel(reduzirTransparencia: Bool) -> AnyShapeStyle` que devolve o material ou `superficieJanela` opaca.
  - `enum Anotacao { static let vermelho, laranja, amarelo, verde, azul, roxo, preto, branco, realce: Color }` lendo as cores `Anotacao*` do catálogo.
  - `enum Espaco { static let e1 = 4.0, e2 = 8.0, e3 = 12.0, e4 = 16.0, e6 = 24.0, e8 = 32.0 }` e `enum Raio { static let controle = 6.0, cartao = 10.0, painel = 14.0, janela = 16.0 }`.

- [ ] **Step 1: 🔒 Instalar o XcodeGen** (`brew install xcodegen`) após confirmação do Pedro; anotar a versão no `README.md`.
- [ ] **Step 2: Escrever os testes dos portões (falham antes do código):**
  - `conferir_entitlements.sh`: lê `App/Capta.entitlements` com `plutil` e **falha** se `com.apple.security.app-sandbox` ≠ `true`, ou se existir `com.apple.security.network.client`, ou se houver chave fora da lista permitida (`app-sandbox`, `files.user-selected.read-write`).
  - `conferir_tokens.sh` (usa `python3 -I`): **falha** (1) se algum `.swift` em `App/Fontes` (exceto `Tema.swift`) contiver `Color.red`/`Color(red:`/`.foregroundColor(.`/`Color(hex`/`.secondary` ou literal `#`-hex; (2) se alguma cor `anotacao-*` de `docs/design-system/tokens.json` não existir em `Assets.xcassets` como `Anotacao<Nome>.colorset` com o **mesmo hexadecimal** (e alfa) nos dois temas; (3) se `superficie-canvas` ou `borda-controle` divergirem do catálogo; (4) se o `Info.plist` ou o código mencionar alguma cor `marca-*` fora de `Assets.xcassets/AppIcon.appiconset`. Passa se tudo conferir.
  - Teste do script: criar `App/Fontes/Tmp.swift` com `let c = Color.red` → Expected: saída ≠ 0; apagar; alterar um hexadecimal em `AnotacaoVermelho.colorset` → Expected: saída ≠ 0 apontando o token; restaurar e rodar → Expected: 0.
  - `gerar_icone.swift`: gera os PNGs do `AppIcon.appiconset` (16 a 1024 px, @1x/@2x) e o glifo do menu a partir de `docs/design-system/assets/Marca/*.svg`. **A confirmar:** se `NSImage` desenhar o SVG; caso contrário, usar `rsvg-convert` (🔒 instalar `librsvg` só com autorização). Teste: rodar o script e conferir que `AppIcon.appiconset/Contents.json` lista os 10 tamanhos e que o PNG de 1024 px tem 1024×1024 (`sips -g pixelWidth`).
- [ ] **Step 3: Criar `App/Capta.entitlements`** (sandbox `true`; `files.user-selected.read-write` `true`; um comentário XML por chave com o motivo) e `App/Info.plist` (chaves da seção 6 do padrão; `LSUIElement` = `true` por ora — a política de ativação com Dock entra no Plano do editor).
- [ ] **Step 4: Criar `project.yml`** a partir do esqueleto do padrão; `project.local.yml.example` com `DEVELOPMENT_TEAM: SEU_TIME_AQUI` (o `project.local.yml` real já está no `.gitignore`); `CaptaApp.swift` com `@main struct CaptaApp: App` e `MenuBarExtra` usando o glifo monocromático do Capta como imagem-modelo (fallback: símbolo do sistema `camera.viewfinder` se o glifo ainda não existir) + botão "Sair do Capta" (texto do String Catalog); `Tema.swift` com todos os tokens listados em Interfaces; catálogo de cores gerado a partir de `docs/design-system/tokens.json` (hexadecimais exatos, claro e escuro) e `AppIcon` gerado por `gerar_icone.swift`. Nenhuma cor `marca-*` aparece em `Tema.swift`.
- [ ] **Step 5: Makefile:** `gerar` roda `xcodegen generate`; `build` roda `xcodebuild -scheme Capta -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build | xcbeautify`; `verificar: lint build test tokens entitlements`.
- [ ] **Step 6: Verificar:** `make gerar && make verificar` → Expected: compila em modo estrito sem avisos; os dois scripts saem com 0.
- [ ] **Step 7: Criar `ferramentas/empacotar.sh`:** compila em Release lendo `DEVELOPMENT_TEAM` de `project.local.yml`, assina com Apple Development e copia para `build/Capta.app`; falha com mensagem clara se `project.local.yml` não existir.
- [ ] **Step 8: Verificação manual (🔒 pedir ao Pedro para criar `project.local.yml`):** `make app && open build/Capta.app` → Expected: ícone na barra de menus; clicar mostra "Sair do Capta"; `codesign -d --entitlements - build/Capta.app` mostra `app-sandbox` verdadeiro.
- [ ] **Step 9: Commit** (`feat(app): cria app de barra de menus sob sandbox`).

---

### Task 3: Integração contínua

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `make lint`, `make test` (e `ferramentas/hooks/commit-msg` para validar mensagens).
- Produces: workflow `CI` com jobs `verificar` e `commits`.

- [ ] **Step 1: Criar o workflow** que dispara em `pull_request` e `push` na `main`: job `verificar` em runner macOS com Xcode ≥ 26 (`macos-26`; **A confirmar** a disponibilidade da imagem — se não existir, usar o mais novo e registrar), instala SwiftLint por Homebrew e roda `make lint` e `make test`; job `commits` roda o script `commit-msg` sobre cada mensagem do intervalo do PR. Sem segredos.
- [ ] **Step 2: 🔒 Verificar:** abrir um PR de teste (ou `git push`) após confirmação → Expected: `gh run list --limit 1` mostra `completed success`. Se falhar por versão de Swift, registrar a causa em `docs/padroes-stack-swift.md` (seção 7) em vez de contornar.
- [ ] **Step 3: Commit** (`ci: adiciona verificação no GitHub Actions`).

---

### Task 4: Modelo do documento

**Files:**
- Create: `Sources/CaptaNucleo/Modelo/{Cor,Estilo,Geometria,Anotacao,Documento,ErroDocumento}.swift`
- Test: `Tests/CaptaNucleoTests/ModeloTests.swift`

**Interfaces:**
- Produces (todos `public`, `Codable`, `Equatable`, `Sendable`):
  - `struct CorRGBA { r, g, b, a: Double }` (0…1, sRGB) com os padrões **iguais aos tokens `anotacao-*` do design system**: `static let vermelho` = `#FF3B30`, `amarelo` = `#FFCC00`, `preto` = `#1C1C1E` (não é o preto puro), `branco` = `#FFFFFF`.
  - `struct Estilo { cor: CorRGBA; largura: Double; opacidade: Double; preenchimento: CorRGBA?; tracejado: Bool }`.
  - `enum TipoForma { retangulo, retanguloArredondado, elipse }`; `enum TipoDesfoque { borrar, pixelizar }`.
  - `enum Geometria { seta(inicio: CGPoint, fim: CGPoint), linha(inicio: CGPoint, fim: CGPoint), forma(TipoForma, CGRect), texto(CGRect, conteudo: String, tamanhoFonte: Double, negrito: Bool, italico: Bool), etapa(centro: CGPoint, diametro: Double, reiniciaSequencia: Bool), carimbo(CGRect, simbolo: String), realce(CGRect), desfoque(CGRect, TipoDesfoque, intensidade: Double) }`.
  - `struct Anotacao: Identifiable { id: UUID; geometria: Geometria; estilo: Estilo }`.
  - `struct Documento { versaoEsquema: Int; tamanhoBase: CGSize; escala: Double; recorte: CGRect?; objetos: [Anotacao]; static func novo(tamanhoBase: CGSize, escala: Double) -> Documento; func validar() throws }` — a **ordem do array é a ordem das camadas** (último = por cima). `init(from:)` chama `validar()`.
  - `enum ErroDocumento: Error, Equatable { valorNaoFinito, valorForaDeFaixa(String), tamanhoInvalido, recorteInvalido, objetoInexistente(UUID) }`.

- [ ] **Step 1: Escrever os testes que falham** em `ModeloTests.swift` (nomes e asserções):
  - `coresPadraoConferemComOsTokensDeAnotacao`: `CorRGBA.vermelho`, `.amarelo`, `.preto`, `.branco` em 0–255 são `(255,59,48)`, `(255,204,0)`, `(28,28,30)`, `(255,255,255)`, com `a == 1`.
  - `documentoNovoComecaVazio`: `Documento.novo(tamanhoBase: .init(width: 200, height: 100), escala: 2)` tem `versaoEsquema == Esquema.versaoAtual`, `objetos.isEmpty`, `recorte == nil`.
  - `ciclaJSONParaCadaGeometria` (parametrizado com um exemplo de cada um dos 8 casos): `decode(encode(x)) == x`.
  - `rejeitaValoresNaoFinitos`: `Anotacao` com `CGPoint(x: .nan, y: 0)` e outra com `.infinity` → `validar()` lança `ErroDocumento.valorNaoFinito`.
  - `rejeitaOpacidadeForaDeFaixa`: opacidade `1.5` e `-0.1` → `valorForaDeFaixa("opacidade")`.
  - `rejeitaTamanhoBaseNaoPositivo`: largura `0` e `-5` → `tamanhoInvalido`; `escala == 0` também.
  - `decodificacaoValidaDocumento`: JSON com `"opacidade": 7` ou número `1e999` → `JSONDecoder().decode` **lança** (qualquer erro).
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL (tipos inexistentes).
- [ ] **Step 3: Implementar os tipos acima**, um arquivo por responsabilidade; `validar()` percorre `tamanhoBase`, `escala`, `recorte` (se existir deve ter largura/altura > 0 e estar contido em `tamanhoBase`) e cada anotação (`isFinite` em todos os números, `opacidade` e componentes de cor em 0…1, `largura ≥ 0`).
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS, lint limpo.
- [ ] **Step 5: Commit** (`feat(nucleo): adiciona modelo do documento e validação`).

---

### Task 5: Edição, desfazer/refazer e numeração de etapas

**Files:**
- Create: `Sources/CaptaNucleo/Edicao/{Edicao,SessaoEdicao,Etapas}.swift`
- Test: `Tests/CaptaNucleoTests/{EdicaoTests,EtapasTests}.swift`

**Interfaces:**
- Consumes: `Documento`, `Anotacao`, `ErroDocumento` (Tarefa 4).
- Produces:
  - `enum Edicao: Sendable { adicionar(Anotacao), remover(Set<UUID>), substituir(Anotacao), mover(Set<UUID>, deslocamento: CGVector), reordenar(UUID, Ordem), definirRecorte(CGRect?), definirReinicioDeEtapa(UUID, Bool) }`; `enum Ordem { paraFrente, paraTras, umNivelAcima, umNivelAbaixo }`.
  - `struct SessaoEdicao: Sendable { private(set) var documento: Documento; init(documento: Documento); mutating func aplicar(_ edicao: Edicao) throws; @discardableResult mutating func desfazer() -> Bool; @discardableResult mutating func refazer() -> Bool; var podeDesfazer: Bool; var podeRefazer: Bool }` — histórico por *snapshot* de `Documento` (o documento não contém a imagem base), ilimitado na sessão; `aplicar` limpa o refazer; edição inválida **não altera** o documento nem o histórico.
  - `extension Documento { func numeroDaEtapa(_ id: UUID) -> Int? }` — numera as etapas na ordem das camadas; uma etapa com `reiniciaSequencia == true` volta a `1`.

- [ ] **Step 1: Escrever os testes que falham:**
  - `adicionarMoverRemoverAplicamNaOrdem` e `desfazerRefazerRestauraCadaPasso` (3 edições, 3 `desfazer()`, 3 `refazer()` → documentos iguais aos instantes anteriores).
  - `aplicarDepoisDeDesfazerLimpaORefazer`: `podeRefazer == false`.
  - `edicaoInvalidaNaoMudaNada`: `remover([UUID()])` e `reordenar(UUID(), .paraFrente)` lançam `objetoInexistente`; `documento` e `podeDesfazer` inalterados.
  - `reordenarMudaAPosicaoNoArray` para cada caso de `Ordem`, incluindo bordas (já no topo + `paraFrente` é no-op sem erro).
  - `recorteForaDosLimitesELancado`: `definirRecorte(CGRect(x: -5, y: 0, width: 10, height: 10))`, `…width: 0…` e o retângulo com altura negativa → `recorteInvalido`; `definirRecorte(nil)` remove o recorte; recorte válido é desfeito por `desfazer()`.
  - Etapas (`EtapasTests`): sem etapas, `numeroDaEtapa(UUID()) == nil`; três etapas → `1,2,3`; **excluir a 2ª** → a antiga 3ª vira `2`; `desfazer()` restaura `3`; `definirReinicioDeEtapa` na 3ª de quatro → `1,2,1,2`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** `Edicao`, `SessaoEdicao` e `numeroDaEtapa` como acima; toda edição termina com `documento.validar()` e só então entra no histórico.
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`feat(nucleo): adiciona edição com desfazer e refazer e numeração de etapas`).

---

### Task 6: Renderizador — base, formas, linhas, setas, realce, etapas e texto

**Files:**
- Create: `Sources/CaptaNucleo/Renderizacao/{Renderizador,DesenhoFormas,DesenhoTexto,ProvedorDeSimbolos}.swift`
- Test: `Tests/CaptaNucleoTests/{RenderizadorFormasTests,RenderizadorTextoTests}.swift`, `Tests/CaptaNucleoTests/Apoio/Pixels.swift`

**Interfaces:**
- Consumes: modelo (Tarefa 4), `numeroDaEtapa` (Tarefa 5).
- Produces:
  - `protocol ProvedorDeSimbolos: Sendable { func imagem(simbolo: String, lado: Double, cor: CorRGBA) -> CGImage? }`.
  - `struct Renderizador: Sendable { init(provedorDeSimbolos: ProvedorDeSimbolos? = nil); func renderizar(_ documento: Documento, base: CGImage) throws -> CGImage }` — saída sRGB, 8 bits, `premultipliedLast`, com o tamanho **em pixels** da base (ou do recorte, quando existir; recorte e desfoque entram na Tarefa 7). Falha com `ErroDocumento.tamanhoInvalido` se `base` não casar com `documento.tamanhoBase`.
  - Apoio de teste (`Pixels.swift`): `func imagemSolida(_ tamanho: CGSize, cor: CorRGBA) -> CGImage` e `func pixel(_ imagem: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)` (origem no canto superior esquerdo).

- [ ] **Step 1: Escrever os testes que falham** (base branca 100×100, tolerância ±2 por canal):
  - `semObjetosDevolveABaseIgual`: todos os pixels amostrados iguais à base.
  - `formaRetanguloPreenchidoPintaSoDentro`: retângulo (10,10,40,40) vermelho opaco → pixel (20,20) vermelho, pixel (60,60) branco.
  - `camadaPosteriorFicaPorCima`: vermelho e depois azul sobrepostos → pixel na interseção é azul.
  - `realceAmareloTranslucidoMisturaComABase`: realce com opacidade 0.5 sobre branco → pixel com `b` menor que `r` e `g`, e `r` < 255 não nulo (valor esperado calculado no teste pela fórmula de mistura).
  - `linhaAtravessaOPixelDoMeio` e `setaTemCorpoECabeca`: ponto do corpo colorido; pixel logo atrás da ponta, fora do eixo, também colorido; pixel afastado branco.
  - `etapaDesenhaCirculoENumero`: círculo (centro (50,50), diâmetro 40) com preenchimento verde → centro do círculo é verde ou texto do número (verificar que **existem** pixels brancos e verdes no círculo) e pixel fora (5,5) branco; a etapa de ordem 2 mostra "2" (comparar contra a mesma etapa isolada: imagens diferentes).
  - `baseComTamanhoDivergenteLancaErro`.
  - **Texto (`RenderizadorTextoTests`, Review Focus 1):** `textoVazioNaoDesenhaNada`; `textoLongoFicaDentroDoRetangulo` (500 caracteres em retângulo 80×20: nenhum pixel alterado fora do retângulo); `emojiRTLENaoQuebram` (`"😀"`, `"مرحبا"`, `"שלום"`: `renderizar` não lança, e há ao menos um pixel alterado dentro do retângulo); `negritoEItalicoMudamOResultado` (imagens diferentes).
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar `Renderizador.renderizar`:** contexto `CGContext` sRGB do tamanho da base; desenha a base; inverte o eixo Y uma vez (documento usa origem no topo); percorre `documento.objetos` em ordem; cada tipo vive em `DesenhoFormas.swift` (formas, linha, seta, realce, etapa) ou `DesenhoTexto.swift` (texto com CoreText, recortado ao retângulo do objeto); texto vazio é *no-op*; `desfoque` e `carimbo` ficam como `fatalError`-livre *no-op* nesta tarefa (entram na Tarefa 7).
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`feat(nucleo): adiciona renderizador de formas, texto e etapas`).

---

### Task 7: Renderizador — recorte, desfoque e carimbo

**Files:**
- Create: `Sources/CaptaNucleo/Renderizacao/Desfoque.swift`, `Sources/CaptaSistema/ProvedorDeSimbolosSF.swift`
- Modify: `Renderizador.swift` (aplicar desfoque, carimbo e recorte)
- Test: `Tests/CaptaNucleoTests/RenderizadorRecorteDesfoqueTests.swift`

**Interfaces:**
- Consumes: `Renderizador`, `ProvedorDeSimbolos` (Tarefa 6); `TipoDesfoque` (Tarefa 4).
- Produces: `struct ProvedorDeSimbolosSF: ProvedorDeSimbolos` em `CaptaSistema` (usa símbolos do sistema; devolve `nil` para símbolo desconhecido); comportamento do `Renderizador`: **desfoque** afeta só o que está **abaixo** dele na ordem das camadas, na região recortada aos limites da imagem; **recorte** é aplicado por último e define o tamanho da saída.

- [ ] **Step 1: Escrever os testes que falham** (base 100×100 em xadrez preto/branco de 2 px para medir variação):
  - `recorteDefineOTamanhoDaSaida`: recorte (10,10,30,20) → imagem 30×20, e o pixel (0,0) da saída é o pixel (10,10) da base.
  - `anotacaoForaDoRecorteNaoApareceNaSaida`: forma vermelha totalmente fora do recorte → nenhum pixel vermelho na saída.
  - `borrarReduzALocalmenteAVariacao`: região (20,20,40,40) → variação (desvio-padrão da luminância) dentro menor que a base; pixel (5,5), fora da região, **idêntico** à base.
  - `pixelizarCriaBlocosUniformes`: dentro da região, pixels vizinhos do mesmo bloco têm cor igual.
  - `desfoqueSoAfetaCamadasAbaixo`: forma vermelha **antes** do desfoque tem a borda suavizada; forma azul **depois** mantém a borda nítida (pixel logo dentro/fora com valores exatos).
  - **Review Focus 2:** `desfoqueParcialmenteForaDaImagemBorraSoOTrechoInterno`; `desfoqueTotalmenteForaOuComTamanhoZeroNaoMudaNada` (sem lançar); `desfoqueComIntensidadeZeroNaoMudaNada`.
  - `carimboUsaOProvedor`: provedor falso devolvendo uma imagem sólida 10×10 → pixels do retângulo do carimbo coloridos; provedor `nil` e provedor que devolve `nil` → nada desenhado, sem erro.
  - `provedorDoSistemaDevolveImagemParaSimboloConhecido` (em `CaptaSistema`): `ProvedorDeSimbolosSF().imagem(simbolo: "star.fill", lado: 24, cor: .preto) != nil` e `imagem(simbolo: "nao.existe.xyz", …) == nil`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** `Desfoque.swift` com CoreImage (`CIGaussianBlur` para `borrar`, `CIPixellate` para `pixelizar`) aplicado à **cópia do compósito até aquele ponto**, recortada a `região ∩ limites da imagem`; `ProvedorDeSimbolosSF` renderiza o símbolo no tamanho e cor pedidos; recorte por `CGImage.cropping(to:)` no final (coordenadas do recorte já estão em pixels da base).
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`feat(nucleo): adiciona recorte, desfoque e carimbo ao renderizador`).

---

### Task 8: Arquivo `.capta` (pacote)

**Files:**
- Create: `Sources/CaptaNucleo/Pacote/{PacoteCapta,ErroPacote}.swift`
- Test: `Tests/CaptaNucleoTests/PacoteCaptaTests.swift`

**Interfaces:**
- Consumes: `Documento`, `Esquema.versaoAtual`, `ErroDocumento`.
- Produces:
  - `enum ErroPacote: Error, Equatable { arquivoAusente(String), jsonInvalido, versaoMaisNova(Int), dadosVazios }`.
  - `struct ConteudoPacote: Sendable { documento: Documento; baseDados: Data; miniaturaDados: Data? }`.
  - `enum PacoteCapta { static let extensao: String /* "capta" */; static func gravar(_ documento: Documento, baseDados: Data, miniaturaDados: Data, em destino: URL) throws; static func atualizar(_ documento: Documento, miniaturaDados: Data?, em destino: URL) throws; static func ler(de origem: URL) throws -> ConteudoPacote }`.
  - Estrutura em disco: pasta `<nome>.capta/` com `documento.json`, `base.png`, `miniatura.png`. `gravar` cria o pacote em pasta temporária irmã e **move atomicamente** para o destino; `atualizar` regrava **apenas** `documento.json` (e a miniatura, se vier) de forma atômica e **nunca toca `base.png`**.

- [ ] **Step 1: Escrever os testes que falham** (pasta temporária por teste):
  - `gravarELerFazemIdaEVolta`: documento com um objeto de cada tipo → `ler` devolve documento igual, `baseDados` e `miniaturaDados` idênticos.
  - `pacoteTemAsTresPartesEExtensao`: nomes dos itens exatamente `documento.json`, `base.png`, `miniatura.png`; destino termina em `.capta`.
  - `atualizarNaoTocaABase`: bytes de `base.png` iguais e **data de modificação inalterada** depois de `atualizar`; `documento.json` reflete a mudança.
  - **Review Focus 3:** `jsonTruncadoLancaJsonInvalido` (cortar o arquivo ao meio); `semBasePngLancaArquivoAusente("base.png")`; `versaoEsquema99LancaVersaoMaisNova(99)` (editar o JSON gravado); `gravarComBaseVaziaLancaDadosVaziosENaoCriaNada`; `gravarSobreUmPacoteExistenteQueFalhaMantemOAntigo` (segunda gravação com `baseDados` vazio → o pacote anterior continua legível e igual); `atualizarComJsonCorrompidoNoDiscoNaoApagaABase`.
  - `lerPastaQueNaoExisteLancaArquivoAusente`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** com `JSONEncoder` (`.sortedKeys`, `.prettyPrinted`) e `FileManager`; `ler` decodifica primeiro só `{ versaoEsquema }` para aplicar o portão de versão (`> Esquema.versaoAtual` → `versaoMaisNova`) **antes** de decodificar o documento completo. A primeira migração real será escrita junto com a primeira mudança de esquema (hoje só existe a versão 1).
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS, cobertura dos tipos de erro acima.
- [ ] **Step 5: Commit** (`feat(nucleo): adiciona arquivo .capta com gravação atômica`).
- [ ] **Step 6: 🔒 `git push`** após confirmação; conferir `gh run list --limit 1` → `success`.

---

## Auto-revisão

- **Cobertura da spec (fatias 1–2):** repositório, CI, projeto gerado, `project.local.yml.example`, `make verificar` sem time de assinatura, sandbox e entitlements (T1–T3); objetos, comandos reversíveis (como *edições* com histórico por *snapshot*, mais simples que comandos com inverso e equivalente para o usuário), renderizador único com desfoque/recorte/carimbo, `.capta` com gravação atômica e portão de versão (T4–T8). **Fora deste plano, de propósito:** captura, overlay, editor, biblioteca, exportação, preferências (Planos 2–4).
- **Consistência de tipos:** `Documento`, `Anotacao`, `Geometria`, `Estilo`, `CorRGBA`, `Edicao`, `SessaoEdicao`, `Renderizador`, `ProvedorDeSimbolos`, `PacoteCapta`, `ErroDocumento`, `ErroPacote` usados com a mesma assinatura em todas as tarefas.
- **Desvio da spec, para o Pedro saber:** a spec fala em "comandos reversíveis"; o plano usa edições puras + histórico por *snapshot*. Comportamento visível igual (desfazer/refazer ilimitado), código menor e sem risco de inverso mal escrito.
