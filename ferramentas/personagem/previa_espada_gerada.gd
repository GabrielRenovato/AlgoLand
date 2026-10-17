extends SceneTree

const HEROI := preload("res://codigo/jogador/heroi_gerado.gd")
const SAIDA := "res://arte/previas/personagens/exemplo_alta_qualidade/ataque_espada/"
const TEMPORARIOS := "/tmp/algoland-espada-transicao/"

class JogadorPrevia extends Node2D:
	var _direcao_ataque := Vector2.RIGHT
	var velocity := Vector2.ZERO
	var usando_espada := false
	var esta_forjando := false
	var esta_sentado := false
	var esta_em_acao_fazenda := false
	var _esta_atacando := false
	var esta_em_dash := false
	var caido := false
	var no_reacao: CanvasItem

func _initialize() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Prévia exige save isolado.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	DirAccess.make_dir_recursive_absolute(TEMPORARIOS)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 660)
	root.content_scale_size = Vector2i(240, 110)
	var cena := Node2D.new()
	root.add_child(cena)
	var fundo := ColorRect.new()
	fundo.size = Vector2(240, 110)
	fundo.color = Color("26343b")
	cena.add_child(fundo)
	var jogadores: Array[JogadorPrevia] = []
	var visuais: Array[Sprite2D] = []
	var rotulos: Array[Label] = []
	for i in 3:
		var titulo := Label.new()
		titulo.text = ["LADO", "FRENTE", "COSTAS"][i]
		titulo.position = Vector2(i * 80, 3)
		titulo.size = Vector2(80, 12)
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo.add_theme_font_size_override("font_size", 8)
		cena.add_child(titulo)
		var estado := Label.new()
		estado.position = Vector2(i * 80, 16)
		estado.size = Vector2(80, 12)
		estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		estado.add_theme_font_size_override("font_size", 6)
		cena.add_child(estado)
		rotulos.append(estado)
		var linha := Line2D.new()
		linha.points = PackedVector2Array([Vector2(i * 80 + 9, 75), Vector2(i * 80 + 71, 75)])
		linha.width = 0.3
		linha.default_color = Color("6f898a")
		cena.add_child(linha)
		var jogador := JogadorPrevia.new()
		jogador.position = Vector2(40 + i * 80, 75)
		jogador._direcao_ataque = [Vector2.RIGHT, Vector2.DOWN, Vector2.UP][i]
		cena.add_child(jogador)
		var visual := HEROI.new()
		visual.correndo = true
		jogador.add_child(visual)
		visual.set_process(false)
		visual.position = Vector2.ZERO
		visual.scale = Vector2.ONE * 1.4 / 16.0
		jogadores.append(jogador)
		visuais.append(visual)
	for quadro in 50:
		var tempo := quadro * 20
		for i in jogadores.size():
			jogadores[i].velocity = Vector2.ZERO
			var visual = visuais[i]
			if quadro == 10:
				visual.iniciar_ataque_espada(0.3, true)
			visual._process(0.0 if quadro in [0, 10] else 0.02)
			rotulos[i].text = "ATACANDO" if visual._espada_ativa else "PARADO"
		await process_frame
		await RenderingServer.frame_post_draw
		var imagem := root.get_texture().get_image()
		imagem.save_png(TEMPORARIOS + "quadro_%03d.png" % quadro)
		if tempo in [0, 200, 240, 280, 320, 400, 460, 500]:
			imagem.save_png(SAIDA + "etapa_%04d.png" % tempo)
	print("ESPADA RENDERIZADA: controlador real, três direções, golpe curto de 300 ms e retorno ao idle, 1 segundo.")
	cena.queue_free()
	await process_frame
	quit()
