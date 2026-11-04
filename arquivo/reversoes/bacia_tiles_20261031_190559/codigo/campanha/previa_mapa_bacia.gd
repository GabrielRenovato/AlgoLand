extends Node2D

## Captura isolada do terreno completo para revisar a composição e as estações.
const LARGURA := 1536.0
const ALTURA := 1024.0

func _ready() -> void:
	var terreno := preload("res://cenas/campanha/terreno_moinho.tscn").instantiate()
	terreno.name = "Terreno"
	terreno.set_meta("captura_visual", true)
	add_child(terreno)
	var camera := Camera2D.new()
	camera.name = "CameraVisaoGeral"
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE * minf(get_viewport_rect().size.x / LARGURA, get_viewport_rect().size.y / ALTURA) * 0.94
	camera.enabled = true
	add_child(camera)
	camera.make_current()
	var capturas := ""
	for argumento in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if argumento.begins_with("--capturas="):
			capturas = argumento.trim_prefix("--capturas=")
	if not capturas.is_empty():
		_capturar_estacoes.call_deferred(capturas, terreno, camera)

func _capturar_estacoes(destino: String, terreno: Node, camera: Camera2D) -> void:
	DirAccess.make_dir_recursive_absolute(destino)
	for i in 4:
		terreno.definir_estacao(i)
		for quadro in 2:
			await get_tree().process_frame
			await get_tree().physics_frame
		var nome: String = ["primavera", "verao", "outono", "inverno"][i]
		var erro := get_viewport().get_texture().get_image().save_png(destino.path_join("bacia_moinho_%s.png" % nome))
		if erro != OK:
			push_error("Não salvou a captura da estação %s: %s" % [nome, erro])
	get_tree().quit()
