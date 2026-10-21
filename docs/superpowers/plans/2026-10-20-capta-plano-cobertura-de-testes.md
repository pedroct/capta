# Cobertura de testes — Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: usar superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa a tarefa. Os passos usam caixas `- [ ]`.

**Meta:** medir a cobertura de linhas do Capta, cobrá-la na CI e no `make verificar` com piso de 98 % em `CaptaNucleo` e `CaptaSistema`, e deixar o relatório pronto para o SonarQube.

**Arquitetura:** um script em `ferramentas/` roda os testes do pacote com cobertura, consolida com `llvm-cov` nos dois binários de teste (o JSON do SwiftPM só cobre `CaptaNucleoTests` e inclui arquivos de teste), compara cada alvo com os pisos de um arquivo versionado e escreve texto, JSON e XML `sonar-generic-coverage` em `build/cobertura/`. A cobertura do app vem de um alvo de testes XcodeGen, rodado só na CI e em `make cobertura-app`.

**Stack:** shell + `xcrun llvm-cov`/`xccov` (do Xcode), Swift Testing, XcodeGen, GitHub Actions. Sem dependências novas.

**Spec:** `docs/superpowers/specs/2026-10-20-capta-cobertura-de-testes-design.md`

## Restrições globais

- Swift 6 em modo estrito, aviso como erro; macOS 14+; sem terceiros; sem `!`, `try!` nem IUO em código de produção.
- Comandos sempre pelo `make` (o Makefile define `DEVELOPER_DIR`; `swift test` puro falha). `make verificar` passa antes de todo commit.
- Domínio, comentários, docs e commits em pt-BR; Conventional Commits; autor `Pedro Teixeira <noreply@pedroct.com.br>`; sem `Co-Authored-By` nem menção a IA; nunca `--no-verify`.
- Testes com Swift Testing, TDD; todo teste novo afirma comportamento observável (nada de teste que só executa linha).
- Não instalar software; `git push` pede confirmação do Pedro.
- Piso por **alvo** (`CaptaNucleo`, `CaptaSistema`, `App`), métrica de **linhas**; arquivo abaixo de 98 % só é sinalizado. Pisos vivem em `ferramentas/cobertura.pisos`.
- Código inalcançável: simplificar o código antes de aceitar ficar abaixo; exceção só com comentário explicando.

## Linha de base (medida em 2026-10-20, `make test` com cobertura)

| Alvo | Linhas | Perdidas |
|---|---|---|
| `CaptaNucleo` | 96,5 % (688/713) | 25 |
| `CaptaSistema` | 96,0 % (48/50) | 2 |

Para 98 % de linhas, o núcleo aceita no máximo 14 perdidas (cortar pelo menos 11) e `CaptaSistema` no máximo 1. Pontos perdidos conhecidos: `Edicao.swift` (`deslocada` para `.texto`, `.etapa`, `.desfoque`: linhas 97–109), `Documento.swift:112` (cor fora da faixa), `DesenhoFormas.swift:49–50` (retângulo arredondado) e `:118` (etapa com traço), `Renderizador.swift:87` (recorte inválido) e `:126–127`, mais 2 linhas em `Utilitarios.swift`, 2 em `DesenhoTexto.swift` e 2 em `ProvedorDeSimbolosSF.swift`. Rodar a medição de novo antes de escrever os testes: a lista real vem do relatório.

## Revisão de foco

- Perfil de cobertura vazio ou ausente (testes não rodaram): o script **falha**, nunca reporta 100 %.
- Alvo sem nenhuma linha encontrada no relatório (renomeado ou filtro errado): falha com mensagem, não passa.
- Arquivo de pisos com alvo faltando ou valor não numérico: falha com mensagem em pt-BR.
- Caminho com espaço (o volume `DOCK` e `Swift Testing…profraw` têm espaços ou nomes longos): o script lida com aspas.
- Gate precisa **falhar de verdade**: cada piso é conferido uma vez subindo-o a 100 e vendo `make cobertura` sair com erro.

## Estrutura de arquivos

- Criar `ferramentas/cobertura.sh`: roda testes com cobertura, consolida, imprime tabela, aplica pisos, gera artefatos.
- Criar `ferramentas/cobertura.pisos`: `alvo=piso` por linha (comentário `#` permitido).
- Criar `ferramentas/cobertura_sonar.sh` ou função no mesmo script: converte o JSON do llvm-cov em XML `sonar-generic-coverage`.
- Modificar `Makefile`: alvos `cobertura`, `cobertura-app`; `verificar` troca `test` por `cobertura`.
- Modificar `.github/workflows/ci.yml`: passo de cobertura, resumo e artefato; cobertura do app no job `app`.
- Modificar `project.yml`: alvo `CaptaTests` do app.
- Criar testes em `Packages/CaptaNucleo/Tests/...` e `App/Testes/`.
- Modificar `CLAUDE.md`, `docs/padroes-stack-swift.md`.

