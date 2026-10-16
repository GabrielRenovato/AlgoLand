extends SceneTree

## Reproduz o vazamento antigo e o recorte atual na cena real, com saves isolados.
class Antes:
	extends Node2D
	var solo_dados: Dictionary
	func _draw() -> void:
		var solo := load("res://codigo/cenario/solo_arado.gd")
		for celula in solo_dados:
			draw_texture(solo.textura(0, false, celula, solo.vizinhos(solo_dados, celula)), Vector2(celula) * 16)

func _initialize() -> void:
	_rodar()

func quadros(n := 12) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		quit(1)
		return
	await process_frame
	var pasta := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	root.get_node("Calendario").dia = 1
	root.get_node("Fazenda").solo.clear()
	root.get_node("Fazenda").entulho.clear()
	root.get_node("Fazenda").entulho_iniciado = true
	root.get_node("Fazenda").definir_clima_hoje(0)
	root.get_node("Transicao").hora_salva = 12.0
	var cena: Node2D = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros()
	cena.get_node("Iluminacao").set_process(false)
	cena.get_node("Iluminacao")._aplicar()
	cena.get_node("Jogador").position = Vector2(240, 450)
	cena.get_node("Jogador").set_physics_process(false)
	for hud in get_nodes_in_group("hud"):
		hud.hide()
	var camera := Camera2D.new()
	camera.position = Vector2(112, 352)
	camera.zoom = Vector2(5, 5)
	cena.add_child(camera)
	camera.make_current()
	var fazenda: Node = root.get_node("Fazenda")
	for y in range(21, 24):
		for x in range(6, 9):
			fazenda.solo[Vector2i(x, y)] = {"molhado": false, "planta": "", "dias": 0, "murcha": false}
	var plantio: Node2D = cena.get_node("Terrains/Plantio")
	plantio.set_process(false)
	plantio._cursor_visivel = false
	plantio.visible = false
	var antes := Antes.new()
	antes.solo_dados = fazenda.solo
	antes.z_index = -997
	cena.get_node("Terrains").add_child(antes)
	await quadros()
	root.get_texture().get_image().save_png(pasta.path_join("limite_plantio_antes.png"))
	antes.visible = false
	plantio.visible = true
	plantio.queue_redraw()
	await quadros()
	root.get_texture().get_image().save_png(pasta.path_join("limite_plantio_depois.png"))
	cena.queue_free()
	current_scene = null
	await quadros()
	quit()
