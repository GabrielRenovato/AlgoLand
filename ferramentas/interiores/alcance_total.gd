extends SceneTree

## godot --headless --path <copia> --script res://ferramentas/interiores/alcance_total.gd (cópia de testes, saves isolados)
## Anda com o corpo real do jogador (passos de 4 px, test_move) a partir da chegada e confere:
## cômodos alcançados, pontos alcançados e se algum passo saiu do chão (atravessou parede).
const PASSO := 4

func _initialize() -> void:
	_rodar()

func _quadros(n := 3) -> void:
	for i in n:
		await physics_frame

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		quit(1)
		return
	var Sala := load("res://codigo/cidade/sala_topdown.gd")
	var layout: Dictionary = load("res://codigo/cidade/interior_casa.gd").dados()
	var total := 0
	for casa in layout["casas"]:
		var cena: Node = load("res://cenas/casa.tscn" if casa == "casa_jogador" else "res://cenas/cidade/%s.tscn" % casa).instantiate()
		root.add_child(cena)
		current_scene = cena
		await _quadros()
		# Moradores fora, para não contarem como obstáculo
		for npc in cena.get("moradores").values() if cena.get("moradores") != null else []:
			npc.queue_free()
		await _quadros()
		var jogador: CharacterBody2D = cena.get_node("Jogador")
		jogador.set_physics_process(false)
		var pes := Vector2.ZERO
		for filho in jogador.get_children():
			if filho is CollisionShape2D:
				pes = filho.position
		var dados: Dictionary = layout["casas"][casa]
		var geo: Dictionary = dados["geometria"]
		var mapa: Dictionary = Sala.mapa(geo)
		var inicio := Vector2(geo["chegada"][0], geo["chegada"][1])
		var visto := {Vector2i(inicio / PASSO): true}
		var fila: Array[Vector2] = [inicio]
		var vazamentos := 0
		while not fila.is_empty():
			var p: Vector2 = fila.pop_back()
			for d in [Vector2(PASSO, 0), Vector2(-PASSO, 0), Vector2(0, PASSO), Vector2(0, -PASSO)]:
				var q: Vector2 = p + d
				var chave := Vector2i(q / PASSO)
				if visto.has(chave) or q.y > geo["recorte"][3]:
					continue
				jogador.global_position = p
				if jogador.test_move(jogador.global_transform, d):
					continue
				visto[chave] = true
				# Os pés não podem pisar fora do chão
				var pe := q + pes
				if not Sala.e_chao(mapa, floori(pe.x / 8), floori(pe.y / 8)):
					vazamentos += 1
					if vazamentos <= 3:
						print("  VAZOU ", casa, " em ", q, " pes ", pe)
				fila.append(q)
		var erros := []
		for area in geo["areas"]:
			var r: Array = area["retangulo"]
			var achou := false
			for y in range(int(r[1]), int(r[1]) + int(r[3]), PASSO):
				for x in range(int(r[0]), int(r[0]) + int(r[2]), PASSO):
					if visto.has(Vector2i(x / PASSO, y / PASSO)):
						achou = true
						break
				if achou:
					break
			if not achou:
				erros.append("comodo inalcancavel: " + area["nome"])
		var pontos := {}
		for k in dados["pontos"]:
			pontos[k] = dados["pontos"][k]
		for i in dados.get("inverno", []).size():
			pontos["inverno%d" % i] = dados["inverno"][i]
		if dados.has("mural"):
			pontos["mural"] = dados["mural"]
		for k in pontos:
			var alvo := Vector2(pontos[k][0], pontos[k][1])
			var perto := false
			for dy in range(-8, 9, PASSO):
				for dx in range(-8, 9, PASSO):
					if visto.has(Vector2i((alvo + Vector2(dx, dy)) / PASSO)):
						perto = true
			if not perto:
				erros.append("ponto inalcancavel: " + k + " " + str(alvo))
		# Rota dos moradores (grade de navegação da cena) da chegada a cada ponto
		var nav: AStarGrid2D = cena.get("navegacao")
		pontos.erase("mural")
		for k in pontos if nav != null else {}:
			var a := Vector2i(inicio / nav.cell_size)
			var b := Vector2i(Vector2(pontos[k][0], pontos[k][1]) / nav.cell_size)
			if not nav.is_in_boundsv(b) or nav.get_id_path(a, b, true).is_empty() or nav.get_id_path(a, b, true)[-1] != b:
				erros.append("morador sem rota ate " + k)
		if vazamentos > 0:
			erros.append("%d passos fora do chao" % vazamentos)
		for e in erros:
			print("  FALHA ", casa, ": ", e)
		print(casa, ": ", visto.size(), " posicoes alcancadas, ", erros.size(), " falhas")
		total += erros.size()
		cena.queue_free()
		current_scene = null
		await _quadros()
	print("TOTAL: ", total)
	quit()
