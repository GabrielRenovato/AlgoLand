extends "res://codigo/cidade/cidade.gd"

## Ambiente próprio: usa as passagens e os mundos separados do cooperativo.
var _tempo := 0.0
var material_mar: ShaderMaterial

func _ready() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://codigo/pesca/layout_praia.json"))
	var estrutura := preload("res://codigo/pesca/estrutura_cais.gd").new()
	estrutura.configurar(layout)
	add_child(estrutura)
	material_mar = ShaderMaterial.new()
	material_mar.shader = preload("res://codigo/pesca/mar.gdshader")
	material_mar.set_shader_parameter("atlas", preload("res://assets/cenario/praia/atlas.png"))
	material_mar.set_shader_parameter("costa_base", float(layout["costa_base"]))
	var curvas: Array = layout["curvas_costa"]
	material_mar.set_shader_parameter("curvas_costa", Vector4(curvas[0], curvas[1], curvas[2], curvas[3]))
	$Terrains/AreiaMar.material = material_mar
	var madeira := ShaderMaterial.new()
	madeira.shader = preload("res://codigo/pesca/madeira_cais.gdshader")
	$Terrains/Pier.material = madeira
	preload("res://codigo/pesca/decoracao_praia.gd").montar(self, layout["adornos"])
	preload("res://codigo/pesca/mobiliario_cais.gd").montar(self, layout["mobiliario"])
	super._ready()

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
