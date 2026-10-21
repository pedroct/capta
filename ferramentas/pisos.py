"""Leitura do arquivo de pisos de cobertura (ferramentas/cobertura.pisos).

Compartilhado por cobertura.sh (pacote) e cobertura_app.sh (app): cada portão exige só
os alvos que mede, e os dois validam o arquivo inteiro do mesmo jeito.
"""

import math
import os
import sys


def erro(msg):
    print(f"cobertura: {msg}", file=sys.stderr)
    sys.exit(1)


def ler_pisos(arq_pisos, exigidos):
    """Devolve {alvo: piso}; sai com erro se uma linha for inválida ou faltar um alvo exigido."""
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
                numero = float(valor)
                if not math.isfinite(numero) or not 0 <= numero <= 100:
                    raise ValueError
            except ValueError:
                erro(f"valor de piso inválido em {arq_pisos}:{n}: '{linha}'")
            if nome in pisos:
                erro(f"piso duplicado para '{nome}' em {arq_pisos}:{n}")
            pisos[nome] = numero
    for alvo in exigidos:
        if alvo not in pisos:
            erro(f"piso ausente para o alvo {alvo} em {arq_pisos}")
    return pisos


PREFIXO_CASCA = "Packages/CaptaNucleo/Sources/CaptaSistema/Casca/"


def ler_exclusoes(arq_exclusoes, raiz):
    """Devolve {caminho relativo à raiz: motivo} de ferramentas/cobertura.exclusoes.

    Formato: uma linha por arquivo, `caminho | motivo`; `#` comenta. Só arquivos sob
    Casca/ podem ser listados, o motivo é obrigatório e o arquivo precisa existir
    (lista velha falha). Só o portão do pacote usa isto; o do app não tem exclusões."""
    exclusoes = {}
    with open(arq_exclusoes, encoding="utf-8") as f:
        for n, linha in enumerate(f, 1):
            linha = linha.strip()
            if not linha or linha.startswith("#"):
                continue
            onde = f"{arq_exclusoes}:{n}"
            caminho, sep, motivo = linha.partition("|")
            caminho, motivo = caminho.strip(), motivo.strip()
            if not sep or not caminho or not motivo:
                erro(f"exclusão inválida em {onde}: '{linha}' (use 'caminho | motivo')")
            if not caminho.startswith(PREFIXO_CASCA) or ".." in caminho.split("/"):
                erro(f"exclusão fora de {PREFIXO_CASCA} em {onde}: '{caminho}'")
            if not os.path.isfile(os.path.join(raiz, caminho)):
                erro(f"exclusão de arquivo inexistente em {onde}: '{caminho}' (lista velha?)")
            if caminho in exclusoes:
                erro(f"exclusão duplicada para '{caminho}' em {onde}")
            exclusoes[caminho] = motivo
    return exclusoes
