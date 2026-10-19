#!/usr/bin/env python3
"""Executa a matriz de regressão do coop/controle/toque em saves descartáveis."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time
import uuid

from preparar_testes import preparar

# Testes de sistemas complementam o coop; não significam que foram executados com dois jogadores.
GRUPOS = {
    "coop": ["coop_entradas", "coop_geral", "interface_coop", "controle_ambientes_coop", "bugs_controle", "assentos_coop", "sono_coop", "pesca_coop", "economia_festa", "praia", "agenda_vila"],
    "controle": ["controle_botoes", "mira", "barra_armas", "pausa"],
    "android": ["coop_android", "toque", "coleta_dedicada", "mini_tutorial"],
    "sistemas": ["inventario", "fazenda", "plantio", "pocoes", "defesa", "morte", "transicoes", "introducao", "dialogo_cidade", "varas_catalogo", "cartas_peixes", "peixes_mochila", "loja_nilo_pedidos", "progresso_pesca", "pesca", "retratos_dialogo"],
}
ARGUMENTOS_TESTES = {"economia_festa": ["--festa-coop"], "pesca_coop": ["--ambos", "--p1-sai"]}
# Uma ocorrência exata: o teste injeta JSON inválido e verifica a recuperação.
ERROS_ESPERADOS = {"calendario": ["ERROR: Parse JSON failed. Error at line 0: Expected 'true', 'false', or 'null', got 'isto'"]}
ERROS = re.compile(r"SCRIPT ERROR|Parse Error|^ERROR:|^FALHA(?:\s|:)|^FALHAS:\s*[1-9]", re.M)


# Diagnósticos conhecidos de encerramento, mantidos no relatório e no log.
# Os GL/RID GLES também aparecem ao instanciar e liberar apenas jogador.tscn, sem carregar mapas.
AVISOS_CONHECIDOS = re.compile(r"^ERROR: (?:Not supported by this display server\.|[0-9]+ resources still in use at exit .*|[0-9]+ RID allocations of type '(?:PN13RendererDummy|N5GLES3).* were leaked at exit\.|Texture with GL ID of [0-9]+: leaked [0-9]+ bytes\.)$")


def executar(comando, log, limite, erros_esperados=()):
    inicio = time.monotonic()
    expirou = False
    with log.open("w") as arquivo:
        processo = subprocess.Popen(comando, stdout=arquivo, stderr=subprocess.STDOUT, start_new_session=True)
        while True:
            try:
                codigo = processo.wait(timeout=0.25)
                break
            except subprocess.TimeoutExpired:
                expirou = time.monotonic() - inicio >= limite
                fatal = re.search(r"SCRIPT ERROR|Parse Error", log.read_text(errors="replace"))
                if expirou or fatal:
                    try:
                        os.killpg(processo.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    codigo = processo.wait()
                    break
    texto = log.read_text(errors="replace")
    avisos, erros, esperados = analisar_log(texto, erros_esperados)
    return {"codigo": codigo, "segundos": round(time.monotonic() - inicio, 2),
            "timeout": expirou, "avisos_conhecidos": avisos, "erros_esperados": esperados, "erros": erros[:30], "total_erros": len(erros),
            "verificacoes_ok": len(re.findall(r"^OK(?:\s|$)", texto, re.M)), "log": str(log),
            "aprovado": codigo == 0 and not expirou and not erros}


def analisar_log(texto, erros_esperados=()):
    """Classifica logs já capturados sem repetir os testes; preserva todos os diagnósticos."""
    diagnosticos = [linha for linha in texto.splitlines() if ERROS.search(linha)]
    avisos = [linha for linha in diagnosticos if AVISOS_CONHECIDOS.fullmatch(linha)]
    erros = [linha for linha in diagnosticos if linha not in avisos]
    esperados = []
    for esperado in erros_esperados:
        if esperado in erros:
            erros.remove(esperado)
            esperados.append(esperado)
    return avisos, erros, esperados


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--grupo", action="append", choices=GRUPOS, help="Repita para combinar grupos; padrão: todos.")
    parser.add_argument("--teste", action="append", help="Nome sem teste_/.gd; restringe os grupos selecionados.")
    parser.add_argument("--listar", action="store_true")
    parser.add_argument("--limite", type=int, default=180, help="Segundos por teste.")
    parser.add_argument("--saida", type=Path, help="Pasta nova para logs, cópia de teste e relatório JSON.")
    parser.add_argument("--grafico", action="store_true", help="Usa a renderização real em vez de headless.")
    args = parser.parse_args()
    selecionados = list(dict.fromkeys(t for g in (args.grupo or GRUPOS) for t in GRUPOS[g]))
    if args.teste:
        desconhecidos = set(args.teste) - set(selecionados)
        if desconhecidos:
            parser.error("Testes fora da seleção: " + ", ".join(sorted(desconhecidos)))
        selecionados = [t for t in selecionados if t in args.teste]
    if args.listar:
        for grupo, testes in GRUPOS.items():
            print(grupo + ": " + ", ".join(t for t in testes if t in selecionados))
        return 0
    if args.limite <= 0:
        parser.error("--limite deve ser positivo")
    saida = args.saida.expanduser().resolve() if args.saida else Path(tempfile.mkdtemp(prefix="algoland-coop-"))
    # Uma execução nunca reaproveita saves nem sobrescreve relatórios anteriores.
    saida.mkdir(parents=True, exist_ok=True)
    if list(saida.iterdir()):
        parser.error("--saida precisa ser uma pasta vazia")
    projeto = preparar(saida / "projeto")
    configuracao_base = (projeto / "project.godot").read_text()
    configuracao_base = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n', '', configuracao_base, flags=re.M)
    identificador = uuid.uuid4().hex
    def isolar(nome):
        config = configuracao_base.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="AlgoLand testes coop %s %s"' % (identificador, nome), 1)
        (projeto / "project.godot").write_text(config)
    isolar("importacao")
    godot = shutil.which("godot") or shutil.which("godot4")
    if not godot and not shutil.which("flatpak"):
        parser.error("Instale Godot 4 ou o Flatpak org.godotengine.Godot.")
    motor = [godot] if godot else ["flatpak", "run", "--filesystem=" + str(saida), "org.godotengine.Godot"]
    print("Logs e relatório: " + str(saida), flush=True)
    importacao = executar(motor + ["--headless", "--editor", "--path", str(projeto), "--import", "--quit"], saida / "importacao.log", max(args.limite, 180))
    relatorio = {"escopo": "Coop local e regressões de sistemas; Android simulado por eventos de toque no Godot, sem certificação em aparelho físico.",
                 "importacao": importacao, "modo": "grafico" if args.grafico else "headless",
                 "selecionados": selecionados, "testes": []}
    if importacao["aprovado"]:
        for nome in selecionados:
            isolar(nome)
            comando = motor + ([] if args.grafico else ["--headless"]) + ["--path", str(projeto), "--script", "res://testes/teste_" + nome + ".gd"]
            if nome in ARGUMENTOS_TESTES:
                comando += ["--"] + ARGUMENTOS_TESTES[nome]
            resultado = executar(comando, saida / (nome + ".log"), args.limite, ERROS_ESPERADOS.get(nome, ()))
            resultado["nome"] = nome
            if resultado["verificacoes_ok"] == 0:
                resultado["aprovado"] = False
                resultado["erros"].append("Nenhuma verificação OK executada; consulte o log.")
                resultado["total_erros"] += 1
            relatorio["testes"].append(resultado)
            print(("OK " if resultado["aprovado"] else "FALHA ") + nome + " (%.1fs, %d verificações OK)" % (resultado["segundos"], resultado["verificacoes_ok"]), flush=True)
            for erro in resultado["erros"][:3]:
                print("  " + erro, flush=True)
    relatorio["falhas"] = sum(not t["aprovado"] for t in relatorio["testes"]) + int(not importacao["aprovado"])
    relatorio["aprovado"] = relatorio["falhas"] == 0 and len(relatorio["testes"]) == len(selecionados)
    (saida / "relatorio.json").write_text(json.dumps(relatorio, ensure_ascii=False, indent=2) + "\n")
    print("%d testes executados; %d falhas. Relatório: %s" % (len(relatorio["testes"]), relatorio["falhas"], saida / "relatorio.json"))
    return 0 if relatorio["aprovado"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
