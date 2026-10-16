"""Monta folhas compatíveis com InimigoGenerico a partir do pacote Tiny original."""
from pathlib import Path
import subprocess
import tempfile
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
PACOTE = RAIZ / 'arte/pacotes/_zips_originais/Farm RPG - Tiny Asset Pack - (All in One).rar'
DESTINO = RAIZ / 'assets/inimigos/tiny'
CORES_SLIME = ['Black', 'Blue', 'Golden', 'Green', 'Pink', 'Pupple']
# id, pastas das variantes, andar, ataque, morte, tamanho do quadro
ESPECIES = [
    ('slime_pequeno', [f'Slimes/{c}/Small Slime' for c in CORES_SLIME], 'Walk.png', 'Idle.png', 'Dead.png', 32),
    ('slime_tiny', [f'Slimes/{c}/Slime' for c in CORES_SLIME], 'Walk.png', 'Idle.png', 'Dead.png', 32),
    ('slime_grande', [f'Slimes/{c}/Big Slime' for c in CORES_SLIME], 'Walk.png', 'Idle.png', 'Dead.png', 32),
    ('slime_broto', [f'Sprout Slime/{c}' for c in ['Blue', 'Pink', 'Purple']], 'Walk.png', 'Idle.png', 'Dead.png', 32),
    ('micônide', [f'Myconid/{c}' for c in ['Blue', 'Green', 'Pink', 'Purple', 'Red']], 'Walk.png', 'Attack.png', 'Dead.png', 32),
    ('goblin_lanceiro', ['Goblins/Spear Goblin'], 'Walk.png', 'Spear.png', 'Dead.png', 32),
    ('goblin_arqueiro', ['Goblins/Archer Goblin'], 'Walk.png', 'Bow.png', 'Dead.png', 32),
    ('goblin_bombardeiro', ['Goblins/Bomb Goblin'], 'Walk bomb.png', 'Throw a bomb.png', 'Dead.png', 32),
    ('espinhento', ['Spike'], 'idle.png', 'spitting.png', 'dead.png', 32),
    ('flor_venenosa', ['Venom Bloom/Purple'], 'Idle.png', 'Attack.png', 'Dead.png', 48),
]


def montar(origem):
    DESTINO.mkdir(parents=True, exist_ok=True)
    for especie, variantes, andar, ataque, morte, tamanho in ESPECIES:
        # Sem acentos nos caminhos dos recursos.
        especie = especie.replace('ô', 'o')
        for variante, pasta in enumerate(variantes):
            folha = Image.new('RGBA', (8 * tamanho, 12 * tamanho))
            for bloco, arquivo in enumerate([andar, ataque, morte]):
                imagem = Image.open(origem / pasta / arquivo).convert('RGBA')
                # O slime com broto é a exceção: quadros de 16x32, centralizados na célula de 32x32.
                largura = 16 if especie == 'slime_broto' else tamanho
                linhas = imagem.height // tamanho
                for direcao in range(4):
                    linha = min(direcao, linhas - 1)
                    for quadro in range(imagem.width // largura):
                        recorte = imagem.crop((quadro * largura, linha * tamanho, (quadro + 1) * largura, (linha + 1) * tamanho))
                        folha.paste(recorte, (quadro * tamanho + (tamanho - largura) // 2, (bloco * 4 + direcao) * tamanho))
            folha.save(DESTINO / f'{especie}_{variante + 1}.png')


if __name__ == '__main__':
    with tempfile.TemporaryDirectory(prefix='algoland-tiny-') as temporario:
        subprocess.run(['unrar', 'x', '-idq', str(PACOTE), '*/Enemy/*', temporario + '/'], check=True)
        montar(Path(temporario) / 'Farm RPG - Tiny Asset Pack - (All in One)/Enemy')
