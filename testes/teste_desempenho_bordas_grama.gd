extends SceneTree
## Compara a rasterização dos lotes com os pixels originais, nas quatro estações.
class Referencia extends Node2D:
	var pixels: Dictionary
	func _draw() -> void:
		for ponto in pixels: draw_rect(Rect2(Vector2(ponto), Vector2.ONE), pixels[ponto])
class Lote extends Node2D:
	var malha: ArrayMesh
	func _draw() -> void:
		if malha != null and malha.get_surface_count() > 0: draw_mesh(malha, null)
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(ok: bool, mensagem: String) -> void:
	print("OK " if ok else "FALHA ", mensagem)
	if not ok: falhas += 1
func quadros(n := 4) -> void:
	for i in n: await process_frame
func viewport_com(no: Node2D, area: Rect2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = area.size
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.world_2d = World2D.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	no.position = -Vector2(area.position)
	vp.add_child(no)
	return vp
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1)
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280,576)
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(40)
	var vila := current_scene
	var bordas = vila._bordas_grama
	bordas.set_process(false)
	var camera: Camera2D = vila.get_node("Jogador").camera
	camera.set_as_top_level(true)
	camera.position_smoothing_enabled = false
	camera.position = Vector2(336,320)
	var terreno: TileMapLayer = vila.get_node("Terrains/Terreno")
	var agua: TileMapLayer = vila.get_node("Terrains/SuperficieAgua")
	var area := terreno.get_used_rect().merge(agua.get_used_rect())
	area = Rect2i(area.position * 16, area.size * 16).grow(16)
	var referencia := Referencia.new()
	var lote := Lote.new()
	var vp_a := viewport_com(referencia, area)
	var vp_b := viewport_com(lote, area)
	var nomes := ["primavera","verao","outono","inverno"]
	for estacao in 4:
		vila.get_node("Terrains/Estacoes").definir_estacao(estacao, true)
		vila._atualizar_ambiente()
		await quadros()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-bordas-%s.png" % nomes[estacao])
		for fase in 8:
			bordas._fase = fase
			bordas.queue_redraw()
			await quadros(2)
			referencia.pixels = bordas.pixels_visiveis()
			lote.malha = bordas._quadros[fase] if not bordas._quadros.is_empty() else null
			referencia.queue_redraw()
			lote.queue_redraw()
			await quadros(2)
			await RenderingServer.frame_post_draw
			var igual := vp_a.get_texture().get_image().get_data() == vp_b.get_texture().get_image().get_data()
			verificar(igual, "rasterização idêntica: %s / fase %d" % [nomes[estacao],fase])
			if not igual:
				vp_a.get_texture().get_image().save_png("/tmp/algoland-bordas-referencia.png")
				vp_b.get_texture().get_image().save_png("/tmp/algoland-bordas-lote.png")
		if estacao != 3:
			var id: int = bordas._quadros[0].get_instance_id()
			var inicio := Time.get_ticks_usec()
			for i in 80: bordas._process(.28)
			verificar(bordas._quadros[0].get_instance_id() == id, "vento reutiliza geometria em " + nomes[estacao])
			print("CPU de 80 trocas de fase (us): ", Time.get_ticks_usec()-inicio)
	# Verifica também a volta do inverno ao ciclo animado.
	bordas.configurar(terreno,agua,0)
	bordas._preparar_quadros()
	verificar(bordas._quadros.size() == 8, "retorno do inverno restaura os oito quadros")
	vp_a.queue_free()
	vp_b.queue_free()
	await quadros()
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
