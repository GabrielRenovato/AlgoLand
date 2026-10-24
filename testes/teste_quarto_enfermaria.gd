extends SceneTree
var Dados: GDScript
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func esperar(n := 15) -> void:
	for i in n: await process_frame
func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA ",mensagem)
func foto(nome: String) -> void:
	await esperar()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-enfermaria-"+nome+".png")
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	await process_frame
	Dados = load("res://codigo/cidade/dados_cidade.gd")
	root.get_node("Introducao").pular_prologo()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(720,400)
	root.size = Vector2i(1440,800)
	root.get_node("Transicao").hora_salva = 23
	change_scene_to_file("res://cenas/cidade/enfermaria.tscn")
	await esperar(50)
	var cena = current_scene
	var rosa = cena.moradores.curandeira
	var jogador = cena.get_node("Jogador")
	var cama_rosa: Dictionary = Dados.cama("curandeira")
	verificar(cama_rosa.base == Vector2(248,96),"Rosa tem cama no quarto privado")
	verificar(rosa.dormindo and rosa.position.x < 272,"Rosa dorme fora da ala dos pacientes")
	var rota: PackedVector2Array = cena.caminho_morador(Vector2(96,190),cama_rosa.base + Vector2(0,12),"curandeira")
	verificar(not rota.is_empty() and rota[-1].distance_to(cama_rosa.base + Vector2(0,12)) < 12,"quarto acessivel pela recepcao: %s" % [rota])
	await foto("quarto-noite")
	# Mesma composição usada no retorno após a morte, em todas as estações.
	cena.get_node("Iluminacao").set_process(false)
	cena.get_node("Iluminacao").hora = 10
	for estacao in 4:
		root.get_node("Calendario").dia = 1 + estacao * 30
		await esperar()
		verificar(cena.get_node("Interior/Sala")._estacao == estacao,"piso acompanha a estacao")
		verificar(cena.get_node("Interior/CamaRosa/DetalheAmbiente").estacao == estacao,"cama privada acompanha a estacao")
		var paciente = cena._deitar_no_leito(jogador)
		verificar(paciente != null,"leito encontrado")
		verificar(jogador.position.distance_to(cena.LEITO_FERIDO) < 30,"jogador permanece junto do leito")
		verificar(not jogador.visible and jogador.esta_sentado,"corpo oculto durante recuperacao")
		var cabeca: Node2D = paciente.get_node("Cabeca")
		verificar(cabeca.get_child_count() == 11,"cabeca preserva aparencia Raven")
		var cobertor: Sprite2D = paciente.get_node("Cobertor")
		verificar(is_equal_approx(cobertor.region_rect.size.y * cobertor.scale.y,29),"cobertor usa altura logica")
		await foto("estacao%d" % estacao)
		paciente.free()
		jogador.show()
		jogador.levantar(cena.LEITO_FERIDO + Vector2(0,26))
	# A Rosa interrompe o sono para cuidar do jogador e retoma a cama depois.
	cena._rosa_ao_lado_do_leito(jogador)
	var posicao: Vector2 = rosa.position
	rosa.atualizar_rotina()
	await esperar(40)
	verificar(rosa.cuidando_de_paciente and not rosa.dormindo and rosa.position == posicao,"Rosa permanece ao lado do paciente")
	print("QUARTO E LEITO: ",falhas," falhas")
	quit(1 if falhas else 0)
