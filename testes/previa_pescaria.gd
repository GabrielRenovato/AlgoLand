extends SceneTree
func _initialize() -> void:
	_rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n: await process_frame
func foto(nome: String) -> void:
	await quadros()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://arte/previas/pesca/"+nome+".png")
func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/pesca"))
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Transicao").hora_salva = 12
	root.get_node("Cidade").trajetos_moradores = {}
	change_scene_to_file("res://cenas/palafita.tscn")
	await quadros(40)
	current_scene.get_node("Iluminacao").definir_hora(12)
	current_scene.get_node("Iluminacao").set_process(false)
	for filho in current_scene.get_children():
		if filho is CanvasLayer: filho.hide()
	await foto("loja_nilo")
	var interface: Node = current_scene.get_node("Interface")
	interface.show()
	var jogador: Node = current_scene.get_node("Jogador")
	root.get_node("Cidade").conversar("nilo",jogador)
	await create_timer(0.3).timeout
	var dialogo: Node = interface._telas["conversa_cidade"]
	dialogo._ver_vara()
	await foto("oficina_nilo")
	interface._fechar_tela("conversa_cidade")
	root.get_node("Fazenda").pescar("sardinha")
	root.get_node("Fazenda").pescar("carpa")
	interface._abrir_tela("inventario")
	var inv: Node = interface._telas["inventario"]
	inv.selecionar_pagina(3)
	await create_timer(0.3).timeout
	await foto("catalogo_grade")
	var slot: Control = inv._pesca._grade_peixes.get_child(0)
	inv._pesca._mostrar_dica("sardinha",slot)
	await foto("catalogo_tooltip")
	inv.selecionar_pagina(2)
	await foto("armas_grade")
	var arma: Control = inv._desafios._grade_catalogo.get_child(0)
	inv._desafios._mostrar_dica(String(arma.get_meta("catalogo")),arma)
	await foto("armas_tooltip")
	print("PREVIAS CONCLUIDAS")
	quit()
