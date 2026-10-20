# Capta — Design do MVP

Data: 2026-10-20 · Autor: Pedro Teixeira (decisões) / Claude (rascunho) · Status: **rascunho para aprovação**
Padrões técnicos: [`docs/padroes-stack-swift.md`](../../padroes-stack-swift.md) (fonte da verdade para ferramentas, estrutura e convenções).
Design system e marca: [`docs/design-system/`](../../design-system/README.md) (fonte da verdade visual: tokens, ativos, componentes). Direção "vidro nativo", claro e escuro, destaque = cor de destaque do macOS; cores da marca só no ícone e na divulgação.

> **Convenção deste documento.** O que o Pedro decidiu está sem marca. O que é escolha do rascunho
> está marcado **[minha decisão]** e pode ser trocado. O que ficou para quem constrói está em
> "Deixado para o construtor".

---

## 1. Intenção e motivo

O Pedro usa o Snagit para capturar a tela e anotar a imagem. O que o incomoda é o **preço**
(assinatura). O Capta é um app **próprio, gratuito e de uso pessoal** que cobre o dia a dia desse
fluxo: capturar uma parte da tela, anotar, guardar, copiar ou compartilhar.

Não é uma cópia do Snagit. A engenharia reversa do Snagit serviu para decidir *o que* vale ter;
*como* escrever é decisão deste projeto.

**Sucesso** é o Pedro conseguir **parar de usar o Snagit no dia a dia** para estes cenários, sem
sentir falta de nada essencial:

1. Capturar uma região e anotar com seta, texto e destaque, copiando o resultado em segundos.
2. Capturar uma janela inteira e salvar como PNG.
3. Numerar passos numa captura (1, 2, 3) para um tutorial.
4. Borrar informação sensível antes de compartilhar.
5. Achar uma captura antiga na biblioteca e reabri-la **com as anotações ainda editáveis**.
6. Capturar com atraso (para pegar um menu ou estado transitório).
7. Fazer tudo isso sem criar conta, sem login e sem o app falar com a internet.

## 2. Objetivos, não objetivos e anti-objetivos

**Objetivos do MVP**

- Captura de **região, janela e tela inteira**, por **atalho global** e pela barra de menus.
- **Editor** com as anotações essenciais, desfazer/refazer ilimitado na sessão e edição
  não destrutiva.
- **Biblioteca** local simples.
- **Exportar e compartilhar** sem rede: salvar arquivo, copiar, folha de compartilhamento do
  sistema.
- **Compatível com o App Sandbox desde o primeiro build** (a loja vem depois).
- Interface em **pt-BR**, claro e escuro, acessível.

**Não objetivos do MVP** (ficam para a Fase 2 ou depois)

Vídeo e GIF · captura com rolagem · OCR / extrair texto · captura em etapas guiada · efeitos
(sombra, borda, arestas, perspectiva) · Combinar em modelo · estilos favoritos e temas ·
etiquetas · múltiplas regiões numa captura · detecção de sub-áreas de janela · importar `.snagx` ·
destinos específicos (Slack, Drive, Camtasia…) · Simplificar, Smart Move, redação inteligente ·
webcam e áudio.

**Anti-objetivos** (falha mesmo que "funcione")

- Qualquer **conta, login, licença ou telemetria**.
- Qualquer **acesso à rede** no MVP.
- **Copiar código, recursos ou estrutura de arquivo do Snagit** (o repositório é público).
- Um app que **precise de permissão de Acessibilidade** para o fluxo principal (barra a loja e
  assusta o usuário).
- Exigir **conta Apple paga** para o Pedro desenvolver e usar o app.

## 3. Restrições

- **macOS 14+**, Swift 6 estrito, SwiftUI + AppKit, Xcode 27 beta no desenvolvimento
  (ver padrões). **[minha decisão]** macOS 14 como piso.
- **App Sandbox ligado.** Entitlements mínimos, cada um justificado.
- **Sem dependências de terceiros** no MVP.
- **Licença MIT**, repositório público: nada de segredo, certificado ou perfil no Git.
- Um desenvolvedor, uma versão por semana: o escopo precisa caber em fatias entregáveis.
- Distribuição inicial: uso próprio, assinado com Apple Development. A conta Apple do Pedro é
  **gratuita**: não há Developer ID nem notarização nem loja por enquanto. Quem receber o app
  precisa liberá-lo manualmente (Configurações do Sistema → Privacidade e Segurança). O design
  continua compatível com sandbox para que a passagem à loja, quando a conta for paga, seja uma
  mudança de assinatura e não de código.

