extends Node2D

## Laguinho da fazenda (pedido de 2026-10-15, estilo Harvest Moon): o regador só enche aqui. Usar o regador virado para a
## água enche (plantio.gd). Desenhado em código: contorno irregular fixo, cheio com o tile de água da folha da estação
## (a mesma da arena), margem de terra, brilho na borda e alguns reflexos piscando. No inverno a água vira gelo claro,
## mas o regador continua enchendo (o jogador quebra o gelo).

const RAIO := Vector2(38, 28)
const PONTOS := 28
const FOLHA_ESTACAO := "res://assets/cenario/Seasonal Forest/arena/%s.png"
const ESTACOES := ["spring", "summer", "autumn", "winter"]
## Tiles de água cheia na folha (colunas 11 a 13 da linha 13, que emendam entre si): repetir 48 px quebra o quadriculado
const REGIAO_AGUA := Rect2i(176, 208, 48, 16)
const COR_MARGEM := Color("6b4a2e")
const COR_MARGEM_ESCURA := Color("4a3220")
const COR_BRILHO := Color(0.75, 0.92, 1.0, 0.55)
## Folga em volta da água que ainda conta como "virado para o lago" (o ponto da ferramenta fica uns 10 px à frente)
const FOLGA_INTERACAO := 8.0

var poligono := PackedVector2Array()
var _textura_agua: Texture2D
var _tempo := 0.0
var _reflexos: Array[Vector2] = []

func _ready() -> void:
	add_to_group("lago_fazenda")
	z_as_relative = false
	z_index = -998
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	poligono = _contorno(0.0)
	var corpo := StaticBody2D.new()
	corpo.name = "Colisao"
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	var forma := CollisionPolygon2D.new()
	forma.polygon = _contorno(-2.0)
	corpo.add_child(forma)
	add_child(corpo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while _reflexos.size() < 6:
		var p := Vector2(rng.randf_range(-RAIO.x, RAIO.x), rng.randf_range(-RAIO.y, RAIO.y)) * 0.7
		if Geometry2D.is_point_in_polygon(p, poligono):
			_reflexos.append(p.round())
	var estacoes := get_parent().get_node_or_null("Estacoes")
	if estacoes != null and estacoes.has_signal("estacao_mudou"):
		estacoes.estacao_mudou.connect(_aplicar_estacao)
	_aplicar_estacao(Calendario.estacao())

## Contorno fixo (mesmo formato em todo jogo): elipse com ondulações, pontos em pixel inteiro. `margem` cresce/encolhe
func _contorno(margem: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for i in PONTOS:
		var angulo := TAU * i / PONTOS
		var onda := 1.0 + 0.08 * sin(angulo * 3.0 + 0.6) + 0.05 * sin(angulo * 5.0 + 1.9)
		var raio := RAIO * onda + Vector2(margem, margem)
		pontos.append((Vector2(cos(angulo), sin(angulo)) * raio).round())
	return pontos

func _aplicar_estacao(estacao: int) -> void:
	var tiny: String = preload("res://codigo/cenario/fazenda_tiny.gd").pasta_do_terreno(get_parent(), estacao)
	if not tiny.is_empty():
		_textura_agua = load(tiny + "agua.png")
		queue_redraw()
		return
	var folha: Texture2D = load(FOLHA_ESTACAO % ESTACOES[clampi(estacao, 0, 3)])
	var imagem := folha.get_image().get_region(REGIAO_AGUA)
	_textura_agua = ImageTexture.create_from_image(imagem)
	queue_redraw()

## O ponto (global) está na água ou na beirinha dela
func contem(ponto_global: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(ponto_global), _contorno(FOLGA_INTERACAO))

func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()

func _draw() -> void:
	draw_colored_polygon(_contorno(4.0), COR_MARGEM_ESCURA)
	draw_colored_polygon(_contorno(2.0), COR_MARGEM)
	var uvs := PackedVector2Array()
	for p in poligono:
		uvs.append(p / Vector2(REGIAO_AGUA.size))
	draw_colored_polygon(poligono, Color.WHITE, uvs, _textura_agua)
	# Sombra da margem na metade de cima e brilho na de baixo
	var metade := PONTOS / 2
	var cima := PackedVector2Array()
	for i in range(metade, PONTOS + 1):
		cima.append(poligono[i % PONTOS] + Vector2(0, 1))
	draw_polyline(cima, Color(0, 0, 0, 0.25), 2.0)
	var baixo := PackedVector2Array()
	for i in range(0, metade + 1):
		baixo.append(poligono[i] - Vector2(0, 1))
	draw_polyline(baixo, COR_BRILHO, 1.0)
	for i in _reflexos.size():
		var alfa := 0.5 + 0.5 * sin(_tempo * 2.2 + i * 1.7)
		draw_rect(Rect2(_reflexos[i], Vector2(3, 1)), Color(1, 1, 1, 0.55 * alfa))
