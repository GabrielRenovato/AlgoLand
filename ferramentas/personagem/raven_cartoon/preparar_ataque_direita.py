#!/usr/bin/env python3
"""Empacota os quatro desenhos completos, sem redesenhar ou escalar por pose."""
from pathlib import Path
import json
from PIL import Image

RAIZ = Path(__file__).resolve().parents[3]
FONTE = RAIZ/'arte/fontes/personagens/raven_cartoon/ataque_direita'
PREVIA = RAIZ/'arte/previas/personagens/raven_cartoon/ataque_direita'
ASSETS = RAIZ/'assets/personagens/raven_cartoon'
DURACOES = [160, 60, 70, 200]
CELULA = (640, 896)


def largura_calota(imagem):
    """Mede a calota acima das orelhas; braços e largura da passada não entram."""
    alfa = imagem.getchannel('A')
    topo = alfa.point(lambda v: 255 if v > 128 else 0).getbbox()[1]
    larguras = []
    for y in range(topo+40, topo+105):
        xs = [x for x in range(imagem.width) if alfa.getpixel((x, y)) > 128]
        if xs:
            larguras.append(max(xs)-min(xs)+1)
    return max(larguras)


def preparar(direcao='direita'):
    fonte = FONTE if direcao == 'direita' else FONTE.parent/f'ataque_{direcao}'
    previa = PREVIA if direcao == 'direita' else PREVIA.parent/f'ataque_{direcao}'
    nome = f'ataque_{direcao}'
    recurso = nome+'_sem_arma'
    previa.mkdir(parents=True, exist_ok=True)
    nome_fonte = {'cima': 'folha_corte_v2_intermediaria.png',
                  'baixo': 'folha_corte_mana_seed_v2.png',
                  'direita': 'folha_corte_mana_seed_v2.png'}[direcao]
    im = Image.open(fonte/nome_fonte).convert('RGBA')
    assert im.size == (1060, 1484)
    # Grade medida das fontes atuais; exceção da mão aberta traseira abaixo.
    caixas = [(0, 0, 530, 742), (530, 0, 1060, 742),
              (0, 742, 530, 1484), (530, 742, 1060, 1484)]
    # Raiz entre os apoios, marcada na fonte, independente da extensão do braço.
    raizes = [265, 260, 275, 275]
    pivo_x = 280
    if direcao in ['baixo', 'cima']:
        caixas = [(0, 0, 530, 742), (530, 0, 1060, 742),
                  (0, 742, 530, 1484), (530, 742, 1060, 1484)]
        raizes = [275, 270, 280, 280]
        pivo_x = 320
        if direcao == 'cima':
            # O braço aberto do segundo quadro atravessa a metade da folha.
            caixas = [(0, 0, 510, 742), (510, 0, 1060, 742),
                      (0, 742, 530, 1484), (530, 742, 1060, 1484)]
            raizes = [272, 295, 265, 265]
    referencia = {'baixo': 'referencia_frente.png', 'cima': 'referencia_costas.png',
                  'direita': 'referencia_perfil.png'}[direcao]
    modelo = Image.open(fonte/referencia).convert('RGBA')
    largura_base = largura_calota(modelo)
    pose_calibracao = im.crop(caixas[0])
    if direcao == 'baixo':
        pose_calibracao = Image.open(fonte/'preparacao_corte_corrigida_v2.png').convert('RGBA')
        assert pose_calibracao.size == (1060, 1484)
        pose_calibracao = pose_calibracao.resize((530, 742), Image.Resampling.LANCZOS)
    largura_fonte = largura_calota(pose_calibracao)
    # Uma escala para a sequência inteira, definida pela anatomia do canônico.
    # A altura da passada/posição dos braços não pode ampliar o personagem.
    escala = largura_base/largura_fonte
    atlas = Image.new('RGBA', (2560, 896))
    contato = Image.new('RGBA', (1280, 1792))
    quadros, dados = [], []
    for i, regiao in enumerate(caixas):
        regiao_fonte = regiao
        pose = im.crop(regiao)
        fonte_quadro = nome_fonte
        if direcao == 'baixo':
            if i == 0:
                pose = pose_calibracao
                fonte_quadro = 'preparacao_corte_corrigida_v2.png'
        if direcao in ['baixo', 'direita'] and i == 3:
            pose = im.crop(caixas[2])
            regiao_fonte = caixas[2]
        if direcao == 'cima' and i >= 2:
            # A pose isolada tem a mesma tela ampliada2x. Retornar à escala da fonte;
            # os dois tempos finais repetem o término do corte, como no Mana Seed.
            pose = Image.open(fonte/'pose_final_corte_v3.png').convert('RGBA')
            assert pose.size == (1060, 1484)
            pose = pose.resize((530, 742), Image.Resampling.LANCZOS)
            fonte_quadro = 'pose_final_corte_v3.png'
        bb = pose.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
        # A fonte pode ter margem curta; a célula final exige margem maior que15px.
        assert bb[0] >= 4 and bb[2] <= pose.width-4, (i, bb)
        pose = pose.resize((round(pose.width*escala), round(pose.height*escala)), Image.Resampling.LANCZOS)
        dx, dy = round(pivo_x-raizes[i]*escala), 850-round((bb[3]-1)*escala)
        quadro = Image.new('RGBA', CELULA)
        quadro.alpha_composite(pose, (dx, dy))
        limite = quadro.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
        assert limite[0] > 15 and limite[2] < 625 and limite[1] > 15 and limite[3] < 865, (i, limite)
        quadro.save(previa/f'quadro_{i+1:02d}.png')
        atlas.alpha_composite(quadro, (640*i, 0))
        contato.alpha_composite(quadro, ((i % 2)*640, (i//2)*896))
        quadros.append(quadro)
        dados.append({'quadro': i+1, 'fonte': fonte_quadro, 'recorte': regiao_fonte if fonte_quadro == nome_fonte else [0, 0, 1060, 1484], 'raiz_fonte_x': raizes[i],
                      'translacao': [dx, dy], 'limites': limite, 'duracao_ms': DURACOES[i]})
    largura_exportada = largura_calota(quadros[0])
    assert abs(largura_exportada-largura_base) <= 2, (direcao, largura_exportada, largura_base)
    atlas.save(ASSETS/f'{recurso}.png')
    atlas.save(previa/'quatro_quadros_juntos.png')
    contato.save(previa/'folha_ataque.png')
    frames = []
    for quadro in quadros:
        fundo = Image.new('RGBA', CELULA, '#ece7d8')
        fundo.alpha_composite(quadro)
        frames.append(fundo.resize((480, 672), Image.Resampling.LANCZOS).convert('RGB'))
    frames[0].save(previa/f'{nome}.gif', save_all=True, append_images=frames[1:], duration=DURACOES, loop=0, disposal=2)
    texto = ['[gd_resource type="SpriteFrames" load_steps=6 format=3]',
             f'[ext_resource type="Texture2D" path="res://assets/personagens/raven_cartoon/{recurso}.png" id="1"]']
    for i in range(4):
        texto.append(f'[sub_resource type="AtlasTexture" id="q{i}"]\natlas = ExtResource("1")\nregion = Rect2({640*i}, 0, 640, 896)\nfilter_clip = true')
    frames = ', '.join(f'{{"duration": {d/100}, "texture": SubResource("q{i}")}}' for i, d in enumerate(DURACOES))
    texto.append('[resource]\nanimations = [{"frames": ['+frames+'], "loop": false, "name": &"'+nome+'", "speed": 10.0}]')
    (ASSETS/f'{recurso}.tres').write_text('\n\n'.join(texto)+'\n')
    contrato = json.loads((fonte/'contrato.json').read_text())
    contrato.update({'fonte': nome_fonte, 'escala_unica': escala, 'quadros_exportados': dados,
                     'calibracao_escala': {'referencia': referencia, 'calota_base_px': largura_base,
                                          'calota_fonte_px': largura_fonte,
                                          'calota_exportada_px': largura_exportada,
                                          'metodo': 'mesma escala em todos os quadros; proporção da calota canônica'},
                     'duracoes_ms': DURACOES, 'pivo': [pivo_x, 850], 'celula': list(CELULA),
                     'observacao_tempo': '65ms/65ms aproximados por60ms/70ms, preservando490ms também no GIF',
                     'repeticao_previa': 'GIF repete quatro quadros para análise; recurso de ataque não repete',
                     'estado': 'empacotado para revisão visual no Godot'})
    (fonte/'contrato.json').write_text(json.dumps(contrato, ensure_ascii=False, indent=2)+'\n')
    print(f'Ataque {direcao}: quatro quadros, sem arma, 490ms, recurso não repetitivo.')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--direcao', choices=['direita', 'baixo', 'cima'], default='direita')
    preparar(parser.parse_args().direcao)
