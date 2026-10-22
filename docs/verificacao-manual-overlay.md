# Verificação manual do overlay de região e janela

Lista para o Pedro percorrer com tela e permissão reais, depois do Plano 3. Cada linha é uma ação seguida do resultado esperado. Marque `[x]` ao confirmar; o que falhar vira pendência no status do plano. Os itens de várias telas pedem duas telas (e, onde diz, três).

## Preparar

1. Na pasta do worktree da branch `worktree-plano-3-overlay`, rode `make app` (exige `project.local.yml`, a partir de `project.local.yml.example`).
2. O `build/Capta.app` do worktree fica sob a pasta oculta `.claude`, então abra pelo terminal: `pkill -x Capta; open <caminho completo>/build/Capta.app`. Encerre antes qualquer instância antiga com `pkill -x Capta`.
3. Para ver o log, deixe aberto em outro terminal: `/usr/bin/log stream --predicate 'subsystem == "com.pedroct.capta"'`. Use `/usr/bin/log`, porque `log` é um comando interno do zsh. As categorias são `captura` e `overlay`.
4. Para repetir os testes de permissão do zero: `tccutil reset ScreenCapture com.pedroct.capta`.
5. Atalhos: `⌃⌥C` abre o overlay de captura livre; `⌃⌥F` captura a tela inteira (sem overlay).

## Overlay: cobertura e `Esc`

- [x] `⌃⌥C` com uma tela: o overlay cobre a tela toda, inclusive a barra de menus e o Dock, e a imagem por baixo está nítida e sem deslocamento (o que se vê é o que estava na tela). **Reconfirmar depois da troca de nível (ver abaixo):** o overlay e a contagem desceram de `.screenSaver` (1000) para `.popUpMenu` (101); pelos valores do `CGWindowLevel.h` ainda ficam acima do Dock (20), da barra de menus (24) e dos itens de status (25), mas isso só vale como certo depois de ver na tela. Confira também os itens de status de outros apps e o relógio no canto direito da barra.
- [x] `Esc` antes de arrastar: o overlay fecha, o cursor volta a ser seta e não sobra janela do overlay.
- [x] `Esc` com uma seleção feita: fecha sem capturar nem gravar rascunho.
- [x] `Esc` com a lupa ligada (`M`): fecha.
- [x] `Esc` no modo janela (`Espaço`): fecha.
- [x] `Esc` durante a contagem do atraso: cancela a captura, sem rascunho, e a janelinha da contagem some.
- [x] Depois de fechar o overlay (e depois da contagem), `Esc` volta a funcionar em outros apps (por exemplo, fechar um menu ou uma folha no Safari ou no Finder): o atalho global do `Esc` foi liberado. Repita depois de cancelar por clique, por `Enter` e por troca de app.
- [x] Com o overlay aberto, trocar de app (`⌘Tab`) ou mudar a resolução de um monitor cancela o overlay sem deixar nada na tela.
- [x] **Correção tentada, falta reconfirmar em tela real.** No primeiro teste em tela real, com o overlay ou a contagem abertos, segurar `⌘` e apertar `Tab` não mostrava o alternador de apps. O mais provável é que o HUD ficasse atrás das janelas do Capta, que estavam no nível `.screenSaver` (1000). Soltar o `Tab` ainda trocava de app, às cegas, e o overlay cancelava certo ao perder a ativação. O nível das duas janelas baixou para `.popUpMenu` (101). A Apple não publica em que nível o alternador do sistema fica, então a escolha é pelos níveis documentados e pode não bastar. Com o overlay aberto, segure `⌘` e aperte `Tab`: o HUD do alternador deve aparecer por cima, dê para escolher um app com `Tab` e setas, e ao soltar o overlay cancela sem sobrar nada na tela. Repita com a contagem correndo: o HUD deve aparecer por cima da janelinha, e a troca de app não cancela a contagem (só o overlay cancela por perda de ativação; o foco já voltou ao app de antes quando a contagem começa). Se o HUD continuar invisível em qualquer dos dois casos, é achado novo: anote e não marque.
- [x] Ainda pela troca de nível: com o overlay aberto, observe se alguma janela aparece por cima dele (banner de notificação, Spotlight, painéis flutuantes de outros apps, dicas de ferramenta, ícone arrastado). Antes, com o nível 1000, quase nada passava por cima; agora o que estiver acima de 101 passa. Anote o que aparecer.
- [x] Desconecte um monitor com o overlay aberto (com duas telas): o overlay cancela e fecha em todas as telas; `Esc` continua funcionando em outros apps.
- [x] Clique de primeira: ao abrir o overlay a janela fica ativa e com o teclado (log `overlay`: "app ficou ativo", janela `chave=1`); o primeiro clique já começa a seleção, sem precisar clicar duas vezes para dar foco.
- [x] `Esc` cancela o overlay: o foco volta ao app que estava ativo antes de abrir (sem precisar clicar nele para continuar usando).
- [x] Deixe o Dock em modo de ocultar automaticamente, ou mude *Reduzir transparência* nas Configurações, com o overlay aberto: nenhum dos dois cancela o overlay nem trava o app.

