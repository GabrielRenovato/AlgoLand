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
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(45)
	current_scene.get_node("Iluminacao").definir_hora(12)
	current_scene.get_node("Iluminacao").set_process(false)
	var npc: Node2D = current_scene.moradores["bento"]
	current_scene.get_node("Jogador").position = npc.position+Vector2(0,30)
	root.get_node("Cidade")._limpar_estado()
	root.get_node("Cidade").aceitar("horta")
	for filho in current_scene.get_children():
		if filho is CanvasLayer: filho.hide()
	await create_timer(3).timeout
	npc.dizer("O mural tem pedidos novos. Passe la quando puder!",30)
	await create_timer(0.3).timeout
	await foto("baloes_pedido_fala")
	print("PREVIAS CONCLUIDAS")
	quit()
