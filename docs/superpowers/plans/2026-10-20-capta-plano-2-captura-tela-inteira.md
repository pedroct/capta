# Capta — Plano 2: Captura de tela inteira

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fechar o esquema v1 do `.capta` e entregar o primeiro fluxo ponta a ponta: atalho ou menu → captura da tela sob o cursor → rascunho gravado → janela com copiar, salvar PNG e salvar `.capta`, com o fluxo de permissão de Gravação de Tela.

**Architecture:** O núcleo ganha o esquema v1 estável, a numeração por ordem de criação, miniatura, PNG, exportação e os protocolos de sistema. `CaptaSistema` implementa os protocolos (ScreenCaptureKit, permissão, pasteboard, painel de arquivos, atalho Carbon); o que chama a API do sistema e não roda sem tela ou permissão fica em `Casca/`, fora do portão de cobertura por uma lista explícita. O app tem um coordenador testável (`FluxoDeCaptura`) e views SwiftUI finas.

**Tech Stack:** Swift 6.4 (modo 6), SwiftPM, XcodeGen, Swift Testing, ScreenCaptureKit, ImageIO, AppKit/SwiftUI, Carbon (só `RegisterEventHotKey`).

**Spec:** `docs/superpowers/specs/2026-10-20-capta-captura-tela-inteira-design.md`. Spec de origem: `docs/superpowers/specs/2026-10-20-capta-mvp-design.md` (§4.2, §4.3, §4.8, §5). Padrões: `docs/padroes-stack-swift.md`. Leia os três antes de começar.

## Global Constraints

- macOS **14+**; Swift 6 em modo de linguagem 6; **aviso tratado como erro**; **nenhuma dependência de terceiros**.
- **App Sandbox ligado**; entitlements **só** `app-sandbox` e `files.user-selected.read-write`; **sem rede**, sem conta, sem telemetria; **nenhuma permissão além de Gravação de Tela** (nada de Acessibilidade).
- `CaptaNucleo` importa só Foundation, CoreGraphics, CoreText, CoreImage, ImageIO e UniformTypeIdentifiers; nunca SwiftUI, AppKit, ScreenCaptureKit ou Vision. Protocolos do sistema no núcleo; implementações em `CaptaSistema`.
- Coordenadas do documento: pixels da imagem base, origem no canto superior esquerdo, Y para baixo.
- Domínio, comentários, docs e commits em **pt-BR**; sem `!`, `try!` nem IUO em produção. Texto de interface só pelo String Catalog; cor só por `Tema.*`; nada de texto de erro técnico ou em inglês na interface; nada sensível em log.
- TDD: teste que falha primeiro, com Swift Testing. Cobertura do pacote ≥ **98 %** por alvo; **nunca descer um piso**; subir piso vai em commit próprio.
- **`make verificar` passa antes de todo commit.** Comandos sempre pelo `make` (`make test` roda os testes do pacote; `make cobertura-app` roda os do app). Nunca `swift test` puro, nunca `sudo xcode-select`.
- Commits em Conventional Commits, descrição em pt-BR, autor e committer `Pedro Teixeira <noreply@pedroct.com.br>` (já configurado no repositório), **sem `Co-Authored-By` e sem menção a IA**, nunca `--no-verify`.
- `git push` e instalação de software **pedem confirmação do Pedro**; os passos marcados 🔒 pausam para isso.
- Antes de usar uma API do ScreenCaptureKit, CoreGraphics ou Carbon, conferir a assinatura e o comportamento no SDK do Xcode-beta ou na documentação da Apple; o plano nomeia a API, não garante a assinatura.

## Review Focus

Entradas e falhas que a spec implica e nenhuma tarefa exercitaria sozinha; cada uma tem teste na tarefa dona:

1. **Duas telas, uma acima ou à esquerda da principal (coordenadas negativas), cursor na divisa ou fora de qualquer tela:** escolhe a tela certa, ou a principal. → Tarefa 9.
2. **Permissão negada na primeira vez, revogada no meio da sessão, "Tentar de novo" sem repetir o pedido ao sistema.** → Tarefa 11.
3. **Atalho disparado várias vezes durante uma captura:** uma só captura. → Tarefa 11.
4. **Falha ao gravar o rascunho (disco cheio, pasta sem permissão) com a janela aberta:** nada se perde; "Salvar como Capta" grava da memória. → Tarefas 6 e 11.
5. **Salvar sobre arquivo existente, destino inválido, painel cancelado:** o destino antigo fica intacto; cancelar não é erro. → Tarefas 7 e 11.

---

## Mapa de arquivos

```text
docs/esquema-capta-v1.md                          (novo: formato do JSON, padrões, regra de congelamento)
docs/verificacao-manual-captura.md                (novo: lista manual)
ferramentas/cobertura.exclusoes                   (novo: arquivos da casca fora do portão, com motivo)
Packages/CaptaNucleo/Sources/CaptaNucleo/
  Modelo/FormasJSON.swift, GeometriaCodable.swift (novos)
  Modelo/{Estilo,Anotacao,Documento,Geometria}.swift, Edicao/{Edicao,Etapas}.swift (alterados)
  Imagem/{CodificadorPNG,Miniatura}.swift         (novos)
  Captura/{Captura,Rascunho}.swift                (novos: tipos, protocolo Capturador, rascunho)
  Exportacao/{Exportador,ProtocolosDeSistema}.swift (novos); Pacote/PacoteCapta.swift (copiar)
Packages/CaptaNucleo/Sources/CaptaSistema/
  Captura/{SelecaoDeTela,MapeadorDeErroDeCaptura,ConfiguracoesDoSistema}.swift, AreaDeTransferenciaPB.swift
  Casca/{CapturadorSC,PermissaoCG,PainelDeArquivosAppKit,AtalhoGlobalCarbon}.swift   (fora do portão)
App/Fontes/Captura/{FluxoDeCaptura,CapturaAberta,Apresentador}.swift
App/Fontes/Janelas/{JanelaDeCapturaView,JanelaDeAjudaView,GerenciadorDeJanelas,Enquadramento}.swift
App/Fontes/CaptaApp.swift (composição), App/Info.plist (tipo exportado), App/Recursos/Localizable.xcstrings
```

