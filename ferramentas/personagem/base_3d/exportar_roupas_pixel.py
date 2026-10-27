#!/usr/bin/env python3
"""Monta prévias dos quadros reais do Godot; não altera os assets de roupa."""
import json
from pathlib import Path
import subprocess
from PIL import Image

RAIZ = Path(__file__).resolve().parents[3]
PASTA = RAIZ / "arte/previas/personagens/base_3d/roupas_pixel"


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *map(str, args)], check=True)


def main():
    tempos = json.loads((PASTA / "tempos.json").read_text())
    quadros = sorted(p for p in PASTA.glob("*.png") if p.name.startswith(("correr_", "espada_")))
    for caminho in quadros:
        with Image.open(caminho) as imagem:
            limites = imagem.getchannel("A").getbbox()
        if limites is None or limites[0]<165 or limites[1]<150 or limites[2]>475 or limites[3]>470:
            raise ValueError(f"Quadro cortado pela área fixa da prévia: {caminho.name}: {limites}")
    for conjunto in range(3):
        for acao in ("correr", "espada"):
            entrada = PASTA / f"{acao}_{conjunto}_2_%02d.png"
            frequencia = 12 / tempos[acao]
            recorte = "crop=310:320:165:150"
            ffmpeg("-framerate", frequencia, "-i", entrada, "-vf", recorte + ",tile=6x2", "-frames:v", 1,
                   PASTA / f"quadros_{acao}_{conjunto}.png")
            # O golpe repete apenas para revisão; cada execução usa o tempo do clipe.
            filtro = recorte + ",scale=620:640:flags=neighbor,split[s0][s1];[s0]palettegen=reserve_transparent=1[p];[s1][p]paletteuse=dither=none"
            ffmpeg("-framerate", frequencia, "-i", entrada, "-filter_complex", filtro, "-loop", 0,
                   PASTA / f"{acao}_{conjunto}.gif")
    ffmpeg("-i", PASTA / "antes_depois.png", "-filter_complex",
           "[0:v]split[a][b];[a]crop=210:330:0:0[antes];[b]crop=210:330:0:330[depois];[antes][depois]hstack,scale=840:660:flags=neighbor",
           "-frames:v", 1, PASTA / "comparacao_frente.png")
    # Três conjuntos finais, de frente, com o mesmo recorte/escala da comparação.
    ffmpeg("-i", PASTA / "depois_0.png", "-i", PASTA / "blusa_bufante_0.png", "-i", PASTA / "jaqueta_viajante_0.png",
           "-filter_complex", "[0:v]crop=210:330:215:155[a];[1:v]crop=210:330:215:155[b];[2:v]crop=210:330:215:155[c];[a][b][c]hstack=inputs=3,scale=1260:660:flags=neighbor",
           "-frames:v", 1, PASTA / "roupas_aplicadas.png")
    print(f"Prévia exportada: {len(quadros)} quadros sem corte; seis GIFs com tempos reais, seis folhas e comparação frontal.")


if __name__ == "__main__":
    main()
