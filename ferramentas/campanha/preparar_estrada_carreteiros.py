#!/usr/bin/env python3
"""Recorta a folha 4×2, mantendo enquadramento comum entre as estações."""
import argparse
import json
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
NOMES = ["primavera", "verao", "outono", "inverno"]

def preparar(origem):
    imagem = Image.open(origem).convert("RGBA")
    destino = RAIZ / "assets/cenario/campanha/estrada_carreteiros"
    fichas = {}
    for linha, nome in enumerate(["carreto", "abrigo"]):
        celulas = []
        for coluna in range(4):
            recorte = imagem.crop((round(coluna*imagem.width/4), round(linha*imagem.height/2), round((coluna+1)*imagem.width/4), round((linha+1)*imagem.height/2)))
            # Colunas fracionárias recebem o mesmo canvas; nunca ajustar cada estação.
            tela = Image.new("RGBA", (round(imagem.width/4), round(imagem.height/2)))
            tela.paste(recorte, (0,0))
            celulas.append(tela)
        caixas = [im.getchannel("A").point(lambda a: 255 if a>40 else 0).getbbox() for im in celulas]
        comum = (min(b[0] for b in caixas), min(b[1] for b in caixas), max(b[2] for b in caixas), max(b[3] for b in caixas))
        pivo = [round((comum[0]+comum[2])/2), comum[3]-4]
        variantes = {}
        for estacao, tela in zip(NOMES, celulas):
            pasta = destino / estacao
            pasta.mkdir(parents=True, exist_ok=True)
            arquivo = pasta / (nome+".png")
            tela.save(arquivo)
            variantes[estacao] = {"textura":"res://"+str(arquivo.relative_to(RAIZ)), "quadro":list(tela.size), "pivo":pivo, "largura_visivel":comum[2]-comum[0]}
        fichas[nome] = {"grupo":"estrada", "variantes":variantes}
    (destino / "pecas.json").write_text(json.dumps(fichas,ensure_ascii=False,indent=2)+"\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("origem", type=Path)
    preparar(parser.parse_args().origem)
