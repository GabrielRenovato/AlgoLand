"""Monta capturas reais do Godot sem sintetizar poses nem mudar o enquadramento."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
ROOT=Path(__file__).resolve().parents[3]
P=ROOT/'arte/previas/inimigos/lorde_goblin_3d/animacoes'
data=json.loads((P/'revisao_animacoes.json').read_text())
try:
    font=ImageFont.truetype('DejaVuSans.ttf',16)
except OSError:
    font=ImageFont.truetype(str(Path.home()/'.local/share/fonts/google-noto/NotoSans-Regular.ttf'),16)
for nome,info in data.items():
    frames=[Image.open(P/f['arquivo']).convert('RGB') for f in info['quadros']]
    if not frames:continue
    # A amostra final fecha o intervalo e não acrescenta pausa artificial ao GIF.
    dur=[round((b['tempo_s']-a['tempo_s'])*1000) for a,b in zip(info['quadros'],info['quadros'][1:])]
    frames[0].save(P/(nome+'.gif'),save_all=True,append_images=frames[1:-1],duration=dur,loop=0,disposal=2,optimize=False)
    selecionados=list(range(0,len(frames),2))
    if selecionados[-1]!=len(frames)-1:selecionados.append(len(frames)-1)
    w,h=240,266;sheet=Image.new('RGB',(w*6,48+h*((len(selecionados)+5)//6)),'#ece8df');d=ImageDraw.Draw(sheet)
    d.text((14,15),nome.replace('_',' ')+' • amostras a cada 0,10 s • Godot',font=font,fill='#333333')
    for n,i in enumerate(selecionados):
        im=frames[i].resize((w,w),Image.Resampling.LANCZOS);x=n%6*w;y=48+n//6*h;sheet.paste(im,(x,y));d.text((x+12,y+243),f'{info["quadros"][i]["tempo_s"]:.2f} s',font=font,fill='#333333')
    sheet.save(P/(nome+'_contato.jpg'),quality=92)
    # Poses frontais e laterais em escala maior para revisão de contatos.
    for tipo in ['pose','lateral']:
        files=sorted(P.glob(nome+'_'+tipo+'_*.png'));w,h=360,386
        sheet=Image.new('RGB',(w*4,h*((len(files)+3)//4)),'#ece8df');d=ImageDraw.Draw(sheet)
        for i,f in enumerate(files):
            im=Image.open(f).resize((w,w),Image.Resampling.LANCZOS);x=i%4*w;y=i//4*h;sheet.paste(im,(x,y));d.text((x+12,y+363),f.stem,font=font,fill='#333333')
        sheet.save(P/(nome+'_'+tipo+'s.jpg'),quality=92)
print('3 GIFs e 9 folhas de contato montados a partir das capturas do Godot.')
