# Capta — Design da fatia 4: overlay de região e janela

Data: 2026-10-21 · Autor: Pedro Teixeira (decisões) / Claude (rascunho) · Status: **rascunho para aprovação**
Spec de origem: [`2026-10-20-capta-mvp-design.md`](2026-10-20-capta-mvp-design.md) (§4.2, §4.3, §4.8, §8). Fatia anterior: [`2026-10-20-capta-captura-tela-inteira-design.md`](2026-10-20-capta-captura-tela-inteira-design.md). Padrões técnicos: [`docs/padroes-stack-swift.md`](../../padroes-stack-swift.md). Visual: [`docs/design-system/`](../../design-system/README.md).

> **Convenção.** O que o Pedro decidiu está sem marca. O que é escolha do rascunho está marcado **[minha decisão]** e pode ser trocado. O que ficou para quem constrói está em "Deixado para o construtor".

---

## 1. Intenção e motivo

A fatia 3 captura a tela sob o cursor, sem escolha. Esta fatia entrega o **jeito normal de capturar**: o Pedro aperta o atalho, a tela congela, ele **arrasta uma região** ou **clica numa janela**, confirma, e cai na mesma janela de resultado da fatia 3 (copiar, salvar PNG, salvar `.capta`).

O que torna isso mais que um recorte é a precisão: ver as dimensões em pixels, ajustar a seleção com o teclado, olhar pixel por pixel com a lupa, e capturar menus e estados passageiros com atraso.

**Sucesso** é o Pedro:

1. apertar `⌃⌥C`, ver todas as telas congeladas em menos de 500 ms (medido, sem prometer);
2. arrastar uma região, ajustá-la com o mouse e com as setas, e confirmar com `Enter`;
3. passar o cursor sobre uma janela, ver o realce e clicar para capturá-la inteira, mesmo com partes cobertas;
4. escolher um atraso, ver a contagem regressiva e capturar um menu aberto;
5. cancelar a qualquer momento com `Esc`, sem deixar rastro (nenhum rascunho, nenhuma janela).

## 2. Objetivos, não objetivos e anti-objetivos

**Objetivos**

- Overlay em **todas as telas**, cada uma com a imagem congelada do instante do disparo, levemente escurecida.
- Seleção de **região** (arrastar, ajustar bordas, mover) e de **janela** (realce ao passar, clique), com alternância por `Espaço`.
- Mira, dimensões em pixels, **lupa de pixels** (`M`), painel de ajuda (`H`) e as teclas da spec §4.2.
- **Atraso** de 3, 5 ou 10 s com contagem visível e cancelável, e **cursor** na captura (§4.5).
- Atalho global `⌃⌥C` e itens de menu *Capturar região* e *Capturar janela*.
- Várias telas e escalas mistas, preservando a escala nativa.

**Não objetivos** (ficam para outras fatias)

- Preferências, atalho configurável e atalhos separados por modo (fatia 7). Aqui os atalhos são fixos.
- Opções "copiar automaticamente" e "abrir no editor" (fatia 7). Nesta fatia a captura **sempre abre a janela de resultado**, como na fatia 3.
- Editor, anotações, zoom (fatia 5); biblioteca (fatia 6).
- Sombra na captura de janela, captura de menus e pop-ups como "janela", região que cruza telas (§4.4).
- Seleção da região só pelo teclado, sem mouse (§4.3).

**Anti-objetivos** (falha mesmo que "funcione")

- Pedir qualquer permissão além de Gravação de Tela, em particular **Acessibilidade** ou **Monitoramento de Entrada**. As teclas do overlay chegam pela janela do próprio app, não por monitoramento global.
- Novo entitlement. Continuam só `app-sandbox` e `files.user-selected.read-write`.
- O overlay, a contagem regressiva ou qualquer janela do Capta aparecerem **dentro da imagem capturada**.
- Overlay que prende o usuário: sem `Esc` funcionando, sem saída, tela escurecida para sempre (ver §5).
- A imagem capturada **diferir do que foi visto** na seleção sem atraso (o recorte vem da imagem congelada).
- Texto de erro técnico ou em inglês na interface; rede, conta ou telemetria.

