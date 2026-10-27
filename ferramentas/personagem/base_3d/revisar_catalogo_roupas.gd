extends SceneTree
const Catalogo := preload("res://codigo/dados/roupas_base_3d.gd")
const SAIDA := "res://arte/previas/personagens/base_3d/catalogo_roupas/"
var falhas:=0
func _initialize(): rodar.call_deferred()
func conferir(ok: bool,msg: String):
    if not ok: falhas+=1;push_error(msg)
func esperar(n: int):
    for i in n:await process_frame
func foto(vp: SubViewport,nome: String):
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    vp.get_texture().get_image().save_png(SAIDA+nome+".png")
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva=12
    change_scene_to_file("res://cenas/fazenda.tscn")
    await esperar(35)
    root.get_node("Transicao").limpar()
    var painel=root.get_node("PainelDebug")
    painel._ativar_base_3d(true,true)
    await esperar(6)
    var j=current_scene.get_node("Jogador")
    var h=j.get_node("HeroiBase3D")
    var mochila: Array=j.inventario.fotografar_mochila()
    j.set_physics_process(false)
    j.no_fazenda.set_process(false)
    h.set_process(false)
    h._empunhadura_lanca.amostragem_automatica=false
    h._acao="parado"
    h._espada.visible=false
    h._escudo.visible=false
    h._lanca.visible=false
    var vp:=SubViewport.new()
    vp.transparent_bg=true
    vp.world_2d=World2D.new()
    vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var sprite:=Sprite2D.new()
    sprite.centered=false
    sprite.texture=h._vp.get_texture()
    vp.add_child(sprite)
    var modelos: Array=[]
    for categoria in Catalogo.CATEGORIAS:
        for item in Catalogo.MODELOS[categoria]:
            var dados:=Catalogo.padrao()
            dados[categoria]=item.id
            modelos.append({"id":item.id,"nome":item.nome,"categoria":categoria,"dados":dados})
    var capturas:=0
    for pixel in [true,false]:
        h.acabamento_pixel_art=pixel
        vp.size=h._vp.size
        sprite.material=h._sprite.material
        sprite.texture_filter=h._sprite.texture_filter
        for modelo in modelos:
            h.definir_roupas_3d(modelo.dados)
            for direcao in 4:
                h._modelo.rotation.y=[0.0,PI/2.0,PI,-PI/2.0][direcao]
                h._player.play("Idle_Loop",0)
                h._player.speed_scale=0
                h._player.seek(0,true)
                await foto(vp,"%s_%s_%d" % ["pixel" if pixel else "suave",modelo.id,direcao])
                capturas+=1
    # Todas as 36 combinações preservam as peças, materiais separados e os pesos.
    var combinacoes:=0
    for cima in Catalogo.MODELOS.camisa:
        for calca in Catalogo.MODELOS.calca:
            for pe in Catalogo.MODELOS.calcado:
                h.definir_roupas_3d({"camisa":cima.id,"calca":calca.id,"calcado":pe.id})
                conferir(h.roupas_3d.camisa==cima.id and h.roupas_3d.calca==calca.id and h.roupas_3d.calcado==pe.id,"Seleção independente")
                for i in 3:
                    var a: Array=h._pecas[i].mesh.surface_get_arrays(0)
                    conferir(a[Mesh.ARRAY_BONES].size()>0 and a[Mesh.ARRAY_WEIGHTS].size()>0,"Peça mantém rig")
                combinacoes+=1
    # Ciclo completo de corrida por conjunto, com as durações reais do clipe.
    h.acabamento_pixel_art=true
    vp.size=h._vp.size
    sprite.material=h._sprite.material
    sprite.texture_filter=h._sprite.texture_filter
    var duracao: float=h._player.get_animation(h._nome_animacao("correr")).length
    for conjunto in 4:
        h.definir_roupas_3d({"camisa":Catalogo.MODELOS.camisa[conjunto].id,"calca":Catalogo.MODELOS.calca[conjunto%3].id,"calcado":Catalogo.MODELOS.calcado[conjunto%3].id})
        for direcao in 4:
            h._modelo.rotation.y=[0.0,PI/2.0,PI,-PI/2.0][direcao]
            h._player.play(h._nome_animacao("correr"),0)
            h._player.speed_scale=0
            for q in 12:
                h._player.seek(duracao*q/12.0,true)
                await foto(vp,"corrida_%d_%d_%02d" % [conjunto,direcao,q])
    # Persistência mescla apenas a seleção, sem perder campos da aparência antiga.
    var caminho: String="user://teste_catalogo_personagem.json"
    FileAccess.open(caminho,FileAccess.WRITE).store_string(JSON.stringify({"apelido":"Teste","aparencia_raven":{"roupa":2},"campo_futuro":17}))
    conferir(h.salvar_roupas_3d(caminho),"Salvar seleção")
    var salvo: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(caminho))
    conferir(salvo.campo_futuro==17 and salvo.aparencia_raven.roupa==2 and salvo.roupas_3d==h.roupas_3d,"Preservação dos campos de aparência")
    conferir(Catalogo.normalizar({"camisa":"inexistente"})==Catalogo.padrao(),"Fallback de ID desconhecido")
    conferir(j.inventario.fotografar_mochila()==mochila,"Customização não altera inventário")
    # Tela real em janela normal e formato de celular.
    h.set_process(true)
    root.mode=Window.MODE_WINDOWED
    root.unresizable=false
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size=Vector2i.ZERO
    for tamanho in [Vector2i(576,360),Vector2i(288,512)]:
        root.size=tamanho
        await esperar(5)
        painel._customizar_roupas_3d()
        await esperar(10)
        var ui=painel.get_node("CustomizacaoRoupas3D")
        var ret: Rect2=ui._painel.get_global_rect()
        conferir(root.get_visible_rect().encloses(ret),"Painel cabe na resolução "+str(tamanho))
        for seletor in ui._seletores.values():
            conferir(ret.grow(-12).encloses(seletor.get_global_rect()),"Seletor respeita margem")
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(SAIDA+"interface_%dx%d.png" % [tamanho.x,tamanho.y])
        var antes: Dictionary=h.roupas_3d.duplicate()
        ui._seletores.camisa.select(1)
        ui._seletores.camisa.item_selected.emit(1)
        conferir(h.roupas_3d.camisa==Catalogo.MODELOS.camisa[1].id,"Seletor altera a prévia")
        conferir(not j.movimento_habilitado and j.ataques_bloqueados,"Customização bloqueia ações do personagem")
        ui._cancelar()
        await esperar(2)
        conferir(h.roupas_3d==antes,"Cancelar restaura a combinação anterior")
    FileAccess.open(SAIDA+"catalogo.json",FileAccess.WRITE).store_string(JSON.stringify({"modelos":modelos,"duracao_corrida":duracao},"  "))
    print("CATÁLOGO 3D: ",modelos.size()," peças, ",combinacoes," combinações, ",capturas," vistas, 192 fases de corrida; persistência e interface; falhas=",falhas)
    quit(1 if falhas else 0)
