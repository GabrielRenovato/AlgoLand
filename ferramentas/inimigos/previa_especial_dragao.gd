extends SceneTree

class AlvoPrevia extends Node2D:
	var estaMorto := false
	func receber_hitkill_dragao() -> void:
		estaMorto = true

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	var jogo := Node2D.new()
	root.add_child(jogo)
	current_scene = jogo
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	jogo.add_child(viewport)
	var palco := Node2D.new()
	viewport.add_child(palco)
	var terreno = load("res://cenas/terreno.tscn").instantiate()
	palco.add_child(terreno)
	var contorno: CollisionPolygon2D = terreno.get_node("LimiteArena/Contorno")
	var mapa := Node2D.new()
	mapa.name = "Terrains"
	jogo.add_child(mapa)
	var limite := StaticBody2D.new()
	limite.name = "LimiteArena"
	limite.collision_layer = 0
	mapa.add_child(limite)
	var copia := CollisionPolygon2D.new()
	copia.name = "Contorno"
	copia.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	copia.polygon = contorno.polygon
	limite.add_child(copia)
	var camera := Camera2D.new()
	camera.position = Vector2(316, 138)
	palco.add_child(camera)
	var jogador := AlvoPrevia.new()
	jogador.name = "Jogador"
	jogador.position = Vector2(350, 200)
	jogo.add_child(jogador)
	var avatar := Node2D.new()
	palco.add_child(avatar)
	var modelo = load("res://cenas/jogador.tscn").instantiate()
	for parte in ["Corpo", "Roupa", "Cabelo"]:
		var original: Sprite2D = modelo.get_node("CompositeSprites/BaseSprites/" + parte)
		var sprite := Sprite2D.new()
		sprite.texture = original.texture
		sprite.hframes = original.hframes
		sprite.vframes = original.vframes
		sprite.frame = original.frame
		sprite.position = original.position
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		avatar.add_child(sprite)
	modelo.free()
	var chefe = load("res://cenas/inimigos/dragao_vermelho.tscn").instantiate()
	palco.add_child(chefe)
	chefe.set_physics_process(false)
	chefe.position = Vector2(320, 160)
	chefe._linha = 2
	chefe._iniciar_especial()
	var inicio := jogador.position
	var destino := Vector2.ZERO
	var melhor := INF
	for y in range(-150, 400, 40):
		for x in range(-50, 720, 40):
			var ponto := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(ponto, copia.polygon) and not Geometry2D.is_point_in_polygon(ponto, chefe._chuva.zona):
				if ponto.distance_squared_to(inicio) < melhor:
					melhor = ponto.distance_squared_to(inicio)
					destino = ponto
	var camada := CanvasLayer.new()
	palco.add_child(camada)
	var texto := Label.new()
	texto.position = Vector2(20, 20)
	texto.add_theme_font_size_override("font_size", 24)
	camada.add_child(texto)
	var saida := "res://arte/previas/inimigos/dragao_vermelho/especial/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	for i in 47:
		var relogio := i * 0.2
		jogador.position = inicio.lerp(destino, clampf((relogio - 1.2) / 2.6, 0, 1))
		avatar.position = jogador.position
		avatar.z_index = preload("res://codigo/globais/profundidade.gd").z_de(avatar.position.y + 11)
		chefe._physics_process(0.2)
		match chefe.estado:
			chefe.Estado.SUBINDO: texto.text = "ESPECIAL — DECOLAGEM"
			chefe.Estado.CHUVA:
				texto.text = "FUJA DA METADE VERMELHA — %ds" % maxi(0, ceili(3 - chefe._tempo_especial)) if chefe._tempo_especial < 3 else "CHUVA DE FOGO — MORTE IMEDIATA"
			chefe.Estado.DESCENDO: texto.text = "POUSO"
			_: texto.text = "COMBATE RETOMADO"
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(saida + "quadro_%03d.png" % i)
	jogo.queue_free()
	await process_frame
	quit()