## Telas, Spaces e tela cheia

- [x] Duas telas: o overlay cobre as duas; a mira acompanha o cursor nas duas direções, em todas as telas.
- [x] Três telas: idem, com a mira e a lupa corretas em cada uma.
- [x] Escalas mistas (Retina e 1x): a imagem congelada de cada tela está nítida 1:1 e a seleção mostra pixels corretos em ambas.
- [x] Uma tela acima ou à esquerda da principal (origem negativa): overlay, mira, seleção e a região capturada ficam na tela certa, sem deslocamento pela origem global.
- [x] A seleção fica presa à tela onde o arrasto começou: arrastar para fora dela para na borda, e a região nunca cruza para outra tela. Soltar o botão fora da tela encerra o arrasto.
- [x] Com um app em tela cheia (Safari, por exemplo), `⌃⌥C` abre o overlay por cima, com teclado funcionando e `Esc` fechando. Com o nível novo (`.popUpMenu`, 101), leve o cursor até a borda de cima: a barra de menus que desce em tela cheia não deve aparecer por cima do overlay. Anote se aparecer.
- [x] Com outro Space ativo, `⌃⌥C` abre o overlay no Space atual, nas telas certas.
- [x] O item do Capta na barra de menus, a janelinha da contagem e o overlay nunca aparecem nas imagens congeladas nem nas capturas ao vivo (região e janela, com e sem atraso). Anote se algum aparecer.

## Seleção de região

- [x] Arraste uma região: ela fica ativa com o contorno, os pixels de fora escurecidos e o rótulo de dimensões em pixels (só largura × altura).
- [x] As dimensões mostradas batem com o PNG salvo, em pixels, em tela Retina e em tela 1x.
- [x] Arraste as bordas e os cantos: a seleção redimensiona.
- [x] Arraste por dentro: a seleção se move sem sair da tela.
- [x] Setas movem a seleção 1 px; `⇧` com setas move 10 px.
- [x] Clique fora da seleção começa outra.
- [x] Região sem atraso, `Enter` confirma: o PNG sai com exatamente o que foi visto. Abra no Preview, ferramenta Mostrar Inspetor, e compare pixel a pixel com a tela (canto superior esquerdo, tamanho exato).
- [x] Repita o item anterior numa tela de escala não inteira (por exemplo, "Mais espaço" ou 1,5×): o retângulo mostrado e o capturado coincidem, sem 1 px de diferença.
- [x] Repita numa tela secundária com origem negativa (acima ou à esquerda da principal): a região capturada é exatamente a selecionada, não a deslocada pela origem.
- [x] Região de 1 px de largura ou altura, junto de uma borda da tela: captura sem erro ou o overlay a recusa de forma clara. Anote o comportamento.

## Lupa, ajuda e modos

- [x] `M` liga e desliga a lupa; ela mostra a coordenada correta do pixel sob o cursor.
- [x] A lupa muda de lado nos quatro cantos da tela (superior esquerdo, superior direito, inferior esquerdo, inferior direito) e nunca sai da tela nem cobre o cursor.
- [x] A lupa a 8× mostra a grade de pixels (8 pt por pixel nativo, ou 16 px físicos em Retina) e o pixel central fica destacado.
- [x] A lupa segue o cursor, não o movimento por setas (desvio aceito da spec; anote se incomodar).
- [x] `H` oculta e mostra o painel de ajuda; a escolha é lembrada na próxima captura e depois de fechar e reabrir o Capta (`pkill -x Capta` e abra de novo).
- [x] `Espaço` alterna entre região e janela, nos dois sentidos, e a dica de modo junto ao cursor some quando há lupa ou seleção.
- [x] O painel de ajuda e a barra de opções não cobrem a seleção no canto inferior esquerdo, e a lupa não esconde o rótulo de dimensões quando o cursor está no canto da seleção. Anote qualquer sobreposição (desvio conhecido).
- [x] Clique no vão entre o painel de ajuda e a barra de opções: não deve começar uma seleção (menor conhecido da `PaineisDoOverlay`). Anote o resultado.

