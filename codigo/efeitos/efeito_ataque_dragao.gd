extends Sprite2D

## Animação visual guiada pelo relógio do golpe; não altera alcance nem aplica dano.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const Geometria := preload("res://codigo/efeitos/geometria_ataque_dragao.gd")
const ARQUIVOS := {"sopro": "fogo", "cauda": "impacto", "asas": "vento", "patada": "impacto"}
var tipo := "sopro"
var direcao := Vector2.RIGHT
var alcance := 150.0
var chefe: Node2D
var origem := Vector2.ZERO

func espelho() -> Dictionary:
	return {"k": "fogo", "tp": tipo, "dr": [direcao.x, direcao.y], "al": alcance, "gp": [snappedf(global_position.x, 0.1), snappedf(global_position.y, 0.1)],
		"rot": snappedf(global_rotation, 0.01), "sc": [scale.x, scale.y], "v": visible, "fr": frame, "zi": z_index}

func _ready() -> void:
	add_to_group("espelhos_coop")
	texture = load("res://assets/efeitos/dragao/" + ARQUIVOS[tipo] + ".png")
	hframes = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	var lado := float(texture.get_height())
	if tipo == "sopro":
		# A arte tem a saída da chama a 8% da largura, no meio da célula.
		centered = false
		rotation = direcao.angle()
		scale = Vector2.ONE * alcance / (lado * 0.84)
		offset = Vector2(-lado * 0.08, -lado * 0.5)
		position = origem
		z_as_relative = false
		z_index = Profundidade.z_de(chefe.global_position.y + chefe.altura_pes) + 1 if is_instance_valid(chefe) else 0
	else:
		# O aro máximo ocupa 85% da célula e corresponde ao alcance real do golpe.
		scale = Vector2.ONE * (alcance * 2.0) / (lado * 0.85)
		position = Vector2.ZERO

func atualizar(em_impacto: bool, tempo: float) -> void:
	visible = em_impacto
	frame = Geometria.quadro(tipo, tempo) if em_impacto else 0
