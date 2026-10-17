extends SceneTree

## Foto do protótipo do herói Tiny RPG (jogador parado, andando e atacando, 4 direções). Saves isolados obrigatórios.

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/cidade.tscn")
	for i in 30:
		await process_frame
	var jogador: Node2D = current_scene.get_node("Jogador")
	jogador.add_child(HeroiTiny.new())
	var tiny: Sprite2D = jogador.get_node("HeroiTiny")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/tiny"))
	var i := 0
	for dir in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		jogador._direcao_ataque = dir
		jogador.velocity = Vector2.ZERO
		for q in 8:
			await process_frame
		jogador.velocity = dir * 60.0
		for q in 8:
			await process_frame
		jogador.global_position = jogador.global_position
		root.get_texture().get_image().save_png("res://arte/previas/tiny/heroi_%d.png" % i)
		i += 1
	print("anim=", tiny._animacao, " pos=", tiny.position)
	quit(0)
