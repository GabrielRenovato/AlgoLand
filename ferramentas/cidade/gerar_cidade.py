#!/usr/bin/env python3
"""Gera a vila com Mana Seed original e os interiores cadastrados. Determinístico.
Uso: python3 ferramentas/cidade/gerar_cidade.py [interiores]   (com "interiores" só refaz as casas, depois de layout_interiores.py)
"""
from pathlib import Path
import sys
import random
import json

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / 'ferramentas/fazenda'))
import gerar_fazenda as F
G, D = F.G, F.D
RNG = random.Random(1401026)
PREDIOS = {
    'carpintaria': ('CASA E OFICINA DE OSVALDO', 816, 224, 'Color(1, 1, 1, 1)'),
    'forja': ('FORJA DO IVO', 192, 112, 'Color(1, 0.9, 0.8, 1)'),
    'venda': ('VENDA DO TOMAS', 240, 184, 'Color(1, 0.95, 0.85, 1)'),
    'sede': ('CASA DA COMUNIDADE', 480, 184, 'Color(0.92, 0.94, 1, 1)'),
    'enfermaria': ('ENFERMARIA', 720, 184, 'Color(1, 0.86, 0.83, 1)'),
    'pousada': ('POUSADA DO CORETO', 240, 456, 'Color(1, 0.94, 0.78, 1)'),
    'mistica': ('CASA DA MISTICA', 720, 456, 'Color(0.87, 0.85, 1, 1)'),
    'casa_bento': ('CASA DO BENTO', 480, 584, 'Color(0.88, 1, 0.85, 1)'),
}


def comuns(c, local, titulo, pos=(480, 392), limites=(704, 576)):
    script = c.recurso('Script', 'res://codigo/cidade/cidade.gd', 'cidade_script')
    jogador = c.recurso('PackedScene', 'res://cenas/jogador.tscn', 'jogador')
    ui = c.recurso('PackedScene', 'res://cenas/ui.tscn', 'ui')
    interface = c.recurso('PackedScene', 'res://cenas/ui/interface.tscn', 'interface')
    luz = c.recurso('Script', 'res://codigo/efeitos/iluminacao.gd', 'luz')
    vinheta = c.recurso('PackedScene', 'res://cenas/efeitos/vinheta.tscn', 'vinheta')
    c.no('cidade' if local == 'cidade' else local, 'Node2D', raiz=True, props=[
        f'script = ExtResource("{script}")', f'local = "{local}"',
        f'limites = Rect2(0, 0, {limites[0]}, {limites[1]})', f'metadata/titulo_hud = "{titulo}"'])
    return jogador, ui, interface, luz, vinheta, pos


def finalizar(c, recursos):
    jogador, ui, interface, luz, vinheta, pos = recursos
    c.no('Jogador', '', instancia=jogador, props=[f'position = {F.vec(*pos)}', 'collision_mask = 96'])
    c.no('Iluminacao', 'Node', props=[f'script = ExtResource("{luz}")'])
    c.no('CanvasModulate', 'CanvasModulate', 'Iluminacao')
    c.no('Vinheta', '', instancia=vinheta, props=['layer = 1'])
    c.no('assets/ui', '', instancia=ui)
    c.no('Interface', '', instancia=interface)


def colisao(c, nome, x0, y0, x1, y1):
    ident = 'Forma_' + nome
    c.sub_recurso('RectangleShape2D', ident, [f'size = {F.vec(x1-x0, y1-y0)}'])
    c.no(nome, 'CollisionShape2D', 'Obstaculos', [f'position = {F.vec((x0+x1)/2, (y0+y1)/2)}', f'shape = SubResource("{ident}")'])


def passagem(c, nome, pos, destino, chegada, automatica=False, saida=None):
    script = c.recurso('Script', 'res://codigo/cidade/passagem_cidade.gd', 'passagem')
    c.no(nome, 'Area2D', props=[f'position = {F.vec(*pos)}', f'script = ExtResource("{script}")',
        f'cena_destino = "res://cenas/{destino}.tscn"', f'ponto_chegada = "{chegada}"', 'so_entre_ondas = false']
        + (['automatica = true'] if automatica else []) + ([f'direcao_saida = {F.vec(*saida)}'] if saida else []))
    c.no('Forma', 'CollisionShape2D', nome, ['shape = SubResource("Forma_porta")'])


def placa(c, nome, pos, texto, pai='Terrains'):
    """Placa que mostra o destino num balão quando o jogador chega perto (codigo/cidade/placa_local.gd)"""
    script = c.recurso('Script', 'res://codigo/cidade/placa_local.gd', 'placa_local')
    c.no(nome, 'Node2D', pai, [f'position = {F.vec(*pos)}', f'script = ExtResource("{script}")', f'texto = "{texto}"'])