## 4. Visão geral do produto

Um app de **barra de menus** (ícone na barra, sem janela até ser necessário). O Dock mostra o
Capta enquanto houver janela de editor ou biblioteca aberta. **[minha decisão]**

### 4.1 Fluxo principal

```
atalho global ou menu  →  overlay de seleção  →  captura  →  editor  →  copiar / salvar / compartilhar
                                                       └──→  biblioteca (guardado automaticamente)
```

### 4.2 Captura

**Entrada:** atalho global configurável e itens na barra de menus: *Capturar região*, *Capturar
janela*, *Capturar tela inteira*, *Abrir editor*, *Biblioteca*, *Preferências*, *Sair*.
Atalho padrão **⌃⌥C** para a captura "livre" (região ou janela, decidido no overlay), com opção de
atalhos separados por modo. **[minha decisão]** (⌃⇧C é o do Snagit e conflitaria na máquina do
Pedro.)

**Atalho global sem Acessibilidade:** registrado por API do sistema que não exige a permissão
(Carbon `RegisterEventHotKey` ou equivalente). Não pode depender de monitoramento global de
teclado.

**Overlay de seleção** (comportamento inspirado no observado no Snagit, implementação própria):

- Cobre **todas as telas**. Cada tela mostra a imagem congelada do instante do disparo, levemente
  escurecida; a captura final é recortada dessa imagem congelada, para sair exatamente o que foi
  visto. **[minha decisão]**
- **Mira** (linhas-guia) seguindo o cursor, e **dimensões** da seleção em pixels.
- **Arrastar** define a região; ajustar bordas e mover a seleção antes de confirmar.
- **Passar o cursor sobre uma janela** a realça; **clicar** a seleciona (janela inteira, sem
  sub-áreas).
- **Teclas:** `Esc` cancela · `F` tela inteira da tela sob o cursor · `M` liga/desliga lupa de
  pixels · `Espaço` alterna entre região e janela · `Enter` confirma · setas movem a seleção de
  1 px (`⇧` = 10 px) · `H` mostra/oculta a ajuda.
- Painel de ajuda das teclas no canto inferior esquerdo, ocultável.
- Várias telas, escalas Retina e mistas funcionam; a captura preserva a escala nativa (@2x).

**Opções por captura** (painel curto no overlay e em Preferências): incluir cursor (desligado por
padrão), **atraso** (nenhum, 3, 5, 10 s), copiar automaticamente para a área de transferência
(desligado), abrir no editor (ligado). O **atraso** mostra contagem regressiva visível e pode ser
cancelado.

**Motor:** ScreenCaptureKit (captura de imagem única). Janelas e telas vêm da lista de conteúdo
compartilhável do sistema. O Capta **exclui as próprias janelas** da captura. **[minha decisão]**

### 4.3 Permissões

- **Gravação de Tela** é a única permissão obrigatória. Sem ela, o primeiro uso mostra uma tela
  de boas-vindas curta que explica o motivo e leva às Configurações do Sistema; nenhum erro técnico
  chega ao usuário.
- O sistema pode **revalidar a permissão periodicamente** (macOS recente): o app detecta a captura
  que falhou por falta de permissão e volta à tela de ajuda, sem perder o trabalho em andamento.
- Nenhuma outra permissão no MVP (sem Acessibilidade, câmera, microfone ou pasta Desktop).

### 4.4 Editor

**Janela:** barra de ferramentas no alto, tela (canvas) com zoom, painel de **propriedades** à
direita (muda com a ferramenta/seleção), rodapé com zoom e tamanho. Abre a cada captura; vários
documentos em janelas (ou abas) separadas.

**Ferramentas do MVP:**

