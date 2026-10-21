# Capta — Padrão de Stack e Playbook de Scaffolding (Swift, macOS)

*Fonte da verdade técnica do projeto. Em conflito com qualquer outro documento do repositório sobre ferramentas, estrutura ou convenções, vale este.*
Versão 1.0 · Outubro de 2026 · Adaptado de `gepro-padrao-stack-swift.md` v1.1.

> **O que veio do documento de origem e o que mudou.** Mantidos: Swift 6 estrito, SwiftPM para a
> lógica, swift-format + SwiftLint, Swift Testing, regra de camadas, convenções de código,
> Conventional Commits, `make verificar`. **Removidos por não se aplicarem:** tudo da Sefaz
> (GitLab, runner interno, Developer ID institucional, MDM), contrato OpenAPI com a API do GEPRO,
> tokens do DS Sefaz, `gepro-voz-copy`. **Mudados:** projeto Xcode gerado (o app terá sandbox e
> entitlements), CI no GitHub Actions, release semanal feito localmente, distribuição pessoal
> agora e App Store depois.

Itens marcados **A confirmar** dependem de algo que ainda não foi verificado.

---

## 1. O padrão em uma olhada

| Item | Padrão |
| --- | --- |
| **Produto** | Capta: captura de imagem e anotação para macOS, uso pessoal, gratuito |
| **Repositório** | `github.com/pedroct/capta` (público) · licença **MIT** · titular: Pedro Teixeira |
| **Linguagem** | Swift 6, modo de linguagem 6 |
| **Interface** | SwiftUI, com AppKit onde o SwiftUI não alcança (overlay de captura, janelas flutuantes) |
| **Estado** | Observation (`@Observable`) + Swift Concurrency |
| **Projeto** | Xcode, **gerado** por XcodeGen a partir de `project.yml`; lógica em pacote SwiftPM local |
| **Formato e lint** | swift-format + SwiftLint |
| **Rigor** | Concorrência completa do Swift 6 + aviso tratado como erro |
| **Testes** | Swift Testing; XCTest só para teste de interface |
| **Plataforma mínima** | macOS 14 *(decisão minha: é o piso do `SCScreenshotManager`; revisar se algo exigir 15)* |
| **Sandbox** | **App Sandbox ligado desde o primeiro build** (requisito da App Store) |
| **Rede** | Nenhuma no MVP. Sem telemetria, sem conta, sem licença |
| **CI** | GitHub Actions em runner macOS: `make verificar` |
| **Release** | Semanal, local, tag SemVer + GitHub Release; changelog gerado |
| **Entrega** | `.dmg` assinado com certificado Apple Development (uso próprio); Developer ID/App Store depois |
| **Idioma da interface** | pt-BR primeiro; String Catalog desde o início para permitir inglês depois |
| **Design system** | `docs/design-system/` (espelho: artefato **DS Capta** no Claude Design). Direção "vidro nativo", claro e escuro, destaque = cor do sistema |
| **Marca** | Nome Capta · símbolo "C de moldura de seleção" com ponto · verde-água `#17B8A6`, ardósia `#14202B`, coral `#FF6B4A` (só no ponto). Cores da marca ficam fora da interface |

---

## 2. Estrutura do repositório

```text
capta/
├── project.yml                 # XcodeGen: alvos, entitlements, assinatura, esquemas
├── Makefile                    # ponto único: gerar, format, lint, build, test, verificar, app, release
├── .swift-format
├── .swiftlint.yml
├── LICENSE                     # MIT
├── README.md
├── CHANGELOG.md                # gerado
├── Packages/
│   └── CaptaNucleo/            # pacote SwiftPM local: regra de negócio, sem UI
│       ├── Package.swift
│       ├── Sources/
│       │   ├── CaptaNucleo/    # modelo de documento, anotações, histórico, exportação
│       │   └── CaptaSistema/   # adaptadores dos frameworks do sistema (captura, OCR, atalhos)
│       └── Tests/
│           └── CaptaNucleoTests/
├── App/                        # alvo do app (SwiftUI/AppKit): telas, overlay, menu bar
│   ├── Fontes/
│   ├── Recursos/               # Assets.xcassets, Localizable.xcstrings, ícone
│   ├── Capta.entitlements
│   └── Info.plist
├── ferramentas/                # scripts: empacotar, conferir_tokens, release, hooks
├── docs/
│   ├── padroes-stack-swift.md  # este arquivo
│   ├── design-system/          # fonte da verdade visual: tokens.json, README.md, assets/Marca, componentes/
│   └── superpowers/specs/      # designs aprovados
└── .github/workflows/ci.yml
```