## 3. Restrições

As do MVP (§3 da spec de origem) e da fatia 3, mais:

- `CaptaNucleo` continua sem ScreenCaptureKit, AppKit e SwiftUI. **Toda a lógica do overlay que não precisa de tela vai para o núcleo**, como valor puro e testável (§4.8). A casca (janelas de overlay, views, ScreenCaptureKit) fica em `CaptaSistema/Casca/` e no app, com o mínimo de código e sem lógica.
- `make verificar` passa em todo commit; pisos de `ferramentas/cobertura.pisos` não caem. Subir piso vai em commit próprio. Casca sem teste automático entra em `ferramentas/cobertura.exclusoes` com o motivo.
- O overlay **não bloqueia a thread principal** durante a captura; a captura ao vivo é assíncrona.

## 4. Desenho

### 4.1 Fluxo

```
disparo (⌃⌥C ou menu)
  → permissão (mesmo fluxo da fatia 3; sem permissão, janela de ajuda e fim)
  → congela todas as telas + lista as janelas
  → overlay em todas as telas
  → seleção (região ou janela) + Enter / clique
        ├─ sem atraso → recorte da imagem congelada (região) ou captura da janela (janela)
        └─ com atraso → fecha o overlay → contagem → captura ao vivo da região ou da janela
  → Documento.novo → janela de resultado + rascunho (idêntico à fatia 3)
```

Da captura em diante nada muda em relação à fatia 3: `Documento.novo(de:)`, rascunho em paralelo, janela de resultado, erros.

### 4.2 Congelar e listar

No disparo, **antes de qualquer janela do Capta aparecer**, o app captura **cada tela** em pixels nativos (como a fatia 3, mas todas) e lista as **janelas** capturáveis com quadro e ordem de empilhamento, excluindo o próprio app. Tudo vem do ScreenCaptureKit, em paralelo entre as telas.

- **Janelas selecionáveis** **[minha decisão]**: janelas comuns de aplicativos (camada normal), visíveis na tela, com tamanho mínimo razoável. Ficam de fora a barra de menus, o Dock, o papel de parede, janelas de camada de sistema e menus/pop-ups (a spec §4.8 os trata como região, com atraso). O critério exato fica com o construtor.
- Cada tela guarda a imagem congelada, o quadro em pontos (espaço global, origem no topo, como `DescricaoDeTela`) e a escala.
- Se a lista de janelas falhar mas as telas funcionarem, o overlay abre **só no modo região** e o modo janela fica indisponível, sem erro **[minha decisão]**.
- A memória das imagens congeladas é liberada ao fechar o overlay.

### 4.3 Overlay

Uma janela sem borda por tela, acima de tudo (inclusive barra de menus e Dock), visível em todos os Spaces e sobre apps em tela cheia. Cada uma mostra a imagem congelada da própria tela, escurecida, com a seleção "furada" (mostrada sem escurecer).

**Modos:** *região* e *janela*. `Espaço` alterna. O disparo pelo menu *Capturar janela* abre direto no modo janela; `⌃⌥C` e *Capturar região*, no modo região **[minha decisão]**. O modo atual aparece no painel de ajuda e na dica junto ao cursor.

**Região**

- Arrastar define o retângulo. O arrasto fica **preso à tela onde começou** e é limitado às bordas dela; região que cruza telas não existe no MVP **[minha decisão]** (cada tela tem escala própria, e unir exigiria costurar imagens).
- Depois de soltar, a seleção **fica ativa**: arrastar uma borda ou um canto a redimensiona; arrastar por dentro a move; clicar fora de uma seleção ativa começa uma nova. Tamanho mínimo de 1×1 pixel; a seleção nunca sai da tela.
- Setas movem a seleção de **1 px nativo**; com `⇧`, de 10 px. Não redimensionam (mover e redimensionar com o mouse; setas só movem) **[minha decisão]**.
- `Enter` confirma. Sem seleção ativa, `Enter` não faz nada.
- Dimensões (`largura × altura`, em pixels nativos) e a posição aparecem junto à seleção, e o texto troca de lado para não sair da tela.

