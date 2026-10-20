# Capta

Aplicativo para macOS que captura a tela e permite anotar a imagem. Código em Swift 6, com o
núcleo num pacote SwiftPM local (`CaptaNucleo`) e o app gerado por XcodeGen.

## Status

Em construção: esqueleto do repositório e do núcleo. Ainda não há app utilizável.

## Verificação

```sh
make verificar
```

Roda o lint (swift-format e SwiftLint) e os testes do núcleo. Para ativar os ganchos do Git:

```sh
git config core.hooksPath ferramentas/hooks
```

Padrões do projeto em `docs/padroes-stack-swift.md`; desenho do MVP em `docs/superpowers/specs/`.

## Licença

MIT. Veja `LICENSE`.
