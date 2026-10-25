extends SceneTree

var Sessao: GDScript
const Habilidade := preload("res://codigo/pesca/progressao_pesca.gd")
var falhas := 0

func _initialize() -> void:
	_rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func quadros(n := 6) -> void:
	for i in n: await process_frame

func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://arte/previas/pesca/aviso_captura/" + nome + ".png")

func conferir(aviso: Control, jogador: Node2D, contexto: String) -> void:
	verificar(contexto + " tamanho compacto", aviso.size.x <= 164 and aviso.size.y <= 72)
	var tela := aviso.get_viewport_rect()
	var caixa := aviso.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, aviso.size)
	verificar(contexto + " fica inteiro na tela", tela.grow(-2).encloses(caixa))
	var cabeca := aviso.get_viewport().get_canvas_transform() * (jogador.global_transform * Vector2(0, -26))
	verificar(contexto + " centralizado acima do personagem", absf(caixa.get_center().x - cabeca.x) <= 2)
	for rotulo in aviso.find_children("*", "Label", true, false):
		verificar(contexto + " não mostra nível", not rotulo.text.contains("NV ") and not rotulo.text.contains("NIVEL") and not rotulo.text.contains("LEVEL"))
		verificar(contexto + " margem de " + rotulo.text, aviso.get_global_rect().grow(-5).encloses(rotulo.get_global_rect()))
		verificar(contexto + " texto sem corte", rotulo.get_line_count() * rotulo.get_line_height() <= rotulo.size.y + 1)

func captura(jogador: CharacterBody2D, peixe: String, qualidade: int, subiu: bool) -> Node:
	var fazenda: Node = root.get_node("Fazenda")
	fazenda.pesca_xp["p2" if jogador.get("eh_p2") == true else "p1"] = Habilidade.xp_para_nivel(50) - 10 if subiu else Habilidade.xp_para_nivel(99)
	var sessao: Node = Sessao.new()
	sessao.iniciar(jogador, Vector2.RIGHT, "rio")
	sessao.peixe = peixe
	sessao.qualidade_peixe = qualidade
	sessao._pegar(subiu)
	return sessao

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/pesca/aviso_captura"))
	Sessao = load("res://codigo/pesca/sessao_pesca.gd")
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Fazenda")._zerar()
	root.get_node("InventarioJogador").limpar()
	root.get_node("Transicao").hora_salva = 12
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	current_scene.get_node("Iluminacao").definir_hora(12)
	current_scene.get_node("Iluminacao").set_process(false)
	var jogador: CharacterBody2D = current_scene.get_node("Jogador")
	jogador.global_position = current_scene.get_node("PescaPierLeste").global_position
	for tamanho in [Vector2i(576, 324), Vector2i(288, 512), Vector2i(288, 216)]:
		root.get_node("Controle").usando_toque = tamanho.x == 288
		root.mode = Window.MODE_WINDOWED
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros(15)
		for especie in ["sardinha", "imperador_abissal", "pedra_vara"]:
			var sessao: Node = captura(jogador, especie, 2 if especie == "sardinha" else 3, especie == "sardinha")
			await create_timer(0.3).timeout
			var aviso: Control = sessao._aviso_captura
			conferir(aviso, jogador, str(tamanho) + " " + especie)
			var medida := aviso.size
			var camera := jogador.get_viewport().get_camera_2d()
			var zoom_anterior := camera.zoom
			camera.zoom *= 1.3
			await quadros()
			verificar("zoom não amplia o resultado", aviso.size.is_equal_approx(medida) and aviso.scale == Vector2.ONE)
			camera.zoom = zoom_anterior
			await quadros()
			await foto("%s_%dx%d" % [especie, tamanho.x, tamanho.y])
			sessao._terminar()
			await quadros()
			verificar("aviso some ao encerrar a sessão", not is_instance_valid(aviso))
	root.get_node("Controle").usando_toque = false
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	await quadros()
	root.get_node("Saves").trocar("coop")
	var coop: Node = root.get_node("Cooperativo")
	coop.entrar(40)
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	var sessoes: Array = []
	for quem in [coop._jogador1(), coop.jogador2()]:
		quem.global_position = current_scene.get_node("PescaPierLeste").global_position
		var sessao: Node = captura(quem, "imperador_abissal", 3, false)
		sessoes.append(sessao)
	await create_timer(0.3).timeout
	for sessao in sessoes:
		conferir(sessao._aviso_captura, sessao.jogador, "cooperativo")
		verificar("aviso pertence à interface do dono", sessao._aviso_captura.get_parent() == root.get_node("EventosJogo").interface_de(sessao.jogador))
	await foto("cooperativo")
	sessoes[0]._terminar()
	await quadros()
	verificar("encerrar P1 preserva aviso de P2", is_instance_valid(sessoes[1]._aviso_captura))
	sessoes[1]._terminar()
	await quadros()
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
