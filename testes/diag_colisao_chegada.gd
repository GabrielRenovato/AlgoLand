extends SceneTree
## Diagnóstico visual: formas de colisão visíveis, andar do jogador por cima das estruturas e luta contra o chefe.
var cena: Node2D
var pasta := "res://capturas-diag"
func _initialize() -> void:
	debug_collisions_hint = true
	rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta.path_join(nome + ".png"))
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1); return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capturas="): pasta = a.trim_prefix("--capturas=")
	DirAccess.make_dir_recursive_absolute(pasta)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(50)
	cena = current_scene
	for n in cena.get_children():
		if n.has_method("_encerrar"): n._encerrar()
	await quadros(4)
	var j: CharacterBody2D = cena.jogador
	j.desabilitar_todas_acoes(false)
	# 1) Estruturas: câmera em cada marco, com as caixas de colisão desenhadas.
	var marcos := {"arco": Vector2(607, -276), "painel": null, "bau": null, "alcova": null, "tronco": null}
	var pecas = cena.terreno._pecas
	for id in ["arco_estrada", "painel_ruinas", "bau_resgate", "muro_alcova_1", "tronco_atalho", "ponte_tronco", "marco_saida"]:
		if not pecas.has(id): continue
		j.position = pecas[id].ponto + Vector2(0, 40)
		j.velocity = Vector2.ZERO
		await quadros(6)
		await foto("estrutura-" + id)
	# 2) Andar contra cada estrutura: o jogador tem de parar nela.
	for id in ["arco_estrada", "painel_ruinas", "bau_resgate", "muro_alcova_1", "tronco_atalho", "pilar_alcova", "marco_saida"]:
		if not pecas.has(id): continue
		for c in pecas[id].colisoes:
			var r: Rect2 = c.ret
			j.position = Vector2(r.get_center().x, r.end.y + 30)
			j.velocity = Vector2.ZERO
			await quadros(3)
			Input.action_press("move_up")
			await quadros(50)
			Input.action_release("move_up")
			var dentro: bool = r.has_point(j.position) or r.grow(-1).intersects(Rect2(j.position - Vector2(3, 3), Vector2(6, 6)))
			print("ANDAR ", id, " rect ", r, " parou em ", j.position, " DENTRO_DO_RET " if dentro else " ok")
	# 3) Chefe: nasce como na vigília e persegue o jogador.
	var origem := Vector2(cena.terreno.dados.alvos.raizes_despertas.p[0], cena.terreno.dados.alvos.raizes_despertas.p[1])
	var chefe: CharacterBody2D = load("res://cenas/inimigos/cerne_partido.tscn").instantiate()
	chefe.position = cena._livre(origem)
	cena.add_child(chefe)
	j.position = chefe.position + Vector2(90, 40)
	await quadros(10)
	await foto("chefe-inicio")
	var parado := 0.0
	var antes: Vector2 = chefe.position
	var atravessou := 0
	for t in 40:
		# o jogador anda em círculo em volta do chefe
		var ang := t * 0.45
		j.position = chefe.position + Vector2(cos(ang), sin(ang)) * 70
		await quadros(15)
		if chefe.position.distance_to(antes) < 1.0: parado += 0.25
		antes = chefe.position
		if j.position.distance_to(chefe.position) < 14: atravessou += 1
		if t % 10 == 0: await foto("chefe-%02d" % t)
	print("CHEFE pos ", chefe.position, " origem ", origem, " segundos parado ", parado, " jogador_dentro_do_corpo ", atravessou)
	# 4) Jogador empurrado para dentro do chefe: o corpo dele bloqueia?
	j.position = chefe.position + Vector2(40, 0)
	Input.action_press("move_left")
	await quadros(40)
	Input.action_release("move_left")
	print("ATRAVESSA_CHEFE dist_final ", j.position.distance_to(chefe.position))
	await foto("chefe-atravessar")
	quit()
