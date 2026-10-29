extends Node2D

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const AvisoAtaque := preload("res://codigo/efeitos/aviso_ataque.gd")
var _aviso: Node2D
const AVISO := 3.0
const DURACAO := 3.0
## Alcance fixo: o tamanho da caverna não pode aumentar a distância necessária para escapar.
const RAIO_ZONA := 96.0
var zona := PackedVector2Array()
var tempo := 0.0
var ativo := false
var chefe: Node2D
var centro_aviso := Vector2.ZERO
var _meteoritos: Array[Vector3] = []
var _textura: Texture2D

func espelho() -> Dictionary:
	var pontos: Array = []
	for p in zona: pontos.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	return {"k": "chuva", "z": pontos.slice(0, 128), "t": snappedf(tempo, 0.01), "a": ativo}

func _ready() -> void:
	add_to_group("espelhos_coop")
	z_as_relative = false
	z_index = Profundidade.Z_CHAO + 30
	var material_efeito := CanvasItemMaterial.new()
	material_efeito.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = material_efeito
	_textura = load("res://assets/efeitos/dragao/meteoro.png")
	_aviso = AvisoAtaque.new()
	add_child(_aviso)
	definir_zona(zona)

func definir_zona(poligono: PackedVector2Array) -> void:
	zona = poligono
	_meteoritos.clear()
	if is_instance_valid(_aviso):
		_aviso.definir_area(zona)
	var limites := limites_poligono(zona)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1907
	for y in range(int(limites.position.y), int(limites.end.y), 48):
		for x in range(int(limites.position.x), int(limites.end.x), 48):
			var ponto := Vector2(x + rng.randf_range(8, 40), y + rng.randf_range(8, 40))
			if Geometry2D.is_point_in_polygon(ponto, zona):
				_meteoritos.append(Vector3(ponto.x, ponto.y, rng.randf_range(0, 0.9)))

func atualizar(relogio: float, em_impacto: bool) -> void:
	tempo = relogio
	ativo = em_impacto
	_aviso.animar(relogio, em_impacto)
	queue_redraw()
	if not ativo or not is_instance_valid(chefe):
		return
	var alvo = chefe.obter_jogador()
	if alvo == null or alvo.get("estaMorto") == true:
		return
	var pes := alvo.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var ponto: Vector2 = pes.global_position if pes != null else alvo.global_position
	if Geometry2D.is_point_in_polygon(ponto, zona) and alvo.has_method("receber_hitkill_dragao"):
		alvo.receber_hitkill_dragao()

func _draw() -> void:
	if zona.size() < 3:
		return
	if not ativo or _textura == null:
		return
	for meteoro in _meteoritos:
		var fase := fposmod(tempo + meteoro.z, 0.9) / 0.9
		var quadro := mini(5, int(fase * 6))
		var ponto := Vector2(meteoro.x, meteoro.y)
		if quadro < 2:
			ponto.y -= (1.0 - fase * 3.0) * 90.0
		draw_texture_rect_region(_textura, Rect2(ponto - Vector2(32, 38), Vector2(64, 64)), Rect2(quadro * 64, 0, 64, 64))

static func limites_poligono(poligono: PackedVector2Array) -> Rect2:
	if poligono.is_empty():
		return Rect2()
	var limites := Rect2(poligono[0], Vector2.ZERO)
	for ponto in poligono:
		limites = limites.expand(ponto)
	return limites

static func area_poligono(poligono: PackedVector2Array) -> float:
	var soma := 0.0
	for i in poligono.size():
		soma += poligono[i].cross(poligono[(i + 1) % poligono.size()])
	return absf(soma) * 0.5

static func metade_mapa(contorno: PackedVector2Array, vertical: bool, menor: bool) -> PackedVector2Array:
	var limites := limites_poligono(contorno)
	var inicio := limites.position.x if vertical else limites.position.y
	var fim := limites.end.x if vertical else limites.end.y
	var alvo := area_poligono(contorno) * 0.5
	for i in 26:
		var meio := (inicio + fim) * 0.5
		if area_poligono(_recortar(contorno, vertical, meio, true)) < alvo:
			inicio = meio
		else:
			fim = meio
	return _recortar(contorno, vertical, (inicio + fim) * 0.5, menor)

static func zona_centrada(contorno: PackedVector2Array, centro: Vector2) -> PackedVector2Array:
	var circulo := PackedVector2Array()
	for i in 64:
		circulo.append(centro + Vector2.from_angle(TAU * i / 64.0) * RAIO_ZONA)
	var partes := Geometry2D.intersect_polygons(contorno, circulo)
	var escolhida := PackedVector2Array()
	var maior_area := 0.0
	for parte in partes:
		# Em contornos côncavos preserva a região que contém o alvo marcado.
		if Geometry2D.is_point_in_polygon(centro, parte): return parte
		var area := area_poligono(parte)
		if area > maior_area:
			maior_area = area
			escolhida = parte
	return escolhida

static func _recortar(contorno: PackedVector2Array, vertical: bool, corte: float, menor: bool) -> PackedVector2Array:
	var resultado := PackedVector2Array()
	if contorno.is_empty():
		return resultado
	var anterior := contorno[-1]
	for atual in contorno:
		var a := anterior.x if vertical else anterior.y
		var b := atual.x if vertical else atual.y
		var dentro_a := a <= corte if menor else a >= corte
		var dentro_b := b <= corte if menor else b >= corte
		if dentro_a != dentro_b:
			resultado.append(anterior.lerp(atual, (corte - a) / (b - a)))
		if dentro_b:
			resultado.append(atual)
		anterior = atual
	return resultado
