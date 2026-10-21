# Capta — Design da fatia 3: captura de tela inteira

Data: 2026-10-20 · Autor: Pedro Teixeira (decisões) / Claude (rascunho) · Status: **rascunho para aprovação**
Spec de origem: [`2026-10-20-capta-mvp-design.md`](2026-10-20-capta-mvp-design.md) (§4.2, §4.3, §4.8, §5, §8). Padrões técnicos: [`docs/padroes-stack-swift.md`](../../padroes-stack-swift.md). Visual: [`docs/design-system/`](../../design-system/README.md).

> **Convenção.** O que o Pedro decidiu está sem marca. O que é escolha do rascunho está marcado **[minha decisão]** e pode ser trocado. O que ficou para quem constrói está em "Deixado para o construtor".

---

## 1. Intenção e motivo

O Plano 1 entregou o núcleo do documento e um app de barra de menus que ainda não faz nada. Esta fatia entrega o **primeiro fluxo ponta a ponta**: o Pedro dispara a captura, o app grava a imagem e mostra o resultado numa janela, de onde ele copia ou salva.

Ela também é a **primeira vez que o app grava um `.capta`**. Por isso abre fechando o esquema v1 e a regra de numeração das etapas: depois de existir um arquivo real no disco, mudar o esquema custa uma migração.

**Sucesso** é o Pedro:

1. apertar o atalho (ou usar o menu), capturar a tela onde está o cursor e ver a imagem numa janela em menos de um segundo;
2. copiar a imagem e colar noutro app;
3. salvar como PNG e como `.capta`;
4. na primeira vez, ou com a permissão revogada, ser levado às Configurações do Sistema por uma tela em pt-BR, sem erro técnico, e voltar a capturar sem perder nada.

## 2. Objetivos, não objetivos e anti-objetivos

**Objetivos**

- Esquema v1 do `.capta` fechado e coberto por testes (§4.1).
- Numeração de etapas por ordem de criação (§4.2).
- Captura da **tela sob o cursor**, por atalho global e pelo menu, com ScreenCaptureKit isolado em `CaptaSistema`.
- Fluxo de permissão de Gravação de Tela (primeira vez, negada, revogada, reinício).
- Janela de visualização com copiar, salvar PNG e salvar `.capta`.
- Rascunho gravado automaticamente no contêiner a cada captura (§4.5).

**Não objetivos** (ficam para outras fatias)

- Overlay, região, janela, atraso, cursor na captura, várias telas escolhíveis (fatia 4).
- Ferramentas de anotação, propriedades, zoom de 25 a 400 %, desfazer na interface (fatia 5).
- Biblioteca, abrir `.capta` pelo Finder ou por duplo clique, registro do tipo de documento para abertura (fatia 6).
- Preferências, atalho configurável, formatos JPEG/HEIC/PDF, @1x, compartilhar, boas-vindas geral (fatia 7).

**Anti-objetivos** (falha mesmo que "funcione")

- Pedir **Acessibilidade** ou qualquer permissão além de Gravação de Tela.
- Qualquer acesso à rede, conta ou telemetria.
- Novo entitlement. Continuam só `app-sandbox` e `files.user-selected.read-write`.
- A captura sair com as janelas do próprio Capta dentro.
- Mostrar ao usuário texto de erro técnico ou em inglês.
- Perder uma captura já feita porque a janela foi fechada.

## 3. Restrições

As do MVP (§3 da spec de origem), mais:

- `CaptaNucleo` continua sem ScreenCaptureKit, AppKit e SwiftUI. O capturador é um **protocolo no núcleo**; a implementação fica em `CaptaSistema`.
- `make verificar` passa em todo commit; os pisos de cobertura de `ferramentas/cobertura.pisos` não caem. Subir piso vai em commit próprio.
- A casca fina que chama o ScreenCaptureKit não é testável sem tela e permissão. A lógica ao redor (escolher a tela, converter escala, mapear erros) precisa ficar fora dela e ser testada. O que sobrar sem teste automático entra na lista de verificação manual (§7) e no registro de exclusões de cobertura descrito em [`2026-10-20-capta-cobertura-de-testes-design.md`](2026-10-20-capta-cobertura-de-testes-design.md).

## 4. Desenho

### 4.1 Esquema v1 fechado

O app nunca gravou um `.capta`; só os testes gravaram. Por isso a v1 é **alterada no lugar, sem migração e sem subir `versaoAtual`** **[minha decisão]**. Passa a valer a regra: **depois do primeiro `.capta` real gravado pelo app, a v1 está congelada** e qualquer mudança incompatível sobe a versão e traz migração com teste.

O que fecha:

