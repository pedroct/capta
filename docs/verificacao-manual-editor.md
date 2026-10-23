# Verificação manual do editor (Plano 5a)

Lista para o Pedro percorrer com tela real, depois do Plano 5a. Um item por linha; marque `[x]` ao confirmar e anote o que falhar no status do plano (`docs/superpowers/plans/2026-10-22-capta-plano-5a-base-do-editor.md`).

## Preparar

- [ ] Na pasta do worktree, `make app && open build/Capta.app` (exige `project.local.yml`); o app abre sem erro e a captura (`⌃⌥C` ou `⌃⌥F`) abre o editor em vez da janela de resultado.
- [ ] Para o registro: `/usr/bin/log stream --predicate 'subsystem == "com.pedroct.capta"'` em outro terminal.

## Ferramentas de criação (mouse, trackpad e `⇧`)

- [ ] Seta com mouse: arrastar cria a seta; a ferramenta continua ativa depois de criar.
- [ ] Seta com trackpad: arrastar com toque cria a seta.
- [ ] Seta com `⇧`: o ângulo trava em múltiplos de 45°.
- [ ] Linha com mouse e com trackpad: cria a linha.
- [ ] Linha com `⇧`: trava em múltiplos de 45°.
- [ ] Retângulo com mouse e com trackpad: cria o retângulo.
- [ ] Retângulo com `⇧`: vira quadrado.
- [ ] Retângulo arredondado com mouse e com trackpad: cria a forma.
- [ ] Retângulo arredondado com `⇧`: vira quadrado.
- [ ] Elipse com mouse e com trackpad: cria a elipse.
- [ ] Elipse com `⇧`: vira círculo.
- [ ] Menu Forma: clicar escolhe a ferramenta com o último tipo; a seta do menu troca o tipo.
- [ ] Realce com mouse e com trackpad: cria o realce translúcido.
- [ ] Realce com `⇧`: trava na horizontal ou vertical, conforme o comportamento esperado do realce.
- [ ] Criação abaixo da tolerância (clique sem arrastar) é descartada e não deixa objeto nem passo de desfazer.
- [ ] Esc durante a criação cancela a prévia e não deixa objeto.
- [ ] Atalhos de letra `V A L R H` trocam a ferramenta.

## Seleção e edição de objetos

- [ ] Clicar num objeto o seleciona; clicar no vazio limpa a seleção.
- [ ] Mover um objeto arrastando; o objeto não salta ao começar o arraste.
- [ ] Mover com as setas (passo normal) e com `⇧` + setas (passo maior).
- [ ] Redimensionar por cada alça (cantos e bordas) de retângulo, elipse e realce.
- [ ] Redimensionar com `⇧` mantém a proporção.
- [ ] Redimensionar seta e linha pelas pontas.
- [ ] Girar pela alça de giro; com `⇧` o giro trava em passos fixos.
- [ ] Excluir com `Delete` e com `⌫`.
- [ ] Duplicar com `⌘D`: a cópia aparece deslocada e fica selecionada.
- [ ] Seleção por retângulo no vazio pega os objetos tocados.
- [ ] Seleção por retângulo com `⇧` soma à seleção atual.
- [ ] Clicar com `⇧` num objeto soma ou tira da seleção.
- [ ] `⌘A` seleciona todos.
- [ ] Mover, redimensionar, girar e excluir vários objetos de uma vez.
- [ ] Clicar e soltar no vazio sem arrastar limpa a seleção (retângulo de área zero).
- [ ] Acerto de objeto sem preenchimento só no contorno (clicar no meio de um retângulo vazio não seleciona).
- [ ] Acerto com tolerância de tela igual em zoom 25 % e 400 %.

## Desfazer e refazer

- [ ] Um arraste de mover desfaz num passo só; refaz num passo só.
- [ ] Um redimensionar, um girar e uma criação desfazem cada um num passo só.
- [ ] Mover várias selecionadas desfaz num passo só.
- [ ] Excluir e duplicar desfazem e refazem num passo.
- [ ] Um arraste de slider (largura, opacidade) é um passo só.
- [ ] `⌘Z` e `⇧⌘Z` pelo teclado e pelos botões da barra.
- [ ] Depois de desfazer tudo, a captura fica igual à original; refazer tudo volta ao estado final.

## Zoom e rolagem

- [ ] Ao abrir captura grande e pequena, a imagem cabe na janela (modo Ajustar) sem piscar visivelmente.
- [ ] Redimensionar a janela em modo Ajustar refaz o ajuste; depois de zoom manual ou pinça, não.
- [ ] Zoom 25 % e zoom 400 %: desenho, seleção e alças corretos, sem borrão estranho.
- [ ] Pinça no trackpad: limita entre 25 % e 400 %; partindo de zoom abaixo de 25 % (imagem muito grande) não pula.
- [ ] `⌘9` ajusta à janela e `⌘0` volta a 100 %.
- [ ] `⌘+` (e `⌘=`) aumenta e `⌘-` diminui o zoom.
- [ ] Menu de zoom do rodapé escolhe os níveis (a dica do atalho não aparece nos itens; conferir se incomoda).
- [ ] Tela Retina: a imagem fica nítida em 100 % e o traço desenhado bate com o resultado.
- [ ] Tela 1x (ou escala reduzida): mesmo resultado, sem deslocamento de meio pixel.
- [ ] A rolagem não se centraliza no ponto da pinça (não implementado; só registrar se atrapalhar).

