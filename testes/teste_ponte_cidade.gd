extends SceneTree
var falhas:=0
func _initialize() -> void:rodar.call_deferred()
func esperar(n:=4) -> void:
	for i in n:await process_frame
func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas+=1
		push_error(mensagem)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	change_scene_to_file("res://cenas/cidade.tscn")
	await esperar(25)
	root.get_node("Transicao").limpar()
	var vila: Node2D=current_scene
	var jogador: CharacterBody2D=vila.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.aparencia_raven={"versao":1,"pele":0,"roupa":1,"cabelo":1,"cor":[0.25,0.3,0.4,1.0]}
	jogador.collision_mask=64
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-ponte-cidade")
	var vp:=SubViewport.new()
	vp.size=Vector2i(720,400)
	vp.world_2d=vila.get_world_2d()
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var camera:=Camera2D.new()
	camera.position=Vector2(676,276)
	camera.zoom=Vector2(4,4)
	vp.add_child(camera)
	camera.make_current()
	for e in 4:
		root.get_node("Calendario").dia=1+e*28
		vila._aplicar_terreno(e)
		jogador.position=Vector2(628,264)
		var leste:=jogador.move_and_collide(Vector2(96,0))
		verificar(leste==null,"Travessia oeste-leste livre")
		var oeste:=jogador.move_and_collide(Vector2(-96,0))
		verificar(oeste==null,"Travessia leste-oeste livre")
		jogador.position=Vector2(676,264)
		var sul:=jogador.move_and_collide(Vector2(0,70))
		verificar(sul!=null and jogador.position.y+11<=285.1,"Beirada sul segura os pés sobre o piso")
		jogador.position=Vector2(676,264)
		var norte:=jogador.move_and_collide(Vector2(0,-70))
		verificar(norte!=null and jogador.position.y+11>=267.9,"Beirada norte segura os pés sobre o piso")
		var rota: PackedVector2Array=vila.caminho_entre(Vector2(628,264),Vector2(724,264),vila._navegacao_cadeira)
		verificar(not rota.is_empty() and rota[-1].distance_to(Vector2(724,264))<24,"Navegação da cadeira atravessa a ponte")
		jogador.position=Vector2(676,270)
		jogador._direcao_ataque=Vector2.DOWN
		jogador.get_node("HeroiRaven")._process(0.0)
		await esperar(3)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("/tmp/algoland-ponte-cidade/estacao_%d.png" % e)
	print("PONTE: ",falhas," falhas; travessia, margens, cadeira e quatro estações.")
	quit(1 if falhas else 0)
