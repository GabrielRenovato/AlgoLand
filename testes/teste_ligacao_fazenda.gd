extends SceneTree

## Percorre as zonas reais e verifica o corredor, sem tocar nos saves da partida.
var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros() -> void:
	for i in range(5):
		await physics_frame
		await process_frame

func trocar(passagem: Node, destino: String) -> void:
	passagem.abrir_tela()
	var transicao: Node = root.get_node("Transicao")
	var limite := Time.get_ticks_msec() + 8000
	while transicao.ocupada and Time.get_ticks_msec() < limite:
		await process_frame
	verificar("transicao conclui: " + destino, not transicao.ocupada and current_scene.scene_file_path == destino)
	await quadros()

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute em copia de testes com saves isolados.")
		quit(1)
		return
	await process_frame
	root.get_node("Transicao").limpar()
	var vila: Node = load("res://cenas/cidade.tscn").instantiate()
	root.add_child(vila)
	current_scene = vila
	await quadros()
	vila.get_node("Iluminacao").set_process(false)
	var jogador: CharacterBody2D = vila.get_node("Jogador")
	jogador.collision_mask = 64
	jogador.position = vila.get_node("Chegada_fazenda").position
	verificar("trilha oeste sem bloqueio invisivel", not jogador.test_move(jogador.global_transform, Vector2(-32, 0)))
	jogador.move_and_collide(Vector2(-32, 0))
	await quadros()
	verificar("chega andando à zona da fazenda", vila.get_node("TrilhaFazenda").jogador_perto)
	jogador.hp_atual = 70
	vila.get_node("Iluminacao").definir_hora(12)
	await trocar(vila.get_node("TrilhaFazenda"), "res://cenas/fazenda.tscn")
	var fazenda: Node = current_scene
	fazenda.get_node("Iluminacao").set_process(false)
	jogador = fazenda.get_node("Jogador")
	jogador.collision_mask = 64
	verificar("chega pelo leste da fazenda", jogador.position.distance_to(fazenda.get_node("Terrains/Chegada_cidade").position) < 2)
	verificar("chegada fora do gatilho de retorno", not fazenda.get_node("Terrains/PassagemCidade").jogador_perto)
	verificar("vida e horario preservados", jogador.hp_atual == 70 and absf(fazenda.get_node("Iluminacao").hora - 12) < 0.1)
	verificar("corredor horizontal livre até a casa", not jogador.test_move(jogador.global_transform, Vector2(632, 327) - jogador.position))
	verificar("corredor vertical livre até a porta", not jogador.test_move(Transform2D(0, Vector2(632, 327)), Vector2(0, -44)))
	verificar("passagem livre até a cidade", not jogador.test_move(jogador.global_transform, Vector2(32, 0)))
	jogador.move_and_collide(Vector2(32, 0))
	await quadros()
	verificar("chega andando à zona da cidade", fazenda.get_node("Terrains/PassagemCidade").jogador_perto)
	verificar("fazenda nao liga mais na arena (so o portal da cidade leva a ela)", fazenda.get_node_or_null("Terrains/PassagemCaverna") == null)
	await trocar(fazenda.get_node("Terrains/PassagemCidade"), "res://cenas/cidade.tscn")
	vila = current_scene
	jogador = vila.get_node("Jogador")
	verificar("retorna pelo oeste da cidade", jogador.position.distance_to(vila.get_node("Chegada_fazenda").position) < 2)
	verificar("retorno fora do gatilho da fazenda", not vila.get_node("TrilhaFazenda").jogador_perto)
	jogador.collision_mask = 64
	verificar("caminho livre do retorno para a vila", not jogador.test_move(jogador.global_transform, Vector2(64, 0)))
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("FALHAS: ", falhas)
	quit(falhas)
