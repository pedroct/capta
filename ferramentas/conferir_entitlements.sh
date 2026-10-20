#!/bin/sh
# Portão dos entitlements: sandbox ligado, sem rede e só chaves da lista permitida.
# Adicionar uma chave nova exige decisão registrada em docs/ e atualização desta lista.
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
arquivo="${1:-$raiz/App/Capta.entitlements}"

if [ ! -f "$arquivo" ]; then
  echo "entitlements: arquivo não encontrado: $arquivo" >&2
  exit 1
fi

if ! json=$(plutil -convert json -o - "$arquivo" 2>&1); then
  echo "entitlements: plist inválido em $arquivo: $json" >&2
  exit 1
fi

printf '%s' "$json" | python3 -I -c '
import json, sys

PERMITIDAS = {
    "com.apple.security.app-sandbox",
    "com.apple.security.files.user-selected.read-write",
}
dados = json.load(sys.stdin)
erros = []
if dados.get("com.apple.security.app-sandbox") is not True:
    erros.append("com.apple.security.app-sandbox deve ser true")
if "com.apple.security.network.client" in dados:
    erros.append("com.apple.security.network.client não é permitido (o app não usa rede)")
for chave in sorted(set(dados) - PERMITIDAS):
    if chave != "com.apple.security.network.client":
        erros.append(f"chave fora da lista permitida: {chave}")
for erro in erros:
    print(f"entitlements: {erro}", file=sys.stderr)
sys.exit(1 if erros else 0)
'
echo "entitlements: ok"
