extends SceneTree
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":
		quit(1)
		return
	await process_frame
	load("res://codigo/ui/mini_tutorial.gd")._fechado=1
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").iniciar_partida()
	root.get_node("Transicao").retornando=true
	root.get_node("Transicao").estado={"onda_atual":1}
	root.get_node("Transicao").iniciar_onda_ao_chegar=false
	change_scene_to_file("res://cenas/fendas/andar_01.tscn")
	await quadros(20)
	root.get_node("Transicao").retornando=false
	var jogador: Node2D=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	var gerente: Node=current_scene.get_node("enemySpawner/GerenciadorOndas")
	gerente.set_physics_process(false)
	gerente.etapa=gerente.Etapa.CONCLUIDO
	gerente.ondas_paradas=false
	gerente.onda_em_andamento=false
	await gerente._abrir_janela_entre_ondas()
	await quadros(15)
	var guia: Node2D=gerente.guia
	if guia==null:
		quit(1)
		return
	var camera:=Camera2D.new()
	current_scene.add_child(camera)
	camera.global_position=(guia.global_position+jogador.global_position)*.5-Vector2(0,20)
	camera.zoom=Vector2(2,2)
	camera.make_current()
	await quadros()
	await RenderingServer.frame_post_draw
	var pasta:="res://arte/previas/fenda/guia/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	root.get_texture().get_image().save_png(pasta+"orion_no_andar.png")
	print("OK captura Orion no andar, mesma escala nativa do jogador")
	current_scene.queue_free()
	current_scene=null
	await quadros()
	quit()
