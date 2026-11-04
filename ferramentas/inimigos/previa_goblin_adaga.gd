extends SceneTree
## Prévia estática do modelo base no cenário; não substitui validação das animações.
func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	if not OS.get_user_data_dir().contains("AlgoLand testes goblin adaga"):
		quit(1)
		return
	var progresso = load("res://codigo/campanha/progresso_campanha.gd").new()
	progresso.iniciar("user://percurso_primeira_raiz", "prototipo")
	progresso.recompensas = progresso._concluidas.duplicate()
	progresso.salvar_retorno("moinho", Vector2(0, 80))
	set_meta("campanha_destino", "moinho")
	set_meta("campanha_nova_instancia", false)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await create_timer(2.0).timeout
	var cena = current_scene
	var jogador = cena.jogador
	jogador.set_physics_process(false)
	jogador.global_position = Vector2(-40, 80)
	for mob in get_nodes_in_group("enemy"):
		mob.set_physics_process(false)
		mob.hide()
	for camera_antiga in cena.find_children("*", "Camera2D", true, false):
		camera_antiga.enabled = false
	var camera := Camera2D.new()
	cena.add_child(camera)
	camera.global_position = Vector2(0, 60)
	camera.make_current()
	var textura := load("res://assets/inimigos/goblin_adaga/modelo_base.png") as Texture2D
	var modelo := Sprite2D.new()
	modelo.name = "GoblinAdagaEstudo"
	modelo.texture = textura
	modelo.hframes = 3
	modelo.offset = Vector2(0, 362 - 672)
	modelo.scale = Vector2.ONE * 0.06
	modelo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	modelo.position = Vector2(8, 92)
	modelo.z_index = preload("res://codigo/globais/profundidade.gd").z_de(92)
	cena.add_child(modelo)
	for direcao in 3:
		modelo.frame = direcao
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/goblin-adaga-%s.png" % [ ["frente", "perfil", "costas"][direcao] ])
	quit()
