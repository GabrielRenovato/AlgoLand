extends SceneTree
const PASTA := "res://arte/previas/cenario/refinado/"
var falhas := 0

func _initialize() -> void:
	_rodar()

func _quadros() -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		quit(1)
		return
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960,640)
	root.content_scale_size = Vector2i(480,320)
	var acabamento: Node = root.get_node("TilesRefinados")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	for tomada in [
		["cidade","res://cenas/cidade.tscn",Vector2(352,288)],
		["fazenda","res://cenas/fazenda.tscn",Vector2(600,320)],
		["casa","res://cenas/casa.tscn",Vector2(144,120)],
		["pousada","res://cenas/cidade/pousada.tscn",Vector2(144,88)],
		["arena","res://cenas/cenario.tscn",Vector2(332,137)]]:
		root.get_node("Calendario").dia = 1
		root.get_node("Transicao").hora_salva = 12
		var cena: Node = load(tomada[1]).instantiate()
		root.add_child(cena)
		current_scene = cena
		await _quadros()
		var luz := cena.get_node_or_null("Iluminacao")
		if luz != null:
			luz.set_process(false)
			luz.definir_hora(12)
		var jogador: Node = cena.get_node("Jogador")
		jogador.camera.position_smoothing_enabled = false
		jogador.camera.set_as_top_level(true)
		jogador.camera.global_position = tomada[2]
		jogador.camera.limit_left = -10000
		jogador.camera.limit_top = -10000
		jogador.camera.limit_right = 10000
		jogador.camera.limit_bottom = 10000
		cena.process_mode = Node.PROCESS_MODE_DISABLED
		for grupo in get_nodes_in_group("hud"):
			grupo.hide()
		for ativa in [false,true]:
			acabamento.ativo = ativa
			await _quadros()
			root.get_texture().get_image().save_png(PASTA+tomada[0]+("_depois" if ativa else "_antes")+".png")
		cena.queue_free()
		current_scene = null
		await _quadros()
	# Confere alfa e tintura contra o shader padrão do motor.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64,64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var imagem := Image.create(16,16,false,Image.FORMAT_RGBA8)
	imagem.fill(Color(0.4,0.7,0.2,0.5))
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(imagem)
	sprite.centered = false
	sprite.position = Vector2(16,16)
	sprite.modulate = Color(0.7,0.8,0.9,0.6)
	viewport.add_child(sprite)
	await _quadros()
	var original := viewport.get_texture().get_image().get_pixel(20,20)
	sprite.material = acabamento.material_tiles
	acabamento.ativo = false
	await _quadros()
	var desligado := viewport.get_texture().get_image().get_pixel(20,20)
	acabamento.ativo = true
	await _quadros()
	var refinado := viewport.get_texture().get_image().get_pixel(20,20)
	if original.a != refinado.a or original != desligado:
		falhas += 1
		print("FALHA alfa/tintura: ",original," / ",desligado," / ",refinado)
	viewport.queue_free()
	await _quadros()
	print("Prévia GPU: cinco mapas; alfa e tintura; falhas: ",falhas)
	quit(falhas)