**Janela**

- Passar o cursor realça a janela mais à frente sob ele (contorno e clareamento). Clicar a seleciona e confirma na hora; `Enter` confirma a realçada.
- Janela inteira, sem sub-áreas.

**Mira e lupa**

- A **mira** é um par de linhas-guia que segue o cursor, nos dois modos, em todas as telas.
- `M` liga e desliga a **lupa de pixels**: uma janela pequena junto ao cursor mostra a área ao redor ampliada (cada pixel nativo vira um quadrado visível, com grade) e as coordenadas do pixel sob o cursor. A lupa lê da imagem congelada, então mostra pixels reais mesmo em Retina. Ampliação inicial de 8× **[minha decisão]**. Cor do pixel e cópia da cor ficam fora do MVP.
- A lupa acompanha o arrasto e o movimento por setas, e muda de lado perto das bordas.

**Teclas** (spec §4.2)

| Tecla | Efeito |
|---|---|
| `Esc` | Cancela e fecha o overlay |
| `F` | Seleciona a tela inteira da tela sob o cursor e confirma |
| `Espaço` | Alterna região e janela |
| `Enter` | Confirma |
| Setas / `⇧`+setas | Movem a seleção 1 px / 10 px |
| `M` | Liga/desliga a lupa |
| `H` | Mostra/oculta o painel de ajuda |

**Painel de ajuda:** canto inferior esquerdo, lista as teclas acima, ocultável com `H`. Aparece na primeira vez e lembra a escolha **[minha decisão]**.

**Barra de opções curta** (spec §4.2, recortada): junto ao painel de ajuda, controles de **atraso** (nenhum, 3, 5, 10 s) e **incluir cursor**. As duas escolhas são lembradas entre capturas, em `UserDefaults`, com chaves que a tela de Preferências da fatia 7 vai reaproveitar **[minha decisão]**.

**Cursor na captura** **[minha decisão, a mais provável de querer revisar]:** a opção só vale **com atraso**, porque só aí há captura ao vivo; a imagem congelada nasce sem cursor. Sem atraso, o controle aparece desabilitado com a explicação em pt-BR. Compor um cursor artificial sobre a imagem congelada fica fora do MVP.

**Mouse e foco**

- O cursor do mouse vira mira durante o overlay.
- O overlay pega o foco do teclado ao abrir, mesmo o app sendo de barra de menus; `Esc` precisa funcionar de imediato.
- Se as telas mudarem (monitor ligado ou desligado, resolução alterada) com o overlay aberto, o overlay **cancela** sem capturar **[minha decisão]**.
- Disparo com overlay ou contagem já em andamento é ignorado.

### 4.4 Captura depois da seleção

**Sem atraso**

- **Região:** recorte da **imagem congelada** da tela, nos pixels da seleção (spec §4.8). O documento nasce com o tamanho do recorte e a escala da tela. A conversão de pontos para pixels arredonda de modo que a seleção mostrada e a imagem capturada tenham **o mesmo retângulo de pixels** (§4.8).
- **Janela:** captura da **própria janela** pelo ScreenCaptureKit (inclui partes cobertas ou fora da tela), **sem sombra**, com cantos como o sistema os desenha (spec §4.8). A escala é a da tela onde a janela está.

**Com atraso**

