"""Organiza capturas reais do Godot; não gera ou repinta o personagem."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parents[3]
PASTA = RAIZ / 'arte/previas/inimigos/lorde_goblin_3d'
try:
    fonte = ImageFont.truetype('DejaVuSans.ttf', 18)
except OSError:
    fonte_noto = Path.home()/'.local/share/fonts/google-noto/NotoSans-Regular.ttf'
    fonte = ImageFont.truetype(str(fonte_noto),18) if fonte_noto.exists() else ImageFont.load_default(size=18)
vistas = [
    ('frente', 'Frente'), ('tres_quartos_direita', 'Três quartos · direita'),
    ('perfil_direito', 'Perfil direito'), ('costas_direita', 'Costas · direita'),
    ('costas', 'Costas'), ('costas_esquerda', 'Costas · esquerda'),
    ('perfil_esquerdo', 'Perfil esquerdo'), ('tres_quartos_esquerda', 'Três quartos · esquerda'),
]
folha = Image.new('RGB', (1536, 832), '#e6e3d9')
desenho = ImageDraw.Draw(folha)
for i, (nome, rotulo) in enumerate(vistas):
    x, y = (i % 4)*384, (i // 4)*416
    imagem = Image.open(PASTA / (nome+'.png')).convert('RGB').resize((384,384), Image.Resampling.LANCZOS)
    folha.paste(imagem,(x,y))
    desenho.text((x+192,y+398),rotulo,font=fonte,fill='#242c29',anchor='mm')
folha.save(PASTA/'oito_vistas.png')

maos=Image.new('RGB',(768,832),'#e6e3d9')
desenho=ImageDraw.Draw(maos)
for i,(nome,rotulo) in enumerate([
        ('mao_direita_frente','Pegada · frente'),('mao_direita_obliqua','Pegada · lateral'),
        ('mao_esquerda_frente','Mão fechada · frente'),('mao_esquerda_obliqua','Mão fechada · lateral')]):
    x,y=i%2*384,i//2*416
    imagem=Image.open(PASTA/(nome+'.png')).convert('RGB').resize((384,384),Image.Resampling.LANCZOS)
    maos.paste(imagem,(x,y))
    desenho.text((x+192,y+398),rotulo,font=fonte,fill='#242c29',anchor='mm')
maos.save(PASTA/'maos.png')

quadros = [Image.open(p).convert('RGB') for p in sorted(PASTA.glob('parado_*.png'))]
contato = Image.new('RGB',(1120,1008),'#e6e3d9')
desenho = ImageDraw.Draw(contato)
for i, quadro in enumerate(quadros):
    x,y = i%5*224,i//5*252
    contato.paste(quadro,(x,y))
    desenho.text((x+112,y+237),f'{i*.4:.1f} s',font=fonte,fill='#242c29',anchor='mm')
contato.save(PASTA/'respiracao_contato.png')
# A amostra em 6,4 s confere o fechamento; o GIF usa 16 intervalos de 400 ms.
animacao = [q.resize((448,448),Image.Resampling.NEAREST) for q in quadros[:16]]
animacao[0].save(PASTA/'respiracao.gif',save_all=True,append_images=animacao[1:],
                 duration=400,loop=0,disposal=2,optimize=False)
print('Oito vistas e dois ciclos de respiração organizados.')