---

## Parte A — Esquema v1 e numeração (só núcleo)

### Task 1: Codable explícito de `Geometria` e dos tipos geométricos do `Documento`

**Files:**
- Create: `Modelo/FormasJSON.swift`, `Modelo/GeometriaCodable.swift`
- Modify: `Modelo/Geometria.swift` (a declaração deixa de listar `Codable`), `Modelo/Documento.swift` (`tamanhoBase` e `recorte` passam a objetos; `encode(to:)` explícito)
- Test: `Tests/CaptaNucleoTests/GeometriaCodableTests.swift`

**Interfaces:**
- Produces: JSON estável. Ponto `{"x","y"}`; retângulo `{"x","y","largura","altura"}` (largura e altura podem ser negativas: o retângulo invertido faz ida e volta sem normalizar); tamanho `{"largura","altura"}`. `Geometria` codifica `"tipo"` (`seta`, `linha`, `forma`, `texto`, `etapa`, `carimbo`, `realce`, `desfoque`) mais:

| tipo | chaves |
|---|---|
| seta, linha | `inicio`, `fim` |
| forma | `forma` (raw de `TipoForma`), `retangulo` |
| texto | `retangulo`, `conteudo`, `tamanhoFonte`, `negrito`, `italico` |
| etapa | `centro`, `diametro`, `reiniciaSequencia` |
| carimbo | `retangulo`, `simbolo` |
| realce | `retangulo` |
| desfoque | `retangulo`, `tipoDesfoque` (raw de `TipoDesfoque`), `intensidade` |

- Tipo desconhecido ou chave obrigatória ausente: a decodificação lança `DecodingError`.

- [ ] **Step 1: Escrever os testes que falham:** `cadaTipoFazIdaEVolta` (parametrizado com as 8 geometrias); `retanguloInvertidoFazIdaEVoltaSemNormalizar`; `jsonDeSetaTemChavesEstaveis` (decodifica o literal `{"tipo":"seta","inicio":{"x":1,"y":2},"fim":{"x":3,"y":4}}` e codifica de volta com `.sortedKeys`, comparando a string); `tipoDesconhecidoLancaDecodingError`; `chaveObrigatoriaAusenteLancaDecodingError` (seta sem `fim`); `documentoGravaTamanhoERecorteComoObjetos` (o JSON contém `"largura"` e não contém `[[`).
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** `PontoJSON`, `RetanguloJSON`, `TamanhoJSON` (internos, `Codable`) e `extension Geometria: Codable` com `init(from:)`/`encode(to:)` por `switch` no `tipo`; em `Documento`, trocar `tamanhoBase` e `recorte` para os tipos novos dentro de `init(from:)` e de um `encode(to:)` explícito (chaves como hoje).
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS (os testes do Plano 1 que gravam e leem pacote continuam verdes).
- [ ] **Step 5: Commit** (`refactor(nucleo): fixa o JSON do esquema v1 com Codable explícito`).

---

### Task 2: Campos novos do esquema v1 (rotação, ponta, fonte, alinhamento, rótulo)

**Files:**
- Modify: `Modelo/Estilo.swift`, `Modelo/Anotacao.swift`, `Modelo/Documento.swift` (validação)
- Test: `Tests/CaptaNucleoTests/CamposNovosV1Tests.swift`

**Interfaces:**
- Produces (todos `Codable, Equatable, Sendable`, com `String` raw):
  - `enum PontaSeta { triangulo, aberta, nenhuma }`, `enum AlinhamentoTexto { esquerda, centro, direita }`, `enum RotuloEtapa { numerico, alfabetico }`.
  - `Estilo` ganha, no fim do `init` e com padrão: `ponta: PontaSeta = .triangulo`, `familiaFonte: String? = nil`, `alinhamento: AlinhamentoTexto = .esquerda`, `rotulo: RotuloEtapa = .numerico`.
  - `Anotacao` ganha `rotacao: Double` (radianos, em torno do centro do retângulo da geometria; padrão `0`) no fim do `init`.
  - Chaves JSON com os mesmos nomes. Chave ausente decodifica no padrão; `familiaFonte` `nil` não é gravada.
- Validação (`ErroDocumento.valorForaDeFaixa`): `"rotacao"` se diferente de zero em seta, linha ou desfoque; `"familiaFonte"` se vazia ou só espaços; rotação não finita lança `valorNaoFinito`.
- O renderizador **não** muda nesta tarefa nem nas seguintes (spec §4.1): os campos são gravados e validados, não desenhados.

- [ ] **Step 1: Escrever os testes que falham:** `camposNovosFazemIdaEVolta` (todos fora do padrão); `jsonSemCamposNovosDecodificaNosPadroes` (o JSON de um `Estilo` e de uma `Anotacao` do Plano 1); `rotacaoNaoZeroEmSetaLinhaDesfoqueLanca` (parametrizado nos três, esperando `valorForaDeFaixa("rotacao")`); `rotacaoValeEmFormaTextoCarimboRealceEEtapa`; `rotacaoNaoFinitaLancaValorNaoFinito`; `familiaFonteVaziaOuSoEspacosLanca`; `familiaFonteNilNaoApareceNoJson`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** os enums, os campos, `init(from:)` com `decodeIfPresent` e padrões em `Estilo` e `Anotacao`, e as regras em `Anotacao.validar()`.
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`feat(nucleo): adiciona rotação, ponta, fonte, alinhamento e rótulo ao esquema v1`).

---

### Task 3: Ordem de criação e numeração de etapas

**Files:**
- Modify: `Modelo/Anotacao.swift`, `Modelo/Documento.swift`, `Edicao/Edicao.swift`, `Edicao/Etapas.swift`, `EtapasTests.swift` e os testes que dependam da numeração por camadas
- Test: `Tests/CaptaNucleoTests/OrdemDeCriacaoTests.swift`

