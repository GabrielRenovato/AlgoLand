#!/usr/bin/env python3
"""Prévia dos quadros reais de teste_brilho_armas_3d.gd, sem redesenhar a arte."""
import json
import subprocess
from pathlib import Path

PASTA = Path(__file__).resolve().parents[2] / "arte/previas/armas_brilho_3d"


def ff(*args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *map(str, args)], check=True)


def gif(entrada, destino):
    ff(*entrada, "-filter_complex",
       "[0:v]crop=120:135:20:5,scale=360:405:flags=neighbor,split[a][b];"
       "[a]palettegen=reserve_transparent=1[p];[b][p]paletteuse=dither=none",
       "-loop", 0, PASTA / destino)


def main():
    ff("-start_number", 1, "-i", PASTA / "nivel_%d.png", "-vf",
       "crop=120:135:20:5,tile=5x1,scale=1200:270:flags=neighbor", "-frames:v", 1, PASTA / "niveis_1_a_5.png")
    entradas = []
    for raridade in ["comum", "incomum", "raro", "epico", "lendario"]:
        entradas.extend(["-i", PASTA / f"raridade_{raridade}.png"])
    ff(*entradas, "-filter_complex",
       "[0:v][1:v][2:v][3:v][4:v]hstack=inputs=5,scale=1280:256:flags=neighbor",
       "-frames:v", 1, PASTA / "raridades.png")
    tempos = json.loads((PASTA / "tempos_pulso.json").read_text())
    linhas = []
    for i, tempo in enumerate(tempos):
        duracao = tempos[i + 1] - tempo if i + 1 < len(tempos) else tempo - tempos[i - 1]
        assert duracao > 0
        linhas.extend([f"file '{PASTA / f'pulso_{i:02d}.png'}'", f"duration {duracao:.6f}"])
    lista = Path("/tmp/algoland-brilho-pulso.ffconcat")
    lista.write_text("\n".join(linhas) + "\n")
    gif(["-f", "concat", "-safe", 0, "-i", lista], "brilho_animado.gif")
    duracao = json.loads((PASTA / "tempo_golpe.json").read_text())
    gif(["-framerate", 24 / duracao, "-i", PASTA / "golpe_%02d.png"], "ataque_com_brilho.gif")
    for nome in ["golpe", "pulso"]:
        ff("-i", PASTA / f"{nome}_%02d.png", "-vf", "crop=120:135:20:5,tile=12x2",
           "-frames:v", 1, PASTA / f"quadros_{nome}.png")
    if (PASTA / "arco_costas/tempos.json").exists():
        exportar_arco_costas()
    print("Brilho 3D: cinco níveis, cinco raridades e duas animações nos tempos capturados.")


def exportar_arco_costas():
    pasta = PASTA / "arco_costas"
    tempos = json.loads((pasta / "tempos.json").read_text())
    for direcao in [0, 2, 4, 6]:
        gif(["-framerate", 24 / tempos["correr"], "-i", pasta / f"correr_{direcao}_%02d.png"],
            f"arco_costas/correr_{direcao}.gif")
    for nome, grupos in [("corrida", [range(4), range(4, 8)]), ("disparo", [[0, 2, 4, 6]])]:
        for grupo, direcoes in enumerate(grupos):
            entradas = []
            for d in direcoes:
                entradas.extend(["-i", pasta / f"{'correr' if nome == 'corrida' else 'disparo'}_{d}_%02d.png"])
            filtro = ";".join(f"[{i}:v]crop=120:135:20:5,tile=12x2[d{i}]" for i in range(4))
            filtro += ";[d0][d1][d2][d3]vstack=inputs=4"
            ff(*entradas, "-filter_complex", filtro, "-frames:v", 1, pasta / f"quadros_{nome}_{grupo}.png")
    ff("-i", pasta / "corrida_motor_%02d.png", "-vf", "crop=120:135:20:5,tile=12x2",
       "-frames:v", 1, pasta / "quadros_motor.png")
    ff("-i", pasta / "parado_4.png", "-vf", "crop=120:135:20:5,scale=360:405:flags=neighbor",
       "-frames:v", 1, pasta / "costas.png")


if __name__ == "__main__":
    main()