def rotulo(c, nome, pos, texto, pai='Terrains'):
    c.no(nome, 'Label', pai, [f'offset_left = {pos[0]-80}.0', f'offset_top = {pos[1]}.0',
        f'offset_right = {pos[0]+80}.0', f'offset_bottom = {pos[1]+20}.0', 'mouse_filter = 2',
        'theme_override_font_sizes/font_size = 7', 'theme_override_colors/font_color = Color(1, 0.91, 0.7, 1)',
        'theme_override_colors/font_shadow_color = Color(0.16, 0.11, 0.1, 1)',
        'theme_override_constants/shadow_offset_x = 1', 'theme_override_constants/shadow_offset_y = 1',
        f'text = "{texto}"', 'horizontal_alignment = 1'])


def exterior():
    import math
    import gerar_tilesets as Kit
    layout=json.loads((RAIZ/'codigo/cidade/layout_vila.json').read_text())
    predios=layout['predios']; w,h=layout['tamanho']; tw,th=w//16,h//16
    praca=layout['praca'];coreto=layout['coreto'];poco=layout['poco']
    c=F.Cena();res=comuns(c,'cidade','VILA DAS FLORES',(392,360),limites=(w,h))
    prof=c.recurso('Script','res://codigo/cenario/profundidade_grupo.gd','prof')
    est=c.recurso('Script','res://codigo/cenario/estacoes.gd','estacoes')
    adorno=c.recurso('Script','res://codigo/cidade/adorno.gd','adorno')
    c.sub_recurso('RectangleShape2D','Forma_porta',['size = Vector2(28, 28)'])
    c.no('Terrains','Node2D',props=['texture_filter = 1'])
    # Terreno todo em tiles do PixelLab no padrão Mana Seed (ferramentas/cidade/gerar_transicoes.gd): grama, terra, pedra e água
    # com bordas por cantos; cidade.gd troca as folhas por estação e anima a água
    import terreno_vila as TV
    tileset=c.recurso('TileSet','res://recursos/cidade/tileset_terreno.tres','tileset_terreno')
    Kit.camada(c,'Terreno',TV.mapa(predios,tw,th),tileset,'Terrains',z=-1000)
    def margem_rio(y,lado):return (round(TV.margem_rio(y)+lado*(TV.MEIA_LARGURA_RIO-2)),y)
    ys=range(0,h+1,16)
    lago=[(round(TV.LAGO[0]+(TV.RAIO_LAGO[0]-8)*math.cos(i*math.tau/32)),round(TV.LAGO[1]+(TV.RAIO_LAGO[1]-6)*math.sin(i*math.tau/32))) for i in range(32)]
    c.no('Construcoes','Node2D','Terrains')
    c.no('Objetos3D','Node2D','Terrains',[f'script = ExtResource("{prof}")'])
    c.no('Obstaculos','StaticBody2D',props=['collision_layer = 64','collision_mask = 0'])
    # Cada casa é uma imagem inteira gerada no PixelLab (codigo/cidade/casa_exterior.gd): a colisão, a âncora na porta, as janelas
    # acesas à noite e a fumaça vêm de assets/cenario/cidade/casas/exteriores.json. As construções modulares antigas
    # (recursos/cidade/construcoes) ficam só como fonte.
    casa=c.recurso('Script','res://codigo/cidade/casa_exterior.gd','casa_exterior')
    for ident,p in predios.items():
        bx,by=p['base']
        c.no(ident.capitalize(),'Node2D','Terrains/Construcoes',[f'script = ExtResource("{casa}")',f'id = "{ident}"',f'position = {F.vec(bx,by)}'])
        passagem(c,'Porta_'+ident,(bx,by+12),'cidade/'+ident,'entrada')
        c.no('Chegada_'+ident,'Marker2D',props=[f'position = {F.vec(bx,by+42)}'],grupos=['chegada'])
    # O rio só deixa passar na ponte, no fim da rua principal
    for nome,y0,y1 in [('RioNorte',0,248),('RioSul',296,h)]:
        ys=range(y0,y1+1,16)
        pontos=[margem_rio(y,-1) for y in ys]+list(reversed([margem_rio(y,1) for y in ys]))
        c.no(nome,'CollisionPolygon2D','Obstaculos',['polygon = '+F.T.poligono(pontos)])
    c.no('Lago','CollisionPolygon2D','Obstaculos',['polygon = '+F.T.poligono(lago)])
    c.no('EnfeitesFesta','Node2D','Terrains')
    c.no('Bandeiras','Node2D','Terrains/EnfeitesFesta',[f'script = ExtResource("{adorno}")','tipo = "bandeiras"','position = Vector2(336, 212)'])
    for nome,caixa in [('Norte',(0,-32,w,14)),('SulOeste',(0,h-14,308,h+32)),('SulLeste',(364,h-14,w,h+32)),('OesteNorte',(-32,0,14,248)),('OesteSul',(-32,296,14,h)),('Leste',(w-14,0,w+32,h))]:colisao(c,nome,*caixa)
    passagem(c,'TrilhaPraia',(336,h-20),'praia','cidade',saida=(0,1))
    c.no('Chegada_praia','Marker2D',props=[f'position = {F.vec(336,h-56)}'],grupos=['chegada'])
    placa(c,'PlacaPraia',(310,h-34),'PRAIA')
    passagem(c,'TrilhaFazenda',layout['entrada_fazenda'],'fazenda','cidade',saida=(-1,0))
    c.no('Chegada_fazenda','Marker2D',props=['position = Vector2(48, 272)'],grupos=['chegada'])
    # A arena só se alcança pelo portal (codigo/cidade/portal_arena.gd, montado por cidade.gd); quem volta dela chega em "portal"
    c.no('Chegada_portal','Marker2D',props=['position = Vector2(488, 136)'],grupos=['chegada'])
    placa(c,'PlacaFazenda',(84,300),'FAZENDA')
    c.no('Estacoes','Node','Terrains',[f'script = ExtResource("{est}")','seguir_calendario = true'])
    finalizar(c,res)
    return c.texto()