---

### Task 1: Medição e gate de cobertura do pacote

**Arquivos:**
- Criar: `ferramentas/cobertura.sh`, `ferramentas/cobertura.pisos`
- Modificar: `Makefile`

**Interfaces:**
- Produz: `make cobertura` (código 0 se todos os pisos forem atendidos); `build/cobertura/resumo.txt`, `build/cobertura/llvm-cov.json` (um JSON por alvo ou combinado, com caminhos relativos à raiz do repositório); `cobertura.sh` aceita `PISOS=<arquivo>` para sobrescrever o arquivo de pisos (usado só para conferir o gate).
- Formato de `ferramentas/cobertura.pisos`: linhas `CaptaNucleo=96`, `CaptaSistema=96` (valores iniciais **abaixo** da linha de base, para o gate nascer verde; sobem na Tarefa 6).

- [ ] **Passo 1: Escrever `cobertura.sh` com a falha esperada primeiro.** Comportamento: `cd Packages/CaptaNucleo && swift test --enable-code-coverage`; localizar `default.profdata` e os binários `CaptaNucleoTests.xctest/Contents/MacOS/CaptaNucleoTests` e `CaptaSistemaTests…` com `swift build --show-bin-path`; `xcrun llvm-cov report/export` por alvo com `-ignore-filename-regex='/Tests/|\.build/'`; agrupar arquivos em `CaptaNucleo` (caminho `Sources/CaptaNucleo/`) e `CaptaSistema` (`Sources/CaptaSistema/`); imprimir arquivo, linhas cobertas/total e % (mais regiões), e o total por alvo; sinalizar com `⚠` arquivos abaixo de 98 %.
- [ ] **Passo 2: Rodar contra a linha de base.** `make cobertura` deve imprimir CaptaNucleo ≈ 96,5 % e CaptaSistema ≈ 96,0 % e sair com 0.
- [ ] **Passo 3: Conferir as falhas da Revisão de foco.** (a) `PISOS=<arquivo com CaptaNucleo=100>` → sai com erro e a mensagem cita alvo, valor e piso; (b) apagar `default.profdata` antes de consolidar → erro "sem perfil de cobertura"; (c) arquivo de pisos sem `CaptaSistema` → erro; cada caso termina em código ≠ 0.
- [ ] **Passo 4: `Makefile`.** Alvo `.PHONY` `cobertura` chamando o script; `verificar: lint build cobertura tokens entitlements` (mantém `make test` isolado e sem medição).
- [ ] **Passo 5: `make verificar` passa; commit** `feat(ferramentas): mede cobertura de linhas e aplica piso por alvo`.

---

### Task 2: Testes de `Edicao` (`deslocada`) e `Documento`

**Arquivos:**
- Testar: `Tests/CaptaNucleoTests/EdicaoTests.swift`, `ModeloTests.swift`
- Código de produção só se um teste revelar bug.

**Interfaces:**
- Consome: `Edicao` (a mover objetos), `Documento.validar()`, `ErroDocumento.valorForaDeFaixa`.

- [ ] **Passo 1: Testes que falham de verdade ou cobrem:** em `EdicaoTests`, um teste por geometria ainda não coberta, `deslocarMoveTextoEPreservaConteudoEFonte`, `deslocarMoveCentroDaEtapaEPreservaDiametroEReinicio`, `deslocarMoveRetanguloDoDesfoquePreservandoTipoEIntensidade`: aplicar o deslocamento (use a edição que chama `deslocada`; confira o nome em `Edicao.swift`) e afirmar a geometria nova **e** que os demais campos ficam iguais. Em `ModeloTests`, `corForaDaFaixaEhRejeitadaPeloValidar` (componente 1,5 e NaN) esperando `.valorForaDeFaixa("cor")`.
- [ ] **Passo 2: Rodar `make cobertura`; ver os trechos acima saírem da lista de perdidos. Completar com o que sobrar de `Edicao.swift` (cobertura 87 %) olhando o relatório (`llvm-cov show`); cada linha sobrando ganha um teste de comportamento.**
- [ ] **Passo 3: `make verificar`; commit** `test(nucleo): cobre o deslocamento de texto, etapa e desfoque e a validação de cor`.

