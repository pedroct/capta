# Capta — Design da fatia 5: editor

Data: 2026-10-22 · Autor: Pedro Teixeira (decisões) / Claude (rascunho) · Status: **rascunho para aprovação**
Spec de origem: [`2026-10-20-capta-mvp-design.md`](2026-10-20-capta-mvp-design.md) (§4.4, §4.8, §5, §7, §8). Fatias anteriores: [`2026-10-20-capta-captura-tela-inteira-design.md`](2026-10-20-capta-captura-tela-inteira-design.md) e [`2026-10-21-capta-overlay-regiao-e-janela-design.md`](2026-10-21-capta-overlay-regiao-e-janela-design.md). Padrões técnicos: [`docs/padroes-stack-swift.md`](../../padroes-stack-swift.md). Visual: [`docs/design-system/`](../../design-system/README.md). Esquema atual: [`docs/esquema-capta-v1.md`](../../esquema-capta-v1.md).
Protótipo aprovado: página "MVP · Plano 3 — Editor" do artefato [Capta — Protótipos](https://claude.ai/artifact/QMAPkACqr3PNQw5SRQuW4W) (dez telas; as quatro da última fileira trazem callout, caneta, agrupar/bloquear, menu Imagem e redimensionar).

> **Convenção.** O que o Pedro decidiu está sem marca. O que é escolha do rascunho está marcado **[minha decisão]** e pode ser trocado. O que ficou para quem constrói está em "Deixado para o construtor".

---

## 1. Intenção e motivo

As fatias 3 e 4 capturam, mas a janela que abre só copia e salva: não dá para anotar. Esta fatia entrega o **editor**, o motivo de o Capta existir. É ele que deixa o Pedro parar de usar o Snagit no dia a dia (spec de origem §1, cenários 1 a 4).

O editor do Snagit atende o Pedro em tudo o que ele usa; a referência de comportamento é ele, com implementação própria (nada de código, recursos ou formato do Snagit). O mapa do editor do Snagit está em `/Volumes/DOCK/Projetos/pessoal/snagit/docs/03-editor-de-imagem.md`, fora do repositório.

**Sucesso** é o Pedro, numa captura recém-feita:

1. pôr seta, texto e realce e copiar o resultado em segundos;
2. numerar passos (1, 2, 3) e borrar um dado sensível;
3. explicar um botão com um **callout** e circular algo com a **caneta**;
4. **agrupar** anotações, **bloquear** ou **achatar** as já prontas para não pegá-las sem querer ao pôr novas;
5. **girar** a imagem e **encolhê-la** antes de mandar;
6. desfazer e refazer qualquer passo, fechar a janela e não perder nada.

## 2. Objetivos, não objetivos e anti-objetivos

**Objetivos**

- Janela do editor que **substitui a janela de resultado** das fatias 3 e 4: barra de ferramentas, canvas com zoom, painel de propriedades à direita, rodapé com zoom e tamanho (protótipo).
- As ferramentas do MVP (spec de origem §4.4): **seleção**, **seta**, **linha**, **forma**, **texto**, **etapa**, **carimbo**, **realce**, **desfoque** e **recorte**.
- Três acréscimos pedidos pelo Pedro, que o MVP não tinha: **callout**, **caneta** e **agrupar / bloquear / achatar**.
- Dois acréscimos no documento inteiro, também pedidos: **girar** (e espelhar) e **redimensionar** (encolher) a imagem.
- O que a spec de origem lista como "comum a todas": propriedades com memória por ferramenta, desfazer e refazer ilimitado na sessão, copiar e colar objetos, ordem de camadas, alinhar, zoom de 25 a 400 % com ajustar e tamanho real, atalhos de teclado.
- Salvar sozinho no rascunho `.capta` que a captura já cria (spec de origem §4.8).
- **Capturas recentes:** um submenu na barra de menus que reabre no editor as últimas capturas da pasta `Capturas` (§4.13), pedido pelo Pedro para não ficar sem como corrigir uma captura fechada até a biblioteca chegar.
- Esquema do `.capta` **v2**, com migração testada da v1.

**Não objetivos** (outras fatias ou Fase 2)

- Biblioteca, abrir `.capta` pelo Finder ou por duplo clique, "Abrir…" com painel e pacotes fora do contêiner (fatia 6). Nesta fatia só se reabre o que está na pasta `Capturas`, pelo submenu de recentes.
- Exportar em JPEG, HEIC ou PDF, reduzir para @1x, folha de compartilhamento, preferências e boas-vindas (fatia 7). Nesta fatia ficam só as saídas que já existem: **Copiar**, **Salvar como PNG…** e **Salvar como Capta…**.
- Lupa, spotlight, estilos rápidos e temas, efeitos (sombra, borda, arestas), aumentar a tela em volta da imagem, girar por ângulo livre, distribuir objetos, grupos dentro de grupos, colar imagem de fora como objeto, edição inteligente (Simplificar, Smart Move), OCR.
- Achatar de verdade (fundir as anotações nos pixels). "Achatar e remover o original" continua candidato da Fase 2 (spec de origem §4.8).

**Anti-objetivos** (falha mesmo que "funcione")

- Qualquer edição que **reescreva o `base.png`** ou perca a possibilidade de reeditar depois de reabrir. Girar, espelhar, encolher, recortar, desfocar e achatar são instruções no documento.
- Perder trabalho: fechar a janela ou sair do app sem gravar, ou perguntar "deseja salvar?" (spec de origem §4.8: não existe estado "não salvo").
- O que se vê no canvas **diferir do que sai** em copiar e salvar PNG. Há um renderizador só.
- Pedir qualquer permissão nova, novo entitlement, rede, conta ou telemetria.
- Copiar código, recursos, ícones ou estrutura de arquivo do Snagit.
- Texto de erro técnico ou em inglês na interface.

## 3. Restrições

As do MVP (§3 da spec de origem) e das fatias 3 e 4, mais:

- `CaptaNucleo` continua sem SwiftUI e AppKit. **Toda regra do editor que não precisa de tela vai para o núcleo** como valor puro e testável (§4.10), no mesmo estilo da máquina de estados do overlay. A casca no app fica com o mínimo de código.
- O documento continua um valor; `Documento.validar()` roda em toda edição, no decode e antes de gravar ou renderizar, e passa a cobrir os campos novos.
- `make verificar` passa em todo commit; pisos de `ferramentas/cobertura.pisos` não caem (98 % em `CaptaNucleo` e `CaptaSistema`). Subir piso vai em commit próprio.
- Interface só pelo String Catalog; cor de controle só por token (`Tema.*`); cores de anotação são as `anotacao-*` do design system, iguais nos dois temas.

## 4. Desenho

### 4.1 Fluxo

```
captura (fatias 3 e 4) → rascunho gravado (já existe) → janela do editor
    → cada edição: valida → aplica → redesenha a área suja → agenda salvamento (~2 s)
    → fechar a janela ou sair do app: salva já, sem perguntar
```

A janela do editor é a janela por captura que já existe (`GerenciadorDeJanelas`), com o conteúdo trocado: a `JanelaDeCapturaView` e o `CapturaAberta` evoluem para o editor, ou são substituídos por ele **[minha decisão: evoluir, sem duas janelas paralelas]**. Uma janela por captura, como hoje; abas do sistema podem funcionar se vierem de graça, sem trabalho próprio.

### 4.2 Janela

Como no protótipo:

- **Barra de ferramentas:** Seleção, Seta, Linha, Forma, Texto, Callout, Caneta, Etapa, Carimbo, Realce, Desfoque, Recorte · Desfazer, Refazer · à direita **Imagem ▾**, **Exportar ▾** (Salvar como PNG…, Salvar como Capta…) e **Copiar** (botão principal).
- **Canvas** com a imagem renderizada, rolagem e zoom.
- **Painel de propriedades** à direita: muda com a ferramenta ou a seleção; com uma seleção de vários objetos mostra só o que eles têm em comum (protótipo "agrupar e bloquear"); sem ferramenta de criação e sem seleção, mostra as ações da **imagem** (girar, espelhar, tamanho, redimensionar).
- **Rodapé:** zoom, tamanho de saída em pixels e escala (`1600 × 900 @2x`), e o estado do salvamento.
- O aviso de rascunho não guardado da fatia 3 continua discreto na barra.

### 4.3 Ferramentas

| Ferramenta | Comportamento nesta fatia |
|---|---|
| Seleção | Clicar seleciona; ⇧-clique soma; arrastar no vazio seleciona por retângulo; arrastar move; alças redimensionam; alça de giro gira os tipos que aceitam rotação; ⌫ exclui; ⌘D duplica. Objetos **bloqueados** não respondem (§4.6). |
| Seta, Linha | Arrastar do início ao fim; ⇧ prende em múltiplos de 45°. Cor, largura, opacidade, tracejado; na seta, a ponta (`triangulo`, `aberta`, `nenhuma`). |
| Forma | Retângulo, retângulo arredondado, elipse; ⇧ faz quadrado ou círculo. Contorno e preenchimento. |
| Texto | Clicar ou arrastar cria a caixa e já entra em edição no lugar. Fonte, tamanho, cor, negrito, itálico, alinhamento, fundo da caixa. `Esc` ou clique fora confirma; caixa vazia ao confirmar é descartada. |
| **Callout** | Balão com texto e um rabicho cuja ponta se arrasta para apontar (protótipo). Forma do balão (retângulo arredondado, retângulo, elipse **[minha decisão]**), contorno, fundo e as propriedades de texto. O texto se edita como na ferramenta Texto. |
| **Caneta** | Arrastar desenha um traço à mão livre, suavizado. Cor, largura, opacidade, como a linha. |
| Etapa | Clicar põe o próximo marcador. Numeração pela **ordem de criação** (já no núcleo, `Etapas.swift`); excluir renumera; "reiniciar sequência" no objeto; rótulo numérico ou alfabético. |
| Carimbo | Escolhe um símbolo de um conjunto embutido (símbolos do sistema) e clica ou arrasta para pôr. Tamanho e cor. |
| Realce | Arrastar uma faixa translúcida (cor padrão `anotacao-realce`). |
| Desfoque | Arrastar a área; borrar ou pixelizar e intensidade. Afeta tudo abaixo dele na ordem das camadas (já no renderizador). |
| Recorte | Mostra alças sobre a imagem inteira (ou sobre o recorte atual); `Enter` confirma, `Esc` cancela; "Remover recorte" no menu Imagem. Anotações fora do recorte continuam guardadas (spec de origem §4.8). |

O esquema v1 já guarda rotação, ponta, família da fonte, alinhamento e rótulo de etapa, mas nenhuma interface os mostra. Esta fatia os põe no painel de propriedades (pendência do Plano 2).

**Texto que não cabe** (pendência do Plano 1) **[minha decisão]:** a caixa mantém a largura que o usuário deu (ou, criada por clique simples, cresce em largura até a borda da imagem e depois quebra linha) e **a altura acompanha o conteúdo** a cada mudança de texto ou de estilo; o editor grava sempre um retângulo em que o texto cabe. O renderizador continua recortando ao retângulo como rede de segurança. Vale também para o texto do callout.

### 4.4 Comum a todas

- **Memória por ferramenta:** cada ferramenta guarda o último estilo usado e a próxima anotação nasce com ele. Persiste entre aberturas do app **[minha decisão]**. Mudar a propriedade de um objeto selecionado também atualiza a memória da ferramenta dele.
- **Desfazer e refazer** ilimitado na sessão, pela `SessaoEdicao` que já existe. Um gesto é **um passo**: um arrasto, uma digitação inteira de texto (da entrada à confirmação), um alinhar de vários objetos, um colar. Para isso o núcleo ganha `Edicao.lote` (pendência do Plano 1). O histórico não sobrevive a reabrir o arquivo (spec de origem §5).
- **Copiar e colar objetos:** ⌘C com seleção copia os objetos; ⌘V cola deslocado alguns pixels, com ids novos, também em outra janela do editor. ⌘C sem seleção, o botão Copiar e ⇧⌘C copiam a **imagem renderizada** **[minha decisão]**. Colar um conteúdo que não é do Capta não faz nada.
- **Ordem das camadas:** trazer para a frente, enviar para trás, um nível acima, um nível abaixo (já em `Edicao.reordenar`).
- **Alinhar** a seleção: esquerda, centro, direita, topo, meio, base, pelo retângulo que envolve a seleção.
- **Zoom:** 25 a 400 %, ajustar à janela e tamanho real (já existe a alternância), por atalho, gesto de pinça e menu.
- **Teclado:** setas movem a seleção 1 px (⇧ 10 px); `Esc` cancela a criação em curso ou limpa a seleção; ⌘A seleciona tudo o que não está bloqueado; atalhos de letra para as ferramentas; os atalhos dos menus de contexto e de Imagem do protótipo são ilustração.

### 4.5 Callout e caneta (tipos novos)

- **Callout:** um retângulo do balão, a forma do balão, o ponto da ponta do rabicho e o texto com os mesmos campos da anotação de texto (conteúdo, tamanho, negrito, itálico; fonte e alinhamento pelo `Estilo`). O rabicho sai da borda do balão mais próxima da ponta; a largura da base do rabicho é do construtor. Sem rotação **[minha decisão]**.
- **Cores do callout [minha decisão]:** contorno = `Estilo.cor`, fundo = `Estilo.preenchimento`, e o texto ganha um campo opcional novo no `Estilo` (cor do texto). Ausente, o texto sai preto ou branco, o que tiver mais contraste com o fundo. O painel do callout ganha "Cor do texto" ao lado de contorno e fundo.
- **Fundo da caixa de texto [minha decisão]:** na ferramenta Texto, "fundo da caixa" é o `Estilo.preenchimento`, desenhado atrás do texto com uma margem interna; a cor do texto continua `Estilo.cor`. O renderizador passa a desenhar esse fundo e essa margem (hoje não desenha); o tamanho da margem é do construtor.
- **Caneta:** uma lista de pontos. A suavização acontece ao desenhar (no renderizador ou ao gravar, a critério do construtor), sem mudar o resultado entre tela e exportação. Pelo menos 2 pontos; um teto de pontos por traço para o arquivo não crescer sem limite, com simplificação ao gravar se passar dele **[minha decisão; o número é do construtor]**. Sem rotação.

### 4.6 Agrupar, bloquear e achatar

O Pedro achata no Snagit para **parar de pegar sem querer as anotações antigas** ao pôr novas, não para perder as camadas. Por isso, no Capta, achatar é bloquear em massa e nada toca a imagem.

- **Agrupar** (⌘G) une dois ou mais objetos selecionados: clicar num seleciona o grupo, arrastar move todos, excluir exclui todos. **Desagrupar** (⇧⌘G) desfaz. Um nível só: agrupar uma seleção que contém grupos junta todos num grupo novo **[minha decisão]**. Editar um objeto dentro do grupo sem desagrupar fica de fora **[minha decisão]**.
- **Bloquear** um objeto (ou grupo): ele continua visível, renderizado e exportado, mas não responde a clique, arrasto nem seleção por retângulo, e fica fora do ⌘A. Mostra um cadeado discreto quando a ferramenta Seleção está ativa (protótipo). **Desbloquear** pelo menu de contexto sobre o objeto bloqueado, que é o único gesto que o alcança.
- **Achatar tudo** bloqueia todas as anotações que existem agora; as criadas depois nascem livres. **Desachatar tudo** desbloqueia todas. É o mesmo campo "bloqueado" do objeto, sem um estado à parte **[minha decisão]**.
- O rodapé mostra quantos objetos estão bloqueados quando há algum.

**Grupos nas camadas e no bloqueio [minha decisão]:**

- **Os membros de um grupo ficam contíguos na ordem das camadas.** Agrupar junta os membros logo abaixo da posição do membro mais alto, mantendo a ordem relativa entre eles. Isso pode mudar o que um desfoque no meio deles cobre, e o resultado aparece na hora (e se desfaz num passo). Trazer para a frente, enviar para trás e os passos de um nível movem o grupo como bloco.
- **O bloqueio é uniforme no grupo.** Bloquear ou desbloquear qualquer membro, ou o grupo, vale para todos. Agrupar uma seleção que mistura bloqueados e livres não acontece, porque bloqueados nunca entram numa seleção.
- `validar()` da v2 exige as duas coisas: membros contíguos e bloqueio igual em todos. O caso de borda "grupo com membro bloqueado" de §6 é o arquivo que viola essa regra e precisa ser recusado.

### 4.7 Girar, espelhar e redimensionar (documento inteiro)

Como o recorte, são **propriedades do documento**, não objetos, e são reversíveis: `base.png` nunca muda.

- **Girar** 90° à esquerda ou à direita, e **espelhar** na horizontal ou na vertical (espelhar é palpite aprovado no protótipo). As anotações acompanham o conteúdo: a seta continua apontando para o mesmo lugar, a forma continua cobrindo a mesma área. **Texto, callout, etapa e carimbo continuam em pé e legíveis** (não giram nem espelham as letras); setas e linhas espelham.
- **Redimensionar** só **encolhe**: largura e altura em pixels ou porcentagem, proporção travada, nunca acima do tamanho cheio (protótipo). As anotações encolhem na mesma proporção, traços e textos incluídos. Voltar a 100 % ou desfazer restaura o tamanho cheio.
- Tudo entra no desfazer como qualquer edição.

**Modelo [minha decisão]:** o documento ganha uma **orientação** (quartos de volta e espelhamento) e um **fator de saída** (0 < fator ≤ 1). Girar e espelhar são edições que **transformam a geometria de todas as anotações e o recorte** para a nova orientação, de modo que as anotações e o recorte passam a estar em **pixels da imagem base já orientada**; os objetos "em pé" (texto, callout, etapa, carimbo) têm só a posição transformada. O fator de saída não mexe nas anotações: o renderizador compõe tudo na resolução cheia e escala o resultado no fim. Ordem do renderizador: orientar a base → desenhar as anotações → recortar → escalar. O invariante "coordenadas em pixels da imagem base" do `CLAUDE.md` e do esquema passa a dizer "pixels da imagem base orientada", e a doc do esquema registra isso.

O fator de saída compõe com a redução para @1x da fatia 7 (multiplicam). O tamanho do rodapé e de Salvar como PNG é o tamanho de saída.

**Escala depois de encolher [minha decisão]:** com fator abaixo de 1, a saída (copiar, PNG, miniatura) é marcada com **escala 1**: os pixels escolhidos são o tamanho com que a imagem aparece em Mail, Mensagens ou Preview. Quem encolhe 1600 × 900 @2x para 800 × 450 recebe uma imagem de 800 × 450 pontos, do mesmo tamanho visual da captura. Com fator 1, a escala do documento continua como hoje. O canvas mostra **a imagem de saída**: 100 % de zoom é um pixel de saída por pixel da tela, e a conversão tela ↔ documento da vista inclui o fator.

### 4.8 Salvar sozinho

- Depois de cada edição, com atraso de ~2 s sem novas edições, o editor grava `documento.json` e a miniatura no pacote do rascunho por `PacoteCapta.atualizar`, fora da *main actor*. Ao fechar a janela e ao sair do app grava imediatamente e espera terminar.
- `base.png` nunca é regravado (spec de origem §4.8). A orientação e o fator de saída vivem no `documento.json`.
- Se o rascunho não foi criado na captura (falhou), o editor tenta criá-lo de novo no primeiro salvamento **[minha decisão]**; se falhar de novo, o aviso discreto continua e a edição segue em memória, com **Salvar como Capta…** disponível.
- Gravar com o app saindo não pode ser cortado no meio: escrita atômica, como já é.

### 4.9 Esquema v2

O app já grava rascunhos em v1, então a v1 está congelada (`docs/esquema-capta-v1.md`). Esta fatia sobe `Esquema.versaoAtual` para **2**, **uma vez só**, com todos os campos novos juntos:

- geometria `callout` e geometria `caneta` (§4.5);
- na anotação: identificador de grupo (opcional) e `bloqueada` (padrão falso);
- no documento: orientação (padrão: nenhuma) e fator de saída (padrão 1).

Mais um campo opcional no `Estilo`: a cor do texto do callout (§4.5).

**Quando a v2 congela [minha decisão]:** ao fim da fatia 5, no último passo do Plano 5c, e não no primeiro rascunho gravado pelo Plano 5a. Até lá a v2 pode mudar no lugar, sem v3, como a v1 mudou no Plano 2. Os rascunhos gravados por builds intermediários são descartáveis: o build que muda a v2 no lugar pode recusar abrir esses rascunhos, e a lista manual do 5c manda apagar a pasta `Capturas` antes de congelar. O congelamento é um passo explícito do 5c: o teste congelado da v2 e a regra de congelamento na doc do esquema. A v1 continua congelada desde já, e a migração v1 → v2 vale para qualquer rascunho v1 que exista hoje.

Regras: um arquivo v1 abre sem perda (migração v1 → v2 só acrescenta os padrões e sobe a versão); a v1 congelada continua como teste; um teste congelado novo guarda o JSON da v2 completo; `validar()` cobre as faixas novas (fator em (0, 1], caneta com pelo menos 2 pontos e abaixo do teto, grupo com pelo menos dois membros, rotação proibida em callout e caneta, recorte dentro do tamanho orientado). Uma doc `docs/esquema-capta-v2.md` no mesmo formato da v1 **[minha decisão: arquivo novo, v1 fica como histórico]**. Nomes exatos de chaves e tipos ficam com o construtor.

### 4.10 O que vai para o núcleo (lógica pura, TDD)

- **Limites e acerto:** o retângulo que envolve cada anotação (com rotação, largura do traço, ponta da seta, rabicho do callout) e o objeto sob um ponto, de cima para baixo, com tolerância em pixels e ignorando bloqueados (pendência do Plano 1).
- **Alças:** onde ficam as alças de cada tipo e o que arrastar cada uma faz (mover ponto, redimensionar com e sem proporção, girar), como transformação pura de `Anotacao`.
- **Seleção:** conjunto selecionado com as regras de grupo e bloqueio (clicar num membro seleciona o grupo; bloqueado nunca entra).
- **Máquina de estados do editor:** ferramenta ativa, criação em curso, arrasto, edição de texto, recorte em curso, como valor imutável com `reduzir(estado, evento)`, igual ao overlay, para testar o fluxo de cada ferramenta sem janela.
- **Edições novas:** `lote`, agrupar, desagrupar, bloquear, desbloquear, achatar tudo, desachatar tudo, alinhar, girar, espelhar, redimensionar, duplicar e colar (ids novos, deslocamento, grupos remapeados).
- **Orientação:** a transformação das geometrias e do recorte nos quartos de volta e espelhamentos, com os objetos "em pé"; quatro giros seguidos devolvem o documento igual.
- **Memória por ferramenta:** o estilo lembrado por ferramenta, como valor codificável.
- **Área a redesenhar** de uma edição (união dos limites antes e depois).
- **Renderizador:** API que desenha num contexto dado, só dentro de uma área suja, para o canvas (pendência do Plano 1), além do `renderizar` inteiro que já existe para exportar; callout, caneta, orientação e fator de saída. O canvas e a exportação usam o mesmo código de desenho.
- **Texto que cabe:** a altura necessária para um texto num retângulo de largura dada, com o mesmo CoreText do renderizador, para o editor manter a caixa justa.

A casca no app: a vista do canvas (eventos de mouse, teclado e gesto, desenho pela API de área suja, alças), a edição de texto no lugar, painéis, menus, área de transferência e o agendador de salvamento.

### 4.11 Acessibilidade e aparência

- Todo controle com rótulo; VoiceOver anuncia a ferramenta ativa, a seleção ("Seta, 1 de 5") e as confirmações.
- O editor se opera pelo teclado: Tab e ⇧Tab percorrem os objetos não bloqueados na ordem das camadas **[minha decisão]**, setas movem, ⌫ exclui, atalhos escolhem a ferramenta.
- Claro e escuro pelos tokens; Reduzir transparência nos painéis, como no overlay.
- O canvas desenha a imagem e as anotações sempre com as mesmas cores nos dois temas; só o fundo em volta muda (`superficie-canvas`).

### 4.12 Esclarecimentos **[minha decisão, todos]**

- **Coordenadas do canvas:** a vista converte entre pontos da tela e pixels do documento pelo zoom e pela escala da tela; tolerâncias de acerto e tamanho das alças são em pontos da tela, não em pixels do documento, para o clique funcionar igual em qualquer zoom.
- **Seleção e desfoque:** um desfoque selecionado mostra o contorno da área; por baixo dele as anotações continuam clicáveis se estiverem por cima na ordem das camadas.
- **Recorte e seleção:** objetos fora da área recortada não aparecem nem são clicáveis enquanto o recorte vale.
- **Fator de saída e novas anotações:** depois de encolher, uma anotação nova nasce com o estilo lembrado em pixels da imagem cheia, então parece proporcionalmente mais fina. A forma de compensar (ou não) fica com o construtor, desde que o painel mostre a espessura como ela sai.

### 4.13 Capturas recentes

- Item **Capturas recentes ▸** no menu da barra de menus, com as **10 capturas** mais recentes da pasta `Capturas` (`Application Support/<bundle id>/Capturas`, dentro do contêiner), ordenadas pela data de modificação do pacote, a mais nova no alto **[minha decisão: 10]**. Cada item mostra o nome do rascunho (`Captura AAAA-MM-DD às HH.mm.ss`). Sem capturas, o submenu mostra um item desabilitado "Nenhuma captura".
- A lista é lida a cada abertura do menu, sem cache. Ignora o que não é pacote `.capta` e as pastas ocultas com ponto, como o temporário `.Captura….capta.tmp-UUID` que sobra se o app sair no meio de uma gravação (pendência do Plano 2).
- Escolher um item abre o pacote no editor, com a mesma janela e o mesmo salvar sozinho de uma captura nova; o pacote aberto é o rascunho que passa a ser atualizado. Se ele já estiver aberto numa janela, essa janela vem para a frente, sem abrir outra.
- Abrir passa por `PacoteCapta.ler`, que roda a migração v1 → v2 (§4.9). É o primeiro caminho real dessa migração.
- Não precisa de entitlement novo nem de acesso de escopo de segurança, porque tudo está no contêiner. Renomear, excluir e buscar ficam para a biblioteca (fatia 6).
- No núcleo: listar os pacotes recentes de uma pasta (filtro, ordem, limite), com testes em pasta temporária.

## 5. Tratamento de erros

| Situação | Comportamento |
|---|---|
| Edição inválida (`validar()` recusa) | Não aplica, nada muda; detalhe só no registro. Não deveria acontecer pela interface. |
| Falha ao salvar sozinho | Aviso discreto na barra; nova tentativa no próximo salvamento; a edição continua em memória. |
| Falha ao renderizar a área suja | Mantém a última imagem boa na tela; registro. |
| Falha em copiar ou salvar PNG / Capta | Como nas fatias 3 e 4 (alerta em folha, curto, em pt-BR). |
| Colar conteúdo que não é do Capta, ou corrompido | Ignora. |
| Abrir um `.capta` v1 | Migra em memória para a v2; grava em v2 no próximo salvamento. |
| Captura recente ilegível ou corrompida (inclusive rascunho de build intermediário, §4.9) | Alerta curto em pt-BR; nada é apagado nem alterado no pacote. |
| Captura recente apagada entre abrir o menu e escolher o item | Alerta curto; o menu se atualiza na próxima abertura. |
| `.capta` de versão mais nova | Como hoje (`versaoMaisNova`). |

## 6. Estratégia de testes

- **Núcleo, TDD, piso de 98 %:** cada item de §4.10 com casos de borda: acerto com rotação e traço largo, objeto bloqueado sob o cursor, grupo com membro bloqueado, alças invertendo o retângulo, ⇧ em 45°, caneta com 1 ponto e no teto, callout com a ponta dentro do balão, alinhar com um só objeto, colar com grupo, quatro giros = identidade, espelhar duas vezes = identidade, orientação com recorte, fator nos limites, migração v1 → v2 e teste congelado da v2, máquina de estados de cada ferramenta (criar, cancelar com `Esc`, confirmar), lote desfeito num passo só, texto que cresce em altura.
- **Renderizador:** testes de imagem com tolerância para callout, caneta, orientação, espelhamento e fator de saída; a API de área suja produz o mesmo pixel que o render inteiro dentro da área.
- **App:** o modelo do editor (seleção ligada à máquina de estados, agendador de salvamento com relógio falso, salvar ao fechar, copiar imagem x objetos) com fakes em `CaptaTests`. **Piso do app** (pendência do Plano 2) **[minha decisão]:** registro de exclusões do app com motivo, no formato de `ferramentas/cobertura.exclusoes`, para as views e a casca do canvas (eventos e desenho AppKit); os modelos do editor ficam dentro da conta e `App=` não desce. O registro e o portão que o lê entram em commit próprio, no Plano 5a, antes do canvas.
- **Lista de verificação manual** nova em `docs/`: cada ferramenta com mouse e trackpad; texto e callout em edição no lugar com acentos e emoji do sistema; zoom 25 % e 400 % em Retina e 1x; 60 fps em imagem 5K com dezenas de objetos (medir, sem prometer); salvar ao fechar e ao sair com ⌘Q no meio do atraso; fechar, reabrir por Capturas recentes e continuar editando; reabrir um rascunho v1 gravado antes desta fatia; girar e encolher e conferir o PNG no Preview; copiar e colar objetos entre duas janelas; VoiceOver e teclado; tema escuro e Reduzir transparência.

## 7. Ordem sugerida para os planos

A fatia é grande demais para um plano só. Uma spec, **três planos** **[minha decisão]**, cada um entregável e verificável:

1. **Plano 5a, base do editor:** esquema v2 completo e migração; `Edicao.lote`; limites, acerto e alças; API de área suja do renderizador; janela do editor no lugar da janela de resultado; canvas com zoom; Seleção (mover, redimensionar, girar, excluir, duplicar); desfazer e refazer; salvar sozinho; **Capturas recentes** (para conferir na hora que nada se perde ao fechar); Seta, Linha, Forma e Realce com propriedades e memória por ferramenta.
2. **Plano 5b, ferramentas de conteúdo:** Texto (edição no lugar e altura que acompanha), Callout, Caneta, Etapa, Carimbo, Desfoque e Recorte, com as propriedades que faltam (ponta, fonte, alinhamento, rótulo de etapa).
3. **Plano 5c, organizar e imagem:** agrupar, bloquear, achatar; alinhar e ordem das camadas; copiar e colar objetos; girar, espelhar e redimensionar; teclado e VoiceOver; lista de verificação manual e conferência com o Pedro.

## 8. Deixado para o construtor

Nomes de tipos, arquivos e chaves do JSON · forma exata da máquina de estados e das edições novas · AppKit ou SwiftUI na vista do canvas (o canvas precisa de mouse, teclado e gesto precisos; a janela pode seguir SwiftUI) · como a edição de texto no lugar casa com o CoreText do renderizador · algoritmo de suavização da caneta e teto de pontos · largura da base do rabicho · tamanho das alças e tolerância de acerto · atalhos de letra das ferramentas e dos menus · conjunto exato de carimbos · cache por camada e estratégia de redesenho · chaves de `UserDefaults` da memória por ferramenta · aparência fina pelos tokens · textos exatos (String Catalog) · como compensar a espessura depois de encolher (§4.12).

## 9. Decisões que continuam com o Pedro

Nenhuma bloqueia a fatia. As escolhas **[minha decisão]** valem até ele trocá-las. As mais prováveis de querer revisar:

- **Achatar = bloquear em massa**, com o mesmo campo do bloqueio; desachatar tudo também desbloqueia o que foi bloqueado um a um (§4.6).
- **Grupos de um nível só** e sem editar um membro dentro do grupo (§4.6).
- **Texto em pé ao girar e espelhar** (§4.7).
- **⌘C sem seleção copia a imagem** (§4.4).
- **Três planos** na ordem de §7.

## 10. Riscos

- **Desempenho na CPU** em imagem 5K com dezenas de objetos e desfoque: o redesenho por área suja e o cache por camada são o que segura os 60 fps; medir cedo no Plano 5a, sem bloquear a fatia (spec de origem §4.8).
- **Texto editado no lugar diferente do texto renderizado** (quebra de linha, métricas) entre o campo de edição do sistema e o CoreText do renderizador: o usuário veria o texto "pular" ao confirmar. Testar cedo no Plano 5b.
- **Transformar coordenadas na orientação** muda o invariante de coordenadas que o núcleo e as docs assumem; precisa de cobertura completa e de atualizar `CLAUDE.md` e a doc do esquema no mesmo plano.
- **Migração v1 → v2** é a primeira migração real do projeto; `PacoteCapta.ler` hoje só tem o portão de versão.
- **Salvar ao sair** com ⌘Q: a gravação precisa terminar antes de o app encerrar.
- **Toolchain beta** muda entre semanas (spec de origem §11).
