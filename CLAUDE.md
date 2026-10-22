# Capta — instruções do projeto

App macOS de captura e anotação de tela. Swift 6 (modo 6, aviso tratado como erro), macOS 14+, sem dependências de terceiros, sem rede, sem conta ou telemetria. Leia antes de mexer: `docs/padroes-stack-swift.md` (padrões), `docs/superpowers/specs/2026-10-20-capta-mvp-design.md` (spec) e `docs/design-system/` (tokens).

## Comandos

Sempre pelo `make`; o Makefile define o `DEVELOPER_DIR` do Xcode-beta. `swift test` puro falha por não achar o TestingMacros.

- `make verificar`: lint, build, cobertura do pacote, tokens e entitlements. Precisa passar antes de todo commit. Roda o portão de cobertura do pacote, mas não os testes do app.
- `make test`: testes do pacote. `make cobertura`: testes com piso por alvo (98 % em `CaptaNucleo` e `CaptaSistema`); relatórios em `build/cobertura/`. `make cobertura-app`: testes do app (`CaptaTests`) com piso próprio, fora do `verificar`. Os pisos ficam em `ferramentas/cobertura.pisos`; subir um piso vai em commit próprio. `make gerar`: gera o `.xcodeproj` (XcodeGen). `make app`: build assinado em `build/Capta.app` (exige `project.local.yml`, ignorado pelo Git, a partir de `project.local.yml.example`).
- Nunca rodar `sudo xcode-select`.

## Arquitetura

`Capta` (UI, `App/`) → `CaptaSistema` (adaptadores do sistema) → `CaptaNucleo` (regra pura, em `Packages/CaptaNucleo`).

- `CaptaNucleo` importa só Foundation, CoreGraphics, CoreText, CoreImage, ImageIO e UniformTypeIdentifiers. Nunca SwiftUI, AppKit, ScreenCaptureKit ou Vision. Protocolos do sistema ficam no núcleo; implementações em `CaptaSistema`.
- Coordenadas do documento: pixels da imagem base, origem no canto superior esquerdo, Y para baixo. O renderizador inverte o eixo uma vez.
- O estado do documento é um valor; `Documento.validar()` é o guardião das invariantes e roda em toda edição, no decode e antes de gravar ou renderizar.
- Sandbox ligado; entitlements só `app-sandbox` e `files.user-selected.read-write`.

## Convenções

- Domínio, comentários, docs e commits em pt-BR; nomes de framework em inglês. Sem `!`, `try!` nem IUO em código de produção.
- Texto de interface só pelo String Catalog; cor só por token (`Tema.*`); cores da marca nunca na interface.
- TDD: teste que falha primeiro. Testes com Swift Testing.
- Commits em Conventional Commits (`feat|fix|refactor|test|docs|chore|perf|ci|build|revert`, escopo opcional). Autor e committer: `Pedro Teixeira <noreply@pedroct.com.br>`. Sem `Co-Authored-By` e sem menção a IA em commits ou PRs. Nunca `--no-verify`.
- `git push` e instalação de software pedem confirmação do Pedro.

## Estado e próximos passos

O Plano 1 (esqueleto e núcleo) está concluído; o status e as decisões adiadas estão no fim de `docs/superpowers/plans/2026-10-20-capta-plano-1-esqueleto-e-nucleo.md`. Esquema em v2 (`docs/esquema-capta-v2.md`), que muda no lugar até o fim do Plano 5c e então congela.
