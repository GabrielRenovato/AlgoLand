#!/usr/bin/env python3
"""Testa o duelo online de ponta a ponta na máquina: servidor do lobby local + dois jogos
(saves isolados) que criam/entram numa sala, lutam dois rounds e voltam. Fotos em /tmp/algoland-duelo/."""
import os, socket, subprocess, sys, time, shutil
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = "/tmp/algoland-duelo"

def porta_livre():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close(); return p

def copia(nome):
    destino = f"/tmp/algoland-duelo-{nome}"
    shutil.rmtree(destino, ignore_errors=True)
    subprocess.run([sys.executable, os.path.join(RAIZ, "ferramentas/projeto/preparar_testes.py"), destino], check=True, capture_output=True)
    cfg = os.path.join(destino, "project.godot")
    texto = open(cfg).read().replace("[application]\n", f'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="AlgoLand testes duelo {nome}"\n', 1)
    open(cfg, "w").write(texto)
    return destino

def main():
    os.makedirs(SAIDA, exist_ok=True)
    # --servidor=ws://... usa um servidor já rodando (ex.: o container do Fly) em vez de subir um local.
    externo = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--servidor=")), "")
    porta = porta_livre()
    servidor = None if externo else subprocess.Popen(["node", "servidor.mjs"], cwd=os.path.join(RAIZ, "ferramentas/lobby/servidor"),
        env={**os.environ, "PORTA": str(porta), "ADMIN_PORTA": "0",
             "ATRASO_TESTE_MS": next((a.split("=")[1] for a in sys.argv[1:] if a.startswith("--atraso=")), "0")}, stdout=open(f"{SAIDA}/servidor.log", "w"), stderr=subprocess.STDOUT)
    time.sleep(1.0)
    jogos = []
    try:
        for papel in ["a", "b"]:
            pasta = copia(papel)
            jogos.append(subprocess.Popen(["flatpak", "run", "--filesystem=/tmp", f"--filesystem={RAIZ}", "org.godotengine.Godot",
                "--path", pasta, "--resolution", "960x540", "--script", "res://ferramentas/duelo/cliente_teste_duelo.gd", "--",
                f"--papel={papel}", f"--duelo-ws={externo or f'ws://127.0.0.1:{porta}'}", f"--saida={SAIDA}"] + sys.argv[1:],
                stdout=open(f"{SAIDA}/jogo_{papel}.log", "w"), stderr=subprocess.STDOUT))
            time.sleep(2.0)
        for jogo in jogos: jogo.wait(timeout=240)
    finally:
        for jogo in jogos:
            if jogo.poll() is None: jogo.kill()
        if servidor: servidor.terminate()
    for papel in ["a", "b"]:
        for linha in open(f"{SAIDA}/jogo_{papel}.log"):
            if "DUELO[" in linha or "SCRIPT ERROR" in linha or "Parse Error" in linha: print(linha.rstrip())

if __name__ == "__main__":
    main()
