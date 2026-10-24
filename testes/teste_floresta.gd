extends SceneTree

## Floresta entre a vila e a fazenda (cenas/floresta.tscn, gerada por ferramentas/floresta/gerar_floresta.py): estrada livre,
## árvores e pedras das ferramentas, plantio bloqueado, lago e pontos de pesca, passagens para a vila e a fazenda, e a fauna
## (alerta, fuga até uma árvore, sumiço, volta e coelho branco no inverno).
## Exige projeto com `config/custom_user_dir_name` começando por "AlgoLand testes" (grava no save). Rodar com renderização
## gráfica para capturar: `-- --capturar` salva as quatro estações e os cantos em arte/previas/floresta/.
const SAIDA := "res://arte/previas/floresta/"

var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	_rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	verificacoes += 1
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 8) -> void:
	for i in n:
		await process_frame
	await physics_frame
	await physics_frame

func _rodar() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Teste exige save isolado (AlgoLand testes ...)")
		quit(1)
		return
	var cena: Node2D = load("res://cenas/floresta.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros(20)
	var terreno := cena.get_node("Terrains")
	var jogador: CharacterBody2D = cena.get_node("Jogador")
	var fazenda := root.get_node("Fazenda")

	# --- estrutura e estrada livre de ponta a ponta
	var extracao := terreno.get_node("Extracao")
	var carvalhos: Array = extracao.recursos.filter(func(r): return r["tipo"] == "arvore")
	var pedras: Array = extracao.recursos.filter(func(r): return r["tipo"] == "pedra")
	verificar("há árvores para cortar (%d)" % carvalhos.size(), carvalhos.size() >= 20)
	verificar("há pedras para quebrar (%d)" % pedras.size(), pedras.size() >= 30)
	verificar("chaves das árvores e pedras têm prefixo próprio", extracao.recursos.all(func(r): return String(r["chave"]).begins_with("F_")))
	var terra: TileMapLayer = terreno.get_node("Terra")
	var bloqueios := 0
	for celula in terra.get_used_cells():
		var centro := terra.to_global(terra.map_to_local(celula))
		# As bordas do mapa têm parede por desenho (a passagem dispara antes dela): só confere o miolo
		if centro.x > 16.0 and centro.x < 1392.0 and _bloqueado(cena, centro):
			bloqueios += 1
	verificar("nada bloqueia o centro da estrada e das trilhas (%d de %d células)" % [bloqueios, terra.get_used_cells().size()], bloqueios == 0)

	# --- ferramentas: carvalho, pedra e arbusto
	var emitidos := []
	extracao.recurso_extraido.connect(func(chave: String, tipo: String): emitidos.append([chave, tipo]))
	var ponto_arvore: Vector2 = terreno.to_global(carvalhos[0]["pos"]) - Vector2(0, 4)
	verificar("machadinha encontra o carvalho", extracao.motivo("machado", ponto_arvore) == "")
	for i in 4:
		extracao.impacto("machado", ponto_arvore)
	await quadros(4)
	verificar("quatro golpes derrubam o carvalho", emitidos.size() == 1 and emitidos[0][1] == "arvore")
	verificar("a árvore cortada grava no save com a chave da floresta", fazenda.removidos.has(carvalhos[0]["chave"]) and not fazenda.removidos.has("Carvalho01"))
	emitidos.clear()
	var ponto_pedra: Vector2 = terreno.to_global(pedras[0]["pos"]) - Vector2(0, 4)
	verificar("picareta encontra a pedra", extracao.motivo("picareta", ponto_pedra) == "")
	for i in 3:
		extracao.impacto("picareta", ponto_pedra)
	await quadros(4)
	verificar("três golpes quebram a pedra", emitidos.size() == 1 and emitidos[0][1] == "pedra")

	# --- sem horta: não ara, não herda o entulho da fazenda
	var plantio := terreno.get_node("Plantio")
	verificar("enxada recusada na floresta", plantio.avaliar_terreno("enxada", Vector2i(10, 25)) != "")
	verificar("entulho da fazenda não aparece aqui", extracao._entulho.is_empty())

	# --- lago e pesca
	var lago := terreno.get_node("Lago")
	var pontos: Array = cena.find_children("PescaLago*", "Area2D", true, false)
	verificar("lago no grupo do regador", lago.is_in_group("lago_fazenda"))
	verificar("sete pontos de pesca de água doce", pontos.size() == 7 and pontos.all(func(p): return p.ambiente == "rio"))
	verificar("todos olham para a água a até 38 px", pontos.all(func(p): return lago.contem(p.global_position + p.direcao.normalized() * 38.0)))
	jogador.global_position = pontos[0].global_position
	await quadros(6)
	verificar("a zona de pesca reconhece o jogador na margem", pontos[0].overlaps_body(jogador))

	# --- passagens e volta
	verificar("leste leva à vila e oeste leva à fazenda", terreno.get_node("PassagemCidade").cena_destino.ends_with("cidade.tscn") and terreno.get_node("PassagemFazenda").cena_destino.ends_with("fazenda.tscn"))
	var cidade: Node = load("res://cenas/cidade.tscn").instantiate()
	var campo: Node = load("res://cenas/terreno_fazenda.tscn").instantiate()
	verificar("a vila aponta para a floresta e tem a chegada de volta", cidade.get_node("TrilhaFazenda").cena_destino.ends_with("floresta.tscn") and cidade.find_child("Chegada_fazenda", true, false) != null)
	verificar("a fazenda aponta para a floresta e tem a chegada de volta", campo.get_node("PassagemCidade").cena_destino.ends_with("floresta.tscn") and campo.find_child("Chegada_cidade", true, false) != null)
	verificar("a floresta tem as duas chegadas", cena.find_child("Chegada_cidade", true, false) != null and cena.find_child("Chegada_fazenda", true, false) != null)
	cidade.free()
	campo.free()

	# --- fauna
	var fauna := terreno.get_node("Animais")
	verificar("a fauna existe (%d bichos)" % fauna.animais.size(), fauna.animais.size() >= 12)
	jogador.global_position = Vector2(-900, -900)
	await quadros(4)
	var cervo: Node2D = fauna.animais.filter(func(a): return a.especie == "cervo")[0]
	verificar("o cervo vive tranquilo sem ninguém perto", cervo.estado in ["parado", "comer", "andando"])
	jogador.global_position = cervo.global_position + Vector2(-95, 6)
	var estados := []
	for i in 420:
		await physics_frame
		if estados.is_empty() or estados[-1] != cervo.estado:
			estados.append(cervo.estado)
	verificar("o cervo repara, foge, some atrás da árvore: %s" % [estados], "alerta" in estados and "fugindo" in estados and "sumindo" in estados and cervo.estado == "oculto")
	jogador.global_position = Vector2(-900, -900)
	cervo._oculto = 0.05
	await quadros(4)
	verificar("o cervo volta mais tarde, visível e longe do jogador", cervo.visible and cervo.estado == "parado" and cervo.modulate.a > 0.99)
	var corvo: Node2D = fauna.animais.filter(func(a): return a.especie == "corvo")[0]
	jogador.global_position = corvo.global_position + Vector2(60, 0)
	var estados_corvo := []
	for i in 260:
		await physics_frame
		if estados_corvo.is_empty() or estados_corvo[-1] != corvo.estado:
			estados_corvo.append(corvo.estado)
	verificar("o corvo levanta voo e some: %s" % [estados_corvo], "fugindo" in estados_corvo and "oculto" in estados_corvo)
	jogador.global_position = Vector2(-900, -900)
	var coelho: Node2D = fauna.animais.filter(func(a): return a.especie == "coelho")[0]
	var estacoes := terreno.get_node("Estacoes")
	estacoes.definir_estacao(3, true)
	await quadros(3)
	verificar("coelhos ficam brancos no inverno", String(coelho._caminho("parar")).ends_with("coelho_branco.png"))
	estacoes.definir_estacao(0, true)
	await quadros(3)

	# --- quatro estações com os mesmos nós
	for estacao in 4:
		estacoes.definir_estacao(estacao, true)
		await quadros(3)
		verificar("estação %d: árvores e fauna seguem no mapa" % estacao, terreno.get_node("Objetos3D").get_child_count() > 200 and fauna.animais.size() >= 12)
	if "--capturar" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _capturar(cena, jogador, estacoes)
	print("%d verificações, %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)

func _bloqueado(cena: Node2D, ponto: Vector2) -> bool:
	var consulta := PhysicsPointQueryParameters2D.new()
	consulta.position = ponto
	consulta.collision_mask = 64
	return not cena.get_world_2d().direct_space_state.intersect_point(consulta).is_empty()

func _capturar(cena: Node2D, jogador: CharacterBody2D, estacoes: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	root.size = Vector2i(1408, 864)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	jogador.camera.enabled = false
	var camera := Camera2D.new()
	cena.add_child(camera)
	camera.make_current()
	jogador.global_position = Vector2(-900, -900)
	for estacao in 4:
		estacoes.definir_estacao(estacao, true)
		camera.zoom = Vector2.ONE
		camera.position = Vector2(704, 432)
		await quadros(60)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA + "visao_geral_%d.png" % estacao))
	estacoes.definir_estacao(0, true)
	for par in {"pesca": Vector2(700, 540), "pedreira": Vector2(640, 170), "acampamento": Vector2(1150, 300)}.keys():
		camera.zoom = Vector2(2.4, 2.4)
		camera.position = {"pesca": Vector2(700, 540), "pedreira": Vector2(640, 170), "acampamento": Vector2(1150, 300)}[par]
		await quadros(30)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA + "canto_%s.png" % par))