**Interfaces:**
- Produces:
  - `Anotacao.ordem: Int` (`public internal(set)`, fora do `init`, padrão `0`) e `Documento.proximaOrdem: Int` (`public internal(set)`; `Documento.novo` começa em `0`; o `init` público ganha `proximaOrdem: Int? = nil`).
  - `Edicao.adicionar` atribui `ordem = proximaOrdem` e incrementa o contador. `Edicao.substituir` preserva a `ordem` da anotação existente. `remover` não decrementa. Duplicar e colar são `adicionar`, logo ganham ordem nova.
  - Documento sem `proximaOrdem` no JSON (ou criado com `proximaOrdem: nil`) recebe `ordem` = índice na lista e `proximaOrdem` = quantidade. `validar()` lança `valorForaDeFaixa("ordem")` se houver ordens repetidas, negativas ou `>= proximaOrdem`.
  - `Documento.numeroDaEtapa(_ id: UUID) -> Int?`: posição entre as etapas **na ordem de criação**, com `reiniciaSequencia` voltando a `1`. Mudar a ordem das camadas não muda números.
  - `RotuloEtapa.texto(paraNumero: Int) -> String`: numérico `"1"`; alfabético em base 26 sem zero (`1→A`, `26→Z`, `27→AA`, `52→AZ`, `53→BA`, `702→ZZ`, `703→AAA`); número menor que 1 vale 1.
  - `Documento.rotuloDaEtapa(_ id: UUID) -> String?`: `estilo.rotulo` da etapa aplicado ao número dela; a posição conta todas as etapas, de qualquer formato.

- [ ] **Step 1: Escrever os testes que falham:** `adicionarAtribuiOrdensCrescentes`; `substituirMantemAOrdem`; `removerNaoReaproveitaOrdem` (remove a última, adiciona outra: ordem nova é maior); `trazerParaFrenteNaoMudaONumeroDaEtapa`; `excluirASegundaRenumeraEDesfazerRestaura`; `reiniciarVoltaAUmEContinua`; `duplicarCriaEtapaNovaNoFimDaSequencia`; `rotuloAlfabeticoNosLimites` (a tabela acima); `rotuloMistoContaPosicaoEmTodasAsEtapas` (etapas `numerico`, `numerico`, `alfabetico` → `"1"`, `"2"`, `"C"`); `arquivoSemOrdemUsaAOrdemDaLista`; `ordemRepetidaOuForaDeFaixaLanca`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** os campos, o ajuste em `init(from:)`/`encode(to:)` do `Documento`, `adicionar`/`substituir`, e reescrever `numeroDaEtapa` ordenando as etapas por `ordem`; adaptar os testes antigos que assumiam camadas.
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`feat(nucleo): numera etapas por ordem de criação`).

---

### Task 4: Congelar e documentar o esquema v1

**Files:**
- Create: `docs/esquema-capta-v1.md`, `Tests/CaptaNucleoTests/EsquemaV1CongeladoTests.swift`
- Modify: `Esquema.swift` (comentário)

**Interfaces:**
- Consumes: tudo das Tarefas 1 a 3.
- Produces: o documento de referência do formato e o teste de referência (*golden*) que trava o JSON.

- [ ] **Step 1: Escrever o teste que falha:** `documentoCompletoTemJsonDeReferencia`: um `Documento` com um objeto de cada tipo, todos os campos fora do padrão, codificado com `.sortedKeys` e `.prettyPrinted` (o mesmo do `PacoteCapta`), comparado com um literal multilinha no arquivo de teste; `jsonDeReferenciaDecodificaDeVolta`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL (literal ainda vazio) → colar o JSON gerado depois de conferi-lo à mão contra a tabela da Tarefa 1.
- [ ] **Step 3: Escrever `docs/esquema-capta-v1.md`:** tabela de chaves por tipo, padrões dos campos ausentes, regra de validação, e a regra **"depois do primeiro `.capta` real gravado pelo app, a v1 está congelada; mudança incompatível sobe `Esquema.versaoAtual` e traz migração com teste"**; repetir a regra no comentário de `Esquema.versaoAtual`.
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`docs(nucleo): documenta e trava o esquema v1`).

---

## Parte B — Núcleo: captura, exportação e protocolos

### Task 5: PNG e miniatura

**Files:**
- Create: `Imagem/CodificadorPNG.swift`, `Imagem/Miniatura.swift`
- Test: `Tests/CaptaNucleoTests/ImagemTests.swift` (usa `Apoio/Pixels.swift`)

**Interfaces:**
- Produces:
  - `enum ErroImagem: Error, Equatable, Sendable { case escalaInvalida, falhaAoCodificar }`.
  - `enum CodificadorPNG { static func codificar(_ imagem: CGImage, escala: Double) throws -> Data }`: PNG com DPI `72 × escala` (`kCGImagePropertyDPIWidth`/`Height`); escala não finita ou `<= 0` lança `escalaInvalida`.
  - `enum Miniatura { static let ladoMaiorPadrao = 512; static func gerar(de imagem: CGImage, ladoMaior: Int = ladoMaiorPadrao) throws -> CGImage }`: mantém a proporção, **não amplia**, nunca devolve lado menor que 1 pixel, saída sRGB.

- [ ] **Step 1: Escrever os testes que falham:** `pngFazIdaEVoltaComOMesmoTamanhoEPixels`; `pngGravaDpiConformeAEscala` (escala 2 → 144, lido de volta por `CGImageSource`); `escalaInvalidaLanca` (0, −1, `.nan`, `.infinity`); `miniaturaReduzMantendoProporcao` (2000×1000 → 512×256); `miniaturaNaoAmpliaImagemPequena` (100×50 fica 100×50); `miniaturaDeUmPixelFunciona`; `miniaturaMuitoLargaNaoViraZeroPixel` (4000×1 → 512×1).
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** com ImageIO (`CGImageDestination`, tipo `UTType.png`) e redesenho em `CGContext` sRGB com `interpolationQuality = .high`; falha de contexto lança `ErroRenderizacao.falhaAoCriarContexto`. O ramo de falha do ImageIO pode ficar sem teste (o piso é do alvo).
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`feat(nucleo): adiciona codificação PNG e miniatura`).

---

### Task 6: Tipos de captura e rascunho

