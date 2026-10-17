extends SceneTree

const HEROI := preload("res://codigo/jogador/heroi_gerado.gd")
const PREVIA := preload("res://ferramentas/personagem/previa_espada_gerada.gd")
const SAIDA := "res://arte/previas/personagens/exemplo_alta_qualidade/ataque_direita/"
const TEMPORARIOS := "/tmp/algoland-ataque-direita/"

func _initialize() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Prévia exige save isolado.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	DirAccess.make_dir_recursive_absolute(TEMPORARIOS)
	var janela := SubViewport.new()
	janela.size = Vector2i(640, 640)
	janela.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(janela)
	var fundo := ColorRect.new()
	fundo.size = Vector2(640, 640)
	fundo.color = Color("26343b")
	janela.add_child(fundo)
	var titulo := Label.new()
	titulo.text = "ATAQUE — DIREITA"
	titulo.position = Vector2(0, 30)
	titulo.size = Vector2(640, 40)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	janela.add_child(titulo)
	var jogador := PREVIA.JogadorPrevia.new()
	jogador.position = Vector2(260, 520)
	janela.add_child(jogador)
	var visual := HEROI.new()
	jogador.add_child(visual)
	visual.set_process(false)
	visual.position = Vector2.ZERO
	visual.scale = Vector2.ONE * 0.5
	for quadro in 50:
		if quadro == 10:
			visual.iniciar_ataque_espada(0.3, true)
		visual._process(0.0 if quadro in [0, 10] else 0.02)
		await process_frame
		await RenderingServer.frame_post_draw
		janela.get_texture().get_image().save_png(TEMPORARIOS + "quadro_%03d.png" % quadro)
	# As poses isoladas têm alpha para comparação sobre o mesmo fundo da referência.
	fundo.hide()
	titulo.hide()
	janela.transparent_bg = true
	for i in 9:
		visual.iniciar_ataque_espada(0.3, true)
		visual._tempo_espada_ms = visual.FASES_ESPADA_DIREITA[i] * 300.0 + 0.01
		visual._process(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		janela.get_texture().get_image().save_png(SAIDA + "pose_%d.png" % i)
	print("PRÉVIA DIREITA: controlador real, nove poses e ciclo de ataque de 300 ms.")
	janela.queue_free()
	await process_frame
	quit()
