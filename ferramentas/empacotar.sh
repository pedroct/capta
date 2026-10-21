#!/bin/sh
# Compila em Release, assina com Apple Development e copia o app para build/Capta.app.
# O ID do time vem de project.local.yml (fora do Git); sem ele, falha com mensagem clara.
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
cd "$raiz"

# Fora do make, usa o mesmo Xcode do Makefile.
if [ -z "${DEVELOPER_DIR:-}" ]; then
  for xcode in /Applications/Xcode-beta.app /Applications/Xcode.app; do
    if [ -d "$xcode" ]; then
      DEVELOPER_DIR="$xcode/Contents/Developer"
      export DEVELOPER_DIR
      break
    fi
  done
fi

if [ ! -f project.local.yml ]; then
  echo "empacotar: project.local.yml não existe." >&2
  echo "Copie project.local.yml.example para project.local.yml e informe seu DEVELOPMENT_TEAM." >&2
  exit 1
fi

time=$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM:[[:space:]]*\([A-Za-z0-9_]*\).*$/\1/p' project.local.yml | head -n 1)
if [ -z "$time" ] || [ "$time" = "SEU_TIME_AQUI" ]; then
  echo "empacotar: DEVELOPMENT_TEAM ausente ou ainda com o valor de exemplo em project.local.yml." >&2
  exit 1
fi

rm -rf build/DerivedData build/Capta.app
xcodebuild \
  -scheme Capta \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  DEVELOPMENT_TEAM="$time" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" \
  build | xcbeautify

origem=build/DerivedData/Build/Products/Release/Capta.app
if [ ! -d "$origem" ]; then
  echo "empacotar: build não gerou $origem" >&2
  exit 1
fi
cp -R "$origem" build/Capta.app
echo "empacotar: build/Capta.app pronto"
