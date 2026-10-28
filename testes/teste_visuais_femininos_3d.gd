extends SceneTree
const Catalogo := preload("res://codigo/dados/roupas_base_3d.gd")
const SAIDA := "res://arte/previas/personagens/base_3d/femininos/"
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
    var conjuntos: Array=[
        {"camisa":"blusa_bufante","calca":"saia_pregas","calcado":"sapatilhas_vinho","cabelo":"cabelo_curto"},
        {"camisa":"casaquinho_lavanda","calca":"saia_campo","calcado":"sapatilhas_vinho","cabelo":"cabelo_cacheado"},
        {"camisa":"blusa_bufante","calca":"saia_campo","calcado":"botinas_trabalho","cabelo":"cabelo_curto"}]
    vp.size=h._vp.size
    sprite.material=h._sprite.material
    sprite.texture_filter=h._sprite.texture_filter
    conferir(Catalogo.modelo("cabelo","cabelo_trancas").id=="cabelo_curto","Tranças antigas migram para bagunçado")
    conferir(Catalogo.modelo("cabelo","cabelo_rabo").id=="cabelo_curto","Rabo antigo migra para bagunçado")
    conferir(Catalogo.modelo("cabelo","cabelo_chanel").id=="cabelo_curto" and Catalogo.modelo("cabelo","cabelo_longo").id=="cabelo_curto" and Catalogo.modelo("cabelo","cabelo_espetado").id=="cabelo_curto","Cortes retirados migram para bagunçado")
    conferir(Catalogo.MODELOS.cabelo.map(func(m):return m.id)==["cabelo_curto","cabelo_raspado","cabelo_cacheado","cabelo_liso_longo"],"Somente os quatro cortes ativos")
    var capturas:=0
    var somente_interface: bool="--somente-interface" in OS.get_cmdline_user_args()
    if somente_interface: h.definir_roupas_3d(conjuntos[2])
    var indices: Array=[] if somente_interface else range(conjuntos.size())
    for argumento in OS.get_cmdline_user_args():
        if argumento.begins_with("--conjunto="): indices=[int(argumento.trim_prefix("--conjunto="))]
    for conjunto in indices:
        h.definir_roupas_3d(conjuntos[conjunto])
        for peca in [h._pecas[1],h._pecas[3]]:
            var a: Array=peca.mesh.surface_get_arrays(0)
            conferir(a[Mesh.ARRAY_BONES].size()==a[Mesh.ARRAY_VERTEX].size()*4,"Pesos do rig presentes")
            for i in a[Mesh.ARRAY_VERTEX].size():
                conferir(a[Mesh.ARRAY_VERTEX][i].is_finite(),"Vértice finito")
                var soma:=0.0
                for k in 4:soma+=a[Mesh.ARRAY_WEIGHTS][i*4+k]
                conferir(absf(soma-1)<.001,"Influências somam 1")
        for direcao in 4:
            h._modelo.rotation.y=[0.0,PI/2,PI,-PI/2][direcao]
            for acao in ["idle","corrida","ataque"]:
                var nome: String="mixamo/Idle" if acao=="idle" else (h._nome_animacao("correr") if acao=="corrida" else "mixamo/SwordSlashA")
                h._player.play(nome,0)
                h._player.speed_scale=0
                for q in (1 if acao=="idle" else 12):
                    h._player.seek(h._player.get_animation(nome).length*q/12.0,true)
                    await foto(vp,"%s_%d_%d_%02d" % [acao,conjunto,direcao,q])
                    var imagem: Image=vp.get_texture().get_image()
                    var limites:=imagem.get_used_rect()
                    conferir(limites.position.x>0 and limites.position.y>0 and limites.end.x<imagem.get_width() and limites.end.y<imagem.get_height(),"Cabelo/roupa sem cortes")
                    capturas+=1
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
    for tamanho in [Vector2i(576,360),Vector2i(288,512),Vector2i(320,324)]:
        root.size=tamanho
        await esperar(5)
        painel._customizar_roupas_3d()
        await esperar(10)
        var ui=painel.get_node("CustomizacaoRoupas3D")
        var ret: Rect2=ui._painel.get_global_rect()
        conferir(root.get_visible_rect().encloses(ret),"Painel cabe na resolução "+str(tamanho))
        for seletor in ui._seletores.values():
            var r: Rect2=seletor.get_global_rect()
            conferir(r.position.x>=ret.position.x+14 and r.end.x<=ret.end.x-14,"Margem horizontal dos seletores")
        conferir(ret.grow(-12).encloses(ui._imagem.get_global_rect()),"Prévia inteira dentro do painel")
        conferir(ui._seletores.cabelo.item_count==3,"Três penteados disponíveis")
        ui._seletores.cabelo.select(2)
        ui._seletores.cabelo.item_selected.emit(2)
        conferir(h.roupas_3d.cabelo=="cabelo_cacheado","Penteado muda na prévia")
        var ret_previa: Rect2=ui._imagem.get_global_rect()
        ui._rolagem.scroll_vertical=1000
        await esperar(2)
        conferir(ui._imagem.get_global_rect()==ret_previa,"Rolagem preserva a prévia inteira e fixa")
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(SAIDA+"interface_%dx%d.png" % [tamanho.x,tamanho.y])
        var antes: Dictionary=ui._original.duplicate()
        ui._seletores.camisa.select(1)
        ui._seletores.camisa.item_selected.emit(1)
        conferir(h.roupas_3d.camisa==Catalogo.MODELOS.camisa[1].id,"Seletor altera a prévia")
        conferir(not j.movimento_habilitado and j.ataques_bloqueados,"Customização bloqueia ações do personagem")
        ui._cancelar()
        await esperar(2)
        conferir(h.roupas_3d==antes,"Cancelar restaura a combinação anterior")
    FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify({"corrida":h._player.get_animation(h._nome_animacao("correr")).length,"ataque":h._player.get_animation("mixamo/SwordSlashA").length,"amostras":12}))
    print("VISUAIS FEMININOS: ",capturas," capturas de ",indices.size()," conjuntos, 4 vistas, corrida/ataque; rig, persistência, cancelamento e 3 resoluções; falhas=",falhas)
    vp.queue_free()
    current_scene.queue_free()
    await esperar(3)
    quit(1 if falhas else 0)
