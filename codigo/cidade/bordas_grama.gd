extends Node2D

## Tufos em pixels nativos, presos à margem real da grama. O calçamento,
## a guia e a água não recebem pixels verdes. Não cria obstáculos.
const PALETAS := [
	[Color("596b3e"), Color("859950"), Color("b4be77")],
	[Color("465c35"), Color("718a44"), Color("a0b563")],
	[Color("94823e"), Color("a38f46"), Color("b9a961")],
	[Color("92917e"), Color("b6baa7"), Color("e1e8df")],
]
var estacao := 0
var tufos: Array[Dictionary] = []
var _terreno: TileMapLayer
var _agua: TileMapLayer
var _mascara_agua: Image
var _tempo := 0.0
var _fase := 0
## O mapa é estável: compõe o ciclo uma vez, em vez de consultar os tiles a cada rajada.
var _quadros: Array[ArrayMesh] = []
var _tufos_preparados := -1

func configurar(terreno: TileMapLayer, agua: TileMapLayer, nova_estacao: int) -> void:
	if _terreno == null:
		_terreno = terreno
		_agua = agua
		_mascara_agua = load("res://assets/cenario/algoland_original/mascara_agua.png").get_image()
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_as_relative = false
		z_index = -990
		_montar_margens()
	estacao = nova_estacao
	_quadros.clear()
	queue_redraw()

func eh_grama(ponto: Vector2i) -> bool:
	var celula := _terreno.local_to_map(Vector2(ponto))
	var fonte := _terreno.get_cell_source_id(celula)
	var atlas := _terreno.get_cell_atlas_coords(celula)
	if fonte == -1:
		fonte = _agua.get_cell_source_id(celula)
		atlas = _agua.get_cell_atlas_coords(celula)
	if fonte not in [0, 1, 3]:
		return false
	if atlas.y == 4:
		return true
	if atlas.y == 5:
		return false
	var local := ponto - celula * 16
	if fonte == 3:
		return _mascara_agua.get_pixel(atlas.x * 16 + local.x, atlas.y * 16 + local.y).r < 0.5
	# A guia usa os mesmos quadrantes Wang de 8 px do atlas da praça.
	var bit := (3 if local.y < 8 else 1) - (0 if local.x < 8 else 1)
	return ((atlas.y * 4 + atlas.x) & (1 << bit)) == 0

func _montar_margens() -> void:
	var candidatos := _terreno.get_used_cells()
	candidatos.append_array(_agua.get_used_cells())
	candidatos.sort()
	var ocupados: Dictionary = {}
	for celula in candidatos:
		var camada := _agua if _agua.get_cell_source_id(celula) == 3 else _terreno
		if camada.get_cell_atlas_coords(celula).y >= 4:
			continue
		for y in range(16):
			for x in range(16):
				var ponto: Vector2i = celula * 16 + Vector2i(x, y)
				var semente := posmod((ponto.x * 73856093) ^ (ponto.y * 19349663), 2147483647)
				if semente % 11 != 0 or not eh_grama(ponto):
					continue
				for direcao in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if eh_grama(ponto + direcao):
						continue
					var raiz: Vector2i = ponto - direcao
					if not eh_grama(raiz):
						continue
					var setor := Vector2i(floori(raiz.x / 7.0), floori(raiz.y / 7.0))
					if ocupados.has(setor):
						continue
					ocupados[setor] = true
					tufos.append({"raiz": raiz, "semente": semente})
					break

func pixels_visiveis() -> Dictionary:
	return _pixels_da_fase(_fase)

func _pixels_da_fase(fase: int) -> Dictionary:
	var pixels: Dictionary = {}
	if estacao == 3:
		return pixels  # O gramado fica inteiramente coberto pela neve.
	for tufo in tufos:
		var semente: int = tufo["semente"]
		var raiz: Vector2i = tufo["raiz"]
		var vento: int = [0, 0, 1, 1, 0, 0, -1, -1][(fase + semente) % 8]
		for lamina in range(3):
			var altura := 2 + (semente + lamina) % 3
			for h in range(altura + 1):
				var dx: int = int(vento) if h > 1 else 0
				var p := raiz + Vector2i((lamina - 1) * 2 + dx, -h)
				if eh_grama(p):
					pixels[p] = PALETAS[estacao][2 if h == altura else 0 if h == 0 else 1]
	return pixels

func _preparar_quadros() -> void:
	_quadros.clear()
	_tufos_preparados = tufos.size()
	if estacao == 3:
		return
	for fase in 8:
		var vertices := PackedVector2Array()
		var cores := PackedColorArray()
		var indices := PackedInt32Array()
		var pixels := _pixels_da_fase(fase)
		for ponto: Vector2i in pixels:
			var inicio := vertices.size()
			var p := Vector2(ponto)
			vertices.append_array(PackedVector2Array([p, p + Vector2.RIGHT, p + Vector2.ONE, p + Vector2.DOWN]))
			for i in 4: cores.append(pixels[ponto])
			indices.append_array(PackedInt32Array([inicio, inicio + 1, inicio + 2, inicio, inicio + 2, inicio + 3]))
		var malha := ArrayMesh.new()
		if not vertices.is_empty():
			var dados := []
			dados.resize(Mesh.ARRAY_MAX)
			dados[Mesh.ARRAY_VERTEX] = vertices
			dados[Mesh.ARRAY_COLOR] = cores
			dados[Mesh.ARRAY_INDEX] = indices
			malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, dados)
		_quadros.append(malha)

func _process(delta: float) -> void:
	if estacao == 3:
		return
	_tempo += delta
	if _tempo >= 0.28:
		_tempo = fmod(_tempo, 0.28)
		_fase = (_fase + 1) % 8
		queue_redraw()

func _draw() -> void:
	if _terreno == null:
		return
	if _quadros.is_empty() or _tufos_preparados != tufos.size():
		_preparar_quadros()
	if not _quadros.is_empty() and _quadros[_fase].get_surface_count() > 0:
		draw_mesh(_quadros[_fase], null)