---

### Task 3: Testes da renderização (`DesenhoFormas`, `Renderizador`, `Utilitarios`, `DesenhoTexto`)

**Arquivos:**
- Testar: `Tests/CaptaNucleoTests/RenderizadorFormasTests.swift`, `RenderizadorValidacaoTests.swift`, `RenderizadorTextoTests.swift`, e um `UtilitariosTests.swift` novo.

**Interfaces:**
- Consome: `Renderizador`, `Documento`, helpers de `Apoio/Pixels.swift`, `retanguloUtil(_:)`, `cgCor(_:)` (acesso por `@testable import` — verificar que já é o padrão dos testes do núcleo; se não for, testar via renderizador).

- [ ] **Passo 1: Testes:** `retanguloArredondadoTemCantosVaziosECentroPreenchido` (pixel do canto da base fica transparente/igual à base, centro com a cor), `etapaComTracoDesenhaBordaDeCorDiferenteDoFundo`, `recorteInvalidoLancaRecorteInvalido` (recorte sem área ou fora da imagem), `retanguloUtilDescartaSemAreaNaoFinitoEPadronizaNegativo`, e um teste por ramo de `DesenhoTexto` perdido (texto vazio, texto que não cabe, alinhamento — confirmar pelo relatório quais linhas faltam).
- [ ] **Passo 2: Linhas `Renderizador.swift:126–127` (`break` de caso tratado em outro lugar):** se um teste de comportamento não alcançar, simplificar o `switch` (remover o caso redundante agrupando com `default` ou reorganizando) em vez de forçar teste; descrever no commit.
- [ ] **Passo 3: `make cobertura`: `CaptaNucleo` ≥ 98 % de linhas.**
- [ ] **Passo 4: `make verificar`; commit** `test(nucleo): cobre formas, recorte inválido, utilitários e texto do renderizador`.

---

### Task 4: Testes de `ProvedorDeSimbolosSF`

**Arquivos:**
- Testar: `Tests/CaptaSistemaTests/ProvedorDeSimbolosSFTests.swift`

- [ ] **Passo 1: Testes dos dois ramos perdidos.** Identificar no relatório as 2 linhas (candidatas: `lado` não finito/fora de `1...4096`, símbolo sem tamanho); testes: `ladoNaoFinitoOuForaDaFaixaDevolveNil` (NaN, 0, 0,5, 5000), `corTingeOSimboloComOAlfaPreservado` (pixel no centro do símbolo tem a cor pedida; pixel do canto transparente).
- [ ] **Passo 2: `make cobertura`: `CaptaSistema` ≥ 98 %** (no máximo 1 linha perdida); se sobrar uma linha de falha de API do sistema que não se provoca, simplificar o `guard` ou deixar comentário.
- [ ] **Passo 3: `make verificar`; commit** `test(sistema): cobre a validação de lado e a tinta do provedor de símbolos`.

---

### Task 5: Relatório para o SonarQube

**Arquivos:**
- Modificar: `ferramentas/cobertura.sh` (ou criar `ferramentas/cobertura_sonar.sh` chamado por ele)

**Interfaces:**
- Produz: `build/cobertura/sonar-cobertura.xml` no formato `<coverage version="1"><file path="Packages/CaptaNucleo/Sources/…"><lineToCover lineNumber="N" covered="true|false"/>…</file></coverage>`, só com arquivos de produção, caminhos relativos à raiz do repositório.

- [ ] **Passo 1: Gerar o XML a partir do `llvm-cov export` (segmentos/linhas executáveis).**
- [ ] **Passo 2: Conferir o XML:** (a) `xmllint --noout` passa; (b) todo `path` existe no repositório (loop de shell); (c) nenhum caminho contém `/Tests/` nem `.build`; (d) a contagem de `lineToCover` por arquivo bate com as linhas executáveis do relatório de texto (±0).
- [ ] **Passo 3: `make verificar`; commit** `feat(ferramentas): gera relatório de cobertura no formato do SonarQube`.

---

### Task 6: Subir os pisos para 98 %

**Arquivos:**
- Modificar: `ferramentas/cobertura.pisos`

- [ ] **Passo 1:** `CaptaNucleo=98` e `CaptaSistema=98`. `make cobertura` passa.
- [ ] **Passo 2:** subir temporariamente um piso para 100 e conferir que o gate falha com a mensagem certa; desfazer.
- [ ] **Passo 3: commit** `chore: sobe o piso de cobertura do núcleo e do sistema para 98 %`.

