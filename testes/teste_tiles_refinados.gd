extends SceneTree
var falhas := 0
var verificacoes := 0
var tiles: Node

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		print("FALHA ",nome)

func _camadas(no: Node, lista: Array) -> void:
	if no is TileMapLayer: lista.append(no)
	for filho in no.get_children(): _camadas(filho,lista)

func _dados(camada: TileMapLayer) -> Array:
	var dados := [camada.tile_set.tile_size,camada.tile_set.get_physics_layers_count()]
	for celula in camada.get_used_cells():
		dados.append([celula,camada.get_cell_source_id(celula),camada.get_cell_atlas_coords(celula),camada.get_cell_alternative_tile(celula)])
	return dados

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		quit(1)
		return
	await process_frame
	tiles = root.get_node("TilesRefinados")
	for caminho in ["res://cenas/cidade.tscn","res://cenas/fazenda.tscn","res://cenas/casa.tscn","res://cenas/cidade/pousada.tscn","res://cenas/cenario.tscn"]:
		var cena: Node = load(caminho).instantiate()
		root.add_child(cena)
		current_scene = cena
		for i in 5: await process_frame
		cena.process_mode = Node.PROCESS_MODE_DISABLED
		var camadas := []
		_camadas(cena,camadas)
		_verificar("mapa contém tiles",not camadas.is_empty())
		for camada: TileMapLayer in camadas:
			var original := _dados(camada)
			var material_original: Material = camada.material
			var elegivel := false
			for i in camada.tile_set.get_source_count():
				var fonte: TileSetSource = camada.tile_set.get_source(camada.tile_set.get_source_id(i))
				if fonte is TileSetAtlasSource and tiles.textura_de_cenario(fonte.texture): elegivel = true
			tiles.ativo = false
			tiles.aplicar_no(camada)
			_verificar("desligar acabamento conserva grid",original == _dados(camada))
			tiles.ativo = true
			tiles.aplicar_no(camada)
			_verificar("ligar acabamento conserva células e colisão",original == _dados(camada))
			if elegivel and material_original is ShaderMaterial and material_original.shader.resource_path == tiles.AGUA:
				_verificar("água mantém seu shader e recebe acabamento", camada.material == material_original and is_equal_approx(float(material_original.get_shader_parameter("intensidade_acabamento")), 1.0))
			else:
				_verificar("cenário recebe acabamento sem substituir material próprio", camada.material == tiles.material_tiles if elegivel and material_original == null else camada.material == material_original)
		var jogador: Node = cena.get_node("Jogador")
		_verificar("acabamento não altera material do jogador",jogador.sprite_corpo.material == null and jogador.sprite_roupa.material == null)
		cena.queue_free()
		current_scene = null
		for i in 3: await process_frame
	# A troca de estação mantém o shader e o tamanho de células/atlas.
	var terreno: Node = load("res://cenas/terreno_fazenda.tscn").instantiate()
	root.add_child(terreno)
	for i in 3: await process_frame
	var chao: TileMapLayer = terreno.get_node("Chao")
	var dados := _dados(chao)
	var estacoes: Node = terreno.get_node("Estacoes")
	for indice in 4:
		estacoes.definir_estacao(indice,true)
		_verificar("estação mantém acabamento e grade",chao.material == tiles.material_tiles and _dados(chao) == dados)
	terreno.queue_free()
	await process_frame
	print("Verificações: %d; falhas: %d" % [verificacoes,falhas])
	quit(falhas)
