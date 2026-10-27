extends SceneTree
## Mede quanto o pé desliza no chão por ciclo de uma corrida (rig chibi), para calibrar PASSADA.
## Uso: -- --biblioteca=res://...mixamo.res --animacao=Running
func _initialize(): rodar.call_deferred()
func rodar():
	var biblioteca_caminho := "res://assets/personagens/base_3d/mixamo.res"
	var nome := "Running"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--biblioteca="): biblioteca_caminho = a.get_slice("=", 1)
		if a.begins_with("--animacao="): nome = a.get_slice("=", 1)
	var cena: Node3D = load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
	root.add_child(cena)
	var esq: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	esq.add_child(preload("res://codigo/jogador/proporcao_chibi.gd").new())
	var player := AnimationPlayer.new()
	cena.add_child(player)
	player.root_node = player.get_path_to(cena)
	player.add_animation_library("m", load(biblioteca_caminho))
	var anim: Animation = player.get_animation("m/" + nome)
	player.play("m/" + nome)
	player.speed_scale = 0.0
	var amostras := []
	for pe in ["DEF-foot.L", "DEF-foot.R"]:
		var osso := esq.find_bone(pe)
		var pontos := []
		for q in 60:
			player.seek(anim.length * q / 60.0, true)
			await process_frame
			pontos.append(esq.global_transform * esq.get_bone_global_pose(osso).origin)
		var y_min: float = pontos.map(func(p): return p.y).min()
		var apoio := pontos.filter(func(p): return p.y <= y_min + 0.04)
		var zs: Array = apoio.map(func(p): return p.z)
		amostras.append(float(zs.max()) - float(zs.min()))
	var desliza: float = (amostras[0] + amostras[1]) / 2.0
	print("PASSADA %s: duracao=%.3f desliza_no_apoio=%.3f m por pé" % [nome, anim.length, desliza])
	quit()