- O **`Capta.xcodeproj` é gerado e fica no `.gitignore`.** `make gerar` o recria. Sem conflito de
  merge no `.pbxproj`.
- **Por que Xcode e não só SwiftPM:** o app precisa de sandbox, entitlements, ícone, catálogo de
  strings e assinatura — exatamente o ponto em que o playbook de origem manda sair do SwiftPM
  puro. A lógica continua em SwiftPM, testável por `swift test` sem abrir o Xcode.

### Regra dos três alvos

| Alvo | Contém | Pode importar |
| --- | --- | --- |
| `CaptaNucleo` | Documento, anotações, comandos de desfazer/refazer, exportação, regras | Foundation, CoreGraphics, CoreText, CoreImage, ImageIO, UniformTypeIdentifiers |
| `CaptaSistema` | Adaptadores atrás de protocolos do núcleo: captura (ScreenCaptureKit), OCR (Vision), atalho global, área de transferência | Frameworks do sistema, `CaptaNucleo` |
| `Capta` (app) | Telas, overlay, menu bar, navegação, estado de apresentação | SwiftUI, AppKit, `CaptaNucleo`, `CaptaSistema` |

CoreText é permitido no núcleo porque faz parte do desenho de texto sem AppKit.
`CaptaNucleo` **nunca** importa SwiftUI, AppKit, ScreenCaptureKit nem Vision. Os protocolos que
descrevem o que o sistema faz vivem no núcleo; as implementações, em `CaptaSistema`. Isso permite
testar todo o comportamento com dublês, sem tela e sem permissão.

---

## 3. Toolchain

| Ferramenta | Versão base | Função |
| --- | --- | --- |
| **Xcode** | 27 (beta no momento: `/Applications/Xcode-beta.app`, preferido a `/Applications/Xcode.app`) | Toolchain, SDK, assinatura |
| **Swift** | 6.4, modo de linguagem 6 | Compilador |
| **SwiftPM** | tools 6.2 | Pacote do núcleo, `swift test` |
| **XcodeGen** | a fixar | Gera o `.xcodeproj` — **A confirmar:** não está instalado; instalar com `brew install xcodegen` exige sua autorização |
| **swift-format** | o do toolchain (`xcrun swift-format`) | Formatador e lint de estilo |
| **SwiftLint** | 0.65.x (instalado) | Lint de regras de código |
| **Swift Testing** | o do toolchain | `@Test`, `#expect` |
| **xcbeautify** | instalado | Saída legível do `xcodebuild` |
| **Validador de commits** | script `ferramentas/hooks/commit-msg` (expressão regular, sem Node) | Valida Conventional Commits no commit e no CI |

Notas:

- **O `xcode-select` aponta para as Command Line Tools.** Todo comando de build usa
  `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` (o `Makefile` faz isso sozinho,
  como no playbook de origem). Nunca troque o padrão da máquina com `sudo xcode-select`.
- **Toolchain beta.** O app é compilado com Xcode 27 beta. Não distribua nada gerado por beta para a
  App Store; para a loja, recompilar com a versão estável. Para uso pessoal, tudo bem.
- **Um formatador só.** swift-format cuida de formato; SwiftLint cobre o que ele não cobre.
- **Swift Testing, não XCTest**, em teste novo.
- **Dependências de terceiros:** nenhuma no MVP, salvo decisão registrada em `docs/`.
- **semgrep e SonarQube:** fora do escopo inicial. Repositório público de um app pessoal não
  justifica; reavaliar se o projeto crescer.

---

## 4. Convenções

- **Idioma:** domínio em pt-BR, técnica em inglês. Tipos e funções de negócio em português
  (`Anotacao`, `Captura`, `Documento`, `exportar()`); termos de framework e de mercado em inglês
  (`View`, `Sendable`, `actor`). Comentários e documentação em pt-BR.
- **Texto de interface:** sempre pelo String Catalog (`Localizable.xcstrings`), nunca literal na
  `View`. Tom: direto, verbo no infinitivo para ação ("Salvar", "Copiar", "Cancelar"). Erro diz o
  que aconteceu e como resolver.
