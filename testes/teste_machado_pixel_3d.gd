extends SceneTree
## Exercita as escolhas do controlador, equipamento e fases nas quatro vistas.
const SAIDA := "res://arte/previas/personagens/base_3d/mixamo/machado_pixel/"
var amostras:=0
var impactos:=0
var pega_renderizada:=Vector3.ZERO
var maior_giro:=0.0
var maior_salto:=0.0
func _initialize(): rodar.call_deferred()
func quadros(n: int):
    for i in n: await process_frame
func foto(h: Node,nome: String,direcao: int,q: int):
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    var im: Image=get_meta("previa").get_texture().get_image()
    var limites:=im.get_used_rect()
    assert(limites.position.x>0 and limites.position.y>0 and limites.end.x<im.get_width() and limites.end.y<im.get_height(),"Equipamento cortado: "+nome)
    im.save_png(SAIDA+"%s_%d_%02d.png" % [nome,direcao,q])
    amostras+=1
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva=12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    await quadros(35)
    root.get_node("Transicao").limpar()
    root.get_node("PainelDebug")._ativar_base_3d(true)
    await quadros(6)
    var j=current_scene.get_node("Jogador")
    var h=j.get_node("HeroiBase3D")
    assert(h.acabamento_pixel_art and h._vp.size==Vector2i(160,160))
    assert(h._sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST)
    assert(h._sprite.material.shader.resource_path.ends_with("pixelizar_base_3d.gdshader"))
    var clipe: Animation=h._player.get_animation("mixamo/AxeTreeChop")
    assert(clipe.get_meta("fonte")=="Standing Melee Attack Horizontal.fbx")
    for trilha in clipe.get_track_count():
        if clipe.track_get_type(trilha)==Animation.TYPE_ROTATION_3D:
            assert(clipe.rotation_track_interpolate(trilha,0).angle_to(clipe.rotation_track_interpolate(trilha,clipe.length))<.002,"Recuperação termina em outra pose")
        elif clipe.track_get_type(trilha)==Animation.TYPE_POSITION_3D:
            assert(clipe.position_track_interpolate(trilha,0).distance_to(clipe.position_track_interpolate(trilha,clipe.length))<.0001)
    var vp:=SubViewport.new()
    vp.size=h._vp.size
    vp.transparent_bg=true
    vp.world_2d=World2D.new()
    vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var sprite:=Sprite2D.new()
    sprite.centered=false
    sprite.texture=h._vp.get_texture()
    sprite.texture_filter=h._sprite.texture_filter
    sprite.material=h._sprite.material
    vp.add_child(sprite)
    set_meta("previa",vp)
    h._esqueleto.skeleton_updated.connect(func():
        var base: Transform3D=h._modelo.global_transform.affine_inverse()*h._esqueleto.global_transform
        pega_renderizada=base*h._esqueleto.get_bone_global_pose(h._esqueleto.find_bone("DEF-hand.R"))*Vector3(0,.08,0)
    )
    j.set_physics_process(false)
    h.set_process(false)
    j.no_fazenda.set_process(false)
    j.no_arco.set_process(false)
    for direcao in 4:
        var anterior:=Transform3D.IDENTITY
        j._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
        assert(j.acao_fazenda("machado"))
        for q in 41:
            var t: float=.68*q/41.0
            j.no_fazenda._indice=0
            while t>=j.no_fazenda._quadros[j.no_fazenda._indice][1]:
                t-=j.no_fazenda._quadros[j.no_fazenda._indice][1]
                j.no_fazenda._indice+=1
            j.no_fazenda._tempo=t
            h._process(0)
            assert(h._player.assigned_animation=="mixamo/AxeTreeChop")
            var instante: float=h._player.current_animation_position
            h._player.play("mixamo/AxeTreeChop",0)
            h._player.speed_scale=0
            h._player.seek(instante,true)
            await foto(h,"machado",direcao,q)
            assert(h._ferramentas._machado.is_visible_in_tree())
            var encaixe=h._esqueleto.get_node("EncaixeMachado3D")
            assert(encaixe.folga>=1.0,"Machado invadiu o volume de resguardo: %d/%d: %f" % [direcao,q,encaixe.folga])
            assert(pega_renderizada.distance_to(h._ferramentas._machado.position)<.0001,"Cabo solto da mão")
            var atual: Transform3D=h._ferramentas._machado.transform
            if q>0:
                var giro:=anterior.basis.get_rotation_quaternion().angle_to(atual.basis.get_rotation_quaternion())
                var salto: float=(anterior*Vector3(.19,.48,0)).distance_to(atual*Vector3(.19,.48,0))
                maior_giro=maxf(maior_giro,giro)
                maior_salto=maxf(maior_salto,salto)
            anterior=atual
        j.cancelar_acao_fazenda()
    assert(maior_giro<deg_to_rad(30),"Orientação do machado saltou entre quadros")
    assert(maior_salto<.33,"Ponta do machado saltou entre quadros")
    # Reprodução com o relógio real: um impacto por uso e retorno ao repouso.
    h.set_process(true)
    j.no_fazenda.set_process(true)
    j.no_fazenda.impacto.connect(func(acao):
        if acao=="machado": impactos+=1
    )
    assert(j.acao_fazenda("machado"))
    await create_timer(.8).timeout
    assert(impactos==1 and not j.esta_em_acao_fazenda)
    assert(h._acao=="parado" and not h._ferramentas._machado.is_visible_in_tree())
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(SAIDA+"mapa.png")
    print("CONTINUIDADE: giro máximo=",rad_to_deg(maior_giro)," graus; ponta=",maior_salto," m por amostra.")
    print("PIXEL MACHADO OK: ",amostras," poses, 4 direções, retorno ao repouso e fonte Mixamo confirmados.")
    vp.queue_free()
    current_scene.queue_free()
    await quadros(3)
    quit()