| Ferramenta | Comportamento |
|---|---|
| Seleção / Mover | Selecionar um ou vários objetos, mover, redimensionar, girar, excluir, duplicar |
| Seta | Seta reta; cor, largura, estilo da ponta |
| Linha | Linha reta (e tracejada) |
| Forma | Retângulo, retângulo arredondado, elipse; contorno e preenchimento |
| Texto | Caixa de texto editável no lugar; fonte, tamanho, cor, negrito/itálico, alinhamento |
| Etapa | Marcador numerado (1, 2, 3 / A, B, C), com **sequência automática** e reinício |
| Carimbo | Conjunto **embutido e próprio** de ícones (símbolos do sistema); tamanho e cor |
| Realce (marca-texto) | Faixa translúcida sobre a área |
| Desfoque | Borra ou pixeliza a área; **aplicado na renderização** (o dado original é preservado no arquivo do Capta) |
| Recorte | Corta a tela; ajustável antes de confirmar |

**Comum a todas:** propriedades (cor, largura, opacidade) com **memória por ferramenta** (a última
usada), **desfazer/refazer** ilimitado na sessão, **copiar/colar** objetos, **ordem de camadas**
(trazer para frente/enviar para trás), **alinhar** objetos selecionados, zoom (25–400 %, ajustar à
janela, tamanho real), **atalhos de teclado** para as ferramentas.

**Edição não destrutiva:** as anotações são objetos; a imagem base não é alterada. O arquivo do
Capta guarda imagem base + objetos, então uma captura reaberta continua editável. Desfoque e
recorte também são guardados como instruções, não como pixels perdidos. **[minha decisão]**

### 4.5 Biblioteca

Janela de grade com miniaturas das capturas guardadas. Cada captura é **guardada automaticamente**
ao capturar (rascunho) e atualizada ao editar.

- Ordenar por data; **buscar por nome**; renomear; **excluir** (vai para a Lixeira do sistema);
  *Mostrar no Finder*; abrir no editor; **arrastar** a captura para outro app (arrasta um PNG).
- Local padrão: pasta do contêiner do app. O usuário pode **escolher outra pasta** (acesso por
  *security-scoped bookmark*). **[minha decisão]**
- Sem etiquetas, sem pastas, sem sincronização no MVP.

### 4.6 Exportar e compartilhar

- **Salvar como…** PNG, JPEG, HEIC, PDF (painel de salvar do sistema). Opção de reduzir de @2x
  para @1x ao exportar.
- **Copiar** a imagem renderizada para a área de transferência.
- **Compartilhar** pela folha de compartilhamento do sistema (e-mail, Mensagens, AirDrop, Notas…),
  que funciona no sandbox e dispensa integrações próprias. **[minha decisão]**
- A exportação usa **o mesmo renderizador** da tela: o que se vê é o que se exporta.

### 4.7 Preferências

Atalhos de captura · atraso e cursor padrão · copiar após capturar · formato e qualidade de
exportação padrão · local da biblioteca · aparência (claro/escuro/sistema) · **abrir ao iniciar o
Mac** (via serviço de login do sistema, aceito pela loja).

### 4.8 Detalhes resolvidos na revisão **[minha decisão, todos]**

**Salvamento e biblioteca**
- `base.png` é gravado **uma vez**, no momento da captura, e nunca mais é reescrito. Só
  `documento.json` (e a miniatura) é regravado.
- O editor **salva sozinho**: depois de cada comando, com atraso de ~2 s (*debounce*), e sempre ao
  fechar a janela ou sair do app. **Não existe estado "não salvo"**: fechar a janela nunca pergunta
  se quer salvar. "Salvar como…" é exportar uma cópia, não salvar o documento.
- Toda captura **fica na biblioteca até o usuário excluí-la**, mesmo sem ter sido editada.
- Se a pasta escolhida da biblioteca estiver **indisponível** (disco desconectado, permissão
  perdida), o app avisa, usa temporariamente a pasta padrão do contêiner e **não apaga nem move
  nada** da pasta original.

**Janela e congelamento**
- **Sem atraso:** a captura é um **recorte da imagem congelada** no instante do atalho (região) ou
  da imagem da janela escolhida.
- **Com atraso (3, 5, 10 s):** a seleção acontece primeiro, sobre a imagem congelada; depois vem a
  contagem regressiva; ao fim, o app **captura de novo, ao vivo**, a região ou a janela escolhida.
  É assim que o atraso consegue pegar um menu ou estado passageiro.
