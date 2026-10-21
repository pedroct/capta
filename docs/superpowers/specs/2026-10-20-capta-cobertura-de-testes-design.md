# Capta — Design da cobertura de testes

Spec complementar à `2026-10-20-capta-mvp-design.md` (§7, Qualidade e testes). Não muda o produto; muda como o projeto mede e protege a própria qualidade.

## 1. Intenção e motivo

O Pedro adota, como padrão pessoal, manter a maior cobertura de testes possível em todo projeto. Hoje o Capta não a mede: a CI roda `make test` sem relatório e sem limite, e `App/Fontes` (0 %) nem entra em qualquer contagem. A spec faz a cobertura virar um número visível, com piso que a CI cobra.

Há um segundo motivo: o Pedro quer, um dia, rodar o SonarQube neste projeto, o que hoje não é possível. O trabalho deve deixar o relatório de cobertura num formato que o Sonar importe sem retrabalho, sem instalar, configurar nem depender de servidor Sonar.

## 2. Objetivos, não objetivos e anti-objetivos

**Objetivos**

- `make cobertura` gera o relatório de cobertura e imprime o resumo por arquivo e o total.
- `make verificar` e a CI falham se a cobertura de linhas ficar abaixo do piso.
- O núcleo (`CaptaNucleo`) e `CaptaSistema` chegam a **no mínimo 98 % de linhas**.
- `App/Fontes` passa a ser medido, com piso próprio.
- O relatório sai também no formato XML genérico de cobertura do SonarQube (`sonar-generic-coverage`), gerado a partir do `xccov`/`llvm-cov`, para um uso futuro.
- Os pisos ficam num único arquivo versionado, fácil de subir.

**Não objetivos**

- Instalar, configurar ou rodar o SonarQube/SonarCloud; criar `sonar-project.properties` com servidor ou token.
- Medir cobertura de ramos como critério de aprovação (só reportar; ver §4).
- Testes de interface (XCUITest) ou testes que dependam de tela real e permissão. Isso segue na lista de verificação manual da spec do MVP.
- Mudar comportamento do produto, salvo o que um teste novo revelar como bug (ver §6).

**Anti-objetivos (seria falha mesmo que o número batesse)**

- Testes que executam o código sem verificar nada, só para subir a porcentagem. Cada teste novo afirma um comportamento observável.
- Código de produção alterado só para ser testável de forma artificial (por exemplo, expor `internal` sem motivo ou criar ramos mortos).
- Exclusões de arquivo que escondam código real para o número parecer melhor.
- Enfraquecer as regras do projeto para testar: sem `!`, `try!` ou IUO em código de produção; Swift Testing; TDD.

## 3. Restrições

- Swift 6 em modo estrito com aviso como erro; macOS 14+; sem dependências de terceiros no app ou no pacote. Ferramentas de medição devem vir do Xcode (`xcrun llvm-cov`, `xccov`) ou de scripts do repositório.
- Comandos sempre pelo `make` (o Makefile define o `DEVELOPER_DIR`; `swift test` puro falha).
- Instalar software exige confirmação do Pedro. A solução não deve exigir instalação além do que já existe (Xcode, XcodeGen, SwiftLint, xcbeautify).
- Idioma: pt-BR em domínio, comentários, docs e commits; Conventional Commits; autoria conforme `CLAUDE.md`.
- A CI roda em `macos-26`; o que mudar nela precisa funcionar lá e localmente.

## 4. O que foi decidido

| Tema | Decisão | Origem |
|---|---|---|
| Piso do núcleo e de `CaptaSistema` | **98 % de linhas** | Pedro |
| Escopo da meta | Núcleo e `CaptaSistema` com o mesmo peso e piso alto; `App/Fontes` entra na medição com **piso próprio e menor** | Pedro confirmou a intenção; o recorte de `App/Fontes` é palpite do assistente |
| Piso de `App/Fontes` | Valor medido no dia em que o gate entrar, arredondado para baixo, e só sobe depois | Minha decisão |
| Exclusões | `CaptaApp.swift` (ponto de entrada, sem lógica) fica fora do cálculo. `Tema.swift` tem lógica e entra | Minha decisão |
| Métrica do gate | Cobertura de **linhas**. Regiões e ramos são reportados no resumo, sem barrar | Minha decisão |
| Sonar | Só o relatório em formato genérico; nenhuma integração | Pedro |
| Onde ficam os pisos | Um arquivo versionado (por exemplo `ferramentas/cobertura.toml` ou variáveis no script), lido pelo `make` e pela CI | Minha decisão |

## 5. Comportamento esperado

1. `make cobertura` roda os testes do pacote com cobertura ligada, e os do app se existirem (ver §7), consolida e imprime uma tabela (arquivo, linhas cobertas/total, %), mais o total por alvo (`CaptaNucleo`, `CaptaSistema`, `App`).
2. Grava os artefatos em `build/cobertura/` (ignorado pelo Git): o relatório de texto, o JSON bruto do llvm-cov e o XML genérico do Sonar.
3. Compara cada alvo com seu piso. Abaixo do piso: sai com código diferente de zero e diz qual alvo, qual valor e qual piso. Mensagem em pt-BR.
4. `make verificar` inclui o gate de cobertura. Para não rodar a suíte duas vezes, `make test` e a medição devem compartilhar a execução (por exemplo, `make verificar` chama `cobertura` no lugar de `test`, mantendo `make test` rápido e sem medição).
5. A CI publica o resumo no resumo do job (`$GITHUB_STEP_SUMMARY`) e anexa o XML do Sonar como artefato do job. Falha se algum piso for violado.
6. Subir o piso é uma edição de uma linha no arquivo de pisos, num commit próprio (`chore` ou `test`).

## 6. Testes a escrever

