#!/usr/bin/env python3
"""Prepara ícones do manifesto; preserva os originais e gera contato para revisão de pixels."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / "arte/fontes/pesca/progressao_99"


def preparar():
    manifesto = json.loads((FONTES / "manifesto.json").read_text())
    ids = ["dourado", "salmao"] + list(manifesto["especies"])
    folha = Image.new("RGB", (512, 272), "#302d35")
    desenho = ImageDraw.Draw(folha)
    for id_peixe, dados in manifesto["especies"].items():
        original = Image.open(FONTES / dados["original"]).convert("RGBA")
        alpha = original.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
        original.putalpha(alpha)
        caixa = alpha.getbbox()
        if caixa is None:
            raise ValueError("Ícone sem silhueta: " + id_peixe)
        sprite = original.crop(caixa)
        proporcao = 14 / max(sprite.size)
        tamanho = tuple(max(1, round(lado * proporcao)) for lado in sprite.size)
        sprite = sprite.resize(tamanho, Image.Resampling.NEAREST)
        # Paleta curta e alpha binário para que a miniatura não herde microtexturas.
        sprite = sprite.quantize(colors=12, method=Image.Quantize.FASTOCTREE).convert("RGBA")
        icone = Image.new("RGBA", (16, 16))
        icone.paste(sprite, ((16 - tamanho[0]) // 2, (16 - tamanho[1]) // 2))
        icone.save(RAIZ / dados["destino"])
    for indice, id_peixe in enumerate(ids):
        x, y = (indice % 4) * 128, (indice // 4) * 136
        icone = Image.open(RAIZ / f"assets/pesca/peixes/{id_peixe}.png").convert("RGBA")
        folha.paste(icone.resize((96, 96), Image.Resampling.NEAREST), (x + 16, y + 4), icone.resize((96, 96), Image.Resampling.NEAREST))
        desenho.text((x + 4, y + 108), id_peixe, fill="#fff0ce")
    destino = RAIZ / "arte/previas/pesca/progressao_99"
    destino.mkdir(parents=True, exist_ok=True)
    folha.save(destino / "contato_icones.png")


if __name__ == "__main__":
    preparar()
