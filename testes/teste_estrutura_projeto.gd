extends SceneTree

var falhas := 0
var recursos_carregados := 0

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Execute na cópia com saves isolados.")
		quit(1)
		return
	for pasta in ["codigo", "cenas", "recursos", "assets/personagens/conjuntos"]:
		_carregar_recursos("res://" + pasta)
	for caminho in ["res://cenas/inicio_do_jogo.tscn", "res://cenas/cenario.tscn", "res://cenas/fazenda.tscn", "res://cenas/casa.tscn"]:
		var recurso = load(caminho)
		if recurso == null:
			falhas += 1
			continue
		var cena: Node = recurso.instantiate()
		root.add_child(cena)
		current_scene = cena
		await process_frame
		await physics_frame
		print("Cena inicializada: ", caminho)
		cena.queue_free()
		await process_frame
	print("Recursos carregados: ", recursos_carregados, "; falhas: ", falhas)
	quit(falhas)

func _carregar_recursos(pasta: String) -> void:
	var diretorio := DirAccess.open(pasta)
	if diretorio == null:
		falhas += 1
		return
	for subpasta in diretorio.get_directories():
		_carregar_recursos(pasta + "/" + subpasta)
	for nome in diretorio.get_files():
		if nome.get_extension() not in ["gd", "tscn", "tres", "gdshader"]:
			continue
		var caminho := pasta + "/" + nome
		if load(caminho) == null:
			push_error("Recurso inválido: " + caminho)
			falhas += 1
		else:
			recursos_carregados += 1