- **`Geometria` com `Codable` explícito.** Hoje usa o `Codable` sintetizado do Swift, cujo JSON para casos com valores sem rótulo é frágil e muda se alguém reordenar ou renomear. O JSON passa a ter um discriminador de tipo (`"tipo": "seta"`, …) e chaves nomeadas, em pt-BR, estáveis. Ponto e retângulo usam objetos com chaves nomeadas, não os arrays do `CGPoint`/`CGRect` **[minha decisão]**. O formato exato fica com o construtor, mas é **documentado em `docs/`** e travado por teste com um JSON de referência (*golden*).
- **Rotação.** Campo `rotacao` em `Anotacao`, em radianos, em torno do centro do retângulo da geometria, padrão `0`. Não se aplica a seta, linha e desfoque; a validação rejeita rotação diferente de zero nesses três **[minha decisão]**.
- **Estilo da ponta da seta.** Em `Estilo`, enum com `triangulo` (padrão), `aberta` e `nenhuma` **[minha decisão]**.
- **Texto: família da fonte e alinhamento.** Família opcional (`nil` = fonte do sistema) e alinhamento `esquerda`/`centro`/`direita`, padrão `esquerda`.
- **Rótulo da etapa.** Formato `numerico` (1, 2, 3) ou `alfabetico` (A, B, C), por etapa, padrão `numerico` (spec §4.4). A posição na sequência conta todas as etapas, de qualquer formato; no formato alfabético a posição 27 vira `AA`, a 28 `AB` e assim por diante (base 26 sem zero) **[minha decisão]**.
- **O renderizador não desenha os campos novos nesta fatia** (rotação, ponta, rótulo alfabético, família e alinhamento): aqui eles são **gravados, validados e testados na ida e volta**. Desenhá-los vem com as ferramentas, na fatia 5 **[minha decisão]**. O que o renderizador já desenhava não muda.
- **Campos novos têm padrão** quando ausentes no JSON, para o decodificador aceitar o que os testes do Plano 1 gravaram.
- `Documento.validar()` cobre todos os campos novos (finitude, faixa, rotação proibida, família de fonte vazia).

### 4.2 Numeração de etapas por ordem de criação

A spec §4.8 manda numerar por ordem de criação; o código numera pela ordem das camadas. O código passa a seguir a spec:

- O documento guarda a **ordem de criação** de cada anotação (um contador monotônico no documento e o valor em cada anotação; a representação fica com o construtor).
- O número exibido de uma etapa é a posição dela entre as etapas **na ordem de criação**, com `reiniciaSequencia` voltando a contagem a `1`. Calculado, não gravado.
- Trazer para frente ou enviar para trás **não muda** números. Excluir a etapa 2 renumera as seguintes. Duplicar ou colar cria uma etapa nova, com ordem de criação nova.
- Arquivos do Plano 1 sem o campo de ordem de criação (só existem em testes) decodificam usando a ordem da lista.

### 4.3 Captura

**Protocolo no núcleo.** Um capturador que, dado um ponto do cursor, devolve a imagem da tela que o contém e a escala dela. Falhas viram um `ErroCaptura` do núcleo com, no mínimo: sem permissão, tela não encontrada, falha genérica. A forma exata do protocolo fica com o construtor.

**Implementação em `CaptaSistema`** (ScreenCaptureKit, captura de imagem única):

- Escolhe a tela pelo ponto do cursor. Sem tela sob o ponto, usa a principal.
- Captura em **pixels nativos** da tela. O documento nasce com `tamanhoBase` em pixels e `escala` igual à da tela (`2` em Retina).
- **Exclui as janelas do próprio Capta** do filtro de conteúdo.
- Sem cursor na imagem (a opção de incluir fica para a fatia 4).
- Falha por permissão negada ou revogada vira `semPermissao`, inclusive a que o sistema devolve quando a permissão expira no meio da sessão.
- Disparo com captura já em andamento é **ignorado** **[minha decisão]**.

**Atalho global.** Registrado sem Acessibilidade (Carbon `RegisterEventHotKey` ou equivalente da spec §4.2). Nesta fatia é **fixo**: **⌃⌥F**, "tela inteira" **[minha decisão]**. ⌃⌥C continua reservado à captura livre da fatia 4; o atalho configurável vem na fatia 7. Se o registro falhar (conflito), o app **avisa** no menu e não cai; o item de menu continua funcionando.

**Menu da barra.** Entram só itens que funcionam: *Capturar tela inteira* (com o atalho à mostra) e *Sair do Capta*. Os demais da spec §4.2 entram nas fatias deles **[minha decisão]**.

### 4.4 Permissão

Fluxo da spec §4.3 e §4.8, com este recorte **[minha decisão]**: a janela de ajuda aparece **na primeira captura sem permissão** e **sempre que uma captura falhar por falta dela**. Não aparece na abertura do app. A boas-vindas geral (spec §4.8, "primeira abertura") fica para a fatia 7; esta janela é só a parte da permissão.

