extends TileMapLayer

## Rocha protegida da neve: reflexos frios no inverno e umidade na primavera.
@export_range(0.1,1.0) var brilho := 1.0
const TONS := [Color(0.83,0.91,0.91),Color(1.0,0.95,0.86),Color(0.9,0.85,0.88),Color(0.8,0.85,1.0)]
func _ready() -> void:
	var estacoes: Node = get_parent().get_node("Estacoes")
	var paleta := ShaderMaterial.new()
	paleta.shader = preload("res://assets/cenario/fendas/materiais/paleta_sazonal.gdshader")
	material = paleta
	estacoes.estacao_mudou.connect(_trocar)
	_trocar(estacoes.estacao_atual)
func _trocar(indice: int) -> void:
	var tom: Color = TONS[clampi(indice,0,3)]
	tom = Color(tom.r*brilho,tom.g*brilho,tom.b*brilho,1)
	(material as ShaderMaterial).set_shader_parameter("tom",tom)
