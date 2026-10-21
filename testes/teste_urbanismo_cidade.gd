extends SceneTree

## Valida a cidade real após mudar o layout. Só executa no projeto com saves isolados.
var Dados: GDScript
var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 8) -> void:
	for i in n:
		await process_frame

func calçamento_conectado(terreno: TileMapLayer, origem: Vector2) -> Dictionary:
	var inicio := terreno.local_to_map(origem)
	var visitados := {inicio: true}
	var fila: Array[Vector2i] = [inicio]
	var indice := 0
	while indice < fila.size():
		var atual := fila[indice]
		indice += 1
		for direcao in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var vizinho: Vector2i = atual + direcao
			if visitados.has(vizinho):
				continue
			var fonte := terreno.get_cell_source_id(vizinho)
			var atlas := terreno.get_cell_atlas_coords(vizinho)
			# A carpintaria fica na margem leste; a ponte é um sprite sobre
			# tiles de água. A rede de acessos inclui seu piso caminhável.
			var piso_ponte := Rect2(636,252,80,40).has_point(terreno.map_to_local(vizinho))
			if (fonte in [1, 2] and atlas.y != 4) or piso_ponte:
				visitados[vizinho] = true
				fila.append(vizinho)
	return visitados

func _rodar() -> void:
	await process_frame
	Dados = load("res://codigo/cidade/dados_cidade.gd")
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute na cópia de testes, com saves isolados.")
		quit(1)
		return
	await process_frame
	root.get_node("Calendario").dia = 1
	root.get_node("Transicao").hora_salva = 12.0
	var vila: Node2D = load("res://cenas/cidade.tscn").instantiate()
	root.add_child(vila)
	current_scene = vila
	await quadros()
	await physics_frame
	var luz: Node = vila.get_node("Iluminacao")
	luz.set_process(false)
	var jogador: Node2D = vila.get_node("Jogador")
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = jogador.get_node("CollisionShape2D").shape
	consulta.collision_mask = 64
	var mundo := vila.get_world_2d().direct_space_state
	var origem: Vector2 = vila.get_node("Chegada_fazenda").position
	for id in Dados.PREDIOS:
		var chegada: Vector2 = vila.get_node("Chegada_" + id).position
		consulta.transform = Transform2D(0, chegada + Vector2(0, 9))
		verificar("chegada livre: " + id, mundo.intersect_shape(consulta).is_empty())
		var porta: Vector2 = vila.porta_do_local(id)
		consulta.transform = Transform2D(0, porta + Vector2(0, 9))
		verificar("acesso à porta livre: " + id, mundo.intersect_shape(consulta).is_empty())
		verificar("rota da fazenda até " + id, not vila.caminho_entre(origem, chegada).is_empty())
		var casa: Node2D
		for candidata in vila.get_node("Terrains/Construcoes").get_children():
			if candidata.id == id:
				casa = candidata
		verificar("fachada alinhada ao cadastro: " + id, casa.position == Dados.PREDIOS[id]["base"])
		var sombra: Node2D = casa.get_node("SombraChao")
		verificar("sombra abaixo dos corpos e acima do terreno: " + id, sombra.z_index > -990 and sombra.z_index < 0 and not sombra.z_as_relative)
	for id in Dados.MORADORES:
		for faixa in Dados.MORADORES[id]["rotina"]:
			if faixa[1] != "cidade":
				continue
			var ponto: Vector2 = faixa[2]
			consulta.transform = Transform2D(0, ponto + Vector2(0, 9))
			verificar("destino livre de " + id + " às " + str(faixa[0]), mundo.intersect_shape(consulta).is_empty())
			verificar("rota até destino de " + id, not vila.caminho_entre(origem, ponto).is_empty())
	verificar("rota até o portal", not vila.caminho_entre(origem, vila.get_node("Chegada_portal").position).is_empty())
	var feiras := 0
	for item in vila.get_node("Decoracao").get_children():
		if item.name.begins_with("feira_"):
			feiras += 1
	verificar("comércio concentrado na venda, sem barracas decorativas", feiras == 0)
	var terreno: TileMapLayer = vila.get_node("Terrains/Terreno")
	var bordas: Node2D = vila.get_node("Terrains/BordasGrama")
	verificar("tufos nas margens foram criados", bordas.tufos.size() > 10)
	var raizes: Array = bordas.tufos.duplicate(true)
	var apenas_margens := true
	for tufo in bordas.tufos:
		var perto := false
		for d in range(1, 5):
			for direcao in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				perto = perto or not bordas.eh_grama(tufo["raiz"] + direcao * d)
		apenas_margens = apenas_margens and perto
	verificar("tufos presos às bordas, sem manchas no gramado aberto", apenas_margens)
	var calcamento := calçamento_conectado(terreno, Vector2(336, 304))
	for id in Dados.PREDIOS:
		verificar("calçamento da praça chega à porta: " + id, calcamento.has(terreno.local_to_map(vila.porta_do_local(id))))
	verificar("calçamento da praça chega ao portal", calcamento.has(terreno.local_to_map(vila.get_node("Chegada_portal").position)))
	verificar("calçamento da praça chega ao coreto", calcamento.has(terreno.local_to_map(Vector2(448, 420))))
	for estacao in 4:
		vila.get_node("Terrains/Estacoes").definir_estacao(estacao, true)
		# A cidade consulta a estação visual a cada meio segundo, inclusive pelo F3.
		await quadros(40)
		var nome_estacao: String = ["primavera", "verao", "outono", "inverno"][estacao]
		verificar("pontas da grama acompanham estação " + nome_estacao, bordas.estacao == estacao)
		verificar("grama coberta pela neve, visível no calor: " + nome_estacao, bordas.pixels_visiveis().is_empty() == (estacao == 3))
		verificar("raízes dos tufos permanecem fixas na estação " + nome_estacao, bordas.tufos == raizes)
		for fonte_id in 4:
			var textura: Texture2D = terreno.tile_set.get_source(fonte_id).texture
			verificar("atlas carregado na estação %d: %d" % [estacao, fonte_id], textura != null and textura.resource_path.contains(nome_estacao))
		var validos := true
		for celula in terreno.get_used_cells():
			var fonte := terreno.tile_set.get_source(terreno.get_cell_source_id(celula)) as TileSetAtlasSource
			validos = validos and fonte != null and fonte.texture != null and fonte.has_tile(terreno.get_cell_atlas_coords(celula))
		verificar("tiles válidos na estação " + str(estacao), validos)
	var agua: TileMapLayer = vila.get_node("Terrains/SuperficieAgua")
	verificar("superfície de água tem tiles e material próprios", not agua.get_used_cells().is_empty() and agua.material != null)
	var separacao_correta := true
	for celula in agua.get_used_cells():
		separacao_correta = separacao_correta and agua.get_cell_source_id(celula) == 3 and terreno.get_cell_source_id(celula) == -1
	verificar("reflexos só na camada da água, sem sobrepor outro chão", separacao_correta)
	var contorno: Texture2D = agua.material.get_shader_parameter("contorno")
	verificar("rio usa máscara contínua no mundo", contorno != null and contorno.get_width()>64)
	verificar("rio tem correnteza e animação temporal", agua.material.shader.resource_path.ends_with("agua_viva.gdshader") and agua.material.get_shader_parameter("corrente").length()>4.0)
	var nuvens: Node = get_first_node_in_group("clima").get_node("Mundo/Nuvens/Cobertura")
	verificar("nuvens da cidade usam sombra suave", nuvens.material != null)
	var fonte_grama: TileSetAtlasSource = terreno.tile_set.get_source(0)
	var grama: PackedByteArray = fonte_grama.texture.get_image().get_region(Rect2i(0, 64, 16, 16)).get_data()
	for fonte_id in [1, 3]:
		var fonte: TileSetAtlasSource = terreno.tile_set.get_source(fonte_id)
		verificar("grama idêntica entre os atlas 0 e " + str(fonte_id), fonte.texture.get_image().get_region(Rect2i(0, 64, 16, 16)).get_data() == grama)
	var sombra: Node = vila.get_node("Terrains/Construcoes/Sede/SombraChao")
	luz.hora = 12.0
	sombra._process(1.0)
	verificar("sombra solar visível ao meio-dia", sombra.get_node("Projecao").modulate.a > 0.0)
	var projecao: Sprite2D = sombra.get_node("Projecao")
	var medida := Vector2(0, -projecao.texture.get_height())
	var base: Vector2 = sombra.global_position
	luz.hora = 8.0
	sombra._process(0.0)
	var manha: Vector2 = projecao.to_global(medida) - base
	verificar("sombra aponta para oeste de manhã", manha.x < 0)
	luz.hora = 12.0
	sombra._process(0.0)
	var meio_dia: Vector2 = projecao.to_global(medida) - base
	verificar("sombra mais curta ao meio-dia", meio_dia.length() < manha.length())
	luz.hora = 16.0
	sombra._process(0.0)
	var tarde: Vector2 = projecao.to_global(medida) - base
	verificar("sombra aponta para leste à tarde", tarde.x > 0)
	verificar("árvores recebem máscara própria", vila.get_node("Decoracao").find_children("arvore_*", "Node2D", false, false).all(func(arvore): return arvore.has_node("SombraChao")))
	luz.hora = 22.0
	sombra._process(1.0)
	verificar("sombra solar recolhe à noite", is_zero_approx(sombra.get_node("Projecao").modulate.a))
	verificar("contato continua à noite", sombra.get_node("Contato").modulate.a > 0.0)
	current_scene.queue_free()
	current_scene = null
	await quadros()
	print("Urbanismo: ", falhas, " falhas")
	quit(1 if falhas > 0 else 0)
