"""Exporta GIFs de conferência dos quadros já preparados para o Godot."""
from pathlib import Path
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ / 'assets/inimigos/esqueletos'
TIPOS = ['guerreiro', 'arqueiro', 'mago']
folhas = {tipo: Image.open(PASTA / f'{tipo}.png').convert('RGBA') for tipo in TIPOS}
PREVIAS = RAIZ / 'arte/previas/inimigos/esqueletos'
PREVIAS.mkdir(parents=True, exist_ok=True)
for nome, linhas in [('caminhada', [0, 1, 2]), ('ataque', [3, 4, 5]), ('morte', [6]), ('completa', [0, 3, 6])]:
    quadros = []
    for quadro in range(6 if nome in ["caminhada", "completa"] else 4):
        imagem = Image.new('RGB', (576, len(linhas) * 192 + 28), (40, 48, 44))
        texto = ImageDraw.Draw(imagem)
        for coluna, tipo in enumerate(TIPOS):
            texto.text((coluna * 192 + 64, 8), tipo, fill='white')
            for linha_previa, linha_folha in enumerate(linhas):
                indice = quadro if linha_folha < 3 else quadro % 4
                sprite = folhas[tipo].crop((indice * 64, linha_folha * 64, (indice + 1) * 64, (linha_folha + 1) * 64))
                sprite = sprite.resize((192, 192), Image.Resampling.NEAREST)
                imagem.paste(sprite, (coluna * 192, linha_previa * 192 + 28), sprite)
        quadros.append(imagem)
    duracao = 130 if nome == 'caminhada' else (167 if nome == 'ataque' else 200)
    quadros[0].save(PREVIAS / f'{nome}.gif', save_all=True, append_images=quadros[1:], duration=duracao, loop=0)
