extends SceneTree
## Exporta as mesmas animações do combo usadas pelo controlador, com seus tempos.
var SAIDA := "res://arte/previas/personagens/base_3d/combo_espada/"
func _initialize(): rodar.call_deferred()
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name() != "headless")
    var lanca := "--lanca" in OS.get_cmdline_user_args()
    var montante := "--montante" in OS.get_cmdline_user_args()
    if lanca: SAIDA = SAIDA.replace("combo_espada/","combo_lanca/")
    if montante: SAIDA=SAIDA.replace("combo_espada/","combo_montante/")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    change_scene_to_file("res://cenas/fazenda.tscn")
    for i in 35: await process_frame
    root.get_node("PainelDebug")._ativar_base_3d(true,true,lanca)
    for i in 5: await process_frame
    var h = current_scene.get_node("Jogador/HeroiBase3D")
    if montante:
        var j=h._jogador
        var item=preload("res://codigo/dados/forja_armas.gd").criar_item("espada_gemea")
        j.inventario.mochila[23]=item
        assert(j.inventario.equipar(item))
        for i in 5: await process_frame
        assert(h._arma_de_duas_maos())
    h.set_process(false)
    h._empunhadura_lanca.amostragem_automatica=false
    h._acao = "lanca" if lanca else "espada"
    var combo = h.COMBO_MONTANTE if montante else (h.COMBO_LANCA if lanca else h.COMBO)
    h._demonstracao = true
    h._encaixar_espada(true)
    var vp := SubViewport.new()
    vp.size = h._vp.size
    vp.transparent_bg = true
    vp.world_2d = World2D.new()
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var sprite := Sprite2D.new()
    sprite.centered = false
    sprite.texture = h._vp.get_texture()
    sprite.texture_filter = h._sprite.texture_filter
    sprite.material = h._sprite.material
    vp.add_child(sprite)
    for direcao in 4:
        h._rastro.limpar()
        h._modelo.rotation.y = [0.0,PI/2.0,PI,-PI/2.0][direcao]
        for golpe in 3:
            h._golpe_demonstracao = golpe+1
            h._encaixar_espada(true)
            h._player.play(combo.NOMES[golpe],0.0)
            h._player.speed_scale = 0
            for q in 24:
                h._progresso_golpe = q/24.0
                h._player.seek(combo.DURACOES[golpe]*q/24.0,true)
                await RenderingServer.frame_post_draw
                h._quadro_rastro = -1
                h._delta_rastro = combo.DURACOES[golpe]/24.0
                h._progresso_golpe = q/24.0
                h._atualizar_rastro(lanca)
                await RenderingServer.frame_post_draw
                vp.get_texture().get_image().save_png(SAIDA+"combo_%d_%d_%02d.png" % [direcao,golpe,q])
    FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify({"duracoes":combo.DURACOES,"quadros_por_golpe":24,"direcoes":4},"  "))
    print("COMBO REVISÃO: 288 fases renderizadas com o filtro no Godot")
    quit()