- Explica em uma ou duas frases por que o Capta precisa da Gravação de Tela e que nada sai do Mac.
- Botões: *Abrir Configurações do Sistema* (direto no painel de Gravação de Tela), *Tentar de novo* e, quando o sistema exigir, *Reiniciar o Capta*.
- Trabalho em andamento nunca se perde: janelas de visualização abertas ficam como estão.
- Quando o sistema só reconhece a permissão depois de reiniciar o app, o botão de reinício aparece. Como detectar isso fica com o construtor, confirmado na documentação da Apple e na lista manual.
- **Quem decide que é falha de permissão** **[minha decisão]**: antes de capturar, o app consulta `CGPreflightScreenCaptureAccess`. Se negada, não captura e mostra a janela de ajuda. Na **primeira vez** ele chama `CGRequestScreenCaptureAccess` **uma única vez** (para o sistema mostrar o pedido dele) e mostra a ajuda em seguida. *Tentar de novo* só consulta; não pede de novo. Se a consulta disser que há permissão mas o ScreenCaptureKit devolver erro de permissão (a revogação no meio da sessão), o erro também vira `semPermissao`. O construtor confirma esse desenho contra a documentação e o macOS 27 beta.

### 4.5 Rascunho gravado a cada captura

A spec §4.8 diz que `base.png` é gravado uma vez, no instante da captura, e que fechar a janela nunca pergunta nada porque tudo fica na biblioteca. A biblioteca só chega na fatia 6, mas o comportamento vale desde já **[minha decisão]**:

- Toda captura vira um pacote `.capta` em uma pasta `Capturas` no contêiner do app (Application Support), gravado com `PacoteCapta.gravar` (atômico, `base.png` uma vez, miniatura junto). Nome: data e hora da captura, em pt-BR; formato exato com o construtor.
- Fechar a janela **não pergunta** e **não perde** a captura.
- O núcleo ganha um gerador de **miniatura** (ImageIO, lado maior fixo, sem ampliar imagens pequenas) e a **codificação PNG** da imagem renderizada.
- Nada apaga esses pacotes nesta fatia. A fatia 6 os lista e permite excluir. Consequência aceita: a pasta cresce até lá.
- A janela **abre sobre a imagem em memória, sem esperar a gravação**, que corre em paralelo **[minha decisão]**. Enquanto a gravação não termina, *Salvar como Capta* fica indisponível; copiar e salvar PNG funcionam desde o primeiro instante.
- Se a gravação do rascunho falhar (disco cheio, por exemplo), a janela continua aberta, copiar e salvar PNG continuam funcionando, *Salvar como Capta* grava o pacote direto da imagem em memória, e um aviso discreto diz que a captura não foi guardada.

### 4.6 Janela de visualização

Janela SwiftUI nova, uma por captura, que mostra o documento pelo **renderizador único** do núcleo (mesmo sem anotações, para o caminho de exibição e o de exportação serem o mesmo desde o início).

- Imagem **ajustada à janela** por padrão, com alternância para **tamanho real** (100 %). Zoom livre é da fatia 5 **[minha decisão]**.
- Barra de ferramentas com três ações: **Copiar** (⌘C), **Salvar como PNG…** e **Salvar como Capta…**.
- *Copiar* põe a imagem renderizada na área de transferência.
- *Salvar como PNG* usa o painel de salvar do sistema e grava a imagem renderizada em pixels nativos, com resolução (DPI) coerente com a escala para o Preview mostrar o tamanho certo.
- *Salvar como Capta* usa o painel de salvar do sistema e **copia o pacote do rascunho** para o destino escolhido. É exportar uma cópia (spec §4.8), não "salvar o documento".
- Feedback curto e acessível depois de copiar e salvar; falha de gravação mostra um alerta em pt-BR.
- Enquanto houver janela aberta, o Capta aparece no **Dock**; sem janela, volta a ser só barra de menus (spec §4).
- Texto de interface só pelo String Catalog, cor só por `Tema.*`, claro e escuro, todo controle com rótulo de acessibilidade, ações operáveis por teclado.
- Os protocolos de área de transferência e de painéis de arquivo ficam no núcleo; as implementações (`NSPasteboard`, `NSSavePanel`) em `CaptaSistema`.

### 4.7 Tipo de documento `.capta`

Para o pacote salvo aparecer no Finder como **um item** e não como pasta, o app **exporta a declaração do tipo** `.capta`, com identificador `com.pedroct.capta.documento`, derivado do ID de bundle provisório, em conformidade com `com.apple.package` **[minha decisão]**. Só a declaração: abrir `.capta` por duplo clique e o registro como documento editável vêm na fatia 6.

## 5. Tratamento de erros

