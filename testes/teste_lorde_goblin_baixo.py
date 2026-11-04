"""Confere o atlas frontal e reproduz dois golpes no Godot sem autoloads/saves."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

RAIZ=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(RAIZ/'ferramentas/projeto'))
from harness import motor_godot

def main():
    direcao=os.environ.get('ALGOLAND_LORDE_DIRECAO','baixo')
    if direcao not in ('baixo','cima','direita'): raise ValueError('Direcao invalida')
    pasta=Path(tempfile.mkdtemp(prefix=f'algoland-lorde-{direcao}-'))
    (pasta/'project.godot').write_text('''config_version=5
[application]
config/name="AlgoLand testes Lorde baixo"
config/use_custom_user_dir=true
config/custom_user_dir_name="AlgoLand testes Lorde baixo"
[display]
window/size/viewport_width=640
window/size/viewport_height=640
[rendering]
renderer/rendering_method="gl_compatibility"
environment/defaults/default_clear_color=Color(0.16,0.2,0.21,1)
''')
    fontes=RAIZ/'arte/fontes/inimigos/lorde_goblin_2d'
    ficha=json.loads((fontes/f'registro_martelada_{direcao}.json').read_text())
    fonte=fontes/ficha['folha_final']
    paleta=json.loads((fontes/f'revisao_paleta_{direcao}.json').read_text())
    efeitos=os.environ.get('ALGOLAND_LORDE_EFEITOS')=='1'
    if efeitos:
        shutil.copyfile(RAIZ/'codigo/efeitos/impacto_marreta_lorde_2d.gd',pasta/'impacto.gd')
        shutil.copyfile(RAIZ/'recursos/shaders/lorde_goblin_paleta.gdshader',pasta/'paleta.gdshader')
    script='''extends SceneTree
var vistos: Dictionary = {}
var capturas: Dictionary = {}
var ganhos_couro := GANHOS_COURO
var ganhos_manto := GANHOS_MANTO
func ajustar_paleta(sprite: AnimatedSprite2D) -> void:
    if sprite.material==null:return
    sprite.material.set_shader_parameter("ganho_couro",ganhos_couro[sprite.frame])
    sprite.material.set_shader_parameter("ganho_manto",ganhos_manto[sprite.frame])
func _initialize() -> void:
    rodar.call_deferred()
func rodar() -> void:
    var imagem := Image.load_from_file(FONTE)
    assert(imagem.get_size()==Vector2i(LARGURA_ATLAS,ALTURA_ATLAS),"Atlas direcional invalido")
    var textura := ImageTexture.create_from_image(imagem)
    var frames := SpriteFrames.new()
    frames.clear_all()
    frames.add_animation("golpe")
    frames.set_animation_loop("golpe",false)
    frames.set_animation_speed("golpe",100.0)
    var tempos := TEMPOS_QUADROS
    var duracao_ms := 0
    for tempo in tempos: duracao_ms+=int(tempo)
    for i in TOTAL_QUADROS:
        var regiao := Rect2i(i%COLUNAS_ATLAS*640,i/COLUNAS_ATLAS*640,640,640)
        var usado := imagem.get_region(regiao).get_used_rect()
        assert(usado.position.x>=16 and usado.position.y>=16 and usado.end.x<=624 and usado.end.y<=624,"Recorte na marreta ou personagem")
        var atlas := AtlasTexture.new()
        atlas.atlas=textura
        atlas.region=regiao
        frames.add_frame("golpe",atlas,float(tempos[i])/10.0)
    print("OK Godot decodifica todos os quadros com margem para a marreta")
    var sprite := AnimatedSprite2D.new()
    root.add_child(sprite)
    sprite.sprite_frames=frames
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.offset=Vector2(0,-180)
    sprite.position=POSICAO_PREVIA
    sprite.scale=Vector2.ONE*0.9
    PREPARAR_PALETA
    await process_frame
    await RenderingServer.frame_post_draw
    for ciclo in 2:
        vistos.clear()
        sprite.stop()
        sprite.play("golpe")
        var inicio := Time.get_ticks_msec()
        while Time.get_ticks_msec()-inicio<duracao_ms+250:
            await RenderingServer.frame_post_draw
            vistos[sprite.frame]=true
            if not capturas.has(sprite.frame): capturas[sprite.frame]=root.get_texture().get_image()
        assert(vistos.size()==TOTAL_QUADROS,"Algum quadro nao apareceu na reproducao")
        assert(not sprite.is_playing() and sprite.frame==TOTAL_QUADROS-1,"Golpe repetiu ou nao terminou")
        print("OK todas as poses e retorno a guarda no golpe ",ciclo+1)
    for i in TOTAL_QUADROS: capturas[i].save_png("res://quadro_%02d.png"%i)
    PREVIA_EFEITOS
    sprite.queue_free()
    await process_frame
    capturas.clear()
    await process_frame
    print("OK revisao grafica isolada sem autoloads ou partida do usuario")
    quit()
'''.replace('FONTE',json.dumps(str(fonte)))
    quantidade=len(ficha['duracoes_ms'])
    script=(script.replace('TOTAL_QUADROS',str(quantidade))
            .replace('COLUNAS_ATLAS',str(ficha['grade'][0]))
            .replace('LARGURA_ATLAS',str(ficha['grade'][0]*ficha['celula'][0]))
            .replace('ALTURA_ATLAS',str(ficha['grade'][1]*ficha['celula'][1]))
            .replace('TEMPOS_QUADROS',json.dumps(ficha['duracoes_ms'])))
    trecho=''
    if efeitos:
        trecho='''var efeito=load("res://impacto.gd").new()
    efeito.textura_escombros=ImageTexture.create_from_image(Image.load_from_file(ARQUIVO_ESCOMBROS))
    efeito.position=sprite.to_global(CONTATO_LOCAL-Vector2(320,320)+sprite.offset)
    root.add_child(efeito)
    sprite.stop()
    for passo in 60:
        var ms:=passo*30
        var fim_quadro:=0
        sprite.frame=tempos.size()-1
        for i in tempos.size():
            fim_quadro+=int(tempos[i])
            if ms<fim_quadro:
                sprite.frame=i
                break
        efeito.amostrar(float(ms-INSTANTE_IMPACTO)/1000.0)
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://efeito_%03d.png"%passo)
    efeito.queue_free()'''
        trecho=trecho.replace('ARQUIVO_ESCOMBROS',json.dumps(str(RAIZ/'assets/inimigos/lorde_goblin_2d/impacto_escombros.png'))).replace('INSTANTE_IMPACTO',str(ficha['impacto_ms']))
    script=script.replace('PREVIA_EFEITOS',trecho)
    def vetor(valores):
        return 'Vector'+str(len(valores))+'('+','.join(str(v) for v in valores)+')'
    script=(script.replace('GANHOS_COURO','['+','.join(vetor(v) for v in paleta['ganhos_couro'])+']')
            .replace('GANHOS_MANTO','['+','.join(vetor(v) for v in paleta['ganhos_manto'])+']')
            .replace('POSICAO_PREVIA',vetor(paleta.get('posicao_previa',[320,520])))
            .replace('CONTATO_LOCAL',vetor(paleta.get('contato',[320,500]))))
    script=script.replace('PREPARAR_PALETA','''var paleta:=ShaderMaterial.new()
    paleta.shader=load("res://paleta.gdshader")
    sprite.material=paleta
    sprite.frame_changed.connect(ajustar_paleta.bind(sprite))
    ajustar_paleta(sprite)''' if efeitos else '')
    (pasta/'revisar.gd').write_text(script)
    motor,_=motor_godot(pasta)
    log=pasta/'godot.log'
    with log.open('w') as f:
        r=subprocess.run(motor+['--path',str(pasta),'--script','res://revisar.gd'],stdout=f,stderr=subprocess.STDOUT,timeout=40)
    texto=log.read_text()
    relevantes=[l for l in texto.splitlines() if l.startswith('OK ') or 'SCRIPT ERROR' in l or 'Parse Error' in l]
    for linha in relevantes: print(linha)
    if r.returncode or 'SCRIPT ERROR' in texto or 'Parse Error' in texto or len([l for l in relevantes if l.startswith('OK ')])!=4:
        print('FALHA reproducao; log:',log)
        return 1
    destino=RAIZ/'arte/previas/inimigos/lorde_goblin_2d'
    (destino/f'revisao_{direcao}_godot.json').write_text(json.dumps({'direcao':direcao,'capturas':str(pasta),'quadros':quantidade,'golpes':2,'efeitos':efeitos,'passo_efeitos_ms':30,'save_isolado':str(pasta/'dados'),'log':str(log)},indent=2)+'\n')
    print('Capturas da revisao:',pasta)
    return 0

if __name__=='__main__': raise SystemExit(main())