## Modo janela

- [x] O realce segue a janela da frente sob o cursor; com janelas sobrepostas de apps diferentes, a mais à frente é a realçada.
- [x] Clique ou `Enter` captura a janela. Janela com parte coberta por outra sai inteira, sem a janela da frente por cima.
- [x] A imagem da janela não tem sombra e os cantos arredondados saem corretos. Abra o PNG e olhe o conteúdo, não só se a captura funcionou.
- [x] Janela numa tela Retina: o PNG tem a escala certa (largura em pixels igual à largura em pontos vezes 2) e o conteúdo está inteiro.
- [x] Janela numa tela 1x: escala 1, conteúdo inteiro.
- [x] Janela entre duas telas (metade em cada): sai inteira, com a escala da tela de maior interseção, sem faixa vazia nem erro. Se a captura falhar por tamanho inesperado, registre a escala e a posição.
- [x] Janela parcialmente fora da tela: sai inteira ou com o comportamento anotado (efeito de `ignoreGlobalClipSingleWindow`).
- [x] `F` captura a tela inteira da tela sob o cursor, logo ao abrir, sem mexer o mouse; com duas telas, a tela do cursor.
- [x] A lista de janelas não mostra nem captura janelas do próprio Capta, e a ordem da frente para trás está certa.
- [x] Capture a janela de um app que não está em primeiro plano: o Capta se ativa antes de congelar as telas, então anote se a janela sai na imagem com a aparência de ativa ou de inativa (cor da barra de título e dos semáforos).

## Atraso, contagem e cursor

