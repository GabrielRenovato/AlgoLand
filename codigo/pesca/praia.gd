extends "res://codigo/cidade/cidade.gd"

## Ambiente próprio: usa as passagens e os mundos separados do cooperativo.
var _tempo := 0.0
var material_mar: ShaderMaterial

func _ready() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://codigo/pesca/layout_praia.json"))
	var estrutura := preload("res://codigo/pesca/estrutura_cais.gd").new()
	estrutura.configurar(layout)
	add_child(estrutura)
	var acabamento := preload("res://codigo/pesca/acabamento_cais.gd").new()
	acabamento.configurar(layout)
	add_child(acabamento)
	material_mar = ShaderMaterial.new()
	material_mar.shader = preload("res://codigo/pesca/mar.gdshader")
	material_mar.set_shader_parameter("atlas", preload("res://assets/cenario/praia/atlas.png"))
	material_mar.set_shader_parameter("rochas", preload("res://assets/cenario/praia/adornos/pedras.png"))
	material_mar.set_shader_parameter("costa_base", float(layout["costa_base"]))
	var curvas: Array = layout["curvas_costa"]
	material_mar.set_shader_parameter("curvas_costa", Vector4(curvas[0], curvas[1], curvas[2], curvas[3]))
	$Terrains/AreiaMar.material = material_mar
	var madeira := ShaderMaterial.new()
	madeira.shader = preload("res://codigo/pesca/madeira_cais.gdshader")
	$Terrains/Pier.material = madeira
	preload("res://codigo/pesca/decoracao_praia.gd").montar(self, layout["adornos"])
	preload("res://codigo/pesca/mobiliario_cais.gd").montar(self, layout["mobiliario"])
	preload("res://codigo/pesca/arte_praia.gd").aplicar($Palafita,"palafita",self)
	_montar_pontos_pesca(layout)
	add_child(preload("res://codigo/pesca/vegetacao_orla.gd").new())
	super._ready()
	var pegadas := preload("res://codigo/pesca/pegadas_praia.gd").new()
	pegadas.configurar(self,layout)
	add_child(pegadas)

## Cada borda voltada para o mar permite pescar olhando para a água.
func _montar_pontos_pesca(layout: Dictionary) -> void:
	var celulas := {}
	for caixa in layout["cais"]:
		for y in range(floori(caixa[1] / 16.0), floori((caixa[1] + caixa[3]) / 16.0)):
			for x in range(floori(caixa[0] / 16.0), floori((caixa[0] + caixa[2]) / 16.0)):
				celulas[Vector2i(x, y)] = true
	var curvas: Array = layout["curvas_costa"]
	var forma := RectangleShape2D.new()
	forma.size = Vector2(20, 20)
	var raiz := Node2D.new()
	raiz.name = "PescaCais"
	add_child(raiz)
	for celula in celulas:
		for direcao in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if celulas.has(celula + direcao):
				continue
			var px: float = celula.x * 16.0
			var py: float = celula.y * 16.0
			var costa: float = float(layout["costa_base"]) + curvas[0] * sin(px * curvas[1]) + curvas[2] * sin(px * curvas[3]) + 4.0
			# Borda que dá em terra (e não em água) não serve para pescar
			if py < costa + 6.0:
				continue
			var ponto := Area2D.new()
			ponto.set_script(preload("res://codigo/pesca/ponto_pesca.gd"))
			ponto.set("direcao", Vector2(direcao))
			ponto.position = Vector2(px + 8.0, py + 8.0) + Vector2(direcao) * 4.0
			var colisao := CollisionShape2D.new()
			colisao.shape = forma
			ponto.add_child(colisao)
			raiz.add_child(ponto)