- **Cor só por token, e o token vem do design system.** A fonte da verdade visual é
  `docs/design-system/` (`tokens.json`, `README.md`, ativos da marca); o espelho navegável é o
  artefato **DS Capta** no Claude Design. `Tema.swift` traduz cada token para Swift:
  - **Superfícies e texto acompanham o macOS.** `texto` → `Color(nsColor: .labelColor)`,
    `textoSecundario` → `.secondaryLabelColor`, `superficieJanela` → `.windowBackgroundColor`;
    `superficiePainel` é material (`.regularMaterial`, com fallback opaco quando "Reduzir
    transparência" estiver ligado); `superficieCanvas` e `bordaControle` vêm do catálogo de
    assets (claro e escuro).
  - **Destaque = cor de destaque do sistema** (`Color.accentColor`), nunca uma cor fixa.
    `anelFoco` usa o mesmo valor.
  - **Cores do conteúdo** (`Tema.Anotacao.vermelho` etc.) vêm do catálogo e são iguais nos dois
    temas; os padrões do núcleo (`CorRGBA`) têm de conferir com elas.
  - **Cores da marca** (`marca-*`) **não existem no código da interface**: vivem só no ícone do
    app e nos materiais de divulgação.
  - Tela nenhuma usa `Color.red`, `.secondary`, `Color(red:…)` ou hexadecimal cru. `make tokens`
    falha se aparecer cor crua em `App/Fontes` ou se os valores `anotacao-*` do catálogo
    divergirem de `docs/design-system/tokens.json`.
- **Tipografia:** fonte do sistema (SF Pro) nos estilos `titulo-janela`, `cabecalho-painel`,
  `corpo`, `apoio`, `rotulo-secao`; SF Mono com números tabulares para medidas (`dimensao`).
  A fonte Outfit (logotipo) não entra no app.
- **Espaço e raios** só pelos tokens (`espaco-*`, `raio-*`); grade de 4 pt.
- **Tema claro e escuro** sempre seguem o sistema; Preferências permitem forçar um. Todo componente
  novo é conferido nos dois temas, com "Reduzir transparência" e "Aumentar contraste".
- **Rigor do compilador:** modo de linguagem Swift 6 e aviso tratado como erro, em todos os
  alvos.
- **Sem force unwrap** (`!`), `try!` ou optional implicitamente desembrulhado em produção. Em
  teste, `URL(string: "literal")!` é aceito.
- **Concorrência:** `async/await` e `actor`. Estado de tela em classe `@MainActor @Observable`.
  Nada de `DispatchQueue` em código novo, nem `@unchecked Sendable` sem comentário que justifique.
- **Camadas:** `View` não decide regra; regra mora no núcleo. Núcleo não conhece o sistema; fala
  com ele por protocolo.
- **Sandbox e privacidade:**
  - App Sandbox ligado. Entitlements só os necessários, cada um com o motivo em comentário no
    `Capta.entitlements`.
  - **Sem rede.** O entitlement `com.apple.security.network.client` não existe no MVP; adicionar
    exige decisão registrada.
  - Sem telemetria, sem conta, sem licença, sem verificação de atualização no MVP.
  - Imagem capturada nunca sai da máquina sem ação explícita do usuário.
  - Nada sensível em log. Capturas e texto extraído por OCR são conteúdo do usuário: não logar.
  - Arquivos fora da pasta do app só por seletor do usuário ou segurança com escopo
    (*security-scoped bookmark*).
- **Permissões:** pedir só no ponto de uso, com explicação. Gravação de Tela é a única obrigatória;
  as demais (microfone, câmera, acessibilidade) só entram junto da funcionalidade que as exige.
- **Acessibilidade:** controle com rótulo em pt-BR; imagem decorativa escondida do leitor de tela;
  nenhuma informação depende só de cor; atalhos de teclado para as ações principais.
- **Versões fixadas:** `Package.resolved` versionado; dependência com versão exata ou intervalo
  fechado, nunca `branch:`.
- **Segredos:** não há. Repositório é **público**: nenhum certificado, perfil de provisionamento,
  `.p12`, chave ou token entra no Git (ver `.gitignore`).
- **Conventional Commits** com descrição em pt-BR (`feat(captura): adiciona captura de região`).
  Tipos: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `ci`, `build`, `revert`.
- **Nada de material do Snagit no repositório:** nem código, nem recursos, nem estruturas de
  arquivo copiadas. O Capta é implementação própria; a engenharia reversa serviu para decidir
  *o que* construir, não *como* escrever.

---

## 5. Scaffolding (passo a passo)

```bash
# 0. Pré-requisitos (cada instalação pede autorização do dono do projeto)
#    Xcode-beta instalado; SwiftLint já presente; XcodeGen:
brew install xcodegen

# 1. Clonar o repositório vazio
cd /Volumes/DOCK/Projetos/pessoal
git clone https://github.com/pedroct/capta.git && cd capta

# 2. Estrutura
mkdir -p Packages/CaptaNucleo/Sources/{CaptaNucleo,CaptaSistema} \
         Packages/CaptaNucleo/Tests/CaptaNucleoTests \
         App/Fontes App/Recursos ferramentas docs/superpowers/specs .github/workflows

# 3. Criar project.yml, Package.swift, .swift-format, .swiftlint.yml, Makefile,
#    .gitignore e LICENSE a partir da seção 6

# 4. Verificação completa
make gerar && make verificar

# 5. Empacotar e abrir
make app && open build/Capta.app
```

O scaffolding só começa depois do design aprovado e do plano escrito.

---

## 6. Templates de configuração

### `Packages/CaptaNucleo/Package.swift`

```swift
// swift-tools-version: 6.2
import PackageDescription

// Modo estrito: Swift 6 (concorrência completa) e aviso tratado como erro.
let rigor: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "CaptaNucleo",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CaptaNucleo", targets: ["CaptaNucleo"]),
        .library(name: "CaptaSistema", targets: ["CaptaSistema"]),
    ],
    targets: [
        .target(name: "CaptaNucleo", swiftSettings: rigor),
        .target(name: "CaptaSistema", dependencies: ["CaptaNucleo"], swiftSettings: rigor),
        .testTarget(
            name: "CaptaNucleoTests",
            dependencies: ["CaptaNucleo"],
            swiftSettings: rigor
        ),
        .testTarget(
            name: "CaptaSistemaTests",
            dependencies: ["CaptaSistema", "CaptaNucleo"],
            swiftSettings: rigor
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

### `project.yml` (XcodeGen)

```yaml
name: Capta
options:
  deploymentTarget: { macOS: "14.0" }
  developmentLanguage: pt-BR
# Assinatura local: DEVELOPMENT_TEAM vem de project.local.yml (fora do Git; veja o .example).
# O Makefile exporta CAPTA_LOCAL=true só quando o arquivo existe.
include:
  - path: project.local.yml
    enable: ${CAPTA_LOCAL}
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    SWIFT_TREAT_WARNINGS_AS_ERRORS: YES
    ENABLE_HARDENED_RUNTIME: YES
    PRODUCT_BUNDLE_IDENTIFIER: com.pedroct.capta   # A confirmar: domínio/ID definitivo
packages:
  CaptaNucleo: { path: Packages/CaptaNucleo }
targets:
  Capta:
    type: application
    platform: macOS
    sources: [App/Fontes, App/Recursos]
    dependencies:
      - package: CaptaNucleo
        product: CaptaNucleo
      - package: CaptaNucleo
        product: CaptaSistema
    settings:
      base:
        INFOPLIST_FILE: App/Info.plist
        # Arquivo à mão (com um comentário por chave); a chave `entitlements:` do XcodeGen o sobrescreveria.
        CODE_SIGN_ENTITLEMENTS: App/Capta.entitlements
        PRODUCT_NAME: Capta
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        CODE_SIGN_STYLE: Automatic
        # DEVELOPMENT_TEAM fica fora do Git: vem de `project.local.yml` (no .gitignore)
```

### `.swift-format`

```json
{
  "version": 1,
  "lineLength": 100,
  "indentation": { "spaces": 4 },
  "maximumBlankLines": 1,
  "respectsExistingLineBreaks": true,
  "lineBreakBeforeEachArgument": true,
  "rules": {
    "NeverForceUnwrap": true,
    "NeverUseForceTry": true,
    "NeverUseImplicitlyUnwrappedOptionals": true,
    "OrderedImports": true,
    "UseLetInEveryBoundCaseVariable": true
  }
}
```

### `.swiftlint.yml`

```yaml
# Formatação é do swift-format; o SwiftLint cobre só o que ele não cobre.
included:
  - App
  - Packages
strict: true
disabled_rules:
  - trailing_comma
  - opening_brace
  - line_length
  - closure_parameter_position
  - identifier_name # o domínio é pt-BR e usa nomes curtos como `id`
opt_in_rules:
  - force_unwrapping
  - implicitly_unwrapped_optional
  - unowned_variable_capture
  - weak_delegate
  - empty_count
  - first_where
  - private_swiftui_state
  - accessibility_label_for_image
cyclomatic_complexity: { warning: 15, error: 15 }
function_body_length: { warning: 60, error: 60 }
file_length: { warning: 400, error: 400 }
analyzer_rules:
  - unused_import
```

As quatro primeiras regras desligadas são de formato e conflitam com o swift-format.

### `Packages/CaptaNucleo/Tests/.swiftlint.yml`

```yaml
# Em teste, `URL(string: "literal")!` é aceitável: a falha aparece no próprio teste.
disabled_rules:
  - force_unwrapping
```

### `Makefile`

```makefile
ifeq ($(origin DEVELOPER_DIR), undefined)
  export DEVELOPER_DIR := $(firstword $(wildcard /Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode.app/Contents/Developer))
endif

FONTES := App Packages

# project.local.yml (assinatura) é opcional: o project.yml só o inclui se existir.
export CAPTA_LOCAL := $(if $(wildcard project.local.yml),true,false)

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: gerar format lint build test tokens entitlements verificar app

gerar:
	xcodegen generate

format:
	xcrun swift-format format --in-place --recursive $(FONTES)

lint:
	xcrun swift-format lint --strict --recursive $(FONTES)
	swiftlint lint --quiet

build: gerar
	xcodebuild -scheme Capta -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build | xcbeautify

test:
	cd Packages/CaptaNucleo && swift test

tokens:
	./ferramentas/conferir_tokens.sh

entitlements:
	./ferramentas/conferir_entitlements.sh

verificar: lint build test tokens entitlements

app: gerar
	./ferramentas/empacotar.sh
```

| Alvo | O que faz |
| --- | --- |
| `make gerar` | Gera `Capta.xcodeproj` a partir do `project.yml` (o `Makefile` exporta `CAPTA_LOCAL`, que liga o `include` de `project.local.yml` só se o arquivo existir) |
| `make format` | Corrige a formatação |
| `make lint` | Confere formato e regras, sem alterar nada |
| `make build` | Compila o app em modo estrito |
| `make test` | Roda os testes do núcleo |
| `make tokens` | Falha se houver cor crua na interface |
| `make entitlements` | Confere as chaves de entitlements do app (`ferramentas/conferir_entitlements.sh`) |
| `make verificar` | `lint`, `build`, `test`, `tokens` e `entitlements` (sem `format`) — é o que o CI roda localmente |
| `make app` | Monta o `.app` assinado para uso próprio |

### `.gitignore`

```gitignore
.build/
build/
.swiftpm/
*.xcodeproj
xcuserdata/
DerivedData/
project.local.yml
.env
.env.*
!.env.example
# Segredos de assinatura — o repositório é público
*.p12
*.cer
*.certSigningRequest
*.mobileprovision
*.provisionprofile
*.dmg
```

### `App/Capta.entitlements` — ponto de partida do MVP

```xml
<!-- Cada chave tem um motivo. Adicionar uma nova exige decisão registrada em docs/. -->
<dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <!-- Salvar capturas onde o usuário escolher -->
  <key>com.apple.security.files.user-selected.read-write</key><true/>
  <!-- Gravação de Tela é permissão TCC, não entitlement. Rede: ausente de propósito. -->
</dict>
```

### `Info.plist` — chaves obrigatórias

| Chave | Valor | Motivo |
| --- | --- | --- |
| `CFBundleIdentifier` | definido no `project.yml` | Identidade do app |
| `CFBundleShortVersionString` | versão SemVer | Escrita pelo `make release` |
| `CFBundleVersion` | inteiro crescente | Número de build |
| `LSMinimumSystemVersion` | `14.0` | Igual ao `deploymentTarget` |
| `LSApplicationCategoryType` | `public.app-category.graphics-design` | Categoria da loja |
| `NSAppTransportSecurity` | ausente | O app não usa rede |

---

## 7. CI (GitHub Actions)

Repositório público: minutos em runner macOS são gratuitos. **A confirmar:** se os runners
`macos-*` já trazem Xcode 27 (os jobs escolhem o Xcode mais novo instalado em `/Applications`).

| Job | O que roda | Quando |
| --- | --- | --- |
| `verificar` | `make lint`, `make test`, `make tokens`, `make entitlements` | PR + push na `main` |
| `app` | `brew install xcodegen xcbeautify` e `make gerar build` (compila o app, sem assinar) | PR + push na `main` |
| `commits` | script `commit-msg` sobre os commits do PR ou do push | PR + push na `main` |

O `make verificar` completo roda localmente (hook `pre-push`); no CI ele é dividido nos jobs
`verificar` e `app` para que a falha de um não esconda a do outro. Todo `actions/checkout` usa
`persist-credentials: false`.

Sem assinatura nem notarização no CI: não há segredo no repositório público. A compilação de
verificação usa `CODE_SIGNING_ALLOWED=NO`; só `make app` assina, com o `DEVELOPMENT_TEAM` de
`project.local.yml` (fora do Git, com `project.local.yml.example` versionado). O pacote é montado
na sua máquina.

Hooks versionados em `ferramentas/hooks/`, ativados por `git config core.hooksPath
ferramentas/hooks`: `commit-msg` (script de expressão regular), `pre-commit` (`make lint`), `pre-push`
(`make verificar`).

---

## 8. Versionamento, changelog e release semanal

- **SemVer dirigido por Conventional Commits:** `feat` → MINOR · `fix`/`perf` → PATCH ·
  `feat!`/`BREAKING CHANGE` → MAJOR. Enquanto for `0.x`, mudanças incompatíveis sobem o MINOR.
- **Changelog gerado, nunca escrito à mão** (`CHANGELOG.md`).
- **Cadência:** uma versão por semana, disparada por você com `make release`. Sem `feat` ou `fix`
  desde a última tag, não há release.
- **A versão vive no `Info.plist`** (`CFBundleShortVersionString`); `CFBundleVersion` é o número de
  commits da `main`.
- **Artefato:** `.dmg` anexado à GitHub Release.
- **Ferramenta de changelog/versão — A confirmar:** `semantic-release` (Node, via `pnpm dlx`) ou
  `git-cliff`. O script `ferramentas/release.sh` esconde a escolha.

---

## 9. Distribuição

| Fase | Como |
| --- | --- |
| **Agora (uso pessoal)** | `.app` assinado com seu certificado Apple Development, `.dmg` na GitHub Release. Outras pessoas precisam liberar manualmente o app nas Configurações do Sistema (Gatekeeper). |
| **Distribuição aberta** | Developer ID Application + notarização (`xcrun notarytool`, `stapler`). **Exige conta paga; a conta atual é gratuita**, então esta fase está bloqueada até o upgrade. |
| **Loja** | Mac App Store: *Apple Distribution*, sandbox ligado (já é regra), recompilar com Xcode estável, política de privacidade, capturas de tela da loja. |

Consequências para o código, desde já:

1. **Sandbox ligado desde o primeiro build.** O que não funciona sob sandbox não entra no design
   sem alternativa.
2. **Sem recursos que a loja barra:** acessibilidade para controlar outros apps, AppleEvents
   amplos, leitura da URL do navegador. A captura com rolagem automática da Fase 2 precisa de um
   desenho próprio compatível com sandbox — **risco registrado**, resolvido na especificação da
   Fase 2.
3. **Sem helper em LoginItem separado** no MVP (o Snagit usa um): app único com ícone na barra de
   menus, mais simples de assinar e de enviar à loja. Iniciar no login, quando entrar, usa
   `SMAppService` (permitido pela loja).

---

## 10. Checklist de revisão

Antes de aprovar um PR:

- [ ] `make verificar` passa: formato, lint, compilação estrita, testes e tokens.
- [ ] Regra nova tem teste no núcleo; comportamento de sistema tem dublê e teste.
- [ ] Nenhum `!`, `try!` ou `@unchecked Sendable` novo sem justificativa.
- [ ] Nenhuma cor crua; só `Tema.*`.
- [ ] Texto de tela está no String Catalog, em pt-BR.
- [ ] Nenhum entitlement novo sem motivo comentado; nenhum acesso à rede.
- [ ] Nada sensível em log; nenhum segredo, certificado ou perfil no diff.
- [ ] Controles com rótulo de acessibilidade; atalho para ação principal.
- [ ] Nada copiado do Snagit (código, recurso ou arquivo).
- [ ] Commit em Conventional Commits.

---

## Pendências deste documento

| Item | Seção | Depende de |
| --- | --- | --- |
| Instalar XcodeGen | 3 | Autorização do dono do projeto |
| Runner GitHub com Xcode 27 | 7 | Verificação |
| Ferramenta de changelog (semantic-release ou git-cliff) | 8 | Decisão no plano |
| ID do bundle e domínio definitivos | 6 | Decisão do dono |
| Conta Apple Developer **paga** (Developer ID / loja) | 9 | Decisão do dono; hoje a conta é gratuita |
| Captura com rolagem compatível com sandbox | 9 | Especificação da Fase 2 |
