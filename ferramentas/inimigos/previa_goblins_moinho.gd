extends SceneTree
## Estudo visual dos modelos; não substitui os inimigos jogáveis.
func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	if not OS.get_user_data_dir().contains("AlgoLand testes"):
		quit(1)
		return
	var catalogo: Dictionary = load("res://codigo/campanha/catalogo_campanha.gd").dados()
	var progresso = load("res://codigo/campanha/progresso_campanha.gd").new()
	progresso.iniciar("user://percurso_primeira_raiz", "prototipo")
	for missao in ["sobreviver_queda", "estrada_interrompida", "acolhimento", "pomar_sulcos", "defesa_da_vila"]:
		for objetivo in catalogo.missoes[missao].objetivos:
			progresso.registrar_objetivo(missao, objetivo.id)
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
	for camera in cena.find_children("*", "Camera2D", true, false):
		camera.enabled = false
	var camera := Camera2D.new()
	cena.add_child(camera)
	camera.global_position = Vector2(0, 60)
	camera.make_current()
	var imagem := Image.load_from_file("res://arte/fontes/inimigos/goblins_moinho/modelos_v1.png")
	var textura := ImageTexture.create_from_image(imagem)
	var modelos: Array[Sprite2D] = []
	for i in 2:
		var modelo := Sprite2D.new()
		modelo.texture = textura
		modelo.hframes = 3
		modelo.vframes = 2
		modelo.offset = Vector2(0, 256 - (480 if i == 0 else 448))
		modelo.scale = Vector2.ONE * 0.075
		modelo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		modelo.position = Vector2(8 + i * 48, 92)
		modelo.z_index = preload("res://codigo/globais/profundidade.gd").z_de(92)
		cena.add_child(modelo)
		modelos.append(modelo)
	var pasta := "res://arte/previas/inimigos/goblins_moinho/"
	for direcao in 3:
		for i in 2:
			modelos[i].frame = i * 3 + direcao
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta + ["frente", "perfil", "costas"][direcao] + "-escala.png")
		print("MODELOS_GOBLINS ", direcao)
	quit()
