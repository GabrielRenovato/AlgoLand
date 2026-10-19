extends SceneTree

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 10) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func continuar(coop := false) -> void:
	change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
	await quadros(20)
	var inicio := current_scene
	if coop: inicio._ao_continuar_coop()
	else: inicio._ao_continuar()
	for tentativa in 180:
		await quadros(1)
		if current_scene != null and current_scene != inicio: break
	await quadros(35)
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	var saves := root.get_node("Saves")
	var progresso := root.get_node("Progresso")
	var coop := root.get_node("Cooperativo")
	saves.trocar("solo")
	root.get_node("Introducao").pular_prologo()
	var personagem := FileAccess.open(saves.caminho_personagem(), FileAccess.WRITE)
	personagem.store_string("{}")
	personagem.close()
	for destino in ["res://cenas/fazenda.tscn", "res://cenas/casa.tscn", "res://cenas/praia.tscn", "res://cenas/palafita.tscn", "res://cenas/cidade.tscn", "res://cenas/andar_fenda.tscn"]:
		change_scene_to_file(destino)
		await quadros(20)
		var jogador: Node2D = coop._jogador1()
		var posicao := jogador.global_position + Vector2(12, 8)
		jogador.global_position = posicao
		saves.salvar_tudo()
		progresso.local_jogadores.clear()
		progresso.carregar()
		var esperado: String = saves.CIDADE if destino.ends_with("andar_fenda.tscn") else destino
		verificar("local gravado no arquivo " + destino, progresso.local_jogadores.get("1", {}).get("cena") == esperado)
		await continuar()
		verificar("continuar retorna ao mapa correto " + destino, current_scene.scene_file_path == esperado)
		if destino == esperado:
			verificar("continuar restaura posicao " + destino, coop._jogador1().global_position.distance_to(posicao) < 0.1)
	# Os dois podem encerrar em ambientes diferentes no mesmo mundo cooperativo.
	saves.trocar("coop")
	root.get_node("Introducao").pular_prologo()
	for segundo in [false, true]:
		personagem = FileAccess.open(saves.caminho_personagem(segundo), FileAccess.WRITE)
		personagem.store_string("{}")
		personagem.close()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(25)
	await coop.viajar_local(coop.jogador2(), "res://cenas/casa.tscn", "")
	var pos1: Vector2 = coop._jogador1().global_position
	var pos2: Vector2 = coop.jogador2().global_position
	saves.salvar_tudo()
	await continuar(true)
	verificar("coop restaura fazenda do jogador 1", coop.cena_de(coop._jogador1()).scene_file_path == "res://cenas/fazenda.tscn" and coop._jogador1().global_position.distance_to(pos1) < 0.1)
	verificar("coop restaura casa do jogador 2", coop.cena_de(coop.jogador2()).scene_file_path == "res://cenas/casa.tscn" and coop.jogador2().global_position.distance_to(pos2) < 0.1)
	progresso.apagar()
	verificar("novo mundo descarta local anterior", progresso.local_jogadores.is_empty())
	current_scene.queue_free()
	await quadros()
	print("Local continuar: %d falhas" % falhas)
	quit(1 if falhas else 0)
