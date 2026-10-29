extends SceneTree
## Revisão gráfica isolada: não carrega autoloads, arenas ou saves da partida.
const MODELO := "res://assets/inimigos/goblin_king/goblin_king.glb"
const SAIDA := "res://arte/previas/inimigos/goblin_king/"
var viewport: SubViewport
var camera: Camera3D
var modelo: Node3D
var animador: AnimationPlayer

func _initialize() -> void:
	rodar.call_deferred()

func procurar(no: Node, tipo: String) -> Node:
	if no.is_class(tipo): return no
	for filho in no.get_children():
		var resultado := procurar(filho, tipo)
		if resultado != null: return resultado
	return null

func luz(posicao: Vector3, cor: Color, energia: float) -> void:
	var sol := DirectionalLight3D.new()
	viewport.add_child(sol)
	sol.position = posicao
	sol.look_at(Vector3(0, 1.6, 0))
	sol.light_color = cor
	sol.light_energy = energia
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 12

func capturar(nome: String) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagem := viewport.get_texture().get_image()
	assert(imagem.save_png(SAIDA + nome + ".png") == OK)
	var usado := imagem.get_used_rect()
	assert(usado.has_area(), "Renderização vazia")
	assert(usado.position.x > 8 and usado.position.y > 8, "Modelo encosta na margem superior/esquerda")
	assert(usado.end.x < imagem.get_width()-8 and usado.end.y < imagem.get_height()-8, "Modelo cortado")
	return imagem

func rodar() -> void:
	assert(DisplayServer.get_name() != "headless", "Revisão exige renderização real")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1000, 1100)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var mundo := WorldEnvironment.new()
	mundo.environment = Environment.new()
	mundo.environment.background_mode = Environment.BG_CLEAR_COLOR
	mundo.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	mundo.environment.ambient_light_color = Color("acb6c8")
	mundo.environment.ambient_light_energy = .28
	mundo.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(mundo)
	luz(Vector3(-3,5,5), Color("ffe0b1"), .75)
	luz(Vector3(4,2,3), Color("a9c9ff"), .25)
	luz(Vector3(1,4,-3), Color("ffb56e"), .6)
	modelo = load(MODELO).instantiate()
	viewport.add_child(modelo)
	var esqueleto := procurar(modelo, "Skeleton3D") as Skeleton3D
	assert(esqueleto != null and esqueleto.get_bone_count() >= 16)
	animador = procurar(modelo, "AnimationPlayer") as AnimationPlayer
	assert(animador != null)
	var clipe := ""
	for nome in animador.get_animation_list():
		if "parado" in nome: clipe = nome
	assert(not clipe.is_empty(), "Ciclo parado não foi importado")
	animador.play(clipe)
	animador.speed_scale = 0
	animador.seek(0, true)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.95
	camera.near = .01
	camera.far = 40
	var vistas := {
		"frente": Vector3(0, 2.1, 7),
		"tres_quartos": Vector3(4.1, 3.1, 7),
		"costas": Vector3(0, 2.4, -7),
		"perfil": Vector3(-7, 2.4, .01),
		"camera_jogo": Vector3(0, 4.3, 7)
	}
	for nome in vistas:
		camera.position = vistas[nome]
		camera.look_at(Vector3(-.05, 1.62, 0))
		await capturar(nome)
	camera.position = vistas.tres_quartos
	camera.look_at(Vector3(-.05, 1.62, 0))
	var duracao := animador.get_animation(clipe).length
	for i in 16:
		animador.seek(duracao*i/16.0, true)
		await capturar("parado_%02d" % i)
	# Instancia a mesma apresentação que pode ser colocada no mapa 2D do jogo.
	root.size = Vector2i(960, 420)
	var palco := Node2D.new()
	root.add_child(palco)
	var chao := Line2D.new()
	chao.points = PackedVector2Array([Vector2(35, 320), Vector2(925, 320)])
	chao.width = 1
	chao.default_color = Color("657568")
	palco.add_child(chao)
	for i in 4:
		var visual = load("res://cenas/inimigos/goblin_king_visual.tscn").instantiate()
		palco.add_child(visual)
		visual.position = Vector2(165+i*210, 320)
		visual.definir_direcao([Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT][i])
		assert(visual.animador != null and visual.animador.is_playing())
		assert(visual._sprite.offset.y < 0, "Origem deve permanecer nos pés")
		assert(visual._sprite.material.shader.resource_path == "res://codigo/jogador/contorno_pixel_base_3d.gdshader")
		assert(visual._viewport.msaa_3d == Viewport.MSAA_DISABLED)
		assert(visual._sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(SAIDA+"visual_2d.png") == OK)
	palco.queue_free()
	await process_frame
	root.size = Vector2i(1280, 720)
	var comparacao := Node2D.new()
	root.add_child(comparacao)
	for i in 2:
		var visual = load("res://cenas/inimigos/goblin_king_visual.tscn").instantiate()
		visual.acabamento_pixel_art = i == 1
		comparacao.add_child(visual)
		visual.position = Vector2(320+i*640, 620)
		visual.scale = Vector2(4, 4)
		visual.definir_direcao(Vector2(.4, 1))
		visual.animador.pause()
		visual.animador.seek(0, true)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(SAIDA+"comparacao_filtro.png") == OK)
	var relatorio := {"motor": Engine.get_version_info().string, "ossos": esqueleto.get_bone_count(),
		"clipe": clipe, "duracao_s": duracao, "quadros_revisados": 16, "vistas": vistas.keys(),
		"save_carregado": false, "margens_integras": true,
		"filtro_personagem": "res://codigo/jogador/contorno_pixel_base_3d.gdshader", "amostras_por_pixel": 2}
	var arquivo := FileAccess.open(SAIDA+"validacao_godot.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(relatorio, "\t")+"\n")
	print("GOBLIN_KING_REVISAO_OK ", JSON.stringify(relatorio))
	quit()