- [x] Barra de opções: o atraso alterna entre os valores oferecidos (sem atraso, 3 s e os demais) e a escolha é lembrada na próxima captura.
- [x] Sem atraso, o controle **Incluir cursor** fica desabilitado e explica o motivo (o cursor só entra com atraso); com atraso, fica habilitado e mostra o valor lembrado.
- [x] Com atraso, a janelinha da contagem aparece no topo da tela certa (inclusive de uma janela numa tela secundária), conta de 1 em 1 s e não aparece na imagem final.
- [x] `Esc` durante a contagem cancela; o clique na contagem também cancela; em ambos não sobra rascunho em `Capturas`.
- [x] `Esc` apertado exatamente quando a contagem termina: o caso comum é a captura ser cancelada (sem rascunho); numa janela de milissegundos a captura ainda pode passar — se acontecer, não é erro, só anote. O app não pode travar nem deixar o `Esc` global preso em nenhum dos dois casos.
- [x] Confirmando com atraso, o foco volta ao app que estava ativo antes de abrir o overlay logo que a contagem começa (sem precisar clicar nele): deve ser possível interagir com ele (por exemplo reabrir um menu) enquanto a contagem corre, sem perder o tempo do atraso clicando de volta nele.
- [x] **Revisão final encontrou, sem tela para confirmar:** depois de devolver o foco (no `Esc` ou ao começar o atraso), a janela do resultado abre ao fim da captura com o Capta de volta ativo e em primeiro plano, mesmo sem clique do usuário. Se a janela abrir atrás do outro app, ou sem foco, anote: a reativação nesse ponto usa uma chamada simples (`NSApp.activate()`), sem o mecanismo de repescagem que o overlay já usa para o mesmo problema.
- [x] **Achado em tela real e corrigido, falta reconfirmar:** com o overlay aberto, trocar para um terceiro app (nem o Capta nem o app que estava ativo antes) deve deixar o foco nesse terceiro app, não no app de antes. Histórico: a revisão final apontou o risco sem tela para confirmar (o overlay, ao cancelar por perda de ativação, também pedia ao app de antes que se reativasse), e o teste em tela real confirmou: com o VS Code à frente ao abrir o overlay, `⌘Tab` até o Bitwarden fechou o overlay certo, mas o VS Code voltou para a frente no lugar do Bitwarden. Correção: o foco só volta ao app de antes quando o próprio Capta sai de cena (`Esc` ou confirmação com atraso); quando o overlay fecha por perda de ativação ou por mudança de telas, o Capta não reativa ninguém. Para reconfirmar, com um app A à frente, abra o overlay, segure `⌘`, aperte `Tab` uma vez (o alternador realça outro app B, que não seja o Capta nem A) e solte o `⌘`: o overlay fecha sem sobrar nada e B fica em primeiro plano, não A. Repita escolhendo B com mais toques de `Tab` ou com as setas. O `Esc` e a confirmação com atraso continuam devolvendo o foco a A (itens acima). Com a contagem correndo, o overlay já fechou e o foco já voltou a A; trocar para B com `⌘Tab` deve deixar B à frente até a janela do resultado abrir. No primeiro teste em tela real esta troca era feita às cegas, porque o HUD do `⌘Tab` não aparecia (ver "Correção tentada" em *Overlay: cobertura e `Esc`*); com o nível novo deve dar para ver e escolher o terceiro app.
- [x] Abra um menu de aplicativo, comece uma região por cima dele com atraso de 3 s e deixe o menu aberto: a imagem final mostra o menu aberto (o menu não fecha ao abrir o overlay se o atraso permitir reabri-lo; anote o fluxo que funcionou).
- [x] Com atraso e **Incluir cursor** ligado, região e janela mostram o cursor na imagem; desligado, não mostram. Sem atraso, nunca mostram.
- [x] Feche a janela capturada durante o atraso: aparece o alerta curto genérico ("Não foi possível capturar a tela.") e não sobra rascunho. Hoje o mesmo texto aparece para qualquer falha da captura ao vivo, sem detalhe por causa (janela ou tela que sumiram); anote se isso incomodar.
- [x] Desconecte o monitor da região durante o atraso: aparece o mesmo alerta curto genérico de falha.
- [x] Minimize a janela, ou mande-a para outro Space, durante o atraso: observe e anote o que acontece (alerta, ou captura de uma janela fora da tela).
- [x] Revogue a permissão de gravação de tela nas Configurações durante o atraso: o fim da contagem leva à ajuda de permissão, e não a uma falha genérica.

## Atalhos e menu

- [x] O menu da barra tem os três itens de captura, nesta ordem: **Capturar região**, **Capturar janela** e **Capturar tela inteira**, seguidos de **Sair do Capta**; os itens de região e tela inteira mostram `⌃⌥C` e `⌃⌥F`. **Capturar janela** abre o overlay já no modo janela (confira e anote).
- [x] `⌃⌥C` e `⌃⌥F` não se confundem: cada um dispara só a sua captura.
- [x] Com o overlay ou a contagem aberta, `⌃⌥C` e `⌃⌥F` (e os itens do menu) são ignorados e não abrem um segundo overlay nem uma segunda captura.
- [x] Com outro app já dono de `⌃⌥C`, abra o Capta: o menu mostra **Atalho ⌃⌥C indisponível** e o item de menu continua abrindo o overlay. (O aviso aparece entre os dois itens de captura, desvio cosmético conhecido.)
- [x] Com outro app dono de `⌃⌥F`, o aviso correspondente aparece e o item de menu continua capturando.
- [x] Nenhum pedido de permissão novo aparece em nenhum momento, em particular Acessibilidade ou Monitoramento de Entrada; só a Gravação de Tela, como antes.
- [x] Listar as janelas (`CGWindowListCopyWindowInfo`) não dispara nenhum alerta de permissão no macOS 27. Anote a versão do sistema.
- [x] `codesign -d --entitlements - build/Capta.app` continua mostrando só `com.apple.security.app-sandbox` e `com.apple.security.files.user-selected.read-write`.

## Acessibilidade e aparência

