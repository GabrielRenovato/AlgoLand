extends SceneTree

## Agendas e deslocamentos reais; execute somente na cópia com saves isolados.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
var Clima: GDScript
var falhas := 0

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

func carregar(caminho: String) -> Node:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await quadros()
	root.get_node("Transicao").hora_salva = 12.0
	var cena: Node = load(caminho).instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros()
	cena.get_node("Iluminacao").set_process(false)
	return cena

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		quit(1)
		return
	await process_frame
	Clima = load("res://codigo/cenario/clima.gd")
	root.get_node("Calendario").dia = 1
	var fazenda: Node = root.get_node("Fazenda")
	fazenda.definir_clima_hoje(Clima.Estado.LIMPO)
	for id in Dados.MORADORES:
		for estacao in range(4):
			for hora in [1.0, 7.0, 12.0, 19.0, 23.0]:
				var abrigo: Dictionary = Dados.agenda(id, hora, estacao, Clima.Estado.TEMPESTADE)
				verificar("temporal mantém %s em casa (%d / %s)" % [id, estacao, hora], abrigo["local"] == Dados.MORADORES[id]["casa"])
		for chuva in [Clima.Estado.CHUVA_LEVE, Clima.Estado.CHUVA_FORTE]:
			verificar("chuva preserva agenda de " + id, Dados.agenda(id, 12, 0, chuva) == Dados.agenda(id, 12, 0))
	var vila := await carregar("res://cenas/cidade.tscn")
	verificar("cidade carrega os seis moradores", vila.moradores.size() == 6)
	vila.get_node("Jogador").position = Vector2(-500, -500)
	var clima: Node = vila.get_node("Terrains/Estacoes/Meteorologia")
	for estado in [Clima.Estado.CHUVA_LEVE, Clima.Estado.CHUVA_FORTE, Clima.Estado.LIMPO, Clima.Estado.NEVE_LEVE]:
		clima.definir_clima(estado, true)
		await quadros()
		for id in vila.moradores:
			var npc: Node = vila.moradores[id]
			verificar("capa de chuva %s clima %s" % [id, estado], npc.usando_capa_chuva == Clima.eh_chuva(estado))
			verificar("folha acompanha o clima: " + id, npc.sprite.texture.resource_path.contains("/capas_chuva/") == npc.usando_capa_chuva)
			verificar("capa mantém escala e célula do morador: " + id,
				npc.sprite.texture.get_width() / npc.sprite.hframes == 64 and npc.sprite.texture.get_height() / npc.sprite.vframes == 64
				and npc.sprite.scale == Vector2.ONE)
	# O temporal começa com moradores na rua: eles precisam alcançar a porta, sem sumir no lugar.
	clima.definir_clima(Clima.Estado.TEMPESTADE, true)
	var saindo: Array[Node] = []
	for npc in vila.moradores.values():
		npc.set_physics_process(false)
		if npc.visible:
			saindo.append(npc)
			verificar("inicia volta para casa: " + npc.id, npc._saindo and not npc.caminho.is_empty() and npc.usando_capa_chuva)
	for passo in range(700):
		var todos_dentro := true
		for npc in saindo:
			if npc.visible:
				todos_dentro = false
				npc._physics_process(0.25)
		if todos_dentro:
			break
		await physics_frame
	for npc in saindo:
		verificar("entra pela porta da própria casa: " + npc.id, not npc.visible and npc.position.distance_to(vila.porta_do_local(Dados.MORADORES[npc.id]["casa"])) < 20)
	clima.definir_clima(Clima.Estado.CHUVA_LEVE, true)
	await quadros()
	for npc in vila.moradores.values():
		verificar("retoma agenda após temporal: " + npc.id, npc.agenda == Dados.agenda(npc.id, 12, 0, Clima.Estado.CHUVA_LEVE))
	# O clima compartilhado mantém os moradores no abrigo ao entrar nas casas.
	fazenda.definir_clima_hoje(Clima.Estado.TEMPESTADE)
	for local in Dados.PREDIOS:
		var interior := await carregar("res://cenas/cidade/%s.tscn" % local)
		verificar("interior carrega os seis moradores: " + local, interior.moradores.size() == 6)
		for id in interior.moradores:
			var npc: Node = interior.moradores[id]
			verificar("abrigo correto %s / %s" % [local, id], npc.visible == (Dados.MORADORES[id]["casa"] == local) and not npc.usando_capa_chuva)
	fazenda.definir_clima_hoje(Clima.Estado.CHUVA_LEVE)
	await quadros()
	for npc in current_scene.moradores.values():
		verificar("interior retoma rotina após chuva: " + npc.id, npc.agenda == Dados.agenda(npc.id, 12, 0, Clima.Estado.CHUVA_LEVE))
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("FALHAS: ", falhas)
	quit(falhas)
