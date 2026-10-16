extends SceneTree

## Confere as colisões dos seis interiores com o corpo real do jogador (cópia de testes, sem tocar nos saves).
## godot --headless --path <copia> --script res://ferramentas/interiores/verificar_colisoes.gd
func _initialize() -> void:
	_rodar()

func _quadros(n := 3) -> void:
	for i in n:
		await physics_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	var layout: Dictionary = load("res://codigo/cidade/interior_casa.gd").dados()
	var falhas := 0
	for casa in layout["casas"]:
		var cena: Node = load("res://cenas/casa.tscn" if casa == "casa_jogador" else "res://cenas/cidade/%s.tscn" % casa).instantiate()
		root.add_child(cena)
		current_scene = cena
		await _quadros()
		# Moradores fora: parados no próprio ponto de trabalho, eles contariam como obstáculo
		for npc in cena.get("moradores").values() if cena.get("moradores") != null else []:
			npc.queue_free()
		await _quadros()
		var jogador: CharacterBody2D = cena.get_node("Jogador")
		jogador.set_physics_process(false)
		var testes := 0
		var erros: Array[String] = []
		var geo: Dictionary = layout["casas"][casa]["geometria"]
		var larg: float = geo["recorte"][2]
		var meio_x: float = (geo["parede_oeste"] + geo["parede_leste"]) / 2.0
		var meio_y: float = (geo["parede_norte"] + geo["chao_sul"]) / 2.0
		# Paredes e fundo: do centro do chão até cada lado (a casa pode ter móvel no meio: o ponto é do vão da porta)
		var vao: Array = geo["porta"]
		var chegada := Vector2(geo["chegada"][0], geo["chegada"][1])
		for par in [["norte", chegada, Vector2(0, -400)], ["oeste", chegada, Vector2(-400, 0)], ["leste", chegada, Vector2(400, 0)], ["sul_esq", Vector2(vao[0] - 20, chegada.y), Vector2(0, 120)], ["sul_dir", Vector2(vao[1] + 20, chegada.y), Vector2(0, 120)]]:
			testes += 1
			jogador.global_position = par[1]
			if not jogador.test_move(jogador.global_transform, par[2]):
				erros.append("parede " + par[0] + " atravessada")
		# A porta tem de estar livre da chegada até o gatilho de saída
		jogador.global_position = chegada
		var choque := KinematicCollision2D.new()
		if jogador.test_move(jogador.global_transform, Vector2(0, 6), choque):
			erros.append("porta bloqueada por " + str(choque.get_collider_shape()) + " em " + str(choque.get_position()))
		# Cada móvel bloqueia quem vem de baixo
		for item in layout["casas"][casa]["itens"]:
			if item["chao"]:
				continue
			testes += 1
			jogador.global_position = Vector2(item["x"], item["y"] + 22)
			if not jogador.test_move(jogador.global_transform, Vector2(0, -30)):
				erros.append("movel sem colisao: " + item["p"] + " em " + str(Vector2(item["x"], item["y"])))
		# Pontos de trabalho dos moradores ficam livres (sem sobrepor móvel)
		for chave in layout["casas"][casa]["pontos"]:
			testes += 1
			jogador.global_position = Vector2(layout["casas"][casa]["pontos"][chave][0], layout["casas"][casa]["pontos"][chave][1])
			if jogador.test_move(jogador.global_transform, Vector2.ZERO, choque):
				erros.append("ponto dentro de movel/parede: " + chave + " (" + str(choque.get_collider_shape().get_parent().name if choque.get_collider_shape() is Object else "?") + ")")
		for e in erros:
			print("  FALHA ", casa, ": ", e)
		falhas += erros.size()
		print(casa, ": ", testes, " conferencias, ", erros.size(), " falhas")
		cena.queue_free()
		current_scene = null
		await _quadros()
	print("TOTAL de falhas: ", falhas)
	quit()
