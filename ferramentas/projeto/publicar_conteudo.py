#!/usr/bin/env python3
"""Publica um patch de conteúdo de ponta a ponta numa só chamada.

Uso (a partir da raiz do jogo, no host):
  host-spawn python3 ferramentas/projeto/publicar_conteudo.py --resumo "o que mudou" [--simular]

Passos: commit do que está pendente em codigo/ e cenas/ -> patch Android/Windows/Linux -> Web ->
README da wiki -> commit e push da wiki -> registro em publicacao.json e CONTEXTO.md (commit local).
Pare e avise em qualquer falha; nada é desfeito. --simular só imprime os passos.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

JOGO = Path(__file__).resolve().parents[2]
WIKI = JOGO.parent / "AlgoLand-wiki"
TMP = Path.home() / ".cache/algoland-tmp"
EXPORT = Path.home() / ".cache/algoland-web-export"
COAUTOR = "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
simular = False


def rodar(args, cwd=JOGO, env=None, saida=False):
    print("$", " ".join(str(a) for a in args))
    if simular:
        return ""
    r = subprocess.run(args, cwd=cwd, env={**os.environ, **(env or {})}, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"FALHOU ({r.returncode}): {' '.join(map(str, args))}\n{(r.stdout + r.stderr)[-1500:]}")
    return r.stdout.strip() if saida else ""


def main() -> None:
    global simular
    ap = argparse.ArgumentParser()
    ap.add_argument("--resumo", required=True, help="parágrafo do README da wiki, sem o prefixo 'Conteúdo N'")
    ap.add_argument("--simular", action="store_true")
    a = ap.parse_args()
    simular = a.simular

    pendente = rodar(["git", "status", "--short", "codigo", "cenas", "recursos"], saida=True)
    if pendente:
        rodar(["git", "add", "codigo", "cenas", "recursos"])
        rodar(["git", "commit", "-q", "-m", f"{a.resumo[:70]}\n\n{COAUTOR}"])
    fonte = rodar(["git", "rev-parse", "--short", "HEAD"], saida=True) or "simulado"

    ultimo = ""
    for preset in ["Android", "Windows Desktop", "Linux"]:
        out = rodar(["python3", "ferramentas/atualizacao/gerar_atualizacao.py", "patch", "--preset", preset], saida=True)
        m = re.search(r"Conteúdo (\d+) \((\w+)\) para ([\d.]+)", out)
        if m:
            ultimo = m.group(0)
    numero = int(re.search(r"Conteúdo (\d+)", ultimo).group(1)) if ultimo else 0
    base = re.search(r"para ([\d.]+)", ultimo).group(1) if ultimo else "?"

    rodar(["python3", "scripts/sincronizar-dados.py", "../AlgoLand"], cwd=WIKI)
    TMP.mkdir(parents=True, exist_ok=True)
    rodar(["python3", "scripts/exportar-jogo-web.py", "../AlgoLand", str(EXPORT)], cwd=WIKI, env={"TMPDIR": str(TMP)})
    rodar(["npm", "run", "build"], cwd=WIKI)

    hoje = date.today().strftime("%d/%m/%Y")
    paragrafo = (f"\nConteúdo {numero} da base {base} ({hoje}): {a.resumo} Pacotes cumulativos assinados para "
                 f"Android/Windows/Linux e Web reexportada. Fonte `{fonte}`.\n")
    print(paragrafo.strip())
    if not simular:
        with open(WIKI / "README.md", "a", encoding="utf-8") as f:
            f.write(paragrafo)
    rodar(["git", "add", "-A"], cwd=WIKI)
    rodar(["git", "commit", "-q", "-m", f"Publica conteudo {numero} da base {base}"], cwd=WIKI)
    rodar(["git", "push", "origin", "main"], cwd=WIKI)
    wiki = rodar(["git", "rev-parse", "HEAD"], cwd=WIKI, saida=True) or "simulado"

    if simular:
        return
    web = json.load(open(WIKI / "public/jogar/manifesto.json"))["versao"]
    arq = JOGO / f"builds/lancamentos/{base}/publicacao.json"
    if arq.exists():
        d = json.load(open(arq))
        d.update({"conteudo_atual": numero, "fonte_commit_conteudo": fonte, "wiki_commit_conteudo": wiki, "web_versao": web})
        json.dump(d, open(arq, "w"), indent=2, ensure_ascii=False)
    ctx = JOGO / "ferramentas/projeto/CONTEXTO.md"
    s = ctx.read_text(encoding="utf-8")
    i = s.index("| Distribuição atual |")
    j = s.index("\n", i)
    nova = s[i:j].rstrip(" |") + f" Conteúdo {numero} ({hoje[:5]}, fonte `{fonte}`, Web `{web}`, wiki `{wiki[:7]}`): {a.resumo} |"
    ctx.write_text(s[:i] + nova + s[j:], encoding="utf-8")
    rodar(["git", "add", "ferramentas/projeto/CONTEXTO.md"])
    rodar(["git", "commit", "-q", "-m", f"Registra publicacao do conteudo {numero}\n\n{COAUTOR}"])
    print(f"Conteúdo {numero} publicado. Falta só conferir os hashes no ar, se quiser.")


if __name__ == "__main__":
    main()