**Files:**
- Create: `Captura/Captura.swift`, `Captura/Rascunho.swift`
- Test: `Tests/CaptaNucleoTests/RascunhoTests.swift`

**Interfaces:**
- Consumes: `CodificadorPNG`, `Miniatura` (Tarefa 5), `PacoteCapta.gravar`.
- Produces:
  - `struct ImagemCapturada: Sendable { let imagem: CGImage; let escala: Double; init(imagem:escala:) }` (se `CGImage` não for `Sendable` no SDK, marcar `@unchecked Sendable` com comentário do motivo).
  - `enum ErroCaptura: Error, Equatable, Sendable { case semPermissao, telaNaoEncontrada, falhou }`.
  - `protocol Capturador: Sendable { func capturarTela(sobCursor ponto: CGPoint) async throws -> ImagemCapturada }`.
  - `Documento.novo(de captura: ImagemCapturada) throws -> Documento`: `tamanhoBase` = pixels da imagem, `escala` da captura; escala inválida lança `ErroDocumento.tamanhoInvalido`.
  - `enum Rascunho { static func nome(para data: Date, fuso: TimeZone = .current) -> String; static func gravar(_ captura: ImagemCapturada, documento: Documento, em pasta: URL, nome: String) throws -> URL }`. `nome` devolve `"Captura AAAA-MM-DD às HH.mm.ss"` (componentes de `Calendar` gregoriano, sem `DateFormatter`, para não depender da localidade). `gravar` cria a pasta se faltar, escolhe `<nome>.capta` ou `<nome> 2.capta`, `<nome> 3.capta`… se já existir, grava base PNG (na escala da captura), miniatura e documento com `PacoteCapta.gravar`, e devolve a URL.

- [ ] **Step 1: Escrever os testes que falham:** `documentoNasceComPixelsEEscalaDaCaptura`; `escalaInvalidaNaoCriaDocumento`; `nomeUsaDataEHoraDoFusoDado` (data fixa em `UTC`); `gravarCriaPastaEPacoteLegivel` (lê de volta: tamanho, escala, zero objetos, `base.png` decodifica no mesmo tamanho, miniatura presente); `nomeRepetidoGanhaSufixoENaoSobrescreve`; **Review Focus 4:** `pastaSemPermissaoDeEscritaLanca` (diretório temporário com `0o500`) e `escalaInvalidaNaoCriaNada` (a pasta continua vazia).
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** como acima; validar o documento e codificar PNG e miniatura **antes** de tocar o disco.
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`feat(nucleo): adiciona captura e rascunho gravado no contêiner`).

---

### Task 7: Exportação, cópia de pacote e protocolos de sistema

**Files:**
- Create: `Exportacao/Exportador.swift`, `Exportacao/ProtocolosDeSistema.swift`
- Modify: `Pacote/PacoteCapta.swift` (`copiar`)
- Test: `Tests/CaptaNucleoTests/ExportadorTests.swift`, `Tests/CaptaNucleoTests/PacoteCopiarTests.swift`

**Interfaces:**
- Produces:
  - `enum Exportador { static func png(_ documento: Documento, base: CGImage, renderizador: Renderizador) throws -> Data }`: renderiza com o renderizador único (saída com o recorte, se houver) e codifica com `CodificadorPNG` na escala do documento.
  - `PacoteCapta.copiar(de origem: URL, para destino: URL) throws`: confere a origem com `ler(de:)` (mesmos erros), copia para uma pasta temporária irmã do destino e então move (`moveItem` se o destino não existe, `replaceItemAt` se existe); em qualquer falha o destino anterior fica intacto e o temporário some.
  - `enum ErroExportacao: Error, Equatable, Sendable { case falhaAoCopiar, falhaAoGravar }`.
  - `protocol AreaDeTransferencia: Sendable { func copiarPNG(_ dados: Data) throws }`.
  - `@MainActor protocol PainelDeArquivos { func escolherDestino(nomeSugerido: String, extensao: String) async -> URL? }` (`nil` = cancelou).
  - `protocol PermissaoDeGravacaoDeTela: Sendable { func consultar() -> Bool; func solicitar() }`.
  - `struct CombinacaoDeTeclas: Equatable, Sendable { let codigoDaTecla: UInt32; let modificadores: Modificadores }`, `struct Modificadores: OptionSet, Sendable { controle, opcao, comando, shift }`, `static let capturarTelaInteira` = `⌃⌥F` (código `3`, o `kVK_ANSI_F`).
  - `enum ErroAtalho: Error, Equatable, Sendable { case conflito, falhou }`; `protocol AtalhoGlobal: Sendable { func registrar(_ combinacao: CombinacaoDeTeclas, acao: @escaping @Sendable () -> Void) throws }`.

- [ ] **Step 1: Escrever os testes que falham:** `exportadorSemAnotacaoDevolvePngDoTamanhoDaBase`; `exportadorRespeitaORecorte` (saída com o tamanho do recorte); `exportadorGravaDpiDaEscala`; `copiarGeraPacoteIgualAOriginal` (`ler` dos dois: documento, base e miniatura iguais); `copiarDeOrigemInexistenteOuInvalidaLancaOErroDeLeitura`; **Review Focus 5:** `copiarSobreDestinoExistenteSubstituiPorInteiro` e `copiarComFalhaMantemODestinoAntigo` (destino em pasta sem escrita, ou origem corrompida depois de existir destino); `combinacaoPadraoEControleOpcaoF`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** como acima; `copiar` segue o padrão de `gravar` (temporário irmão + `defer` de limpeza).
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`feat(nucleo): adiciona exportação PNG, cópia de pacote e protocolos de sistema`).

---

## Parte C — `CaptaSistema`

### Task 8: Exclusões explícitas de cobertura para a casca do sistema

**Files:**
- Create: `ferramentas/cobertura.exclusoes`
- Modify: `ferramentas/cobertura.sh`, `docs/padroes-stack-swift.md` (seção de cobertura), `docs/superpowers/specs/2026-10-20-capta-captura-tela-inteira-design.md` (§3: apontar para `ferramentas/cobertura.exclusoes`, que é o registro que a frase "registro de exclusões" prometia e ainda não existia)

