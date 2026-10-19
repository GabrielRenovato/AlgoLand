"""Importa os quatro sprites desenhados em pixel art ampliado, preservando a base e o alfa."""
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / "arte/fontes/fendas/tesouro/portal_sazonal_fonte.png"
DESTINO = RAIZ / "assets/cenario/fendas/tesouro/portal_sazonal.png"


def preparar():
    fonte = Image.open(FONTE).convert("RGBA")
    folha = Image.new("RGBA", (256, 80))
    for indice in range(4):
        inicio = round(indice * fonte.width / 4)
        fim = round((indice + 1) * fonte.width / 4)
        sprite = fonte.crop((inicio, 0, fim, fonte.height))
        # A fonte é pixel art ampliada; limpar somente o halo residual do alfa gerado.
        alfa = sprite.getchannel("A").point(lambda valor: 255 if valor >= 192 else 0)
        sprite.putalpha(alfa)
        sprite = sprite.crop(alfa.getbbox())
        fator = min(56 / sprite.width, 68 / sprite.height)
        tamanho = (round(sprite.width * fator), round(sprite.height * fator))
        sprite = sprite.resize(tamanho, Image.Resampling.NEAREST)
        folha.alpha_composite(sprite, (indice * 64 + (64 - sprite.width) // 2, 72 - sprite.height))
    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    folha.save(DESTINO)
    print(DESTINO)
    quadros = sorted((FONTE.parent / "animacao").glob("quadro_*.png"))
    if quadros:
        assert len(quadros) == 9, "A animação deve ter nove quadros completos."
        animacao = Image.new("RGBA", (256, 80 * len(quadros)))
        for indice, caminho in enumerate(quadros):
            quadro = Image.open(caminho).convert("RGBA")
            assert quadro.size == (256, 80), (caminho, quadro.size)
            animacao.alpha_composite(quadro, (0, indice * 80))
        animacao.save(DESTINO.with_name("portal_sazonal_animado.png"))


if __name__ == "__main__":
    preparar()
