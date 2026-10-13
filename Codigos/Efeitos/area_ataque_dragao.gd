extends Node2D

## Aviso no chão e efeitos de impacto. A geometria é a mesma usada pelo chefe.
const Profundidade := preload("res://Codigos/Globais/profundidade.gd")
const EfeitoAtaque := preload("res://Codigos/Efeitos/efeito_ataque_dragao.gd")
const Geometria := preload("res://Codigos/Efeitos/geometria_ataque_dragao.gd")
const AvisoAtaque := preload("res://Codigos/Efeitos/aviso_ataque.gd")
var _aviso: Node2D
var _efeito: Sprite2D
var tipo := "sopro"
var direcao := Vector2.DOWN
var alcance := 150.0
var progresso := 0.0
var ativo := false
var tempo := 0.0
var chefe: Node2D
var origem := Vector2.ZERO
const MEIO_CONE := Geometria.MEIO_CONE

func _ready() -> void:
	z_as_relative = false
	z_index = Profundidade.Z_CHAO + 20
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_aviso = AvisoAtaque.new()
	add_child(_aviso)
	var pontos := Geometria.cone(origem, direcao, alcance) if tipo in ["sopro", "patada"] else PackedVector2Array()
	if tipo not in ["sopro", "patada"]:
		for i in 64:
			pontos.append(Vector2.from_angle(TAU * i / 64.0) * alcance)
	_aviso.definir_area(pontos)
	_efeito = EfeitoAtaque.new()
	_efeito.tipo = tipo
	_efeito.direcao = direcao
	_efeito.alcance = alcance
	_efeito.chefe = chefe
	_efeito.origem = origem
	add_child(_efeito)

func atualizar(novo_progresso: float, em_impacto: bool, relogio: float) -> void:
	progresso = clampf(novo_progresso, 0, 1)
	ativo = em_impacto
	tempo = relogio
	_aviso.visible = not em_impacto and alcance > 0
	_aviso.animar(relogio)
	if is_instance_valid(_efeito):
		_efeito.atualizar(em_impacto, relogio)
	queue_redraw()

static func contem_ponto(tipo_golpe: String, deslocamento: Vector2, rumo: Vector2, raio: float) -> bool:
	if deslocamento.length() > raio:
		return false
	return tipo_golpe not in ["sopro", "patada"] or deslocamento.length() < 12 or absf(rumo.angle_to(deslocamento)) <= MEIO_CONE

func atinge_alvo(alvo: Node2D, instante: float = -1.0) -> bool:
	var fator := Geometria.fator_dano(tipo, tempo if instante < 0 else instante)
	if not ativo or fator <= 0 or alcance <= 0:
		return false
	# Fogo atinge o corpo; impactos no chão usam o círculo dos pés.
	var caminho := "AreaDano/CollisionShape2D" if tipo == "sopro" else "CollisionShape2D"
	var colisor := alvo.get_node_or_null(caminho) as CollisionShape2D
	var forma_alvo: Shape2D
	var transformacao := alvo.global_transform
	if colisor != null:
		if colisor.disabled or colisor.shape == null:
			return false
		forma_alvo = colisor.shape
		transformacao = colisor.global_transform
	else:
		var circulo := CircleShape2D.new()
		circulo.radius = 5
		forma_alvo = circulo
	var forma_golpe: Shape2D
	if tipo in ["sopro", "patada"]:
		var poligono := ConvexPolygonShape2D.new()
		poligono.points = Geometria.cone(origem, direcao, alcance * fator)
		forma_golpe = poligono
	else:
		var circulo := CircleShape2D.new()
		circulo.radius = alcance
		forma_golpe = circulo
	if not forma_golpe.collide(global_transform, forma_alvo, transformacao):
		return false
	var consulta := PhysicsRayQueryParameters2D.create(to_global(origem), transformacao.origin, 64)
	return get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()
