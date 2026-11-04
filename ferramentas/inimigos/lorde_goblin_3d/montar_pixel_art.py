"""Amplia a renderização nativa do Godot em 3x, sem interpolar os pixels."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
P=Path(__file__).resolve().parents[3]/'arte/previas/inimigos/lorde_goblin_3d/animacoes/pixel_art'
dados=json.loads((P/'revisao_animacoes.json').read_text())
font=ImageFont.load_default(size=18)
for nome,info in dados.items():
    if not isinstance(info,dict) or 'quadros' not in info:continue
    frames=[Image.open(P/f['arquivo']).convert('RGB').resize((672,672),Image.Resampling.NEAREST) for f in info['quadros']]
    dur=[round((b['tempo_s']-a['tempo_s'])*1000) for a,b in zip(info['quadros'],info['quadros'][1:])]
    frames[0].save(P/(nome+'.gif'),save_all=True,append_images=frames[1:-1],duration=dur,loop=0,disposal=2,optimize=False)
    i=round((float(info['duracao_s'])*.5)*20)
    frames[i].save(P/(nome+'_pixel_art.png'))
    sheet=Image.new('RGB',(672*3,710),'#ece8df');draw=ImageDraw.Draw(sheet)
    for k,frac in enumerate([.25,.45,.65]):
        sheet.paste(frames[min(len(frames)-1,round(frac*len(frames)))],(k*672,0));draw.text((k*672+16,682),f'{nome} · {frac*info["duracao_s"]:.2f}s',font=font,fill='#333333')
    sheet.save(P/(nome+'_poses.png'))
(P/'LEIAME.md').write_text('Renderização real do Godot a224x224, MSAA desligado, mesma câmera e origem.\nAmpliação3x por nearest-neighbor. Personagem, martelo, sombra, anéis e tornado\npassam pela mesma grade. GIFs a20FPS preservam os tempos amostrados do motor.\nPrévia de aparência solicitada; não altera a IA2D nem a partida.\n')
print('Três prévias pixel art exportadas, nativas224² e ampliação3x nearest.')
