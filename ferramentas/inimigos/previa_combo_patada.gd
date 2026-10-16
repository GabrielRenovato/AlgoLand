extends SceneTree

class AlvoPrevia extends Node2D:
	var estaMorto := false
	var invulneravel := false
	var forca := Vector2.ZERO
	var ferido := 0.0
	func receber_dano(_dano: int, empurrao: Vector2) -> void:
		forca = empurrao
		ferido = 0.2
	func atualizar(delta: float) -> void:
		forca = forca.move_toward(Vector2.ZERO, 950 * delta)
		position += forca * delta
		ferido = maxf(0, ferido - delta)

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	var jogo := Node2D.new()
	root.add_child(jogo)
	current_scene = jogo
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	jogo.add_child(viewport)
	var palco := Node2D.new()
	viewport.add_child(palco)
	var jogador := AlvoPrevia.new()
	jogador.name = "Jogador"
	jogador.position = Vector2(254, 250)
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
	chefe.position = Vector2(200, 250)
	chefe.set_physics_process(false)
	var camada := CanvasLayer.new()
	palco.add_child(camada)
	var texto := Label.new()
	texto.position = Vector2(20, 20)
	texto.add_theme_font_size_override("font_size", 20)
	camada.add_child(texto)
	var saida := "res://arte/previas/inimigos/dragao_vermelho/patada/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	for i in 70:
		jogador.atualizar(0.05)
		jogador.z_index = preload("res://codigo/globais/profundidade.gd").z_de(jogador.position.y + 11)
		chefe._physics_process(0.05)
		avatar.position = jogador.position
		avatar.z_index = jogador.z_index
		avatar.modulate = Color(1, 0.6, 0.5) if jogador.ferido > 0 else Color.WHITE
		texto.text = "PATADA: MENOS DANO + EMPURRAO" if chefe.ataque_atual == "patada" else "COMBO: SOPRO NA NOVA POSICAO"
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(saida + "quadro_%03d.png" % i)
	jogo.queue_free()
	await process_frame
	quit()
