extends SceneTree

class ApoioInvadindoPiso extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(320, 400, 48, 32), Color.MAGENTA)

## Regressão visual: ligar os apoios não pode alterar nenhum pixel do piso caminhável.
## Exige renderização gráfica real, em cópia com save isolado.
func _initialize() -> void:
	_rodar()

func capturar(vista: SubViewport) -> Image:
	for i in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	return vista.get_texture().get_image()

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Execute em cópia com saves isolados.")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Este teste compara pixels renderizados; execute com renderização gráfica.")
		quit(1)
		return
	await process_frame
	var fonte: Node = load("res://cenas/praia.tscn").instantiate()
	var vista := SubViewport.new()
	vista.size = Vector2i(704, 576)
	vista.world_2d = World2D.new()
	vista.transparent_bg = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var terreno := Node2D.new()
	terreno.name = "Terrains"
	vista.add_child(terreno)
	terreno.add_child(fonte.get_node("Terrains/AreiaMar").duplicate())
	var piso: TileMapLayer = fonte.get_node("Terrains/Pier").duplicate()
	terreno.add_child(piso)
	fonte.free()
	var base := await capturar(vista)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://codigo/pesca/layout_praia.json"))
	var estrutura := preload("res://codigo/pesca/estrutura_cais.gd").new()
	estrutura.configurar(layout)
	vista.add_child(estrutura)
	var normal := await capturar(vista)
	# Força uma ordem errada: a máscara deve proteger o piso mesmo nessa condição.
	estrutura.z_index = piso.z_index + 1
	var acima := await capturar(vista)
	var invasor := ApoioInvadindoPiso.new()
	invasor.use_parent_material = true
	estrutura.add_child(invasor)
	var forçado := await capturar(vista)
	var invasoes_normal := 0
	var invasoes_acima := 0
	var apoios_visiveis := 0
	var invasoes_forcadas := 0
	for y in 576:
		for x in 704:
			var original := base.get_pixel(x, y)
			var ocupado := piso.get_cell_source_id(Vector2i(x / 16, y / 16)) != -1
			if ocupado:
				invasoes_normal += int(normal.get_pixel(x, y) != original)
				invasoes_acima += int(acima.get_pixel(x, y) != original)
				invasoes_forcadas += int(forçado.get_pixel(x, y) != original)
			elif normal.get_pixel(x, y) != original:
				apoios_visiveis += 1
	print("Pixels do piso alterados na ordem real: ", invasoes_normal)
	print("Pixels do piso alterados com apoios acima: ", invasoes_acima)
	print("Pixels visíveis dos apoios fora do piso: ", apoios_visiveis)
	print("Pixels do piso alterados por invasão proposital: ", invasoes_forcadas)
	var ok := invasoes_normal == 0 and invasoes_acima == 0 and invasoes_forcadas == 0 and apoios_visiveis > 500
	print("Sobreposição do cais: ", "OK" if ok else "FALHA")
	vista.queue_free()
	await process_frame
	quit(0 if ok else 1)