- Confirmada a seleção, o overlay **fecha** e começa a contagem. O app captura **de novo, ao vivo**, a região (mesmas coordenadas, mesma tela) ou a janela (pelo identificador), para pegar o que mudou, como um menu aberto (spec §4.8).
- **Contagem regressiva visível**: uma janelinha flutuante pequena do Capta com o número e a instrução "Esc cancela", **fora da imagem** (o app inteiro é excluído da captura, como na fatia 3). Fica no topo da tela da seleção, longe do centro **[minha decisão]**. Sem animação com *Reduzir movimento* ligado; o número é anunciado pelo VoiceOver.
- `Esc` ou clicar na janelinha **cancela**, sem rascunho.
- Se, ao fim da contagem, a janela escolhida não existir mais ou a tela da região sumiu, a captura falha com alerta curto em pt-BR e nada é gravado.

**Tela inteira (`F`)** usa a mesma regra da seleção de região com o retângulo igual à tela inteira e vai pelo mesmo caminho (com ou sem atraso). O atalho `⌃⌥F` e o item *Capturar tela inteira* da fatia 3 continuam como estão: captura direta, **sem overlay** **[minha decisão]**.

### 4.5 Atalhos e menu

- Atalho global fixo **`⌃⌥C`** para a captura livre (região, com `Espaço` para janela), registrado como o `⌃⌥F` da fatia 3, sem Acessibilidade. Fica o `⌃⌥F` já existente.
- Conflito de registro: aviso no menu, por atalho, e os itens de menu continuam funcionando.
- Menu da barra passa a ter: *Capturar região* (`⌃⌥C`), *Capturar janela*, *Capturar tela inteira* (`⌃⌥F`) e *Sair do Capta*. Os demais da spec §4.2 entram nas fatias deles.

### 4.6 Permissão

Idêntica à fatia 3, antes de congelar: sem permissão, não abre o overlay e mostra a janela de ajuda. Permissão revogada entre a congelada e a captura ao vivo (só com atraso) leva à mesma ajuda, sem perder nada.

### 4.7 Acessibilidade e aparência

- O overlay é uma ferramenta de apontar; **não há alternativa só por teclado para começar uma região** nesta fatia. O que existe por teclado: `F` (tela inteira), `Enter` em janela realçada, setas, `Esc`, e o painel de ajuda. As janelas de overlay têm rótulo de acessibilidade ("Seleção de captura. Esc cancela."), e a contagem é anunciada. Isso é uma **limitação aceita** do MVP **[minha decisão]**, a revisitar no acabamento (fatia 8).
- *Reduzir transparência* deixa o escurecimento e os painéis opacos; claro e escuro só por `Tema.*`; texto de interface só pelo String Catalog.

### 4.8 O que vai para o núcleo (lógica pura, TDD)

Sem tela, sem AppKit, só CoreGraphics:

- **Geometria da seleção:** normalizar o arrasto em qualquer direção; limitar à tela; mover; redimensionar por borda ou canto (tamanho mínimo, inversão ao cruzar); passo de seta; conversão entre pontos da tela e pixels nativos com arredondamento que mantenha **o retângulo mostrado igual ao capturado**, também com escala mista.
- **Acerto de região:** o que está sob o ponto (dentro, borda, canto, fora) com tolerância em pontos.
- **Janelas:** ordenar por empilhamento e achar a janela sob um ponto; filtro das selecionáveis (§4.2).
- **Máquina de estados do overlay:** modo (região/janela), seleção, lupa, ajuda, atraso, cursor, confirmação e cancelamento, como valor imutável com transições (`reduzir(estado, evento)`), para testar o fluxo inteiro sem janela.
- **Lupa:** o retângulo de pixels a amostrar ao redor de um ponto, com limite nas bordas da imagem, e a posição da janela da lupa e do texto das dimensões para ficarem dentro da tela.
- **Atraso:** contagem regressiva por relógio injetado, cancelável.
- **Recorte** de uma imagem congelada por retângulo em pixels.

