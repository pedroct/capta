# Esquema do arquivo `.capta`, versão 2

Referência do JSON do documento (`Documento`) gravado dentro do pacote `.capta`. O JSON é codificado com `.sortedKeys` e `.prettyPrinted`. O teste `EsquemaV2Tests` guarda o JSON completo de um documento com um objeto de cada tipo e falha se o formato mudar.

## Migração

- v1 → v2: só a versão. Nenhum campo muda nesta versão. Ao decodificar um documento com `versaoEsquema` 1, `Migracao.migrar` o leva para 2 antes de `validar()`; ao gravar de novo, o arquivo sai como v2. `Esquema.versaoMinimaLegivel` é 1: versão menor que isso é recusada (`valorForaDeFaixa("versaoEsquema")`); versão maior que a atual vira `ErroPacote.versaoMaisNova`.

## Regra de congelamento

A v2 muda no lugar até o fim do Plano 5c; quem acrescenta campo atualiza `jsonEsquemaV2DeReferencia` no mesmo commit. Depois disso ela congela: mudança incompatível sobe `Esquema.versaoAtual` para 3, com migração e teste.

## Convenções

- Coordenadas em pixels da imagem base, origem no canto superior esquerdo, Y para baixo.
- Números são `Double` (exceto `versaoEsquema`, `proximaOrdem` e `ordem`, que são inteiros).
- Rotação em radianos, em torno do centro do retângulo da geometria.
- Ponto: `{"x", "y"}`. Tamanho: `{"largura", "altura"}`. Retângulo: `{"x", "y", "largura", "altura"}`; largura e altura podem ser negativas (retângulo invertido) e quem consome padroniza.
- Cor: `{"r", "g", "b", "a"}`, cada componente de 0 a 1.

## Documento

| Chave | Tipo | Obrigatória | Observação |
| --- | --- | --- | --- |
| `versaoEsquema` | inteiro | sim | Igual a `Esquema.versaoAtual` (2). |
| `tamanhoBase` | tamanho | sim | Largura e altura finitas e maiores que zero. |
| `escala` | número | sim | Finita e maior que zero. |
| `recorte` | retângulo | não | Ausente significa sem recorte. Largura e altura positivas, dentro de `tamanhoBase`. |
| `objetos` | lista de anotações | sim | Ordem da lista = ordem das camadas; o último fica por cima. |
| `proximaOrdem` | inteiro | não | Próxima ordem de criação a atribuir; nunca diminui. Ausente: ver padrões. |

## Anotação

| Chave | Tipo | Obrigatória | Observação |
| --- | --- | --- | --- |
| `id` | UUID (texto) | sim | Único no documento. |
| `geometria` | objeto | sim | Ver a seção Geometria. |
| `estilo` | objeto | sim | Ver a seção Estilo. |
| `rotacao` | número | não | Radianos; padrão 0. |
| `ordem` | inteiro | não | Posição na ordem de criação, base da numeração das etapas. |

## Estilo

| Chave | Tipo | Obrigatória | Observação |
| --- | --- | --- | --- |
| `cor` | cor | sim | Cor do traço. |
| `largura` | número | sim | Espessura do traço em pixels, maior ou igual a 0. |
| `opacidade` | número | sim | De 0 a 1. |
| `preenchimento` | cor | não | Ausente significa sem preenchimento. |
| `tracejado` | booleano | sim | |
| `ponta` | texto | não | `triangulo` (padrão), `aberta` ou `nenhuma`. Só afeta setas. |
| `familiaFonte` | texto | não | Ausente usa a fonte padrão. Quando presente, não pode ser vazia nem só espaços. |
| `alinhamento` | texto | não | `esquerda` (padrão), `centro` ou `direita`. Só afeta texto. |
| `rotulo` | texto | não | `numerico` (padrão) ou `alfabetico`. Só afeta etapas. |

## Geometria

Todo objeto de geometria tem a chave `tipo`, que escolhe as demais chaves. Todas as chaves abaixo são obrigatórias.

| `tipo` | Chaves |
| --- | --- |
| `seta` | `inicio` (ponto), `fim` (ponto) |
| `linha` | `inicio` (ponto), `fim` (ponto) |
| `forma` | `forma` (`retangulo`, `retanguloArredondado` ou `elipse`), `retangulo` |
| `texto` | `retangulo`, `conteudo` (texto), `tamanhoFonte` (número), `negrito` (booleano), `italico` (booleano) |
| `etapa` | `centro` (ponto), `diametro` (número), `reiniciaSequencia` (booleano) |
| `carimbo` | `retangulo`, `simbolo` (texto, nome do símbolo) |
| `realce` | `retangulo` |
| `desfoque` | `retangulo`, `tipoDesfoque` (`borrar` ou `pixelizar`), `intensidade` (número) |

Tipo desconhecido ou chave obrigatória ausente faz a decodificação lançar `DecodingError`.

## Padrões dos campos ausentes

| Campo ausente | Valor assumido |
| --- | --- |
| `rotacao` | 0 |
| `ordem` | 0 (mas ver `proximaOrdem`) |
| `ponta` | `triangulo` |
| `alinhamento` | `esquerda` |
| `rotulo` | `numerico` |
| `familiaFonte` | nenhuma (fonte padrão) |
| `preenchimento` | nenhum |
| `recorte` | nenhum |
| `proximaOrdem` | Arquivo anterior à ordem de criação: cada anotação recebe como `ordem` o seu índice na lista e `proximaOrdem` vira o número de objetos. |

Ao gravar, `familiaFonte`, `preenchimento` e `recorte` nulos não aparecem no JSON; os demais campos são sempre gravados.

## Regras de validação

`Documento.validar()` roda em toda edição, no decode e antes de gravar ou renderizar. Falha com `ErroDocumento`.

- `versaoEsquema` igual à versão atual.
- `tamanhoBase`, `escala` e todos os números da geometria, do estilo e da rotação finitos (`valorNaoFinito`).
- `tamanhoBase` e `escala` maiores que zero (`tamanhoInvalido`).
- `recorte` com largura e altura positivas e contido em `tamanhoBase` (`recorteInvalido`).
- `id` único entre as anotações (`idDuplicado`).
- `proximaOrdem` maior ou igual a 0 e menor que `Int.max`; cada `ordem` maior ou igual a 0, menor que `proximaOrdem` e única entre as anotações (`valorForaDeFaixa("ordem")`).
- `largura` do estilo maior ou igual a 0; `opacidade` de 0 a 1; componentes das cores de 0 a 1.
- `rotacao` diferente de zero é proibida em `seta`, `linha` e `desfoque` (`valorForaDeFaixa("rotacao")`); vale em `forma`, `texto`, `carimbo`, `realce` e `etapa`.
- `familiaFonte`, quando presente, não pode ser vazia nem só espaços (`valorForaDeFaixa("familiaFonte")`).