## Atalhos nos botões invisíveis e foco

- [ ] `⌘A`, `⌘D`, `⌘9`, `⌘0`, `⌘+` e `⌘-` disparam com o foco no canvas.
- [ ] Os mesmos atalhos disparam com o foco no slider, no menu e nos botões de cor.
- [ ] `⌘Z`, `⇧⌘Z` e `⌘C` funcionam também pela barra.
- [ ] Depois de clicar num slider, numa cor ou num botão, as letras `V A L R H` e as setas ainda chegam ao canvas.
- [ ] As setas e o `Delete` sem objeto selecionado não dão aviso sonoro nem travam o foco.

## Propriedades e memória por ferramenta

- [ ] O painel mostra cor, largura e opacidade da ferramenta ativa e do objeto selecionado.
- [ ] Trocar cor, largura e opacidade com um objeto selecionado altera o objeto (um passo de desfazer).
- [ ] Os sliders só gravam ao soltar (sem prévia ao vivo do objeto durante o arraste); conferir que não incomoda.
- [ ] Ajustar slider por teclado ou VoiceOver grava na hora.
- [ ] A memória de estilo é por ferramenta: mudar a cor da seta não muda a da linha.
- [ ] Fechar e reabrir o app: cada ferramenta volta com o último estilo usado.
- [ ] Tamanho inicial da janela (canvas + painel + barras) e mínimo de 640 x 400.

## Salvar sozinho

- [ ] Editar, esperar cerca de 2 s e abrir o pacote em outro lugar: a edição está gravada.
- [ ] Fechar a janela logo depois de editar: reabrir e conferir que a última edição está lá.
- [ ] `⌘Q` logo depois de uma edição: reabrir e conferir que a edição está lá.
- [ ] `⌘Q` logo depois de uma edição durante a gravação inicial do rascunho (capturar e editar na hora): a edição não se perde.
- [ ] Falha ao gravar o rascunho (pasta sem permissão, por exemplo): aparece o aviso na barra e no rodapé, e nada é perdido.
- [ ] Abrir um pacote v1 gravado antes desta fatia, editar e salvar: o pacote passa a v2 e continua abrindo.

## Capturas recentes (menu da barra)

- [ ] O submenu mostra até 10 capturas, a mais nova primeiro; sem capturas mostra "Nenhuma captura" em cinza.
- [ ] Capturar, esperar o rascunho e abrir o menu: a captura nova aparece (a lista é relida depois do rascunho, a cada salvamento e ao iniciar).
- [ ] Editar, esperar cerca de 2 s e abrir o menu: a ordem muda, com a editada em primeiro.
- [ ] Abrir uma recente: abre o editor com a captura.
- [ ] Abrir a mesma de novo traz a janela para a frente, sem abrir outra (inclusive miniaturizada).
- [ ] Reabrir uma captura pelo menu logo depois de fechá-la: abre com a última edição (corrida estreita: a janela fechada pode ainda estar gravando).
- [ ] Abrir uma recente v1, gravada antes desta fatia.
- [ ] Apagar um pacote pelo Finder com o menu aberto e clicar nele: alerta "Não foi possível abrir a captura." sem travar.
- [ ] Abrir uma recente não muda a ordem por si só (a recência só muda ao salvar).

## Copiar e salvar PNG

- [ ] Copiar com anotações e colar no Preview: as anotações estão na imagem.
- [ ] Salvar PNG com anotações e abrir no Preview: bate com o canvas.
- [ ] Seta, linha, formas e realce girados: o PNG copiado e o salvo batem com o canvas (a rotação é desenhada pelo renderizador).
- [ ] Forma com preenchimento e sem preenchimento, com opacidade menor que 100 %: o PNG bate com o canvas.
- [ ] A captura sem nenhuma anotação continua igual à original.

## Aparência e acessibilidade

- [ ] Tema escuro: barra, painel e rodapé legíveis, só com cores de token.
- [ ] Reduzir transparência ligado: barra, painel e rodapé continuam legíveis.
- [ ] VoiceOver na barra: cada botão tem rótulo; trocar a ferramenta anuncia o nome (a forma anuncia o tipo).
- [ ] VoiceOver nos círculos de cor: o selecionado é anunciado como tal.
- [ ] VoiceOver no painel e no rodapé: valores de largura, opacidade e zoom são lidos.

## Desempenho

- [ ] Abrir uma captura 5K com 30 objetos e 2 desfoques e arrastar um objeto: a fluidez é aceitável a olho.
- [ ] Medir os quadros por segundo com Instruments (Core Animation ou Time Profiler) ou pelo registro; meta de 60 fps, medida sem promessa.
- [ ] Registrar o número medido no status do plano; abaixo de 60 fps, só anotar, sem bloquear.