O núcleo ganha também o contrato de captura expandido: congelar todas as telas e listar janelas, capturar região ao vivo, capturar janela, com `ErroCaptura` estendido (por exemplo, janela inexistente). A forma exata fica com o construtor.

### 4.9 Esclarecimentos da revisão **[minha decisão, todos]**

- **Foco e saída do overlay.** O overlay ativa o app e usa janelas que podem virar a janela de teclado (a classe sobrescreve `canBecomeKey`). Como rede de segurança contra ficar preso: **perder a ativação do app fecha o overlay e cancela**, clicar em qualquer janela do overlay recupera o foco, e `Esc` funciona nos dois casos. Não existe fallback com Acessibilidade ou Monitoramento de Entrada (anti-objetivo). Se o foco do teclado não puder ser garantido no macOS 27 beta, isso é problema **bloqueante** da fatia, descoberto no primeiro passo do overlay (§7, item 3), antes de construir o resto dele.
- **Mesmo retângulo de pixels, também com atraso.** O retângulo é sempre guardado em **pixels nativos**. A captura ao vivo converte para pontos pela escala da tela (exata em escala 1 e 2) e pede **o tamanho de saída em pixels da seleção**; a imagem recebida tem de ter exatamente a largura e a altura da seleção, senão a captura falha com alerta. A conversão pixels↔pontos do núcleo é invertível e testada nas duas direções. Se a escala ou o arranjo das telas mudar durante a contagem, a captura falha com alerta e nada é gravado, como na janela que some.
- **Janelas: coordenadas e tela de origem.** O quadro da janela vem do ScreenCaptureKit já no espaço global com origem no topo, em pontos, o mesmo das telas. A **tela da janela** é a que tem a maior área de interseção com o quadro (empate: a que contém o canto superior esquerdo); a escala do documento vem dessa tela. Janela parcialmente fora da tela ou coberta continua capturável inteira (captura da própria janela).
- **Congelar depois do menu fechar.** Pelo menu, a ação só roda depois que o menu fecha, e o app inteiro (menus incluídos) já é excluído do conteúdo capturado; ainda assim a lista manual confere que o menu não aparece na imagem congelada. Sem atraso artificial.
- **Cursor e atraso lembrados.** O valor lembrado de "incluir cursor" é **preservado** quando o controle está desabilitado (sem atraso) e o controle mostra esse valor, desabilitado. O atraso é **um só**, não por modo.
- **`F` com atraso e cursor.** Segue as mesmas opções que a região e o resultado é o mesmo da captura direta de tela inteira da fatia 3 (tela sob o cursor, pixels nativos); sempre há overlay na tela sob o cursor, então não existe o caso "tela sem overlay".

## 5. Tratamento de erros

| Situação | Comportamento |
|---|---|
| Sem permissão (antes de congelar, ou revogada na captura ao vivo) | Janela de ajuda; nenhum overlay |
| Falha ao congelar uma tela | Overlay não abre; alerta curto em pt-BR; detalhe só no registro local |
| Lista de janelas indisponível | Só modo região, sem erro (§4.2) |
| Telas mudam com o overlay aberto | Cancela sem capturar |
| Janela some durante o atraso | Alerta curto; nada gravado |
| `Esc` / clique na contagem | Cancela; nada gravado |
| Disparo durante overlay ou contagem | Ignorado |
| Overlay sem foco | Qualquer janela de overlay clicada recupera o foco; `Esc` sempre fecha |

Falha de gravação do rascunho, de cópia e de salvamento: como na fatia 3.

## 6. Estratégia de testes