- **Captura de janela:** usa a imagem da própria janela (inclui as partes cobertas por outras
  janelas ou fora da tela), **sem sombra** e com cantos como o sistema os desenha. Sombra opcional é
  da Fase 2.
- **Menus e pop-ups não são "janelas"** no MVP; capturam-se por região, normalmente com atraso.

**Recorte e desfoque (modelo de dados)**
- **Recorte** é uma propriedade do **documento** (retângulo sobre a imagem base), não um objeto:
  não destrói pixels, pode ser reeditado depois de reabrir o arquivo, e anotações fora da área
  recortada continuam guardadas, apenas não aparecem nem são exportadas.
- **Desfoque** é um **objeto** com região e tipo (*borrar* ou *pixelizar*). Afeta tudo o que está
  **abaixo** dele na ordem de camadas (imagem base e objetos anteriores), e é aplicado na
  renderização.
- **Exportar, copiar, compartilhar e arrastar entregam sempre a imagem renderizada ("achatada")**,
  nunca o arquivo `.capta`. O arquivo `.capta` só sai do app se o usuário o copiar pelo Finder.
- **Decidido pelo Pedro:** o `.capta` **guarda o original por trás do desfoque** (desfoque
  reeditável), com toda saída achatada. Consequência aceita: quem copiar o arquivo `.capta` pelo
  Finder leva o original junto. Uma ação "achatar e remover o original" fica como candidata da
  Fase 2.

**Arquivo, arrastar e nomes**
- `.capta` é **tipo de documento registrado** (declaração exportada, pacote): clicar duas vezes
  abre no Capta; no Finder aparece como um item único (pacote), não como pasta.
- **Arrastar** da biblioteca entrega um **PNG gerado na hora** (promessa de arquivo), sem cache.
- **Renomear** uma captura renomeia o pacote `.capta`; o nome do PNG exportado vem do nome da
  captura.
- Etapas: a numeração **segue a ordem de criação**; excluir a etapa 2 **renumera** as seguintes
  (com a opção de reiniciar a sequência).

**Permissões**
- A permissão é verificada **no primeiro uso da captura**, não na abertura do app. A tela de
  boas-vindas aparece **uma vez** (primeira abertura) e **de novo sempre que uma captura falhar por
  falta de permissão**.
- Se o sistema exigir reiniciar o app depois de conceder a permissão, a tela oferece o botão
  **Reiniciar o Capta**.
- O atalho é configurável por um campo simples de "gravar atalho"; conflito de registro é avisado.

**Desempenho**
- Canvas **desenhado na CPU** (CoreGraphics), com cache por camada e redesenho só da área suja.
  Metal não está no plano. Meta não atingida **registra um problema e não bloqueia a fatia**, a
  menos que o editor fique inutilizável.

## 5. Arquivo do Capta

- Documento próprio, **pacote de pasta** `.capta` **[minha decisão]**:
  - `documento.json` — `versaoEsquema`, tamanho e escala da imagem, lista de objetos
    (tipo, geometria, estilo, ordem), histórico mínimo para desfazer após reabrir não é exigido.
  - `base.png` — imagem original capturada (nunca alterada).
  - `miniatura.png` — para a biblioteca.
- **Versão do esquema** desde a primeira versão, com **migração** testada: o app nunca falha ao abrir
  arquivo de versão anterior.
- Escrita **atômica** (sem arquivo meio gravado se o app fechar no meio).
- **Sem relação com o `.snagx`.** Importador de `.snagx` é Fase 2.

## 6. Arquitetura (resumo; detalhes nos padrões)

Três camadas, nesta ordem de dependência: `Capta` (UI) → `CaptaSistema` (adaptadores) →
`CaptaNucleo` (regra, sem UI e sem sistema).

- **Núcleo:** modelo do documento e dos objetos de anotação, **comandos reversíveis** (desfazer /
  refazer), geometria, **renderizador único** (CoreGraphics + CoreImage para desfoque), serialização
  e migração do `.capta`, armazenamento da biblioteca, regras de exportação. Protocolos que
  descrevem o sistema: capturador, registro de atalho, área de transferência, local de arquivos.