| Situação | Comportamento |
|---|---|
| Sem permissão (primeira vez, negada, revogada) | Janela de ajuda (§4.4); nenhuma janela de captura é aberta |
| Tela não encontrada ou falha genérica | Alerta curto em pt-BR, sem texto técnico; o detalhe vai para o registro local do sistema, sem dado do usuário |
| Falha ao gravar o rascunho | Janela abre com a imagem em memória e aviso discreto (§4.5) |
| Falha ao copiar ou salvar | Alerta em pt-BR; a captura e o rascunho continuam intactos |
| Atalho em conflito | Aviso no menu; o item de menu segue funcionando |
| Disparo durante uma captura | Ignorado |
| Arquivo `.capta` de versão mais nova | Fora desta fatia (o app ainda não abre `.capta`); o portão de versão do núcleo já existe |

## 6. Estratégia de testes

- **Núcleo, com TDD (teste que falha primeiro) e piso de 98 %:** `Codable` explícito de cada caso de `Geometria` (ida e volta, JSON de referência, chaves ausentes com padrão, tipo desconhecido, valor inválido); validação dos campos novos (rotação proibida em seta/linha/desfoque, família vazia, finitude); numeração por ordem de criação (reordenar camadas, excluir, reiniciar, duplicar, arquivo sem o campo); miniatura (proporção, imagem menor que o lado fixo, 1×1, muito larga); codificação PNG e DPI; criação do documento a partir de uma imagem capturada; mapeamento de `ErroCaptura`.
- **Sistema:** a lógica pura (tela sob o ponto, conversão de escala, mapeamento de erro do ScreenCaptureKit) testada com dublês. A casca do ScreenCaptureKit, do registro de atalho, de `NSPasteboard` e dos painéis fica na lista manual e, quando não for testável, no registro de exclusões de cobertura com o motivo escrito.
- **App:** o coordenador do fluxo (disparo → permissão → captura → rascunho → janela) testado com capturador, gravador e área de transferência falsos, em `CaptaTests`, medido por `make cobertura-app` sem subir o piso nesta fatia.
- **Lista de verificação manual** em `docs/` (nova, versionada): primeira captura sem permissão; permissão negada; permissão concedida com e sem reinício; permissão revogada com o app aberto; duas telas com escalas diferentes (captura da tela do cursor, pixels e escala certos); janelas do Capta ausentes da imagem; atalho em conflito; PNG colado no Preview com o tamanho certo; `.capta` salvo aparece como item único no Finder; Dock aparece e some com a janela.
- **Alvo a medir, sem prometer:** do atalho à janela aberta em menos de 500 ms em tela Retina.

## 7. Ordem sugerida para o plano

1. **Esquema v1 e numeração** (§4.1, §4.2): só núcleo, commits próprios, antes de qualquer outra coisa.
2. **Miniatura e PNG** no núcleo, protocolos de captura, área de transferência e painéis, `ErroCaptura`.
3. **Adaptadores em `CaptaSistema`:** captura, atalho, área de transferência, painéis.
4. **App:** coordenador, janela de ajuda de permissão, janela de visualização, menu, Dock, declaração do tipo.
5. **Lista de verificação manual** e conferência com o Pedro.

## 8. Deixado para o construtor

Nomes de tipos e arquivos · forma dos protocolos · nomes exatos das chaves do JSON (documentados e travados por teste) · representação da ordem de criação · lado fixo da miniatura · formato do nome do rascunho · textos exatos da interface e do String Catalog (tom dos padrões) · tamanho e posição da janela · ícone das ações · forma do feedback após copiar/salvar · como detectar que o reinício é necessário · como o registro de exclusões de cobertura enxerga a casca do ScreenCaptureKit.

## 9. Decisões que continuam com o Pedro

Nenhuma bloqueia esta fatia. As escolhas marcadas **[minha decisão]** valem até ele trocá-las; as mais prováveis de querer revisar: atalho ⌃⌥F, rascunho automático desde já (e a pasta que cresce até a fatia 6), v1 alterada sem migração, janela de ajuda só na captura (não na abertura do app).

Um ponto novo: o identificador `com.pedroct.capta.documento` nasce do ID de bundle, que a spec de origem (§10) ainda lista como provisório. Depois que existirem `.capta` fora do seu Mac, trocar o identificador custa caro; fechar o ID de bundle antes de distribuir qualquer arquivo.

## 10. Riscos

- **Comportamento da permissão no macOS 27 beta** (reinício, revalidação periódica) pode diferir da documentação: confirmar na lista manual, não só no código.
- **ScreenCaptureKit com escala mista:** a fatia captura só a tela do cursor, mas a conversão de escala é o ponto que o overlay da fatia 4 vai herdar; testar com duas telas desde já.
- **Toolchain beta** muda entre semanas (spec de origem §11).
- **Mudar o esquema no lugar** só é seguro porque nenhum `.capta` real existe; se o Pedro gravou algum à mão, ele precisa descartá-lo.
