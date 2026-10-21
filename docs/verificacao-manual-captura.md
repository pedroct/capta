# Verificação manual da captura de tela inteira

Lista para o Pedro percorrer com tela e permissão reais, depois do Plano 2. Cada linha é uma ação seguida do resultado esperado. Marque `[x]` ao confirmar; o que falhar vira pendência no status do plano.

## Preparar

1. Copie `project.local.yml.example` para `project.local.yml` e preencha o time de assinatura (o arquivo é ignorado pelo Git).
2. Rode `make app`.
3. Abra o app com `open build/Capta.app`.
4. Para ver o log, deixe aberto em outro terminal: `log stream --predicate 'subsystem == "com.pedroct.capta"'` (categoria `captura`; o subsistema é o identificador do bundle, hoje `com.pedroct.capta`).
5. Para repetir os testes de permissão do zero, zere o registro com `tccutil reset ScreenCapture com.pedroct.capta`.

## Permissão de gravação de tela

- [ ] Com a permissão zerada, dispare a captura pela primeira vez: o pedido do sistema aparece uma vez e, depois dele, a janela de ajuda de permissão.
- [ ] Dispare a captura de novo sem conceder: o pedido do sistema não volta; só a ajuda aparece.
- [ ] Negue a permissão no pedido do sistema: a ajuda explica o que fazer e o botão de abrir as Configurações leva ao painel de Gravação de Tela (confira no macOS 27 que abre o painel certo).
- [ ] Conceda a permissão nas Configurações e use **Tentar de novo** na ajuda, sem reiniciar: se o sistema já reconhece a concessão, a captura refaz e a janela de captura abre.
- [ ] Conceda a permissão e, se o sistema exigir reinício, confirme que o botão **Reiniciar o Capta** só aparece depois de uma tentativa que falhou, e que ele abre uma nova instância do app.
- [ ] Com o app aberto e capturando normalmente, revogue a permissão nas Configurações e dispare a captura: o resultado é o mesmo erro de permissão e leva à ajuda (não a uma mensagem de falha genérica). Se aparecer falha genérica, o macOS 27 devolve outro código de erro e isso precisa de correção.

## Captura e imagem

- [ ] Dispare a captura numa tela Retina: o PNG salvo tem largura igual à da tela em pontos vezes 2 (por exemplo, 3024 para uma tela de 1512 pontos).
- [ ] Com duas telas de escalas diferentes, deixe o cursor numa delas e dispare: sai a tela do cursor, com os pixels e a escala daquela tela (uma Retina e uma não Retina).
- [ ] Posicione uma tela acima ou à esquerda da principal e dispare com o cursor nela: sai a tela certa, não a principal (confirma que as coordenadas ficam no espaço global com origem no topo).
- [ ] Deixe uma tela sem nenhuma janela aberta e dispare com o cursor nela: a captura sai dessa tela.
- [ ] A imagem capturada não mostra o cursor do mouse.
- [ ] A janela do Capta que aparece durante a captura (e a de ajuda, se estiver aberta) não entra na imagem.
- [ ] Confira se o item do Capta na barra de menus aparece na imagem capturada e anote o resultado (aparecendo ou não, registre; decidimos depois se é aceitável).

## Atalho e menu

- [ ] Com o Capta em segundo plano, `⌃⌥F` dispara a captura sem pedir permissão de Acessibilidade.
- [ ] O item de captura no menu faz o mesmo que o atalho e mostra o atalho `⌃⌥F` ao lado.
- [ ] Com outro app já usando `⌃⌥F`, abra o Capta: o menu mostra o aviso **Atalho indisponível** e o item de menu continua capturando.

## Janela de captura e resultado

- [ ] A janela de captura abre com tamanho inicial razoável e centralizada; ajustar à janela e tamanho real funcionam.
- [ ] `⌘C` e o botão da barra copiam a imagem; cole em outro app (Preview, Notas, Mensagens) e ela chega com o tamanho certo.
- [ ] Salve como PNG e abra no Preview: o tamanho em pixels bate com o esperado da tela capturada.
- [ ] Salve como Capta: o painel sugere um nome, aceita só o tipo `.capta`, e cancelar não faz nada. Enquanto grava, o botão de salvar fica desabilitado; ao terminar aparece a confirmação.
- [ ] No Finder, o arquivo `.capta` salvo aparece como **um item** (não como pasta) e o sistema reconhece o tipo.
- [ ] Feche a janela sem salvar: a captura não se perde; o pacote fica na pasta `Capturas` do contêiner (`~/Library/Containers/com.pedroct.capta/Data/Library/Application Support/com.pedroct.capta/Capturas`).
- [ ] Ao capturar, a pasta `Capturas` é criada no contêiner na primeira vez e o rascunho é gravado nela.

## Dock e aparência

- [ ] O ícone do Capta aparece no Dock enquanto há janela aberta e some quando todas se fecham.
- [ ] A ajuda de permissão abre uma janela só, mesmo com vários disparos seguidos.
- [ ] Alterne entre aparência clara e escura: as janelas seguem o tema, sem cor estranha.
- [ ] Ligue **Reduzir transparência** nas Configurações de Acessibilidade: o fundo do painel fica opaco.
- [ ] Com o VoiceOver ligado, a barra, os botões e a ajuda são lidos com rótulos compreensíveis.

## Desempenho

- [ ] Dispare a captura algumas vezes e leia no log a linha "do disparo à janela: N ms". Meta: menos de 500 ms numa tela Retina. É uma medição, não uma promessa; anote os valores encontrados.

## Pendências do Plano 1

- [ ] Tarefa 2, passo 8: com `build/Capta.app` aberto, o ícone aparece na barra de menus e o menu tem o item **Sair do Capta**, que encerra o app.
- [ ] Tarefa 2, passo 8: `codesign -d --entitlements - build/Capta.app` mostra só `com.apple.security.app-sandbox` e `com.apple.security.files.user-selected.read-write`.