---

### Task 7: Cobertura do app (`App/Fontes`)

**Arquivos:**
- Modificar: `project.yml`, `Makefile`
- Criar: `App/Testes/TemaTests.swift`

**Interfaces:**
- Produz: alvo XcodeGen `CaptaTests` (tipo `bundle.unit-test`, plataforma macOS, depende de `Capta`), `make cobertura-app` (gera o projeto, roda `xcodebuild test -scheme Capta -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO`, extrai com `xcrun xccov view --report --json`, imprime a linha de `App/Fontes` sem `CaptaApp.swift` e compara com o piso `App=` de `cobertura.pisos`).

- [ ] **Passo 1: Teste que falha primeiro:** `TemaTests`: `fundoDoPainelUsaSuperficieOpacaComReduzirTransparencia` e `fundoDoPainelUsaMaterialPorPadrao` (comparar o `AnyShapeStyle` não é direto: testar por `Tema.fundoDoPainel(reduzirTransparencia:)` renderizado/descrito, ou extrair a decisão para uma função pura testável sem mudar o comportamento visível); mais um teste de que os nomes de cor de `Tema.Anotacao.*` existem no catálogo (`NSColor(named:)` não nulo).
- [ ] **Passo 2: Configurar o alvo no `project.yml`**, sem assinatura, que roda sem `project.local.yml`. Medir. Escrever o valor medido, arredondado para baixo, em `App=` de `cobertura.pisos`. `CaptaApp.swift` fica fora da conta no script (filtro por nome).
- [ ] **Passo 3: Se `xcodebuild test` não rodar com sandbox e teste hospedado** (bundle de testes injetado em app sandboxed e sem assinatura), aplicar o fallback do spec §7: medir só o pacote, deixar o app fora do gate e registrar a decisão e a causa no spec e em `docs/padroes-stack-swift.md`. Não é falha do plano, mas a decisão não pode ser silenciosa.
- [ ] **Passo 4: `make verificar` e `make cobertura-app`; commit** `test(app): mede a cobertura de App/Fontes e cobre o Tema`.

---

### Task 8: CI e documentação

**Arquivos:**
- Modificar: `.github/workflows/ci.yml`, `CLAUDE.md`, `docs/padroes-stack-swift.md`

- [ ] **Passo 1: CI, job `verificar`:** trocar `make test` por `make cobertura`; passo seguinte (`if: always()`) que escreve `build/cobertura/resumo.txt` em `$GITHUB_STEP_SUMMARY` e envia `build/cobertura/` com `actions/upload-artifact` (versão fixa, acima de duas semanas de idade). Job `app`: acrescentar `make cobertura-app` (se o alvo existir; senão registrar o fallback).
- [ ] **Passo 2: Docs:** `CLAUDE.md` (comandos: `make cobertura`, `make cobertura-app`; pisos em `ferramentas/cobertura.pisos`; subir piso em commit próprio) e `docs/padroes-stack-swift.md` (seção de qualidade: piso 98 % por alvo, medição por `llvm-cov`, XML do Sonar, divergência CI × local = vale o menor).
- [ ] **Passo 3: `make verificar` local; commit** `ci: cobra o piso de cobertura e publica o relatório`.
- [ ] **Passo 4: 🔒 `git push` após confirmação do Pedro; conferir `gh run list --limit 1` → `success`.** Se o valor na CI divergir do local, usar o menor para o piso e registrar a divergência em comentário em `cobertura.pisos`.

---

## Autorrevisão

- **Cobertura da spec:** §5.1–5.3 (tabela, artefatos, gate) → T1; §5.4 (`verificar`) → T1; §5.5 (resumo e artefato na CI) → T8; §5.6 (subir piso em commit próprio) → T6; §6 (testes) → T2–T4; XML do Sonar (§1/§4) → T5; §7 (app e fallback) → T7; §8 aceite → T6, T7, T8; documentação → T8.
- **Chamadas do spec §9.1:** piso por alvo (T1); `make verificar` só mede o pacote e o app fica em `cobertura-app` e na CI (T7, T8); caminhos relativos (T5); piso do app pelo valor honesto (T7); CI × local (T8).
- **Descoberta que muda o desenho:** o JSON do SwiftPM não inclui `CaptaSistema` e inclui arquivos de teste, por isso a T1 usa `llvm-cov` direto nos dois binários.
- **Desvio de ordem:** os pisos nascem abaixo da linha de base (T1) e só chegam a 98 % na T6, depois dos testes; o gate nunca fica vermelho no meio do caminho.