## Usa a mesma costa do shader e exclui os pisos que cobrem a água.
func agua_mar_no_ponto(ponto_global: Vector2) -> bool:
	var ponto := to_local(ponto_global)
	if not limites.has_point(ponto): return false
	var costa: float = material_mar.get_shader_parameter("costa_base")
	var curvas: Vector4 = material_mar.get_shader_parameter("curvas_costa")
	costa += curvas.x * sin(ponto.x * curvas.y) + curvas.z * sin(ponto.x * curvas.w)
	# Fora da faixa de espuma, mesmo no avanço máximo da maré animada.
	if ponto.y <= costa + 8.0: return false
	for caminho in ["Terrains/Pier", "Terrains/CalcadaOrla", "Terrains/VegetacaoOrla"]:
		var piso := get_node(caminho) as TileMapLayer
		if piso.get_cell_source_id(piso.local_to_map(piso.to_local(ponto_global))) >= 0:
			return false
	return true

## Ajusta a distância à água visível. INF indica direção sem destino válido.
func alvo_pesca_mar(origem_global: Vector2, direcao: Vector2, alcance: float) -> Vector2:
	var alvo := Vector2.INF
	var distancia := INF
	for passo in range(28, 121):
		var ponto := origem_global + direcao * passo
		if absf(passo - alcance) >= distancia: continue
		# Reserva espaço para a boia ao lado dos arremates do piso.
		if agua_mar_no_ponto(ponto) and agua_mar_no_ponto(ponto + Vector2(4,0)) \
				and agua_mar_no_ponto(ponto - Vector2(4,0)) and agua_mar_no_ponto(ponto + Vector2(0,4)) \
				and agua_mar_no_ponto(ponto - Vector2(0,4)):
			alvo = ponto
			distancia = absf(passo - alcance)
	return alvo

func _process(delta: float) -> void:
	super._process(delta)
	_tempo += delta
	if material_mar != null:
		material_mar.set_shader_parameter("tempo", _tempo)

func _aplicar_terreno(estacao: int) -> void:
	super._aplicar_terreno(estacao)
	var camada := get_node_or_null("Terrains/CalcadaOrla") as TileMapLayer
	if camada != null:
		# TileSet próprio: a prévia de outro ambiente do coop não altera esta orla.
		camada.tile_set = camada.tile_set.duplicate(true)
		var fonte := camada.tile_set.get_source(0) as TileSetAtlasSource
		fonte.texture = load("res://assets/cenario/praia/orla/" + ESTACOES_TERRENO[estacao] + ".png")
	var grama := get_node_or_null("Terrains/VegetacaoOrla") as TileMapLayer
	if grama != null:
		grama.tile_set = grama.tile_set.duplicate(true)
		(grama.tile_set.get_source(0) as TileSetAtlasSource).texture = load("res://assets/cenario/praia/vegetacao_orla/"+ESTACOES_TERRENO[estacao]+".png")
	if material_mar != null: material_mar.set_shader_parameter("estacao",estacao)
	if material_mar != null:
		material_mar.set_shader_parameter("areia_detalhada",load("res://assets/cenario/praia/detalhada/materiais/"+ESTACOES_TERRENO[estacao]+"/areia.png"))
		material_mar.set_shader_parameter("rochas",load("res://assets/cenario/praia/detalhada/adornos/pedras/"+ESTACOES_TERRENO[estacao]+".png"))
	if $Terrains/Pier.material != null:
		$Terrains/Pier.material.set_shader_parameter("estacao",estacao)
		$Terrains/Pier.material.set_shader_parameter("arte",load("res://assets/cenario/praia/detalhada/materiais/"+ESTACOES_TERRENO[estacao]+"/madeira.png"))
	for dados in [["CalcadaOrla", "pedra"], ["VegetacaoOrla", "grama"]]:
		var piso := get_node_or_null("Terrains/"+dados[0]) as TileMapLayer
		if piso == null: continue
		if piso.material == null:
			var acabamento := ShaderMaterial.new()
			acabamento.shader = preload("res://codigo/pesca/superficie_orla.gdshader")
			acabamento.set_shader_parameter("pedra",dados[1]=="pedra")
			piso.material=acabamento
		piso.material.set_shader_parameter("arte",load("res://assets/cenario/cidade/chao_detalhado/%s_%s.png" % [dados[1],ESTACOES_TERRENO[estacao]]))
	for nome in ["EstruturaCais", "AcabamentoCais"]:
		var parte := get_node_or_null(nome)
		if parte != null: parte.aplicar_estacao(estacao)
