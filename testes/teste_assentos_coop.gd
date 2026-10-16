extends SceneTree

## Interação real dos dois controles, sem chamar _sentar diretamente; saves isolados obrigatórios.
var falhas := 0
var coop: Node

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await physics_frame
		await process_frame

func apertar(dispositivo: int) -> void:
	for pressionado in [true, false]:
		var evento := InputEventJoypadButton.new()
		evento.device = dispositivo
		evento.button_index = JOY_BUTTON_A  # interagir (open_menu) no controle
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await quadros(2)

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Calendario").dia = 6
	root.get_node("Transicao").hora_salva = 20.0
	change_scene_to_file("res://cenas/cidade/pousada.tscn")
	await quadros(20)
	coop = root.get_node("Cooperativo")
	coop.dispositivo_p1 = 41
	coop.dispositivo_p2 = 40
	coop._reconfigurar_entrada()
	var vila: Node = current_scene
	vila.get_node("Iluminacao").set_process(false)
	vila.get_node("RotinaTaverna").set_process(false)
	vila._proximo_papo = INF
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	var bancos: Array = get_nodes_in_group("assentos").filter(func(banco): return banco.get_world_2d() == p1.get_world_2d() and banco.global_position.y > 300 and banco.frente == -1)
	verificar("ha dois bancos livres para validar os controles", bancos.size() >= 2)
	if bancos.size() < 2:
		quit(1)
		return
	for ordem in [[p1, p2], [p2, p1]]:
		p1.position = bancos[0].global_position + Vector2(0, -4)
		p2.position = bancos[1].global_position + Vector2(0, -4)
		await quadros()
		for jogador in ordem:
			await apertar(40 if jogador.eh_p2 else 41)
			verificar("controle senta jogador " + ("2" if jogador.eh_p2 else "1"), jogador.esta_sentado)
		verificar("os dois permanecem sentados simultaneamente", p1.esta_sentado and p2.esta_sentado)
		for jogador in [p1, p2]:
			verificar("pose de costas oculta a caminhada e usa quadro 43", jogador._frente_sentado == -1 and jogador.sprite_corpo_forja.frame == 43 and jogador.no_forja.visible and not jogador.get_node("CompositeSprites/BaseSprites").visible)
		if "--exportar-pose" in OS.get_cmdline_user_args():
			_exportar_pose(p1, bancos[0])
		# Um jogador sentado ao lado do trajeto não pode segurar Caio.
		var caio: Node2D = vila.moradores["bardo"]
		caio.visible = true
		caio.dormindo = false
		caio._saindo = false
		caio.atendendo_mesas = true
		caio.position = p1.position + Vector2(24, 0)
		caio.caminho = PackedVector2Array([caio.position + Vector2(0, -28)])
		caio._alvo = caio.caminho[0]
		var partida: Vector2 = caio.position
		await quadros(45)
		verificar("taverneiro continua andando com jogadores sentados por perto", caio.position.distance_to(partida) > 12)
		p1.pediu_levantar.emit()
		await quadros()
		verificar("levantar P1 nao levanta P2", not p1.esta_sentado and p2.esta_sentado)
		p2.pediu_levantar.emit()
		await quadros()
		verificar("ambos liberam os bancos ao levantar", not p2.esta_sentado and not bancos[0].ocupada and not bancos[1].ocupada)
	await _testar_disputa(vila, p1, p2, bancos)
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)

## Pedido de 2026-10-16: com um jogador sentado, o outro via F em todo mundo e não conseguia sentar; e o banco vazio
## deve vencer o morador ao lado na disputa do F.
func _testar_disputa(vila: Node, p1: Node2D, p2: Node2D, bancos: Array) -> void:
	var Interagivel = load("res://codigo/logica/interagivel.gd")
	var rosa: Node2D = vila.moradores["curandeira"]
	rosa.visible = true
	rosa.dormindo = false
	# P1 sentado no banco 0; Rosa em pé ao lado do banco 1, mais perto do P2 que o banco
	p1.position = bancos[0].global_position + Vector2(0, -4)
	await quadros()
	await apertar(41)
	verificar("disputa: P1 senta", p1.esta_sentado)
	# Rosa parada (sem agenda) colada ao P2, mais perto dele que o centro do banco
	rosa.set_physics_process(false)
	rosa.set_process(false)
	p2.position = bancos[1].global_position + Vector2(0, -4)
	rosa.position = p2.position + Vector2(3, -2)
	await quadros(6)
	verificar("disputa: P2 perto do banco e da Rosa", bancos[1].p2_perto and rosa.interacao.p2_perto)
	verificar("disputa: banco vazio vence a Rosa para o P2", bancos[1].disponivel_para_p2() and not rosa.interacao.disponivel_para_p2())
	var avisos_p2 := get_nodes_in_group("interagiveis").filter(func(z): return z.has_method("disponivel_para_p2") and z.get_world_2d() == p2.get_world_2d() and z.disponivel_para_p2())
	verificar("disputa: so uma zona oferece F ao P2 (%d)" % avisos_p2.size(), avisos_p2.size() == 1)
	verificar("disputa: P1 sentado nao recebe F em nada", get_nodes_in_group("interagiveis").all(func(z): return not z.has_method("disponivel_para_interacao") or z.get_world_2d() != p1.get_world_2d() or not z.disponivel_para_interacao() or not z._aviso.visible or z.disponivel_para_p2()))
	await apertar(40)
	verificar("disputa: P2 senta com P1 ja sentado", p2.esta_sentado and p1.esta_sentado)
	verificar("disputa: P2 nao abriu conversa junto", root.get_node("Cidade").interlocutor == "")
	p2.pediu_levantar.emit()
	p1.pediu_levantar.emit()
	await quadros()
	# Banco ocupado: aí o morador volta a ser a opção
	bancos[1].ocupada = true
	p2.position = bancos[1].global_position + Vector2(0, -4)
	await quadros(4)
	verificar("disputa: banco ocupado devolve o F para a Rosa", rosa.interacao.disponivel_para_p2())
	bancos[1].ocupada = false
	p2.position = bancos[0].global_position + Vector2(0, -4)
	p1.position = bancos[1].global_position + Vector2(0, -4)
	rosa.position = p1.position + Vector2(3, -2)
	await quadros(6)
	verificar("disputa: P1 tambem prioriza o banco", bancos[1].disponivel_para_interacao() and not rosa.interacao.disponivel_para_interacao())

func _exportar_pose(jogador: Node2D, banco: Node2D) -> void:
	var camadas: Array = []
	for nome in ["Corpo", "Cabelo", "Roupa"]:
		var sprite: Sprite2D = jogador.no_forja.get_node(nome)
		var tamanho := Vector2i(sprite.texture.get_size()) / Vector2i(sprite.hframes, sprite.vframes)
		var recorte := Rect2i(Vector2i(sprite.frame % sprite.hframes, sprite.frame / sprite.hframes) * tamanho, tamanho)
		sprite.texture.get_image().get_region(recorte).save_png("/tmp/algoland-assento-" + nome + ".png")
		camadas.append({"nome": nome, "pos": [sprite.position.x, sprite.position.y], "escala": [sprite.scale.x, sprite.scale.y]})
	var arquivo := FileAccess.open("/tmp/algoland-assento-pivo.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"posicao": [jogador.position.x - banco.global_position.x, jogador.position.y - banco.global_position.y], "camadas": camadas}))
