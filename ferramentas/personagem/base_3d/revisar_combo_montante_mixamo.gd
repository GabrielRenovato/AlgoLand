extends SceneTree
## Reproduz a sequência no controlador, incluindo encadeamento e retorno ao repouso.
const SAIDA := "res://arte/previas/personagens/base_3d/mixamo/espadão/"
func _initialize(): rodar.call_deferred()
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name()!="headless")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva=12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    for i in 35: await process_frame
    root.get_node("Transicao").limpar()
    root.get_node("PainelDebug")._ativar_base_3d(true,true)
    for i in 6: await process_frame
    var j=current_scene.get_node("Jogador")
    var h=j.get_node("HeroiBase3D")
    j.set_physics_process(false)
    var item=preload("res://codigo/dados/forja_armas.gd").criar_item("espada_gemea")
    j.inventario.mochila[23]=item
    assert(j.inventario.equipar(item))
    for i in 6: await process_frame
    var registros: Array=[]
    for direcao in 4:
        var dir: Vector2=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
        j._direcao_ataque=dir
        h._iniciar_demonstracao()
        h._direcao_demonstracao=dir
        h._fila_demonstracao=true
        h._rastro.limpar()
        for q in 96:
            await process_frame
            await RenderingServer.frame_post_draw
            var imagem: Image=h._vp.get_texture().get_image()
            var limites:=imagem.get_used_rect()
            assert(limites.position.x>0 and limites.position.y>0 and limites.end.x<imagem.get_width() and limites.end.y<imagem.get_height(),"Golpe cortado")
            imagem.save_png(SAIDA+"combo_%d_%02d.png" % [direcao,q])
            registros.append({"direcao":direcao,"quadro":q,"tempo":q/60.0,"golpe":h._golpe_demonstracao,"acao":h._acao})
        assert(not h._demonstracao and h._acao=="parado")
    FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify(registros))
    print("ESPADÃO MIXAMO: 384 quadros reais a 60 fps; corte → salto → repouso nas quatro direções OK")
    current_scene.queue_free()
    for i in 3: await process_frame
    quit()