**Interfaces:**
- Produces: formato de `cobertura.exclusoes`: uma linha por arquivo, `caminho relativo à raiz | motivo`; `#` comenta. Regras do portão: só arquivos sob `Packages/CaptaNucleo/Sources/CaptaSistema/Casca/` podem ser listados (outro caminho falha com mensagem); arquivo listado que não existe falha (lista velha); os arquivos listados saem da conta do alvo **e** do XML do Sonar; o resumo imprime "Fora da conta" com cada arquivo e motivo. `EXCLUSOES=<arquivo>` sobrescreve o caminho, como `PISOS`.

- [ ] **Step 1: Provar que o portão atual falha:** criar `Casca/Temporario.swift` com uma função pública de 10 linhas sem teste e rodar `make cobertura` → Expected: abaixo do piso de 98 % em `CaptaSistema`.
- [ ] **Step 2: Implementar** a leitura do arquivo de exclusões em `cobertura.sh` (no bloco Python que já consolida), com as regras acima; adicionar a linha de `Temporario.swift` em `cobertura.exclusoes`.
- [ ] **Step 3: Conferir o portão pelos dois lados:** com a linha, `make cobertura` passa e o resumo lista o arquivo; sem a linha (`EXCLUSOES=/dev/null`), falha; com um caminho fora de `Casca/` ou inexistente, falha com mensagem clara; o XML do Sonar não contém o arquivo.
- [ ] **Step 4: Remover** `Temporario.swift` e a linha de teste (o arquivo de exclusões fica só com o cabeçalho explicando o formato); `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`build(ferramentas): adiciona exclusões explícitas de cobertura para a casca do sistema`). Não editar `sonar-project.properties` (tem mudança local do Pedro não commitada); só avisar no resumo final que `sonar.coverage.exclusions` pode precisar do padrão `**/CaptaSistema/Casca/**`.

---

### Task 9: Captura de tela e permissão

**Files:**
- Create: `CaptaSistema/Captura/SelecaoDeTela.swift`, `Captura/MapeadorDeErroDeCaptura.swift`, `Captura/ConfiguracoesDoSistema.swift`, `Casca/CapturadorSC.swift`, `Casca/PermissaoCG.swift`
- Modify: `ferramentas/cobertura.exclusoes` (os dois arquivos de `Casca/`, com motivo: "chama ScreenCaptureKit / CoreGraphics, exige tela e permissão reais; coberto pela lista manual")
- Test: `Tests/CaptaSistemaTests/SelecaoDeTelaTests.swift`, `MapeadorDeErroDeCapturaTests.swift`, `ConfiguracoesDoSistemaTests.swift`

**Interfaces:**
- Consumes: `Capturador`, `ImagemCapturada`, `ErroCaptura`, `PermissaoDeGravacaoDeTela` (Tarefas 6 e 7).
- Produces:
  - `struct DescricaoDeTela: Equatable, Sendable { let id: UInt32; let quadro: CGRect; let escala: Double; let principal: Bool }` — `quadro` em pontos, no espaço global do CoreGraphics (origem no canto superior esquerdo da tela principal; telas acima ou à esquerda têm coordenadas negativas).
  - `enum SelecaoDeTela { static func escolher(entre telas: [DescricaoDeTela], sob ponto: CGPoint) -> DescricaoDeTela? }`: a primeira tela cujo quadro contém o ponto, com borda esquerda/superior inclusiva e direita/inferior exclusiva (a divisa pertence à tela da direita/de baixo); ponto fora de todas ou não finito → a principal; lista vazia → `nil`.
  - `enum MapeadorDeErroDeCaptura { static func mapear(dominio: String, codigo: Int) -> ErroCaptura }`: `SCStreamErrorDomain` com `SCStreamError.Code.userDeclined` → `.semPermissao`; o resto → `.falhou`.
  - `enum ConfiguracoesDoSistema { static let urlGravacaoDeTela: URL }` (`x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`).
  - `struct CapturadorSC: Capturador` e `struct PermissaoCG: PermissaoDeGravacaoDeTela` (casca).

- [ ] **Step 1: Escrever os testes que falham:** `escolheATelaQueContemOPonto`; **Review Focus 1:** `telaAcimaDaPrincipalTemCoordenadasNegativas` (principal `(0,0,1440,900)`, outra `(0,-1080,1920,1080)`; ponto `(100,-10)` → a de cima), `telaAEsquerdaTemXNegativo`, `divisaPertenceAProximaTela` (ponto em `x = 1440`), `pontoForaDeTodasAsTelasUsaAPrincipal`, `pontoNaoFinitoUsaAPrincipal`, `semTelasDevolveNil`; `usuarioNegouViraSemPermissao` (usa as constantes do SDK); `outrosErrosViramFalhou`; `urlAbreOPainelDeGravacaoDeTela` (esquema e `Privacy_ScreenCapture`).
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** a lógica pura. `CapturadorSC`: lê o cursor por `CGEvent(source: nil)?.location` (espaço global do CoreGraphics, o mesmo do quadro das telas; **não** `NSEvent.mouseLocation`, que tem origem embaixo), monta `[DescricaoDeTela]` de `SCShareableContent`, escolhe com `SelecaoDeTela`, exclui as janelas do próprio app (`owningApplication` com o `bundleIdentifier` do `Bundle.main`), captura com `SCScreenshotManager.captureImage` em **pixels nativos** (tamanho em pontos × `pointPixelScale`), sem cursor, devolve `ImagemCapturada(imagem:escala:)` com a escala da tela; erros passam por `MapeadorDeErroDeCaptura`; sem tela → `.telaNaoEncontrada`. `PermissaoCG`: `CGPreflightScreenCaptureAccess` e `CGRequestScreenCaptureAccess`.
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS (inclusive o portão com a casca fora da conta).
- [ ] **Step 5: Commit** (`feat(sistema): adiciona captura de tela com ScreenCaptureKit e permissão`).

---

### Task 10: Área de transferência, painel de arquivos e atalho global

**Files:**
- Create: `CaptaSistema/AreaDeTransferenciaPB.swift`, `Casca/PainelDeArquivosAppKit.swift`, `Casca/AtalhoGlobalCarbon.swift`
- Modify: `ferramentas/cobertura.exclusoes` (os dois da casca)
- Test: `Tests/CaptaSistemaTests/AreaDeTransferenciaPBTests.swift`, `CombinacaoDeTeclasCarbonTests.swift`

**Interfaces:**
- Consumes: `AreaDeTransferencia`, `PainelDeArquivos`, `AtalhoGlobal`, `CombinacaoDeTeclas`, `ErroExportacao`, `ErroAtalho` (Tarefa 7).
- Produces:
  - `struct AreaDeTransferenciaPB: AreaDeTransferencia { init(nome: NSPasteboard.Name = .general) }`: guarda o *nome* (a `NSPasteboard` não é `Sendable`) e a procura a cada chamada; `copiarPNG` limpa e grava o tipo `.png`; dados vazios ou gravação recusada lançam `ErroExportacao.falhaAoCopiar`.
  - `extension Modificadores { var mascaraCarbon: UInt32 }` (`controlKey`, `optionKey`, `cmdKey`, `shiftKey`).
  - `@MainActor struct PainelDeArquivosAppKit: PainelDeArquivos` (`NSSavePanel`; para `capta`, restringe ao tipo `com.pedroct.capta.documento` se resolver, senão só sugere a extensão) e `final class AtalhoGlobalCarbon: AtalhoGlobal` (`RegisterEventHotKey` + `InstallEventHandler`; `eventHotKeyExistsErr` vira `.conflito`, outro erro vira `.falhou`).

- [ ] **Step 1: Escrever os testes que falham:** `copiarPNGGravaOsBytesNaPasteboardNomeada` (pasteboard com nome único por teste, `data(forType: .png)` igual); `copiarPNGComDadosVaziosLanca`; `copiarPNGSubstituiOConteudoAnterior`; `mascaraCarbonSomaOsModificadores` (controle+opção = `4096 | 2048`); `mascaraVaziaEZero`.
- [ ] **Step 2: Rodar:** `make test` → Expected: FAIL.
- [ ] **Step 3: Implementar** como acima. O painel e o atalho ficam na casca porque dependem de interface e do sistema; manter neles só a chamada de API.
- [ ] **Step 4: Rodar:** `make verificar` → Expected: PASS.
- [ ] **Step 5: Commit** (`feat(sistema): adiciona área de transferência, painel de arquivos e atalho global`).

---

## Parte D — App

### Task 11: Coordenador do fluxo e captura aberta

**Files:**
- Create: `App/Fontes/Captura/Apresentador.swift`, `FluxoDeCaptura.swift`, `CapturaAberta.swift`
- Test: `App/Testes/FluxoDeCapturaTests.swift`, `App/Testes/CapturaAbertaTests.swift` (com capturador, permissão, apresentador, área de transferência e painel falsos)

**Interfaces:**
- Consumes: protocolos do núcleo (Tarefas 6 e 7), `Rascunho`, `Exportador`, `PacoteCapta`.
- Produces:
  - `enum MensagemDeErro: Equatable { case capturaFalhou, naoFoiPossivelCopiar, naoFoiPossivelSalvar, rascunhoNaoGuardado }` (a view troca cada caso por texto do String Catalog).
  - `enum ResultadoDeAcao: Equatable { case concluido, cancelado, falhou(MensagemDeErro) }`.
  - `@MainActor protocol Apresentador { func mostrarAjudaDePermissao(); func mostrarCaptura(_ captura: CapturaAberta); func mostrarAlerta(_ mensagem: MensagemDeErro) }`.
  - `@MainActor @Observable final class CapturaAberta`: `let nome: String`, `let documento: Documento`, `let base: CGImage`, `let escala: Double`; `enum EstadoRascunho: Equatable { case gravando, gravado(URL), falhou }` em `var rascunho`; `var podeSalvarCapta: Bool` (`rascunho != .gravando`); `func copiar() -> ResultadoDeAcao`; `func salvarPNG() async -> ResultadoDeAcao`; `func salvarCapta() async -> ResultadoDeAcao`. `salvarCapta`: painel cancelado → `.cancelado`; rascunho gravado → `PacoteCapta.copiar`; rascunho falhou → `PacoteCapta.gravar` direto da memória (base PNG e miniatura gerados na hora); erro de disco → `.falhou(.naoFoiPossivelSalvar)`. PNG: `Exportador.png` + `Data.write(options: .atomic)`.
  - `@MainActor final class FluxoDeCaptura { init(capturador:permissao:apresentador:pastaDeRascunhos:cursor:agora:defaults:gravadorDeRascunho:painel:areaDeTransferencia:); func capturarTelaInteira() async }`, em que `cursor: () -> CGPoint`, `agora: () -> Date`, `defaults: UserDefaults` e `gravadorDeRascunho: (ImagemCapturada, Documento, URL, String) async throws -> URL` (padrão: `Rascunho.gravar` fora da *main actor*) são injetáveis.
- Regras do fluxo (spec §4.3 a §4.5):
  1. Se uma captura já está em andamento, a chamada **retorna sem fazer nada**.
  2. Se `permissao.consultar()` é `false`: na **primeira vez** (chave `permissaoJaSolicitada` em `defaults`) chama `solicitar()` **uma única vez**; em qualquer caso `mostrarAjudaDePermissao()` e retorna sem capturar. Chamadas seguintes só consultam.
  3. `ErroCaptura.semPermissao` durante a captura também leva à ajuda; qualquer outro erro vira `mostrarAlerta(.capturaFalhou)`.
  4. Em sucesso: cria o documento, cria `CapturaAberta` com `rascunho = .gravando`, chama `mostrarCaptura` **sem esperar a gravação**, e grava o rascunho em paralelo; ao terminar, atualiza `rascunho` (`gravado(url)` ou `falhou`, esta com `mostrarAlerta(.rascunhoNaoGuardado)` discreto).
  5. Log por `os.Logger` (subsistema do app) só com o tipo do erro e a duração do atalho até a janela em ms; nada de conteúdo ou caminho do usuário.

- [ ] **Step 1: Escrever os testes que falham** (fluxo): `primeiraCapturaSemPermissaoSolicitaUmaVezEMostraAjuda`; **Review Focus 2:** `tentarDeNovoSemPermissaoNaoSolicitaDeNovo`, `permissaoRevogadaNoMeioViraAjuda` (consultar `true`, capturador lança `.semPermissao`); `outroErroMostraAlertaEPermanceSemJanela`; **Review Focus 3:** `dispararDuasVezesCapturaUmaVez` (capturador lento com *gate*, segunda chamada retorna na hora); `janelaAbreAntesDeTerminarAGravacao` (gravador preso num *gate*; `mostrarCaptura` já foi chamado e `rascunho == .gravando`); **Review Focus 4:** `falhaNoRascunhoAtualizaOEstadoEAvisa`.
- [ ] **Step 2: Escrever os testes que falham** (captura aberta): `copiarGravaOPngRenderizadoNaAreaDeTransferencia`; `copiarComFalhaDevolveFalhou`; `salvarPNGGravaNoDestinoEscolhido`; **Review Focus 5:** `painelCanceladoDevolveCanceladoESemEfeito`, `salvarPNGEmDestinoInvalidoDevolveFalhou`; `salvarCaptaCopiaORascunhoGravado`; `salvarCaptaComRascunhoFalhoGravaDaMemoria` (abre com `PacoteCapta.ler`); `podeSalvarCaptaSoDepoisDaGravacao`.
- [ ] **Step 3: Rodar:** `make cobertura-app` → Expected: FAIL.
- [ ] **Step 4: Implementar** os tipos e o fluxo; o renderizador usa `Renderizador(provedorDeSimbolos: ProvedorDeSimbolosSF())`.
- [ ] **Step 5: Rodar:** `make cobertura-app` e `make verificar` → Expected: PASS.
- [ ] **Step 6: Commit** (`feat(app): adiciona o fluxo de captura e a captura aberta`).

---

### Task 12: Janelas de visualização e de ajuda, Dock e String Catalog

**Files:**
- Create: `App/Fontes/Janelas/Enquadramento.swift`, `JanelaDeCapturaView.swift`, `JanelaDeAjudaView.swift`, `AjudaDePermissaoModelo.swift`, `GerenciadorDeJanelas.swift`
- Modify: `App/Recursos/Localizable.xcstrings`
- Test: `App/Testes/EnquadramentoTests.swift`, `AjudaDePermissaoModeloTests.swift`, `PoliticaDeAtivacaoTests.swift`

**Interfaces:**
- Consumes: `CapturaAberta`, `FluxoDeCaptura`, `Apresentador` (Tarefa 11), `ConfiguracoesDoSistema` (Tarefa 9), `Tema`.
- Produces:
  - `enum ModoDeExibicao { case ajustar, tamanhoReal }` e `enum Enquadramento { static func escala(imagem: CGSize, area: CGSize, modo: ModoDeExibicao) -> CGFloat }`: `tamanhoReal` = 1; `ajustar` = o menor entre 1 e a razão que cabe na área (**nunca amplia**); `imagem` ou `area` com lado zero → 1. `imagem` em pontos (pixels ÷ escala da captura).
  - `enum PoliticaDeAtivacao { static func para(janelasAbertas: Int) -> NSApplication.ActivationPolicy }`: `0` → `.accessory`, senão `.regular`.
  - `@MainActor @Observable final class AjudaDePermissaoModelo { var mostraReiniciar: Bool; func tentouDeNovoSemSucesso() }`: o botão **Reiniciar o Capta** aparece depois de um "Tentar de novo" que ainda falha por permissão **[decisão do plano; a lista manual confirma se o macOS 27 exige isso]**.
  - `GerenciadorDeJanelas: Apresentador`: uma `NSWindow` por captura (`NSHostingController`), uma janela de ajuda única, aplica `PoliticaDeAtivacao` ao abrir e fechar, ativa o app ao mostrar, e abre as Configurações pela `ConfiguracoesDoSistema.urlGravacaoDeTela`. "Reiniciar" abre uma nova instância do app e encerra a atual.
  - View de captura: imagem renderizada pelo `Renderizador`, alternância ajustar/tamanho real, barra com **Copiar** (⌘C), **Salvar como PNG…**, **Salvar como Capta…** (desabilitada enquanto `!podeSalvarCapta`), confirmação curta ("Copiado", "Salvo") e alerta em caso de falha; fundo `Tema.superficieCanvas`; todo controle com rótulo de acessibilidade; operável por teclado.
  - Strings novas no catálogo (pt-BR, tom dos padrões), uma chave por texto: título e corpo da ajuda ("Para capturar a tela, o Capta precisa da permissão de Gravação de Tela. Nada sai do seu Mac."), três botões da ajuda, três ações da barra, as confirmações e os quatro alertas de `MensagemDeErro`.

- [ ] **Step 1: Escrever os testes que falham:** `tamanhoRealSempreUm`; `ajustarReduzSoQuandoNaoCabe`; `ajustarNuncaAmplia`; `ladoZeroDevolveUm`; `semJanelasVoltaParaAccessory` e `comJanelasUsaRegular`; `reiniciarSoApareceDepoisDeTentarDeNovoSemSucesso`.
- [ ] **Step 2: Rodar:** `make cobertura-app` → Expected: FAIL.
- [ ] **Step 3: Implementar** a lógica pura e as views; manter nas views só layout e ligação (a cobertura do app é medida sem subir o piso nesta tarefa).
- [ ] **Step 4: Rodar:** `make cobertura-app` e `make verificar` → Expected: PASS (inclui `conferir_tokens.sh`: nenhuma cor crua em `App/Fontes`).
- [ ] **Step 5: Commit** (`feat(app): adiciona as janelas de captura e de ajuda de permissão`).

---

### Task 13: Menu, atalho, composição e tipo `.capta`

**Files:**
- Modify: `App/Fontes/CaptaApp.swift`, `App/Info.plist`, `App/Recursos/Localizable.xcstrings`

**Interfaces:**
- Consumes: tudo das Tarefas 9 a 12.
- Produces:
  - `CaptaApp` compõe `CapturadorSC`, `PermissaoCG`, `AreaDeTransferenciaPB`, `PainelDeArquivosAppKit`, `AtalhoGlobalCarbon`, `GerenciadorDeJanelas` e `FluxoDeCaptura`; pasta de rascunhos em Application Support do contêiner, subpasta `Capturas`. É o único lugar com essa fiação (o arquivo já está fora da cobertura do app).
  - Menu: **Capturar tela inteira** (atalho `⌃⌥F` à mostra), um rótulo desabilitado "Atalho indisponível" só se o registro falhar com `ErroAtalho`, e **Sair do Capta**. O registro do atalho acontece na abertura do app; falha não impede o app nem o item de menu.
  - `Info.plist`: `UTExportedTypeDeclarations` com `com.pedroct.capta.documento`, conforme `com.apple.package`, extensão `capta`, descrição "Captura do Capta"; um comentário por chave, como o arquivo já faz. **Só** a declaração (sem `CFBundleDocumentTypes`).
  - `LSUIElement` continua `true` (a política de ativação muda em tempo de execução, Tarefa 12).

- [ ] **Step 1: Implementar** a composição, o menu e a declaração do tipo; adicionar as strings novas ao catálogo.
- [ ] **Step 2: Rodar:** `make verificar` → Expected: PASS (`conferir_entitlements.sh` confirma que continuam só os dois entitlements).
- [ ] **Step 3: Rodar `make cobertura-app`** → Expected: PASS.
- [ ] **Step 4: Commit** (`feat(app): liga o menu, o atalho global e o tipo de documento .capta`).

---

### Task 14: Fechamento — lista manual, piso do app e verificação com o Pedro

**Files:**
- Create: `docs/verificacao-manual-captura.md`
- Modify: `ferramentas/cobertura.pisos` (linha `App=`, em commit próprio), `docs/superpowers/plans/2026-10-20-capta-plano-2-captura-tela-inteira.md` (status ao fim)

**Interfaces:**
- Consumes: o app completo.

- [ ] **Step 1: Escrever `docs/verificacao-manual-captura.md`** com um item marcável por linha: primeira captura sem permissão (pedido do sistema aparece uma vez, depois a ajuda); permissão negada; permissão concedida com e sem reinício, confirmando se o botão **Reiniciar o Capta** aparece quando deve; permissão revogada com o app aberto; duas telas com escalas diferentes (captura da tela do cursor, com pixels e escala certos, e uma tela acima ou à esquerda da principal); janelas do próprio Capta ausentes da imagem; atalho `⌃⌥F` em conflito com outro app (aviso no menu, item de menu funcionando); PNG salvo e colado no Preview com o tamanho certo; imagem copiada e colada noutro app; `.capta` salvo aparece como **um item** no Finder; Dock aparece com a janela e some sem janelas; fechar a janela não perde a captura (pacote em `Capturas`); tempo do atalho até a janela (ler o log de duração, meta < 500 ms em Retina, medir sem prometer).
- [ ] **Step 2: Rodar `make cobertura-app`**, anotar o valor medido de `App/Fontes` e ajustar `App=` em `cobertura.pisos` para esse valor (o piso do app é provisório e pode ser reajustado; vale o menor entre CI e local), em commit próprio (`test(app): ajusta o piso de cobertura do app`).
- [ ] **Step 3: Rodar `make verificar` e `make cobertura-app`** → Expected: PASS; commit da lista manual (`docs: adiciona a lista de verificação manual da captura`).
- [ ] **Step 4: 🔒 Pedir ao Pedro** para criar o `project.local.yml`, rodar `make app && open build/Capta.app` e percorrer a lista manual (isso fecha também o passo 8 da Tarefa 2 do Plano 1); registrar os itens que falharem como pendências no status deste plano.
- [ ] **Step 5: 🔒 `git push`** só depois da confirmação do Pedro; conferir `gh run list --limit 1` → `success`; se o piso do app medido na CI for menor que o local, baixar `App=` ao valor da CI em commit próprio.

---

## Auto-revisão

- **Cobertura da spec:** §4.1 Tarefas 1, 2 e 4; §4.2 Tarefa 3; §4.3 Tarefas 7, 9, 10 e 13 (captura, exclusão das janelas próprias, escala nativa, atalho `⌃⌥F` fixo, menu); §4.4 Tarefas 11 e 12 (decisão por `CGPreflight` e pedido único); §4.5 Tarefas 5, 6 e 11 (rascunho em paralelo, falha de gravação, miniatura); §4.6 Tarefas 7, 11 e 12; §4.7 Tarefa 13; §5 (erros) Tarefa 11; §6 (testes) distribuídos, com lista manual e piso do app na Tarefa 14; §10 (riscos) na lista manual.
- **Ponto que a spec afirmava e não existia:** o "registro de exclusões de cobertura" da spec §3 não existia no repositório; a Tarefa 8 o cria e corrige o texto da spec, em vez de baixar o piso de `CaptaSistema`.
- **Escolhas do plano que a spec deixou ao construtor:** rótulo da etapa, ponta, fonte e alinhamento ficam em `Estilo` (menos mudança que um parâmetro novo em `Geometria.etapa`); `Anotacao.ordem` e `Documento.proximaOrdem` guardam a ordem de criação; `Captura AAAA-MM-DD às HH.mm.ss` como nome do rascunho; miniatura de 512 px; `CGEvent` (não `NSEvent`) para o cursor; "Reiniciar o Capta" depois de um "Tentar de novo" que ainda falha.
- **Consistência de tipos:** `ImagemCapturada`, `ErroCaptura`, `Capturador`, `Rascunho`, `Exportador`, `PacoteCapta.copiar`, `AreaDeTransferencia`, `PainelDeArquivos`, `PermissaoDeGravacaoDeTela`, `AtalhoGlobal`, `CombinacaoDeTeclas`, `CapturaAberta`, `FluxoDeCaptura`, `Apresentador` e `MensagemDeErro` mantêm a mesma assinatura entre as tarefas que os definem e as que os usam.