- **Sistema:** implementações com ScreenCaptureKit, atalho global, `NSPasteboard`, painéis de
  arquivo, folha de compartilhamento.
- **App:** barra de menus, overlay (AppKit, janelas sem moldura por tela), editor (SwiftUI com
  canvas desenhado pelo renderizador do núcleo), biblioteca, preferências, boas-vindas.

## 7. Qualidade e testes

- **Núcleo** (a maior parte dos testes): modelo, comandos e desfazer/refazer, geometria,
  serialização e migração de arquivos antigos, biblioteca em pasta temporária, regras de exportação,
  **testes de imagem** do renderizador (comparação com tolerância contra imagens de referência).
- **Sistema:** testado contra dublês; o que depende de permissão e de tela real fica numa **lista de
  verificação manual** versionada em `docs/` (overlay em várias telas, escala mista, permissão
  revogada, atraso, atalho em conflito).
- **Alvos de desempenho** (medir, não prometer) **[minha decisão]**: overlay visível em < 200 ms após o
  atalho; do clique de confirmação ao editor aberto em < 500 ms; edição fluida (60 fps) em imagem de
  tela 5K com dezenas de objetos.
- **Acessibilidade:** todo controle com rótulo; operação do editor por teclado; contraste nos dois
  temas.
- `make verificar` passa em todo commit (padrões, seção 6).

## 8. Fatias de entrega (para o plano)

Sugestão de ordem, cada fatia entregável e testável por si **[minha decisão]**:

1. **Esqueleto:** repositório, **instalar XcodeGen (com autorização do Pedro)**, projeto gerado,
   `project.local.yml.example` (o `DEVELOPMENT_TEAM` fica fora do Git), CI com lint e testes do
   núcleo, app vazio na barra de menus, sandbox. `make verificar` **funciona sem time de
   assinatura** (assinatura desligada na compilação de verificação); só `make app` assina.
2. **Núcleo do documento:** objetos, comandos, renderizador, `.capta`, testes.
3. **Captura de tela inteira** + permissões + abrir no editor (fluxo mínimo ponta a ponta).
4. **Overlay** de região e janela, atalhos, atraso, múltiplas telas.
5. **Editor:** ferramentas, propriedades, desfazer/refazer, zoom.
6. **Biblioteca.**
7. **Exportar, copiar, compartilhar; preferências; aviso de boas-vindas.**
8. **Acabamento:** acessibilidade, lista de verificação manual, ícone, primeira release `0.1.0`.

## 9. Deixado para o construtor

Aparência visual detalhada (espaçamentos, ícones das ferramentas, ícone do app) · atalhos de
teclado das ferramentas dentro do editor · nomes internos de tipos · conjunto exato de carimbos ·
estrutura interna do renderizador e do stack de comandos · formatos de miniatura · estratégia de
cache da biblioteca · textos exatos da interface (seguindo o tom dos padrões).

## 10. Decisões que continuam com o Pedro

| Item | Situação |
|---|---|
| `.capta` guarda o original por trás do desfoque | **Decidido: sim** (saídas sempre achatadas) |
| ID do bundle e domínio (`com.pedroct.capta` é provisório) | Pendente |
| Nome definitivo "Capta" | Provisório |
| Conta Apple Developer | **Gratuita (não paga).** Sem Developer ID, sem notarização e sem loja até virar paga; não bloqueia o MVP |
| Ícone do app | Pendente; não bloqueia o MVP |

## 11. Riscos conhecidos

- **Toolchain beta:** Xcode 27 beta pode mudar entre semanas; não usar para a loja.
- **Overlay com várias telas e escalas mistas** é a parte mais frágil; ganha lista de verificação.
- **Revalidação periódica da Gravação de Tela** pelo sistema pode interromper capturas.
- **Atalho global em conflito** com outros apps (inclusive o Snagit instalado): o app detecta falha
  de registro e avisa.
- **Sandbox:** qualquer recurso futuro que exija Acessibilidade ou AppleEvents amplos precisa de
  alternativa (o principal é a captura com rolagem da Fase 2).

## 12. Referência fora do repositório

O mapa de funcionalidades do Snagit (engenharia reversa) está em
`/Volumes/DOCK/Projetos/pessoal/snagit/docs/`. Fica **fora** deste repositório de propósito.
