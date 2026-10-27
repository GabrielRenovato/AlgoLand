extends SceneTree
## Regressão: repouso e corrida após terminar/interromper cada golpe da espada.
var SAIDA := "res://arte/previas/personagens/base_3d/retorno_espada/"
var falhas := 0
func _initialize(): rodar.call_deferred()
func conferir(ok: bool,mensagem: String):
    if not ok: falhas+=1; push_error(mensagem)
func poses(s: Skeleton3D) -> Array:
    var resultado: Array=[]
    for i in s.get_bone_count(): resultado.append(s.get_bone_pose(i))
    return resultado
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    var montante: bool="--montante" in OS.get_cmdline_user_args()
    if montante: SAIDA=SAIDA.replace("retorno_espada/","retorno_montante/")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    change_scene_to_file("res://cenas/fazenda.tscn")
    for i in 35: await process_frame
    root.get_node("Transicao").limpar()
    root.get_node("PainelDebug")._ativar_base_3d(true,true)
    for i in 6: await process_frame
    var j=current_scene.get_node("Jogador")
    var h=j.get_node("HeroiBase3D")
    if montante:
        var item=preload("res://codigo/dados/forja_armas.gd").criar_item("espada_gemea")
        j.inventario.mochila[23]=item
        assert(j.inventario.equipar(item))
        for i in 5: await process_frame
    var combo=h.COMBO_MONTANTE if montante else h.COMBO
    j.set_physics_process(false)
    j.velocity=Vector2.ZERO
    h.set_process(false)
    var p: AnimationPlayer=h._player
    var s: Skeleton3D=h._esqueleto
    var vp:=SubViewport.new()
    vp.size=h._vp.size
    vp.transparent_bg=true
    vp.world_2d=World2D.new()
    vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var sprite:=Sprite2D.new()
    sprite.centered=false
    sprite.texture=h._vp.get_texture()
    sprite.material=h._sprite.material
    sprite.texture_filter=h._sprite.texture_filter
    vp.add_child(sprite)
    var transicoes:=0
    var erro_maximo:=0.0
    for direcao in 4:
        h._modelo.rotation.y=[0.0,PI/2.0,PI,-PI/2.0][direcao]
        for acao in ["parado","correr"]:
            var nome: String=h._nome_animacao(acao)
            var tempo: float=p.get_animation(nome).length*0.20
            p.play(nome,0);p.speed_scale=0;p.seek(tempo,true)
            h._acao=acao
            h._encaixar_espada(false)
            var esperado:=poses(s)
            await RenderingServer.frame_post_draw
            await RenderingServer.frame_post_draw
            var imagem:=vp.get_texture().get_image()
            imagem.save_png(SAIDA+"%s_%d_antes.png" % [acao,direcao])
            for golpe in combo.NOMES.size():
                for fase in [0.55,0.999]:
                    p.play(combo.NOMES[golpe],0)
                    p.seek(p.get_animation(combo.NOMES[golpe]).length*fase,true)
                    h._acao="espada"
                    h._tocar(acao,1.0)
                    p.advance(h.MISTURA+0.05)
                    p.pause()
                    p.seek(tempo,true)
                    h._acao=acao
                    h._encaixar_espada(false)
                    var maior:=0.0
                    for i in s.get_bone_count():
                        var antes: Transform3D=esperado[i]
                        var agora:=s.get_bone_pose(i)
                        # A rotação relativa evita o arredondamento de acos(dot(q,q)) em poses iguais.
                        var relativa: Quaternion=(antes.basis.orthonormalized().inverse()*agora.basis.orthonormalized()).get_rotation_quaternion().normalized()
                        var erro:=2.0*atan2(Vector3(relativa.x,relativa.y,relativa.z).length(),absf(relativa.w))
                        maior=maxf(maior,erro)
                        conferir(antes.origin.distance_to(agora.origin)<0.0001,"Posição residual no osso "+s.get_bone_name(i))
                    erro_maximo=maxf(erro_maximo,maior)
                    conferir(maior<0.001,"Rotação residual após golpe %d, ação %s, direção %d" % [golpe+1,acao,direcao])
                    await RenderingServer.frame_post_draw
                    await RenderingServer.frame_post_draw
                    var depois:=vp.get_texture().get_image()
                    conferir(imagem.get_data()==depois.get_data(),"Render mudou após retorno à mesma pose: "+acao)
                    if fase>0.9: depois.save_png(SAIDA+"%s_%d_depois_%d.png" % [acao,direcao,golpe+1])
                    transicoes+=1
    print("RETORNO ESPADA 3D: ",transicoes," transições, ",falhas," falhas; desvio máximo=",rad_to_deg(erro_maximo)," graus; quatro direções, repouso/corrida, término/interrupção")
    quit(1 if falhas else 0)