- **Núcleo, TDD, piso de 98 %:** cada função de §4.8 com casos de borda: arrasto em todas as direções, seleção zero, fora da tela, tela com origem negativa, escala 1 e 2 e mista, arredondamento (seleção com meio ponto), redimensionar até inverter, janelas sobrepostas, ponto sem janela, lupa nos quatro cantos e em imagem menor que a amostra, máquina de estados (toda transição válida e as inválidas ignoradas), atraso com relógio falso e cancelamento no meio.
- **Sistema:** a lógica pura que cerca o ScreenCaptureKit (filtro das janelas, conversão de quadro, mapeamento de erro) com dublês. A casca (janelas de overlay, `SCContentFilter`, captura de região e de janela ao vivo) na lista manual e no registro de exclusões.
- **App:** o coordenador do fluxo (disparo → permissão → congela → overlay → captura → rascunho → janela) com fakes, incluindo cancelamento, atraso e falhas; em `CaptaTests`, sem subir o piso nesta fatia.
- **Lista de verificação manual** nova em `docs/`, entre outros: overlay cobre barra de menus e Dock; uma, duas e três telas, escalas mistas, tela acima ou à esquerda; app em tela cheia e outro Space; região sem atraso é exatamente o que foi visto; janela com parte coberta sai inteira e sem sombra; menu capturado com atraso; contagem fora da imagem; `Esc` em todos os estados; atalho em conflito; monitor desconectado com o overlay aberto; VoiceOver; Reduzir transparência e Reduzir movimento; tempo do atalho ao overlay (alvo < 500 ms, sem prometer).

## 7. Ordem sugerida para o plano

1. **Núcleo:** geometria da seleção, acerto, janelas, lupa, recorte, atraso e máquina de estados, tudo com TDD.
2. **Contrato de captura** expandido no núcleo e adaptadores em `CaptaSistema` (congelar telas, listar janelas, captura ao vivo de região e de janela).
3. **Overlay** (janelas, views da seleção, mira, lupa, painel de ajuda, barra de opções) sobre a máquina de estados.
4. **Fluxo, atraso, contagem, atalho `⌃⌥C` e menu**, ligando ao que a fatia 3 já faz.
5. **Lista de verificação manual** e conferência com o Pedro, incluindo várias telas.

## 8. Deixado para o construtor

Nomes de tipos e arquivos · forma dos protocolos e do `ErroCaptura` estendido · critério exato das janelas selecionáveis · nível e comportamento das janelas de overlay por Space e tela cheia · aparência (escurecimento, contorno, mira, lupa, painel, janelinha da contagem) pelos tokens · textos exatos (String Catalog) · tolerância de acerto das bordas · tamanho da lupa e da grade · chaves de `UserDefaults` · como o overlay recupera o foco · como o sistema entrega a ordem das janelas.

## 9. Decisões que continuam com o Pedro

Nenhuma bloqueia a fatia. As escolhas **[minha decisão]** valem até ele trocá-las. As mais prováveis de querer revisar:

- **Cursor só com atraso** (§4.3): sem atraso não há cursor na imagem.
- **Região presa a uma tela** (§4.3), sem região que cruze monitores.
- **Sem alternativa só por teclado** para começar uma região (§4.7).
- **`⌃⌥F` continua sem overlay** (§4.4).
- **Overlay cancela se as telas mudarem** (§4.3).

## 10. Riscos

- **Janelas de overlay sobre apps em tela cheia, Spaces e barra de menus** no macOS 27 beta podem se comportar diferente do esperado; confirmar na lista manual, não só no código.
- **Foco do teclado** num app de barra de menus: se o `Esc` não chegar, o overlay prende o usuário (anti-objetivo). Precisa de teste manual antes de qualquer outra coisa do overlay.
- **Escala mista:** o arredondamento entre pontos e pixels é o ponto em que "o que vi" e "o que saiu" podem divergir por 1 px; o núcleo o trava por testes e a lista manual o confere em duas telas.
- **Ordem e tipo das janelas** vindos do ScreenCaptureKit podem incluir janelas que o usuário não considera janelas; o filtro precisa de ajuste com uso real.
- **Custo de memória** de congelar várias telas Retina (cada uma dezenas de MB); liberar ao fechar o overlay e medir com três telas.
- **Toolchain beta** muda entre semanas (spec de origem §11).
