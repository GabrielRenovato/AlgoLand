"""Organiza as capturas reais do escudo, sem alterar as poses do motor."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[3]
P=R/'arte/previas/personagens/base_3d/escudo_madeira'
F=ImageFont.load_default(size=16)
def celula(nome):
    return Image.open(P/f'{nome}.png').convert('RGBA').crop((35,25,115,125)).resize((200,250),Image.Resampling.NEAREST)
def exportar():
    poster=Image.new('RGB',(800,570),'#58645f');d=ImageDraw.Draw(poster)
    for linha,acao in enumerate(['costas','guarda']):
        for direcao in range(4):
            im=celula(f'{acao}_{direcao}');poster.paste(im,(direcao*200,linha*285+30),im)
            texto='NAS COSTAS' if linha==0 else 'GUARDA / APARO'
            box=d.textbbox((0,0),texto,font=F)
            d.text((direcao*200+(200-box[2])/2,linha*285+8),texto,font=F,fill='white')
    poster.save(P/'costas_e_guarda.png')
    dados=json.loads((P/'tempos.json').read_text());tempos=dados['erguer'];frames=[]
    for q in range(len(tempos)):
        frame=Image.new('RGB',(800,280),'#58645f');d=ImageDraw.Draw(frame)
        for direcao in range(4):
            im=celula(f'erguer_{direcao}_{q:02d}');frame.paste(im,(direcao*200,30),im)
            d.text((direcao*200+48,8),['FRENTE','DIREITA','COSTAS','ESQUERDA'][direcao],font=F,fill='white')
        frames.append(frame)
    duracoes=[round(tempos[i+1]*100)*10-round(tempos[i]*100)*10 for i in range(len(tempos)-1)]+[300]
    frames[0].save(P/'erguer_escudo.gif',save_all=True,append_images=frames[1:],duration=duracoes,loop=0,disposal=2)
    print('Escudo: costas/guarda e movimento de erguer nas quatro direções, a partir do filtro real.')
if __name__=='__main__':exportar()
