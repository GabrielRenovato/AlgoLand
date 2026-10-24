extends Node2D

## Lago de abastecimento do regador: mantém contorno e interação existentes.
## A superfície usa AguaViva com profundidade, ondulação e gelo nas margens;
## a comparação Tiny conserva o desenho legado. A água continua utilizável no inverno.

const FOLHA_ESTACAO := "res://assets/cenario/substitutos/natureza/%s.png"
const ESTACOES := ["spring", "summer", "autumn", "winter"]
## Tiles de água cheia na folha (colunas 11 a 13 da linha 13, que emendam entre si): repetir 48 px quebra o quadriculado
const REGIAO_AGUA := Rect2i(176, 208, 48, 16)
const COR_MARGEM := Color("6b4a2e")
const COR_MARGEM_ESCURA := Color("4a3220")
const COR_BRILHO := Color(0.75, 0.92, 1.0, 0.55)
## Folga em volta da água que ainda conta como "virado para o lago" (o ponto da ferramenta fica uns 10 px à frente)
const FOLGA_INTERACAO := 8.0

## Tamanho do lago (elipse com ondulações): o laguinho do regador tem o padrão; a floresta usa um lago grande para pescar
@export var raio := Vector2(38, 28)
@export var pontos := 28
var poligono := PackedVector2Array()
var _textura_terra: Texture2D
var _textura_agua: Texture2D
var _tempo := 0.0
var _reflexos: Array[Vector2] = []
var _agua_viva = preload("res://codigo/cenario/agua_viva.gd").new()
var _superficie: Polygon2D

func _ready() -> void:
	add_to_group("lago_fazenda")
	z_as_relative = false
	z_index = -998
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	poligono = _contorno(0.0)
	_agua_viva.configurar_poligono(self,poligono)
	_superficie=Polygon2D.new()
	_superficie.name="SuperficieAgua"
	_superficie.polygon=poligono
	_superficie.material=_agua_viva.material
	add_child(_superficie)
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
	while _reflexos.size() < roundi(6.0 * raio.x * raio.y / (38.0 * 28.0)):
		var p := Vector2(rng.randf_range(-raio.x, raio.x), rng.randf_range(-raio.y, raio.y)) * 0.7
		if Geometry2D.is_point_in_polygon(p, poligono):
			_reflexos.append(p.round())
	var estacoes := get_parent().get_node_or_null("Estacoes")
	if estacoes != null and estacoes.has_signal("estacao_mudou"):
		estacoes.estacao_mudou.connect(_aplicar_estacao)
	_aplicar_estacao(Calendario.estacao())

## Contorno fixo (mesmo formato em todo jogo): elipse com ondulações, pontos em pixel inteiro. `margem` cresce/encolhe
func _contorno(margem: float) -> PackedVector2Array:
	var lista := PackedVector2Array()
	for i in pontos:
		var angulo := TAU * i / pontos
		var onda := 1.0 + 0.08 * sin(angulo * 3.0 + 0.6) + 0.05 * sin(angulo * 5.0 + 1.9)
		var tamanho := raio * onda + Vector2(margem, margem)
		lista.append((Vector2(cos(angulo), sin(angulo)) * tamanho).round())
	return lista

func _aplicar_estacao(estacao: int) -> void:
	_agua_viva.aplicar(estacao)
	_superficie.visible=not bool(get_parent().get_meta("visual_tiny",false))
	_textura_terra = load("res://assets/cenario/substitutos/terra_continua/campo_%s.png" % ESTACOES[clampi(estacao,0,3)])
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
	# Só o desenho legado (Tiny) anima reflexos; a água viva é um Polygon2D com shader e o resto é estático
	if _superficie.visible:
		return
	_tempo += delta
	queue_redraw()

func _draw() -> void:
	draw_colored_polygon(_contorno(4.0), COR_MARGEM_ESCURA)
	var margem := _contorno(2.0)
	var uvs_terra := PackedVector2Array()
	for p in margem: uvs_terra.append((global_position+p)/128.0)
	if bool(get_parent().get_meta("visual_tiny",false)):
		draw_colored_polygon(margem,COR_MARGEM)
	else:
		draw_colored_polygon(margem,Color.WHITE,uvs_terra,_textura_terra)
	if _superficie.visible:return
	var uvs := PackedVector2Array()
	for p in poligono:
		uvs.append(p / Vector2(REGIAO_AGUA.size))
	draw_colored_polygon(poligono, Color.WHITE, uvs, _textura_agua)
	# Sombra da margem na metade de cima e brilho na de baixo
	var metade := pontos / 2
	var cima := PackedVector2Array()
	for i in range(metade, pontos + 1):
		cima.append(poligono[i % pontos] + Vector2(0, 1))
	draw_polyline(cima, Color(0, 0, 0, 0.25), 2.0)
	var baixo := PackedVector2Array()
	for i in range(0, metade + 1):
		baixo.append(poligono[i] - Vector2(0, 1))
	draw_polyline(baixo, COR_BRILHO, 1.0)
	for i in _reflexos.size():
		var alfa := 0.5 + 0.5 * sin(_tempo * 2.2 + i * 1.7)
		draw_rect(Rect2(_reflexos[i], Vector2(3, 1)), Color(1, 1, 1, 0.55 * alfa))