- [x] Com o VoiceOver ligado, o overlay lê "Seleção de captura. Esc cancela." uma vez só, sem repetir.
- [x] Com o VoiceOver ligado, a contagem é lida a cada tick, sem ler duas vezes (rótulo e anúncio juntos podem duplicar a leitura: anote).
- [x] Reduzir transparência: a máscara escurece mais forte (0,75 de opacidade), mas não fica totalmente opaca, e a tela por baixo ainda é visível; os painéis ficam opacos. Anote o resultado visual. Mude a configuração com o overlay aberto: o desenho só atualiza na próxima abertura (menor conhecido).
- [x] Reduzir movimento: nada anima no overlay nem na contagem (não há animação alguma).
- [x] Claro e escuro: rótulos, painéis, barra de opções, lupa e contagem seguem o tema, sem cor estranha nem texto ilegível.
- [x] A barra de opções responde ao clique de primeira e o clique nela não inicia seleção.

## Desempenho e memória

- [x] Dispare `⌃⌥C` algumas vezes com uma tela e leia no log `captura` a linha "do disparo ao overlay": meta de menos de 500 ms. Anote os valores.
- [x] Repita com três telas e anote os valores (congelar em paralelo).
- [x] A mira acompanha o mouse sem atraso visível numa tela 5K ou com várias telas; se houver lag, o desenho é em CPU e o passo seguinte é uma camada estática.
- [x] Memória do Capta com três telas, no Monitor de Atividade: anote o uso com o overlay aberto e depois de fechar. Depois de fechar, deve cair para perto do valor de antes (as imagens congeladas são liberadas).
- [x] Região sem atraso: leia no log a linha "da seleção à janela: N ms" e anote.

## Janela de captura e resultado

- [x] A captura de região e a de janela abrem a janela de captura como a tela inteira abre: centralizada na tela certa, com copiar e salvar funcionando, e o rascunho gravado em `Capturas`.

## Pendências do Plano 3

**Decidido pelo Pedro em 2026-10-22:** os seis desvios da spec abaixo (Tarefa 10) ficam como estão; o piso de cobertura do app fica em 89 %, apesar da spec §6 dizer "sem subir o piso nesta fatia" (deslize do plano, não atalho). Os menores adiados seguem como trabalho futuro, sem bloquear esta fatia.

Desvios da spec (Tarefa 10):

- [ ] (a) O rótulo de dimensões mostra só largura × altura, sem a posição.
- [ ] (b) *Reduzir transparência* escurece a máscara para 0,75, e não a deixa opaca (opaca esconderia a tela); os painéis são sempre opacos.
- [ ] (c) A dica de modo junto ao cursor some com a lupa ou com uma seleção.
- [ ] (d) A lupa segue o cursor, e não o movimento por setas.
- [ ] (e) A 8× significa 8 pt por pixel nativo (16 px físicos em Retina).
- [ ] (f) Os painéis podem cobrir a seleção no canto inferior esquerdo e a lupa pode sobrepor o rótulo de dimensões.

Menores adiados:

- [ ] Os painéis são atualizados a cada evento em todas as telas (guardar por mudança); *Reduzir transparência* não redesenha ao mudar com o overlay aberto.
- [ ] Uma `Task` já cancelada pisca o overlay (checar `Task.isCancelled` antes de abrir).
- [ ] Tokens de `Tema` duplicados e a posse de `destaqueFundo` invertida (`Tema.Overlay.*`).
- [ ] `JanelaDaContagem`: sem `deinit` que libere o `Esc`; `aoCancelar` com padrão silencioso; rótulo e anúncio podem duplicar a leitura do VoiceOver.
- [ ] Captura de janela fora de toda tela dá `.telaNaoEncontrada` (poderia cair em `desktopIndependentWindow.pointPixelScale`); a conferência de tamanho da janela (quadro × escala) pode ser rígida demais, caso a lista acima mostre divergência de 1 px ou de escala.
- [ ] Região fracionária aceita em `RecorteDeImagem`; conversão de seleção sem tamanho mínimo; teste do meio ponto não distingue `toNearestOrEven` de `floor`.
- [ ] `AtalhoGlobalCarbon`: contador estático com `nonisolated(unsafe)` e trava; o aviso de `⌃⌥C` fica entre os dois itens de captura; chaves do catálogo fora de ordem alfabética.
- [ ] Testes: os de caminho feliz do overlay instalam monitores `NSEvent` reais; faltam testes de NaN e de limites fracionários da seleção; a fiação real do `CaptaApp` está fora da conta de cobertura.