Linha de base medida em 2026-10-20: núcleo 96,5 % de linhas e 89,1 % de regiões. Os arquivos abaixo do piso de 98 %, e o que falta neles:

| Arquivo | Linhas | Regiões | Observação |
|---|---|---|---|
| `Edicao` | 87 % | — | caminhos de erro e casos de borda das edições |
| `Utilitarios` | 87,5 % | 66,7 % | ramos de geometria e conversão não exercitados |
| `DesenhoTexto` | — | 77,8 % | texto vazio, não cabe, alinhamentos |
| `ProvedorDeSimbolosSF` | — | 60 % | símbolo inexistente, tamanho inválido, cores |
| `App/Fontes` | 0 % | 0 % | fora de qualquer medição |

Regras:

- **TDD:** cada teste novo nasce para afirmar um comportamento. Se um teste novo revelar bug, o bug é corrigido num commit `fix` com o teste que falhava antes; não fica escondido.
- **Código inalcançável:** se um ramo realmente não pode ser exercitado (por exemplo, falha de API do sistema que não se provoca), o caminho preferido é simplificar o código para o ramo deixar de existir. Só em último caso se aceita ficar fora dos 98 %, e o motivo vai em comentário no código.
- Os testes de imagem seguem o padrão existente (`Apoio/Pixels.swift`) e não dependem de arquivos binários grandes no Git.

## 7. Medindo `App/Fontes`

`App/Fontes` está fora do pacote SwiftPM, e o app hoje não tem alvo de testes. Para medi-lo é preciso um alvo de testes no `project.yml` (XcodeGen) rodado por `xcodebuild test`, que também gera cobertura. Isso é o caminho esperado; o construtor decide os detalhes. Condições:

- O alvo de testes do app roda sem assinatura (`CODE_SIGNING_ALLOWED=NO`), como o build de verificação, e funciona sem `project.local.yml`.
- Código de interface sem lógica pode ficar com cobertura baixa; o piso do app reflete isso. Lógica que mora em `App/Fontes` e seja testável (como `Tema`) é testada.
- Se medir o app se mostrar inviável ou frágil na CI, o fallback aceito é medir só o pacote, deixar o app fora do gate e registrar isso aqui e em `docs/padroes-stack-swift.md`. Essa decisão não pode ser silenciosa.

## 8. Critérios de aceite

- `make cobertura` roda localmente, imprime a tabela e gera os três artefatos em `build/cobertura/`.
- Em `CaptaNucleo` e `CaptaSistema`, linhas ≥ 98 % em cada alvo; o gate falha de verdade quando se reduz o teste de propósito (conferir uma vez, manualmente, e descrever no commit).
- `App/Fontes` aparece na tabela com piso próprio (ou, se for o caso do fallback do §7, o fallback está documentado).
- `make verificar` e a CI passam, a CI mostra o resumo e guarda o XML.
- O XML gerado é válido para o formato `sonar-generic-coverage` (conferido contra o esquema documentado do Sonar; sem rodar o Sonar).
- `CLAUDE.md` e `docs/padroes-stack-swift.md` mencionam `make cobertura`, os pisos e o arquivo onde eles vivem.

## 9. Deixado para o construtor

Formato do arquivo de pisos · linguagem do script de consolidação (shell, ou Swift em `ferramentas/`, seguindo o que já existe) · estrutura do alvo de testes do app · quais casos de borda testar em cada arquivo, desde que o piso seja atingido com asserções reais · apresentação da tabela.

## 9.1 Chamadas do assistente após a revisão **[minha decisão, todas]**

- **Piso por alvo, não por arquivo.** O gate compara o total de cada alvo (`CaptaNucleo`, `CaptaSistema`, `App`) com o piso. A tabela mostra cada arquivo, e os que ficarem abaixo de 98 % aparecem sinalizados, sem barrar. A lista da §6 é onde procurar primeiro, não um piso por arquivo.
- **`CaptaSistema` hoje só tem `ProvedorDeSimbolosSF`** (símbolos do SF Symbols, sem permissão nem tela real), então 98 % é alcançável. Adaptadores futuros de ScreenCaptureKit e Vision terão de ser testados contra os protocolos do núcleo; se algum não puder chegar a 98 %, a spec daquele plano ajusta o piso do alvo de forma explícita.
- **Onde o app é medido.** `make verificar` local mede só o pacote (rápido, sem XcodeGen). A cobertura do app roda no job `app` da CI e, localmente, por `make cobertura-app`, que não entra no `make verificar`. O XML do Sonar leva os dois, com caminhos relativos à raiz do repositório (`Packages/CaptaNucleo/Sources/...`, `App/Fontes/...`).
- **Piso do app muito baixo é aceitável** se for o valor honesto. A lógica testável de `App/Fontes` (`Tema`) é testada; não se reorganiza código só para subir o número.
- **Piso medido na CI.** Os pisos valem para a CI (`macos-26`). Se o valor local divergir (versão de macOS ou do renderizador de símbolos), vale o menor dos dois, e a divergência vai registrada no arquivo de pisos.

## 10. Decisões que continuam com o Pedro

Nenhuma bloqueia a execução. Quando o SonarQube puder rodar: onde hospedar, e se o gate dele substitui ou complementa o piso local.

## 11. Riscos

- **Toolchain beta:** o formato do perfil de cobertura (`.profdata`/`xccov`) pode mudar entre betas do Xcode; os scripts devem falhar com mensagem clara, não medir errado.
- **Cobertura do app na CI** pode exigir `xcodebuild test` mais lento; o job `app` já tem 45 min.
- **Piso rígido demais** pode empurrar para testes artificiais; por isso o anti-objetivo da §2 e a preferência por simplificar código em vez de forçar teste (§6).