def interior(ident):
    """Sala e móveis vêm do PixelLab; codigo/cidade/interior_casa.gd monta tudo a partir de interiores.json."""
    layout=json.loads((RAIZ/'assets/cenario/cidade/interiores/interiores.json').read_text())
    geo=layout['casas'][ident]['geometria']
    c=F.Cena()
    titulo=PREDIOS[ident][0]
    res=comuns(c,ident,titulo,tuple(geo['chegada']),(geo['recorte'][2],geo['recorte'][3]))
    interior_script=c.recurso('Script','res://codigo/cidade/interior_casa.gd','interior')
    c.sub_recurso('RectangleShape2D','Forma_porta',['size = Vector2(40, 16)'])
    c.no('Fundo','ColorRect',props=['z_index = -1001','offset_left = -1000.0','offset_top = -1000.0','offset_right = 1000.0','offset_bottom = 1000.0','mouse_filter = 2','color = Color(0.075, 0.07, 0.105, 1)'])
    c.no('Interior','Node2D',props=[f'script = ExtResource("{interior_script}")',f'id = "{ident}"'])
    # Sai sozinho ao pisar no vão da porta
    passagem(c,'Saida',tuple(geo['saida']),'cidade',ident,automatica=True)
    c.no('Chegada_entrada','Marker2D',props=[f'position = {F.vec(*geo["chegada"])}'],grupos=['chegada'])
    if ident == 'pousada':
        cama=layout['casas'][ident]['pontos']['cama']
        interacao = c.recurso('Script', 'res://codigo/logica/interagivel.gd', 'interacao_cama')
        c.no('Cama', 'Area2D', props=[f'position = {F.vec(cama[0], cama[1]-20)}', f'script = ExtResource("{interacao}")', 'nome_tela = "dormir"', 'so_entre_ondas = false'])
        c.sub_recurso('RectangleShape2D','Forma_cama',['size = Vector2(52, 50)'])
        c.no('Forma', 'CollisionShape2D', 'Cama', ['shape = SubResource("Forma_cama")'])
        c.no('Chegada_cama', 'Marker2D', props=[f'position = {F.vec(cama[0], cama[1])}'], grupos=['chegada'])
    finalizar(c,res)
    return c.texto()


def so_interiores():
    for ident in PREDIOS:
        (RAIZ/'cenas/cidade'/f'{ident}.tscn').write_text(interior(ident))
    print(f'{len(PREDIOS)} interiores gerados.')

def liberar_saida_praia():
    """Preserva a decoração existente e libera só o corredor acrescentado ao sul."""
    caminho = RAIZ / 'assets/cenario/cidade/decoracao/decoracao.json'
    itens = json.loads(caminho.read_text())
    livres = [i for i in itens if not (i['y'] >= 464 and
        i['x'] + i['usado'][2] / 2 > 312 and i['x'] - i['usado'][2] / 2 < 360)]
    if len(livres) != len(itens):
        caminho.write_text(json.dumps(livres, indent=1) + '\n')

def main():
    if 'interiores' in sys.argv[1:]:
        return so_interiores()
    import gerar_tilesets as Kit
    Kit.gerar_tileset()
    liberar_saida_praia()
    from decorar_quintal_carpinteiro import atualizar
    atualizar()
    RNG.seed(1401026)
    G.RNG = RNG
    (RAIZ/'cenas/cidade.tscn').write_text(exterior())
    for ident in PREDIOS:
        (RAIZ/'cenas/cidade'/f'{ident}.tscn').write_text(interior(ident))
    print(f'Cidade e {len(PREDIOS)} interiores gerados.')

if __name__=='__main__':
    main()
