extends SceneTree
## godot --headless --path <copia de testes> --script res://ferramentas/fazenda/alcance_fazenda.gd
## Anda com o corpo do jogador (passos de 8 px) a partir da porta e confere os lugares-chave e a borda do mapa.
func _initialize() -> void:
	_rodar()
func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		quit(1)
		return
	await process_frame
	var cena: Node = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	for i in 10:
		await physics_frame
	var j: CharacterBody2D = cena.get_node("Jogador")
	j.set_physics_process(false)
	var t: Node2D = cena.get_node("Terrains")
	var inicio: Vector2 = t.get_node("Chegada_porta").global_position
	var visto := {Vector2i(inicio / 8): true}
	var fila: Array[Vector2] = [inicio]
	var fora := 0
	while not fila.is_empty():
		var p: Vector2 = fila.pop_back()
		for d in [Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8)]:
			var q: Vector2 = p + d
			var k := Vector2i(q / 8)
			if visto.has(k):
				continue
			j.global_position = p
			if j.test_move(j.global_transform, d):
				continue
			visto[k] = true
			if q.x < 40 or q.y < 70 or q.x > 1152 or q.y > 740:
				fora += 1
			fila.append(q)
	var lugares := {"saida_vila": t.get_node("PassagemCidade").global_position,
		"horta_canto_ne": Vector2(600, 340), "horta_canto_so": Vector2(104, 584), "pomar": Vector2(800, 590), "pedreira": Vector2(900, 150)}
	for nome in lugares:
		var perto := false
		for dy in range(-24, 25, 8):
			for dx in range(-24, 25, 8):
				perto = perto or visto.has(Vector2i((lugares[nome] + Vector2(dx, dy)) / 8))
		print(nome, ": ", "alcanca" if perto else "NAO ALCANCA")
	print("posicoes: ", visto.size(), " fora da borda: ", fora)
	quit()
