#!/bin/sh
# Portão dos tokens de cor (docs/design-system/tokens.json é a fonte da verdade):
#  1. nenhuma cor crua nos .swift de App/Fontes (exceto Tema.swift);
#  2. cores anotacao-* idênticas no catálogo, nos dois temas;
#  3. superficie-canvas e borda-controle idênticas ao catálogo;
#  4. nenhuma cor marca-* fora de AppIcon.appiconset.
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
cd "$raiz"
exec python3 -I - "$raiz" <<'PY'
import json
import re
import sys
from pathlib import Path

raiz = Path(sys.argv[1])
fontes = raiz / "App" / "Fontes"
catalogo = raiz / "App" / "Recursos" / "Assets.xcassets"
tokens = json.loads((raiz / "docs/design-system/tokens.json").read_text())["color"]["tokens"]
erros = []

# 1. Cor crua na interface.
PROIBIDOS = [
    (re.compile(r"\bColor\.red\b"), "Color.red"),
    (re.compile(r"\bColor\(\s*red:"), "Color(red:"),
    (re.compile(r"\.foregroundColor\(\s*\."), ".foregroundColor(.)"),
    (re.compile(r"\bColor\(\s*hex"), "Color(hex"),
    (re.compile(r"\.secondary\b"), ".secondary"),
    (re.compile(r"#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?\b"), "literal #hex"),
]
for arquivo in sorted(fontes.rglob("*.swift")):
    if arquivo.name == "Tema.swift":
        continue
    for numero, linha in enumerate(arquivo.read_text().splitlines(), 1):
        for padrao, nome in PROIBIDOS:
            if padrao.search(linha):
                erros.append(f"{arquivo.relative_to(raiz)}:{numero}: cor crua ({nome})")


# 2 e 3. Catálogo x tokens.
def bytes_do_hex(valor):
    h = valor.lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) for i in (0, 2, 4))
    a = int(h[6:8], 16) if len(h) == 8 else 255
    return (r, g, b, a)


def componente(texto):
    texto = str(texto).strip()
    return int(texto, 16) if texto.lower().startswith("0x") else round(float(texto) * 255)


def bytes_do_colorset(caminho):
    """Devolve {'light': (r,g,b,a), 'dark': (...)}; 'dark' cai em 'light' se ausente."""
    dados = json.loads((caminho / "Contents.json").read_text())
    achado = {}
    for item in dados.get("colors", []):
        escuro = any(
            a.get("appearance") == "luminosity" and a.get("value") == "dark"
            for a in item.get("appearances", [])
        )
        c = item["color"]["components"]
        achado["dark" if escuro else "light"] = (
            componente(c["red"]),
            componente(c["green"]),
            componente(c["blue"]),
            round(float(c["alpha"]) * 255),
        )
    if "light" in achado:
        achado.setdefault("dark", achado["light"])
    return achado


def nome_do_colorset(token, prefixo=""):
    return prefixo + "".join(p.capitalize() for p in token.split("-"))


def hex_de(t):
    return "#%02x%02x%02x%02x" % t


for token in tokens:
    nome = token["name"]
    if nome.startswith("anotacao-") or nome in ("superficie-canvas", "borda-controle"):
        colorset = catalogo / (nome_do_colorset(nome) + ".colorset")
        if not colorset.is_dir():
            erros.append(f"token {nome}: faltando {colorset.relative_to(raiz)}")
            continue
        achado = bytes_do_colorset(colorset)
        for tema in ("light", "dark"):
            esperado = bytes_do_hex(token["value"][tema])
            if achado.get(tema) != esperado:
                obtido = hex_de(achado[tema]) if tema in achado else "ausente"
                erros.append(
                    f"token {nome} ({tema}): catálogo tem {obtido}, "
                    f"tokens.json tem {token['value'][tema]}"
                )

# 4. Cores da marca só no ícone do app.
marcas = [t for t in tokens if t["name"].startswith("marca-")]
nomes_marca = [t["name"] for t in marcas]
hex_marca = {bytes_do_hex(t["value"][tema])[:3] for t in marcas for tema in ("light", "dark")}
procurar = [raiz / "App" / "Info.plist", *sorted(fontes.rglob("*.swift"))]
for arquivo in procurar:
    if arquivo.is_file():
        texto = arquivo.read_text()
        for nome in nomes_marca:
            if nome in texto or nome_do_colorset(nome) in texto:
                erros.append(f"{arquivo.relative_to(raiz)}: menciona cor da marca {nome}")
for colorset in sorted(catalogo.rglob("*.colorset")):
    if "AppIcon.appiconset" in colorset.parts:
        continue
    if colorset.name.startswith("Marca"):
        erros.append(f"{colorset.relative_to(raiz)}: cor da marca fora do AppIcon")
    for tema, rgba in bytes_do_colorset(colorset).items():
        if rgba[:3] in hex_marca:
            erros.append(
                f"{colorset.relative_to(raiz)} ({tema}): valor {hex_de(rgba)} é de uma cor marca-*"
            )

for erro in erros:
    print(f"tokens: {erro}", file=sys.stderr)
if erros:
    sys.exit(1)
print("tokens: ok")
PY
