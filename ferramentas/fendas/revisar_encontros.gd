extends SceneTree

## Captura a patrulha no jogo real em dois instantes, com save isolado.
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
	root.get_node("Introducao").aula_arena=false
	root.get_node("Cooperativo").sair()
	root.get_node("Progresso").iniciar_partida()
	var pasta := "res://arte/previas/fenda/encontros/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	for andar in [1,3]:
		var transicao: Node=root.get_node("Transicao")
		transicao.retornando=true
		transicao.estado={"onda_atual":andar}
		transicao.iniciar_onda_ao_chegar=false
		change_scene_to_file("res://cenas/fendas/andar_%02d.tscn" % andar)
		await quadros(20)
		transicao.retornando=false
		var jogador: Node2D=current_scene.get_node("Jogador")
		jogador.set_physics_process(false)
		var gerente: Node=current_scene.get_node("enemySpawner/GerenciadorOndas")
		gerente.iniciar_onda(true)
		await quadros(6)
		gerente.set_physics_process(false)
		var camera := Camera2D.new()
		current_scene.add_child(camera)
		camera.global_position=current_scene.get_node("Terrains/Setores").get_child(1).global_position
		camera.zoom=Vector2.ONE
		camera.make_current()
		await quadros(4)
		for instante in 2:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(pasta+"andar_%02d_patrulha_%d.png" % [andar,instante])
			await quadros(150 if instante==0 else 2)
		print("RENDER ENCONTROS ",andar," populacao ",current_scene.get_node("enemySpawner")._populacao.size())
		gerente.parar_ondas()
		await quadros()
	current_scene.queue_free()
	current_scene=null
	await quadros(10)
	quit()
