#!/bin/bash
# Portão de cobertura do app: roda o alvo CaptaTests (hospedado no Capta.app, sem assinatura)
# com cobertura, resume App/Fontes por arquivo e falha se o total ficar abaixo do piso `App=`
# em cobertura.pisos. CaptaApp.swift (ponto de entrada, sem lógica) fica fora da conta (spec §4);
# os arquivos de cobertura-app.exclusoes (casca de view sem como rodar sem tela, com motivo por
# arquivo) também saem da conta e do XML do Sonar, e aparecem em "Fora da conta" no resumo.
# Espera o .xcodeproj já gerado (`make cobertura-app` roda `make gerar` antes).
# Sem assinatura, os entitlements não entram no binário: os testes rodam fora do sandbox.
# PISOS=<arquivo> sobrescreve o arquivo de pisos (usado para conferir o próprio portão).
# EXCLUSOES_APP=<arquivo> sobrescreve o arquivo de exclusões, como PISOS faz com o de pisos.
set -eu -o pipefail

raiz=$(cd "$(dirname "$0")/.." && pwd)
pisos="${PISOS:-$raiz/ferramentas/cobertura.pisos}"
case "$pisos" in /*) ;; *) pisos="$PWD/$pisos" ;; esac
exclusoes="${EXCLUSOES_APP:-$raiz/ferramentas/cobertura-app.exclusoes}"
case "$exclusoes" in /*) ;; *) exclusoes="$PWD/$exclusoes" ;; esac
saida="$raiz/build/cobertura"
trabalho="$raiz/build/cobertura-app"
resultado="$trabalho/Testes.xcresult"

if [[ ! -f "$pisos" ]]; then
  echo "cobertura-app: arquivo de pisos não encontrado: $pisos" >&2
  exit 1
fi

if [[ ! -e "$exclusoes" ]]; then
  echo "cobertura-app: arquivo de exclusões não encontrado: $exclusoes" >&2
  exit 1
fi

# Valida o registro antes do build demorado: erro de digitação falha em segundos.
python3 -I -c '
import os, sys
raiz = sys.argv[1]
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(raiz, "ferramentas"))
from pisos import ler_exclusoes
ler_exclusoes(sys.argv[2], raiz, "App/Fontes/")
' "$raiz" "$exclusoes"

mkdir -p "$saida" "$trabalho"
# O xcodebuild recusa um pacote de resultados que já exista.
rm -rf "$resultado"
rm -f "$saida/resumo-app.txt" "$saida/sonar-cobertura-app.xml"

cd "$raiz"
xcodebuild test -scheme Capta -destination 'platform=macOS' \
  -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$trabalho/DerivedData" -resultBundlePath "$resultado" \
  | xcbeautify >&2

xcrun xccov view --report --json "$resultado" >"$trabalho/relatorio.json"
xcrun xccov view --archive --json "$resultado" >"$trabalho/linhas.json"

python3 -I - "$raiz" "$saida" "$trabalho" "$pisos" "$exclusoes" <<'PY'
import json, os, sys
import xml.etree.ElementTree as ET

raiz, saida, trabalho, arq_pisos, arq_exclusoes = sys.argv[1:6]
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(raiz, "ferramentas"))
from pisos import erro, ler_exclusoes, ler_pisos

ALVO = "App"
PASTA = "App/Fontes/"
FORA_DA_CONTA = {"CaptaApp.swift"}

pisos = ler_pisos(arq_pisos, [ALVO])
exclusoes = ler_exclusoes(arq_exclusoes, raiz, PASTA)

with open(os.path.join(trabalho, "relatorio.json"), encoding="utf-8") as f:
    relatorio = json.load(f)
with open(os.path.join(trabalho, "linhas.json"), encoding="utf-8") as f:
    linhas_por_arquivo = json.load(f)


def relativo(caminho):
    return os.path.relpath(caminho, raiz) if os.path.isabs(caminho) else caminho


medidos, ignorados = {}, []
for alvo in relatorio.get("targets", []):
    for arq in alvo.get("files", []):
        rel = relativo(arq["path"])
        if not rel.startswith(PASTA):
            continue
        if os.path.basename(rel) in FORA_DA_CONTA:
            ignorados.append(rel)
            continue
        if rel in exclusoes:
            continue
        medidos[rel] = (arq["coveredLines"], arq["executableLines"], arq["path"])
if not medidos:
    erro(f"nenhum arquivo de {PASTA} no relatório do xccov (formato mudou ou teste não rodou?)")


def pct(cob, tot):
    return 100.0 * cob / tot if tot else 0.0


txt = [f"== {ALVO} ==", f"{'arquivo':<76} {'linhas':>11} {'%':>7}"]
tc = tl = 0
for rel in sorted(medidos):
    cob, tot, _ = medidos[rel]
    txt.append(f"{rel:<76} {cob:>5}/{tot:<5} {pct(cob, tot):>6.1f}%")
    tc += cob
    tl += tot
if tl == 0:
    erro(f"sem perfil de cobertura para o alvo {ALVO} (0 linhas medidas)")
p = pct(tc, tl)
txt.append(f"{'TOTAL ' + ALVO:<76} {tc:>5}/{tl:<5} {p:>6.1f}%   (piso {pisos[ALVO]:g}%)")
for rel in sorted(ignorados):
    txt.append(f"fora da conta (ponto de entrada, sem lógica): {rel}")
if exclusoes:
    txt.append("")
    txt.append("Fora da conta (cobertura-app.exclusoes):")
    for rel, motivo in sorted(exclusoes.items()):
        txt.append(f"  {rel} | {motivo}")
texto = "\n".join(txt) + "\n"
with open(os.path.join(saida, "resumo-app.txt"), "w", encoding="utf-8") as f:
    f.write(texto)

# Mesmo formato genérico do SonarQube que o pacote grava em sonar-cobertura.xml.
raiz_xml = ET.Element("coverage", version="1")
for rel in sorted(medidos):
    no = ET.SubElement(raiz_xml, "file", path=rel)
    for linha in linhas_por_arquivo.get(medidos[rel][2], []):
        if linha.get("isExecutable"):
            ET.SubElement(no, "lineToCover", lineNumber=str(linha["line"]),
                          covered="true" if linha.get("executionCount", 0) > 0 else "false")
ET.indent(raiz_xml)
ET.ElementTree(raiz_xml).write(os.path.join(saida, "sonar-cobertura-app.xml"),
                               encoding="utf-8", xml_declaration=True)

sys.stdout.write(texto)
if p < pisos[ALVO]:
    print(f"cobertura-app: FALHA: alvo {ALVO} com {p:.2f}% de linhas, abaixo do piso de "
          f"{pisos[ALVO]:g}%", file=sys.stderr)
    sys.exit(1)
PY
echo "cobertura-app: ok"
