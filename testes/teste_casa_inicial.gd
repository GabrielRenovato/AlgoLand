extends SceneTree

## Casa inicial nas cenas reais. Usar ferramentas/projeto/preparar_testes.py antes de executar.
var falhas := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func _quadros() -> void:
	for i in 4:
		await physics_frame
		await process_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute na cópia com saves isolados.")
		quit(1)
		return
	var casa: Node2D = load("res://cenas/casa.tscn").instantiate()
	root.add_child(casa)
	current_scene = casa
	await _quadros()
	var jogador: CharacterBody2D = casa.get_node("Jogador")
	jogador.set_physics_process(false)
	var inicio: Vector2 = casa.get_node("Chegada_entrada").position
	var fila: Array[Vector2] = [inicio]
	var visitados := {Vector2i(inicio): true}
	# Percorre a planta com o corpo real: verifica rotas entre a entrada e os móveis essenciais.
	while not fila.is_empty():
		var p: Vector2 = fila.pop_back()
		for d in [Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
			var q: Vector2 = p + d
			if visitados.has(Vector2i(q)) or not Rect2(0, 0, 256, 208).has_point(q):
				continue
			jogador.position = p
			if not jogador.test_move(jogador.global_transform, d):
				visitados[Vector2i(q)] = true
				fila.append(q)
	var alvos := {
		"acordar ao lado da cama": casa.get_node("Chegada_cama").position,
		"dormir": casa.get_node("Objetos3D/CamaDormindo").position + Vector2(-28, -16),
		"baú": casa.get_node("Objetos3D/Bau").position + Vector2(0, 8),
	}
	for lado in ["E", "D"]:
		var cadeira: Node2D = casa.get_node("ZonaCadeira" + lado)
		alvos["cadeira " + lado] = cadeira.position + Vector2(0, 8)
		alvos["levantar " + lado] = cadeira.position + cadeira.saida
	for nome in alvos:
		var perto := false
		for p in visitados:
			if Vector2(p).distance_to(alvos[nome]) <= 5:
				perto = true
		_verificar("rota livre para " + nome, perto)
	jogador.position = inicio
	_verificar("saída livre", not jogador.test_move(jogador.global_transform, Vector2(0, 20)))
	var cama: Node2D = casa.get_node("Objetos3D/CamaDormindo")
	cama.deitar()
	_verificar("sono mostra cabeça e cobertor sobre a cama", cama.deitado and not jogador.visible
		and cama.get_node("Cabeca").z_index > load("res://codigo/globais/profundidade.gd").z_de(cama.position.y))
	cama.levantar()
	_verificar("levantar restaura jogador", not cama.deitado and jogador.visible)
	casa.queue_free()
	current_scene = null
	await _quadros()
	var fazenda: Node2D = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(fazenda)
	current_scene = fazenda
	var terreno: Node2D = fazenda.get_node("Terrains")
	await _quadros()
	var fachada: Node2D = terreno.get_node("Objetos3D/Casa")
	_verificar("fachada inicial usa a mesma estrutura da cidade", fachada.id == "casa_jogador"
		and fachada.get_node_or_null("SombraChao") != null and fachada.get_node_or_null("Fumaca") != null)
	_verificar("porta alinhada ao caminho", fachada.position.x == terreno.get_node("PortaCasa").position.x)
	_verificar("janelas ilumináveis", fachada.get_node_or_null("LuzJanela0") != null and fachada.get_node_or_null("LuzJanela1") != null)
	var estacoes: Node = terreno.get_node("Estacoes")
	var sprite: Sprite2D = fachada.get_node("Fachada")
	var nomes := ["primavera", "verao", "outono", "inverno"]
	for indice in range(4):
		estacoes.definir_estacao(indice, true)
		await _quadros()
		_verificar("F3 troca a fachada para " + nomes[indice], sprite.texture.resource_path.ends_with(nomes[indice] + ".png"))
		_verificar("estação mantém tamanho e âncora", sprite.texture.get_height() == 90 and sprite.offset == Vector2(-56, -90))
	# Dormir na última noite do outono deve trocar a casa junto com o terreno.
	estacoes.definir_estacao(2, true)
	var calendario: Node = root.get_node("Calendario")
	calendario.dia = 21
	calendario.dormir()
	await create_timer(1.6).timeout
	_verificar("calendário troca a fachada ao entrar no inverno", sprite.texture.resource_path.ends_with("inverno.png"))
	fazenda.queue_free()
	current_scene = null
	await _quadros()
	print("FALHAS: ", falhas)
	quit(falhas)
