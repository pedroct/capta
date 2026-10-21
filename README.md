# Capta

Aplicativo para macOS que captura a tela e permite anotar a imagem. Código em Swift 6, com o
núcleo num pacote SwiftPM local (`CaptaNucleo`) e o app gerado por XcodeGen.

## Status

Em construção: esqueleto do repositório e do núcleo. O app já abre na barra de menus, mas ainda não captura nada.

## Ferramentas

- Xcode: o `Makefile` e `ferramentas/empacotar.sh` preferem `/Applications/Xcode-beta.app` a
  `/Applications/Xcode.app`.
- XcodeGen 2.46.0 (`brew install xcodegen`): gera `Capta.xcodeproj` com `make gerar`.
- `make app` monta `build/Capta.app` assinado; exige `project.local.yml` (copie de
  `project.local.yml.example` e informe o `DEVELOPMENT_TEAM`).

## Verificação

```sh
make verificar
```

Roda o lint (swift-format e SwiftLint), a compilação do app em modo estrito, os testes do núcleo com
o portão de cobertura (`make cobertura`, também disponível sozinho) e os portões de tokens de cor e de
entitlements. Para ativar os ganchos do Git:

```sh
git config core.hooksPath ferramentas/hooks
```

Padrões do projeto em `docs/padroes-stack-swift.md`; desenho do MVP em `docs/superpowers/specs/`.

## Licença

MIT. Veja `LICENSE`.
