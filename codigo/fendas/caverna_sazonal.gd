extends CanvasItem

## Pedra protegida: mantém material e geometria, refletindo discretamente a estação.
const TONS := [Color(.98,1,1),Color(1,.98,.94),Color(1,.96,.95),Color(.94,.98,1)]
func _ready() -> void:
	var paleta := ShaderMaterial.new()
	paleta.shader = preload("res://assets/cenario/fendas/materiais/paleta_sazonal.gdshader")
	material = paleta
	var estacoes: Node = get_parent().get_node("Estacoes")
	estacoes.estacao_mudou.connect(_trocar)
	_trocar(estacoes.estacao_atual)
func _trocar(indice: int) -> void:
	(material as ShaderMaterial).set_shader_parameter("tom",TONS[clampi(indice,0,3)])
