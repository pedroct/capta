O Capta captura a tela e anota a imagem no macOS. É gratuito, sem conta, sem rede e sem telemetria. Este sistema define a marca e a interface; o app é escrito em Swift (SwiftUI com AppKit) e cada token daqui vira um valor de `Tema.swift`.

## Fundamentos de conteúdo

- Escreva em pt-BR, direto, com verbo no infinitivo para ação: "Capturar", "Copiar", "Cancelar". Nunca "Clique aqui para…".
- Confirme em uma palavra, sem exclamação: "Copiado.", "Pronto.", "Salvo.".
- Erro diz o que aconteceu e como resolver: "O Capta não pode ver a tela. Abra Ajustes do Sistema › Privacidade › Gravação de Tela e ative o Capta."
- Use "tela", "região", "janela", "captura" e "anotação". Evite "screenshot", "snap" e "print" na interface.
- Sem emoji, sem humor forçado, sem "Ops!". O tom é o de um colega calmo: curto e preciso.
- Todo texto de tela vem do String Catalog; nenhuma frase fica escrita direto na `View`.

## Fundamentos visuais

**Cor da interface.** Superfícies e texto acompanham o macOS, claro e escuro. Use `superficie-janela` para janelas, `superficie-painel` para barras e painéis de vidro, `superficie-canvas` para a área de edição (sempre opaca e neutra) e `texto`/`texto-secundario` para texto. O destaque da interface (`destaque`, `destaque-fundo`, `anel-foco`) é a cor que a pessoa escolhe nos Ajustes do Sistema; os valores do token são só o padrão azul. Nenhum controle usa as cores da marca.

**Cor da marca.** `marca-verde-agua`, `marca-ardosia` e `marca-foco` aparecem no ícone do app, no logotipo, no README e nos materiais de divulgação. `marca-foco` só pinta o ponto do símbolo. `marca-verde-agua` não serve de texto: sobre branco ela chega a 2,4:1.

**Cor do conteúdo.** As oito `anotacao-*` e `anotacao-realce` pertencem à imagem e são iguais nos dois temas. Seta, linha, forma e etapa começam em `anotacao-vermelho`; o realce em `anotacao-realce`; o texto em `anotacao-preto` sobre `anotacao-branco`.

**Vidro.** Barras, painéis e popovers usam `superficie-painel` sobre `superficie-janela`, com `raio-painel` e `sombra-painel`. Com "Reduzir transparência" ligado, todo vidro vira superfície sólida. A imagem capturada nunca fica sobre vidro.

**Tipografia.** A interface usa a fonte do sistema: `titulo-janela` (17), `cabecalho-painel` (13 semibold), `corpo` (13), `apoio` (11), `rotulo-secao` (10 em maiúsculas) e `dimensao` (SF Mono, números tabulares) para medidas. A família `marca` (Outfit) só existe no logotipo e em materiais fora do app.

**Espaço e raios.** Grade de 4 pt: `espaco-1` a `espaco-8`. Use `raio-controle` em botões, `raio-cartao` na biblioteca, `raio-painel` em painéis e `raio-chip` em pílulas. Raios aninhados são concêntricos: o interno é o externo menos o espaçamento.

**Estados.** Ferramenta ativa = `destaque-fundo` com ícone em `destaque` (forma e peso mudam, não só a cor). Desabilitado = 35 % de opacidade. Foco de teclado = `anel-foco` de 2 px, sempre visível.

**Acessibilidade.** Texto em 4,5:1 contra o fundo que o token nomeia, nos dois temas; contornos de controle em 3:1 (`borda-controle`). "Aumentar contraste" reforça as bordas; "Reduzir movimento" remove transições. Todo controle tem rótulo em pt-BR e atalho para a ação principal.

## Iconografia

- Ícones de interface são símbolos do sistema (SF Symbols), na cor `texto-secundario` e, quando ativos, `destaque`.
- O ícone do menu na barra de menus é monocromático (modelo, preto), como o macOS exige: `assets/Marca/capta-simbolo-barra-de-menus.svg`.
- Carimbos do editor são símbolos do sistema escolhidos e recoloridos pela pessoa.

## Uso da marca

- O símbolo é um **C feito de moldura de seleção**, com um ponto sólido no vão: o momento capturado. Use `capta-simbolo.svg` sobre fundo claro e `capta-simbolo-claro.svg` sobre `marca-ardosia` ou fundos escuros.
- O ícone do app é `capta-icone-app.svg`: quadrado arredondado em degradê de `marca-ardosia` para `marca-verde-agua`, com o C branco e o ponto em `marca-foco`.
- O logotipo é "capta" em minúsculas, estilo `wordmark`, em `marca-ardosia` (ou `texto` no tema escuro). Deixe livre ao redor uma margem igual à altura do "c".
- Tamanho mínimo do símbolo: 16 px. Não gire, não estique, não troque as cores, não ponha o símbolo sobre imagem sem contraste e não use `marca-foco` fora do ponto.
- Nada visual do Snagit é reaproveitado: nem ícones, nem imagens, nem proporções de logotipo.
