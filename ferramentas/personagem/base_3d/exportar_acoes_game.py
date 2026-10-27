"""Compõe as capturas reais do Godot; não altera o desenho nem recentraliza poses."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
R = Path(__file__).resolve().parents[3]
P = R/'arte/previas/personagens/base_3d/acoes_game'
F = ImageFont.load_default(size=16)
FUNDO = '#58645f'

def quadro(acao, direcao, q):
    return Image.open(P/f'{acao}_{direcao}_{q:02d}.png').convert('RGBA').crop((35, 25, 115, 125))

def exportar():
    tempos = json.loads((P/'tempos.json').read_text())
    contato = Image.new('RGB', (1440, 8*182), FUNDO)
    d = ImageDraw.Draw(contato)
    for a, acao in enumerate(['machado', 'plantar']):
        frames = []
        for q in range(12):
            frame = Image.new('RGB', (800, 285), FUNDO)
            draw = ImageDraw.Draw(frame)
            for direcao, nome in enumerate(['FRENTE', 'DIREITA', 'COSTAS', 'ESQUERDA']):
                im = quadro(acao, direcao, q).resize((200, 250), Image.Resampling.NEAREST)
                frame.paste(im, (direcao*200, 30), im)
                box = draw.textbbox((0, 0), nome, font=F)
                draw.text((direcao*200+(200-box[2])/2, 8), nome, font=F, fill='white')
                row = a*4+direcao
                pequeno = quadro(acao, direcao, q).resize((120, 150), Image.Resampling.NEAREST)
                contato.paste(pequeno, (q*120, row*182+28), pequeno)
                d.text((q*120+4, row*182+4), f'{acao} {direcao}/{q+1:02d}', font=F, fill='white')
            frames.append(frame)
        duracao = tempos[acao]
        duracoes = [round((q+1)*duracao*100/12)*10-round(q*duracao*100/12)*10 for q in range(12)]
        nome = 'corte_duas_maos.gif' if acao == 'machado' else 'plantar_mana_seed.gif'
        frames[0].save(P/nome, save_all=True, append_images=frames[1:], duration=duracoes, loop=0, disposal=2)
    contato.save(P/'quadros_acoes.png')
    # Mesmo fator de ampliação por pixel de mundo nas três referências.
    poster = Image.new('RGB', (960, 370), FUNDO)
    draw = ImageDraw.Draw(poster)
    mana = Image.open(R/'arte/fontes/personagens/prototipo/base_mana_seed/andar.png').convert('RGBA').crop((0,0,64,64))
    m = Image.new('RGBA',(80,80)); m.paste(mana,(8,8),mana)
    raven = Image.new('RGBA',(80,80))
    for parte in ['corpo_1','camisa_azul','cabelo_21']:
        raven.alpha_composite(Image.open(R/f'assets/personagens/raven_fantasy/web/{parte}/parado.png').convert('RGBA').crop((0,0,80,80)))
    modelo = Image.open(R/'arte/previas/personagens/base_3d/teste_pixel_art/pixel_parado_0.png').convert('RGBA').resize((80,80),Image.Resampling.NEAREST)
    for i,(im,nome) in enumerate([(m,'MANA SEED'),(raven,'RAVEN'),(modelo,'MODELO 3D / SEM BORDA AUTOMATICA')]):
        im=im.resize((320,320),Image.Resampling.NEAREST);poster.paste(im,(i*320,42),im)
        box=draw.textbbox((0,0),nome,font=F)
        draw.text((i*320+(320-box[2])/2,15),nome,font=F,fill='white')
    poster.save(P/'referencias_acabamento.png')
    print('Prévias compostas das capturas do motor: dois GIFs nos tempos reais, quatro direções e referências de acabamento.')

if __name__ == '__main__': exportar()
