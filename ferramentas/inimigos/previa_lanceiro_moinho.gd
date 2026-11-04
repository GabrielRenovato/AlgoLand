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
	set_meta("dicas_vistas", {"golpe": true, "rebento": true})
	var cena = current_scene
	var jogador = cena.jogador
	jogador.set_physics_process(false)
	jogador.global_position = Vector2(-112, 80)
	for mob in get_nodes_in_group("enemy"):
		mob.set_physics_process(false)
		mob.hide()
	for camera in cena.find_children("*", "Camera2D", true, false):
		camera.enabled = false
	var camera := Camera2D.new()
	cena.add_child(camera)
	camera.global_position = Vector2(-16, 60)
	camera.make_current()
	var modelos: Array[AnimatedSprite2D] = []
	var direcoes := ["baixo", "direita", "cima", "esquerda"]
	for i in 4:
		var visual := load("res://cenas/inimigos/goblin_lanceiro_visual.tscn").instantiate() as AnimatedSprite2D
		visual.position = Vector2(-64 + i * 48, 92)
		visual.z_index = preload("res://codigo/globais/profundidade.gd").z_de(92)
		cena.add_child(visual)
		modelos.append(visual)
	var pasta := "res://arte/previas/inimigos/goblins_moinho/lanceiro/"
	var capturas: Array[Dictionary] = []
	for acao in ["andar", "ataque"]:
		for i in 4:
			modelos[i].tocar(acao, direcoes[i])
		# Reprodução real do SpriteFrames: dois ciclos de caminhada e um ataque.
		if acao == "andar":
			await create_timer(1.2).timeout
		else:
			await modelos[0].animation_finished
		for visual in modelos:
			visual.stop()
		for q in 6:
			for visual in modelos:
				visual.frame = q
			await process_frame
			await RenderingServer.frame_post_draw
			capturas.append({"nome": acao + "-%d.png" % q, "imagem": root.get_texture().get_image()})
		print("LANCEIRO_REPRODUCAO ", acao, " quatro direcoes, seis poses")
	for captura in capturas:
		captura.imagem.save_png(pasta + captura.nome)
	quit()
