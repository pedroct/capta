Camada que cobre cada tela durante a captura de região ou janela: imagem congelada, máscara, mira, retângulo de seleção, chip de dimensões e painel de ajuda das teclas.

Quem usa fornece a imagem congelada de cada tela, a região atual em pixels e as teclas ativas.

- A máscara escurece o que está fora da seleção com `opacidade-mascara`.
- O retângulo de seleção é tracejado de 2 px em `destaque`, a cor do sistema da pessoa.
- A mira usa branco a 70 % para ser vista sobre qualquer imagem.
- O chip de dimensões e o painel de ajuda usam `superficie-janela` com `raio-chip` e `raio-cartao`; as medidas ficam em `dimensao`, com números tabulares.
- O painel de ajuda é ocultável com a tecla H e nunca cobre a seleção.
- Esc cancela a qualquer momento. Não use as cores da marca no overlay.
