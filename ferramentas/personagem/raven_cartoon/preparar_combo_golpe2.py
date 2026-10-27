#!/usr/bin/env python3
"""Empacota os desenhos novos do Slash2, com escala única e apoios marcados."""
from pathlib import Path
import json
from PIL import Image
from preparar_ataque_direita import largura_calota

RAIZ = Path(__file__).resolve().parents[3]
FONTE = RAIZ/'arte/fontes/personagens/raven_cartoon/combo_golpe2'
ASSETS = RAIZ/'assets/personagens/raven_cartoon'
PREVIA = RAIZ/'arte/previas/personagens/raven_cartoon/combo_golpe2'
TEMPOS = [160, 60, 70, 200]
MARCAS = {
    'direita': {'raizes': [265, 270, 300], 'chao': [730, 730, 708], 'pivo': 280, 'modelo': 'perfil'},
    'baixo': {'raizes': [285, 255, 305], 'chao': [687, 685, 695], 'pivo': 320, 'modelo': 'frente'},
    'cima': {'raizes': [250, 270, 310], 'chao': [683, 679, 662], 'pivo': 320, 'modelo': 'costas'},
}


def preparar():
    contrato = json.loads((FONTE/'contrato.json').read_text())
    contrato['empacotamento'] = {}
    for direcao, marcas in MARCAS.items():
        previa = PREVIA/direcao
        previa.mkdir(parents=True, exist_ok=True)
        fonte = Image.open(FONTE/f'folha_{direcao}_v1.png').convert('RGBA')
        assert fonte.size == (1060, 1484)
        # A ponta do pé do terceiro desenho cruza a metade em poucos pixels.
        # A quarta pose gerada não é usada: sustentamos exatamente a terceira.
        caixas = [(0, 0, 530, 742), (530, 0, 1060, 742), (0, 742, 540, 1484)]
        modelo = Image.open(FONTE.parent/f'ataque_{direcao}'/f'referencia_{marcas["modelo"]}.png').convert('RGBA')
        largura_base = largura_calota(modelo)
        largura_fonte = largura_calota(fonte.crop(caixas[0]))
        escala = largura_base/largura_fonte
        # A faixa de medição é em pixels finais: compensar sua mudança na escala.
        calibracao = fonte.crop(caixas[0])
        for _ in range(5):
            medida = largura_calota(calibracao.resize((round(calibracao.width*escala), round(calibracao.height*escala)), Image.Resampling.LANCZOS))
            if abs(medida-largura_base) <= 1:
                break
            escala *= largura_base/medida
        atlas = Image.new('RGBA', (2560, 896))
        contato = Image.new('RGBA', (1280, 1792))
        quadros, exportados = [], []
        for q in range(4):
            n = min(q, 2)
            pose = fonte.crop(caixas[n])
            pose = pose.resize((round(pose.width*escala), round(pose.height*escala)), Image.Resampling.LANCZOS)
            dx = round(marcas['pivo']-marcas['raizes'][n]*escala)
            dy = round(850-marcas['chao'][n]*escala)
            quadro = Image.new('RGBA', (640, 896))
            quadro.alpha_composite(pose, (dx, dy))
            limites = quadro.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
            assert limites[0] > 15 and limites[2] < 625 and limites[1] > 15 and limites[3] < 865, (direcao, q, limites)
            quadro.save(previa/f'quadro_{q+1:02}.png')
            atlas.alpha_composite(quadro, (q*640, 0))
            contato.alpha_composite(quadro, (q % 2*640, q//2*896))
            quadros.append(quadro)
            exportados.append({'quadro': q+1, 'recorte': caixas[n], 'raiz_fonte': [marcas['raizes'][n], marcas['chao'][n]], 'translacao': [dx, dy], 'limites': limites})
        assert abs(largura_calota(quadros[0])-largura_base) <= 2
        assert quadros[2].tobytes() == quadros[3].tobytes()
        nome = f'ataque2_{direcao}_sem_arma'
        atlas.save(ASSETS/f'{nome}.png')
        contato.save(previa/'folha_corpo.png')
        texto = ['[gd_resource type="SpriteFrames" load_steps=6 format=3]',
                 f'[ext_resource type="Texture2D" path="res://assets/personagens/raven_cartoon/{nome}.png" id="1"]']
        for q in range(4):
            texto.append(f'[sub_resource type="AtlasTexture" id="q{q}"]\natlas = ExtResource("1")\nregion = Rect2({q*640}, 0, 640, 896)\nfilter_clip = true')
        frames = ', '.join(f'{{"duration": {d/100}, "texture": SubResource("q{q}")}}' for q, d in enumerate(TEMPOS))
        texto.append('[resource]\nanimations = [{"frames": ['+frames+'], "loop": false, "name": &"ataque2_'+direcao+'", "speed": 10.0}]')
        (ASSETS/f'{nome}.tres').write_text('\n\n'.join(texto)+'\n')
        contrato['empacotamento'][direcao] = {'escala_unica': escala, 'calota_base': largura_base, 'calota_fonte': largura_fonte, 'pivo': [marcas['pivo'], 850], 'quadros': exportados}
    (FONTE/'contrato.json').write_text(json.dumps(contrato, ensure_ascii=False, indent=2)+'\n')
    print('Slash2: três direções novas; quatro quadros cada; escala constante e término sustentado.')


if __name__ == '__main__':
    preparar()
