#!/usr/bin/env python3
"""Recorta o Raven 3.0 sem escala, deformação ou recentralização por pose."""
from pathlib import Path
from PIL import Image
import io, json, zipfile, shutil

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / 'arte/fontes/personagens/raven_fantasy'
SAIDA = RAIZ / 'assets/personagens/raven_fantasy'
PACOTES = {'base': 'RAVENF~1.ZIP', 'roupa': 'Raven Fantasy - Pixelart Top Down Character - Adventurer Set 3.0.zip', 'cabelos': 'Raven Fantasy - Pixelart Top Down Character - Hairstyles.zip'}

def pacote(chave):
    alvo = FONTES / (chave + '.zip')
    if not alvo.exists():
        shutil.copy2(Path.home() / 'Downloads' / PACOTES[chave], alvo)
    return zipfile.ZipFile(alvo)

def imagem(z, fim):
    nome = next(n for n in z.namelist() if n.endswith(fim))
    return Image.open(io.BytesIO(z.read(nome))).convert('RGBA')

# Origem interna das molduras; as colunas originais são baixo/direita/cima/esquerda.
# Cada linha de origem é um instante, não uma direção.
ACOES = {
    'andar': (96,64,None), 'parado': (336,64,None), 'correr': (576,64,None),
    'pular': (1056,64,None), 'morrer': (1296,64,None),
    'carregar': (96,384,None), 'jogar': (336,384,None),
    'empurrar': (576,384,None), 'puxar': (816,384,None), 'esquiva': (1056,384,None),
    'espada': (96,704,'Basic Sword.png'), 'espada_2': (336,704,'Basic Sword.png'),
    'espada_dupla': (576,704,'Two Handed Sword.png'),
    'machado': (96,1024,'Two Handed Axe.png'),
    'conjurar': (336,1024,'Conjure.png'), 'magia': (576,1024,'Magic.png'),
    'bloquear': (96,1344,'Shield Above.png'), 'andar_escudo': (336,1344,'Shield Above.png'),
    'arco': (576,1344,'Bow.png'), 'picareta': (96,1664,'Pickaxe.png'),
    'pa': (336,1664,'Shovel.png'), 'enxada': (576,1664,'Hoe.png'),
    'regar': (816,1664,'Watering Can.png'), 'pescar': (1056,1664,'Fishing Rod.png'),
    'lanca': (880,864,'Spear.png'),
    # Ações de gameplay que reutilizam os gestos correspondentes do Raven:
    # semear = lançar da mão; colher = puxar; forjar = impacto de ferramenta.
    'plantar': (336,384,None), 'colher': (816,384,None),
    'forjar': (96,1664,None), 'sentado': (336,64,None),
    'ferido': (576,384,None),
}

def preparar():
    SAIDA.mkdir(parents=True, exist_ok=True)
    base = pacote('base')
    # Preserva os complementos adquiridos, sem aplicá-los ao corpo base.
    pacote('roupa')
    pacote('cabelos')
    camadas = [imagem(base,'Base/Skin 1.png')]
    dados = {}
    pontas_pesca = []
    for nome,(x,y,extra) in ACOES.items():
        largura,altura = (80,80) if nome == 'lanca' else (48,64)
        folha = Image.new('RGBA',(320,320))
        ferramenta = imagem(base,'Extras/'+extra) if extra else None
        for direcao in range(4):
            for quadro in range(4):
                origem_quadro = 2 if nome == 'pescar' and direcao == 2 and quadro == 3 else quadro
                caixa = (x+direcao*largura,y+origem_quadro*altura,x+(direcao+1)*largura,y+(origem_quadro+1)*altura)
                celula = Image.new('RGBA',(80,80))
                deslocamento = (0,0) if nome == 'lanca' else (16,0)
                if nome in ['bloquear','andar_escudo']:
                    escudo = imagem(base,'Extras/Shield back.png')
                    ex = 48 + (240 if nome == 'andar_escudo' else 0)
                    celula.alpha_composite(escudo.crop((ex+direcao*48,64+quadro*64,ex+(direcao+1)*48,64+(quadro+1)*64)),deslocamento)
                for camada in camadas:
                    celula.alpha_composite(camada.crop(caixa),deslocamento)
                if ferramenta:
                    ex,ey = (16,16) if nome == 'lanca' else (48,64)
                    if nome in ['espada_2','andar_escudo']: ex += 240
                    # O escudo frontal fica acima do cabelo, conforme as instruções do autor.
                    recorte = ferramenta.crop((ex+direcao*largura,ey+origem_quadro*altura,ex+(direcao+1)*largura,ey+(origem_quadro+1)*altura))
                    if nome not in ['bloquear','andar_escudo']: celula.alpha_composite(recorte,deslocamento)
                if nome in ['bloquear','andar_escudo']: celula.alpha_composite(recorte,deslocamento)
                folha.alpha_composite(celula,(quadro*80,direcao*80))
        folha.save(SAIDA/(nome+'.png'))
        if nome == 'pescar':
            for direcao in range(4):
                pontos = []
                for quadro in range(4):
                    q = 2 if direcao == 2 and quadro == 3 else quadro
                    recorte = ferramenta.crop((48+direcao*48,64+q*64,96+direcao*48,128+q*64))
                    pixels = [(px,py) for py in range(64) for px in range(48) if recorte.getpixel((px,py))[3] > 127]
                    ponta = max(pixels or [(24,32)],key=lambda p: (p[0]-24)**2+(p[1]-40)**2)
                    pontos.append([ponta[0]-24,ponta[1]-47+11])
                pontas_pesca.append(pontos)
        dados[nome] = {'folha': 'res://assets/personagens/raven_fantasy/'+nome+'.png', 'quadros':4, 'duracao': 0.6 if nome in ['andar','correr','andar_escudo'] else 0.8}
    (SAIDA/'pontas_pesca.json').write_text(json.dumps(pontas_pesca)+'\n')
    (SAIDA/'animacoes.json').write_text(json.dumps(dados,indent=2)+'\n')
    contrato = {'origem':'Clockwork Raven, base e Adventurer Set 3.0 + Hairstyles adquiridos pelo usuário', 'modelo':'Corpo base original Skin 1, sem roupa, capa ou cabelo; ferramentas originais nas ações correspondentes', 'celula_origem':[48,64], 'celula_lanca':[80,80], 'celula_destino':[80,80], 'pivo':[40,47], 'direcoes':['baixo','direita','cima','esquerda'], 'transformacao':'Translação fixa x=16 nas células 48x64; sem escala, sem recorte pela silhueta', 'destino':'Somente Jogador; não alterar Aparencia nem NPCs', 'acoes':ACOES}
    (FONTES/'contrato.json').write_text(json.dumps(contrato,ensure_ascii=False,indent=2)+'\n')
    print(f'{len(dados)} animações exportadas; 4 direções × 4 quadros, sem redimensionamento.')

if __name__ == '__main__': preparar()
