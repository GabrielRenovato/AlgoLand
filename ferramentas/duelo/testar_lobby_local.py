#!/usr/bin/env python3
"""Presença na cidade com servidor local e dois jogos (saves isolados): o A anda, o B mede a suavidade.
Opções: --atraso=MS (latência simulada no servidor), --tick=MS (instantâneos do servidor)."""
import os, socket, subprocess, sys, time, shutil
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = "/tmp/algoland-lobby-teste"
def opcao(nome, padrao):
    return next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith(f"--{nome}=")), padrao)
def porta_livre():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close(); return p
def copia(nome):
    destino = f"/tmp/algoland-lobby-{nome}"
    shutil.rmtree(destino, ignore_errors=True)
    subprocess.run([sys.executable, os.path.join(RAIZ, "ferramentas/projeto/preparar_testes.py"), destino], check=True, capture_output=True)
    cfg = os.path.join(destino, "project.godot")
    texto = open(cfg).read().replace("[application]\n", f'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="AlgoLand testes lobby {nome}"\n', 1)
    open(cfg, "w").write(texto)
    return destino
os.makedirs(SAIDA, exist_ok=True)
porta = porta_livre()
servidor = subprocess.Popen(["node", "servidor.mjs"], cwd=os.path.join(RAIZ, "ferramentas/lobby/servidor"),
    env={**os.environ, "PORTA": str(porta), "ADMIN_PORTA": "0", "ATRASO_TESTE_MS": opcao("atraso", "0"), "TICK_MS": opcao("tick", "50")},
    stdout=open(f"{SAIDA}/servidor.log", "w"), stderr=subprocess.STDOUT)
time.sleep(1.0)
jogos = []
try:
    for papel in ["b", "a"]:
        pasta = copia(papel)
        jogos.append(subprocess.Popen(["flatpak", "run", "--filesystem=/tmp", f"--filesystem={RAIZ}", "org.godotengine.Godot", "--path", pasta,
            "--resolution", "960x540", "--script", "res://ferramentas/duelo/cliente_teste_lobby.gd", "--", f"--papel={papel}", f"--lobby-ws=ws://127.0.0.1:{porta}"] + [a for a in sys.argv[1:] if not a.startswith(("--atraso=", "--tick="))],
            stdout=open(f"{SAIDA}/jogo_{papel}.log", "w"), stderr=subprocess.STDOUT))
        time.sleep(2.0)
    for jogo in jogos: jogo.wait(timeout=200)
    print("saidas:", [j.returncode for j in jogos])
finally:
    for jogo in jogos:
        if jogo.poll() is None: jogo.kill()
    servidor.terminate()
for papel in ["a", "b"]:
    for linha in open(f"{SAIDA}/jogo_{papel}.log"):
        if "LOBBY[" in linha or "Parse Error" in linha: print(linha.rstrip())
