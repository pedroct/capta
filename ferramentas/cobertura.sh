#!/bin/bash
# Portão de cobertura: roda os testes do pacote com cobertura, resume por arquivo e por alvo
# e falha se a cobertura de linhas de um alvo ficar abaixo do piso em cobertura.pisos.
# PISOS=<arquivo> sobrescreve o arquivo de pisos (usado para conferir o próprio portão).
set -eu -o pipefail

raiz=$(cd "$(dirname "$0")/.." && pwd)
pisos="${PISOS:-$raiz/ferramentas/cobertura.pisos}"
saida="$raiz/build/cobertura"
pacote="$raiz/Packages/CaptaNucleo"

if [ ! -f "$pisos" ]; then
  echo "cobertura: arquivo de pisos não encontrado: $pisos" >&2
  exit 1
fi

mkdir -p "$saida"
rm -f "$saida/resumo.txt" "$saida/llvm-cov.json" "$saida"/bruto-*.json

cd "$pacote"
swift test --enable-code-coverage >&2

bin=$(swift build --show-bin-path)
perfil="$bin/codecov/default.profdata"
if [ ! -s "$perfil" ]; then
  echo "cobertura: sem perfil de cobertura em $perfil" >&2
  exit 1
fi

for alvo in CaptaNucleo CaptaSistema; do
  binario="$bin/${alvo}Tests.xctest/Contents/MacOS/${alvo}Tests"
  if [ ! -f "$binario" ]; then
    echo "cobertura: binário de testes não encontrado: $binario" >&2
    exit 1
  fi
  xcrun llvm-cov export -instr-profile="$perfil" "$binario" \
    -ignore-filename-regex='/Tests/|\.build/' >"$saida/bruto-$alvo.json"
done

python3 -I - "$raiz" "$saida" "$pisos" <<'PY'
import json, os, re, sys

raiz, saida, arq_pisos = sys.argv[1:4]
ALVOS = ["CaptaNucleo", "CaptaSistema"]
LIMITE_AVISO = 98.0


def erro(msg):
    print(f"cobertura: {msg}", file=sys.stderr)
    sys.exit(1)


def alvo_do_arquivo(caminho):
    if "/Tests/" in caminho:
        return None
    # O diretório do pacote também se chama CaptaNucleo: o que vale é o diretório
    # logo após Sources/ (ou, sem Sources/, o primeiro componente que for um alvo).
    m = re.search(r"(^|/)Sources/([^/]+)/", caminho)
    if m:
        return m.group(2) if m.group(2) in ALVOS else None
    for parte in caminho.split("/"):
        if parte in ALVOS:
            return parte
    return None


pisos = {}
with open(arq_pisos, encoding="utf-8") as f:
    for n, linha in enumerate(f, 1):
        linha = linha.strip()
        if not linha or linha.startswith("#"):
            continue
        nome, sep, valor = linha.partition("=")
        nome, valor = nome.strip(), valor.strip()
        try:
            if not sep:
                raise ValueError
            pisos[nome] = float(valor)
        except ValueError:
            erro(f"valor de piso inválido em {arq_pisos}:{n}: '{linha}'")
for alvo in ALVOS:
    if alvo not in pisos:
        erro(f"piso ausente para o alvo {alvo} em {arq_pisos}")

arquivos = {a: {} for a in ALVOS}
for alvo in ALVOS:
    with open(os.path.join(saida, f"bruto-{alvo}.json"), encoding="utf-8") as f:
        dados = json.load(f)
    for bloco in dados.get("data", []):
        for arq in bloco.get("files", []):
            nome = arq["filename"]
            dono = alvo_do_arquivo(nome)
            # Cada alvo só é lido do seu próprio binário de testes: sem contagem dupla.
            if dono != alvo:
                continue
            rel = os.path.relpath(nome, raiz) if os.path.isabs(nome) else nome
            arq["filename"] = rel
            arquivos[alvo][rel] = arq
    os.remove(os.path.join(saida, f"bruto-{alvo}.json"))


def pct(cob, tot):
    return 100.0 * cob / tot if tot else 0.0


linhas_txt = []
falhas = []
combinado = {"data": [{"files": []}]}
for alvo in ALVOS:
    lista = sorted(arquivos[alvo].values(), key=lambda a: a["filename"])
    combinado["data"][0]["files"].extend(lista)
    if not lista:
        erro(f"sem perfil de cobertura para o alvo {alvo} (nenhum arquivo medido)")
    tl = tc = rl = rc = 0
    linhas_txt.append(f"== {alvo} ==")
    linhas_txt.append(f"{'arquivo':<76} {'linhas':>11} {'%':>7} {'regiões %':>10}")
    for a in lista:
        sl, sr = a["summary"]["lines"], a["summary"]["regions"]
        p = pct(sl["covered"], sl["count"])
        marca = " ⚠" if sl["count"] and p < LIMITE_AVISO else ""
        linhas_txt.append(
            f"{a['filename']:<76} {sl['covered']:>5}/{sl['count']:<5} {p:>6.1f}% "
            f"{pct(sr['covered'], sr['count']):>9.1f}%{marca}"
        )
        tl += sl["count"]; tc += sl["covered"]
        rl += sr["count"]; rc += sr["covered"]
    if tl == 0:
        erro(f"sem perfil de cobertura para o alvo {alvo} (0 linhas medidas)")
    p = pct(tc, tl)
    linhas_txt.append(
        f"{'TOTAL ' + alvo:<76} {tc:>5}/{tl:<5} {p:>6.1f}% {pct(rc, rl):>9.1f}%"
        f"   (piso {pisos[alvo]:g}%)"
    )
    linhas_txt.append("")
    if p < pisos[alvo]:
        falhas.append(
            f"alvo {alvo} com {p:.2f}% de linhas, abaixo do piso de {pisos[alvo]:g}%"
        )

linhas_txt.append("⚠ = arquivo abaixo de 98% de linhas (só aviso; o portão usa o total por alvo)")
texto = "\n".join(linhas_txt) + "\n"
with open(os.path.join(saida, "resumo.txt"), "w", encoding="utf-8") as f:
    f.write(texto)
with open(os.path.join(saida, "llvm-cov.json"), "w", encoding="utf-8") as f:
    json.dump(combinado, f)
sys.stdout.write(texto)
for falha in falhas:
    print(f"cobertura: FALHA: {falha}", file=sys.stderr)
sys.exit(1 if falhas else 0)
PY
echo "cobertura: ok"
