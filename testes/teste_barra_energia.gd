extends SceneTree

## Renderização do HUD com save isolado; posição fora do joystick e energia cheia/baixa/vazia.
var falhas := 0

func _initialize() -> void:
	_rodar.call_deferred()

func _quadros() -> void:
	for i in 12: await process_frame

func _verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use uma cópia com save isolado.")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	var controle := root.get_node("Controle")
	controle.usando_toque = true
	root.get_node("Introducao").pular_prologo()
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	var cena: Node = load("res://cenas/ui.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await _quadros()
	var hud := get_first_node_in_group("hud")
	hud._criar_barra_energia()
	await _quadros()
	var barra: Control = hud.barra_energia
	var status: Control = hud.get_node("Status")
	var capturar := "--capturar" in OS.get_cmdline_user_args()
	var pasta := "res://arte/previas/ui/energia"
	if capturar: DirAccess.make_dir_recursive_absolute(pasta)
	for tamanho in [Vector2i(720,324), Vector2i(576,324), Vector2i(480,270)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await _quadros()
		var area := barra.get_global_rect()
		_verificar("energia visível e dentro da tela %s" % tamanho, barra.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(tamanho)).encloses(area))
		_verificar("energia abaixo do status %s" % tamanho, area.position.y >= status.get_global_rect().end.y + 6)
		_verificar("energia fora da região inferior do joystick %s" % tamanho, area.end.y < tamanho.y / 2.0)
		for valor in [100,20,0]:
			root.get_node("Fazenda")._definir_energia(1,valor)
			await _quadros()
			await RenderingServer.frame_post_draw
			var imagem := root.get_texture().get_image()
			var escala := Vector2(imagem.get_size()) / Vector2(tamanho)
			var ponto := (area.position + Vector2(4.5, barra.ALTURA - 5.5)) * escala
			var cor := imagem.get_pixelv(Vector2i(ponto))
			var preenchido := cor.g > cor.r and cor.g > cor.b if valor == 100 else cor.r > cor.g and cor.r > cor.b
			if valor == 0:
				var vazia: Color = barra.DesenhoBarra.VAZIA[0].get_image().get_pixel(5,3)
				preenchido = cor.is_equal_approx(vazia)
			_verificar("preenchimento renderizado %s energia %d" % [tamanho,valor], preenchido)
			if capturar: imagem.save_png("%s/mobile_%dx%d_%d.png" % [pasta,tamanho.x,tamanho.y,valor])
	controle.usando_toque = false
	barra._posicionar()
	await _quadros()
	_verificar("desktop preserva canto inferior direito", barra.get_global_rect().end.is_equal_approx(Vector2(472,262)))
	cena.queue_free()
	current_scene = null
	await _quadros()
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
