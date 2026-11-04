"""GIFs e contatos a partir das capturas reais e dos tempos exportados no Godot."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
RAIZ=Path(__file__).resolve().parents[3]
PASTA=RAIZ/'arte/previas/inimigos/goblin_capuz_3d/mixamo'
rel=json.loads((PASTA/'revisao.json').read_text())
for info in rel:
    nome=info['nome'];arquivos=[PASTA/nome/f'{i:04d}.png' for i in range(info['quadros'])]
    frames=[Image.open(p).convert('RGB').resize((640,640),Image.Resampling.NEAREST) for p in arquivos]
    tempos=[max(10,(round((i+1)*info['duracao']*100/len(frames))-round(i*info['duracao']*100/len(frames)))*10) for i in range(len(frames))]
    # Ataques e morte repetem somente na demonstração; o recurso real é de execução única.
    frames[0].save(PASTA/(nome+'.gif'),save_all=True,append_images=frames[1:],duration=tempos,loop=0,disposal=2)
    folha=Image.new('RGB',(12*160,4*180),(32,40,39));d=ImageDraw.Draw(folha)
    for direcao in range(4):
        for q in range(12):
            arquivo=PASTA/nome/f'vista_{direcao}_{q:02d}.png'
            if arquivo.exists():
                folha.paste(Image.open(arquivo).convert('RGB'),(q*160,direcao*180))
                d.text((q*160+6,direcao*180+163),f'{nome} d{direcao} q{q}',fill='white')
    folha.save(PASTA/(nome+'_contato.png'))
print(f'{len(rel)} GIFs e contatos exportados com as durações do Godot.')
