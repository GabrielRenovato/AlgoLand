#!/usr/bin/env python3
"""Valida e monta as prévias da grade real renderizada pelo Godot."""
import json
from pathlib import Path
import subprocess
from PIL import Image

RAIZ=Path(__file__).resolve().parents[3]
PASTA=RAIZ/"arte/previas/personagens/base_3d/grade_pixel"


def ffmpeg(*args):
    subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y",*map(str,args)],check=True)


def main():
    tempos=json.loads((PASTA/"tempos.json").read_text())
    quadros=sorted(p for p in PASTA.glob("*.png") if p.name.startswith(("correr_","espada_")))
    assert len(quadros)==288,"Capturas completas dos três conjuntos"
    for p in quadros:
        with Image.open(p) as img:
            assert img.size==(160,160),p.name
            limites=img.getchannel("A").getbbox()
        assert limites and limites[0]>=35 and limites[1]>=35 and limites[2]<=130 and limites[3]<=125,(p.name,limites)
    olhos=[]
    for q in range(24):
        with Image.open(PASTA/f"repouso_{q:02d}.png") as img:
            quantidade=0
            for y in range(48,65):
                for x in range(69,93):
                    r,g,b,a=img.getpixel((x,y))
                    quantidade+=int(a>0 and g>r*1.12 and b>g*1.08)
            olhos.append(quantidade)
    assert min(olhos)>=2,"Íris não pode desaparecer durante o repouso frontal"
    for conjunto in range(3):
        for acao in ("correr","espada"):
            entrada=PASTA/f"{acao}_{conjunto}_2_%02d.png"
            frequencia=12/tempos[acao]
            ffmpeg("-framerate",frequencia,"-i",entrada,"-vf",
                   "crop=95:90:35:35,scale=285:270:flags=neighbor,tile=6x2","-frames:v",1,
                   PASTA/f"quadros_{acao}_{conjunto}.png")
            ffmpeg("-framerate",frequencia,"-i",entrada,"-filter_complex",
                   "crop=95:90:35:35,scale=475:450:flags=neighbor,split[s0][s1];[s0]palettegen=reserve_transparent=1[p];[s1][p]paletteuse=dither=none",
                   "-loop",0,PASTA/f"{acao}_{conjunto}.gif")
    ffmpeg("-i",PASTA/"suave_0.png","-i",PASTA/"parado_0_0.png","-filter_complex",
           "[0:v]crop=380:360:140:140[a];[1:v]crop=95:90:35:35,scale=380:360:flags=neighbor[b];[a][b]hstack[frente];color=c=0x52624f:s=760x360:d=1,format=rgba[fundo];[fundo][frente]overlay=format=rgb,format=rgba",
           "-frames:v",1,PASTA/"antes_depois.png")
    ffmpeg("-framerate",9.6,"-i",PASTA/"repouso_%02d.png","-vf",
           "crop=40:32:60:38,scale=200:160:flags=neighbor,tile=6x4","-frames:v",1,PASTA/"rostos_repouso.png")
    entradas=[]
    for conjunto in range(3):entradas.extend(("-i",PASTA/f"parado_{conjunto}_0.png"))
    ffmpeg(*entradas,"-filter_complex",
           "[0:v]crop=95:90:35:35[a];[1:v]crop=95:90:35:35[b];[2:v]crop=95:90:35:35[c];[a][b][c]hstack=inputs=3,scale=1140:360:flags=neighbor",
           "-frames:v",1,PASTA/"conjuntos.png")
    resultado={"quadros_sem_corte":len(quadros),"azul_olhos_repouso":olhos,"tempos":tempos,"grade":[160,160]}
    (PASTA/"validacao.json").write_text(json.dumps(resultado,ensure_ascii=False,indent=2)+"\n")
    print(f"GRADE: {len(quadros)} quadros sem corte; íris legível nas24 fases; prévias com duração do jogo (corrida114px/s).")


if __name__=="__main__":main()
