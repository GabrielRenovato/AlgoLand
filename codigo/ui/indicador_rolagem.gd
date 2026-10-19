extends Control

## Setinhas de "tem mais": como as listas não mostram barra de rolagem, uma seta para cima/baixo aparece na borda da lista
## quando há conteúdo escondido naquele lado. Fica ao lado da rolagem (mesmo pai) e acompanha posição e tamanho dela.
## Uso: IndicadorRolagem.ligar(rolagem)

const COR := Color(1.0, 0.9, 0.55)
const COR_SOMBRA := Color(0.1, 0.08, 0.06, 0.9)
const LARGURA := 9.0
const ALTURA := 5.0

var _rolagem: ScrollContainer
var _acima := false
var _abaixo := false
var _tempo := 0.0

static func ligar(rolagem: ScrollContainer) -> Control:
	var indicador: Control = load("res://codigo/ui/indicador_rolagem.gd").new()
	indicador.name = "SetasRolagem"
	indicador._rolagem = rolagem
	indicador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicador.z_index = 20
	indicador.top_level = true
	rolagem.add_child(indicador)
	return indicador

func _process(delta: float) -> void:
	if not is_instance_valid(_rolagem):
		queue_free()
		return
	var visivel := _rolagem.is_visible_in_tree()
	if not visivel:
		_acima = false
		_abaixo = false
		return
	global_position = _rolagem.global_position
	size = _rolagem.size
	var conteudo := 0.0
	for filho in _rolagem.get_children():
		if filho is Control and filho.visible and filho != self:
			conteudo = maxf(conteudo, filho.get_combined_minimum_size().y)
	var sobra := conteudo - _rolagem.size.y
	var acima := _rolagem.scroll_vertical > 0
	var abaixo := sobra > 1.0 and _rolagem.scroll_vertical < sobra - 1.0
	_tempo += delta
	if acima != _acima or abaixo != _abaixo:
		_acima = acima
		_abaixo = abaixo
	queue_redraw()

func _draw() -> void:
	var meio := size.x / 2.0
	var pulso := 0.65 + 0.35 * sin(_tempo * 5.0)
	if _acima:
		_triangulo(Vector2(meio, 1.0), -1.0, pulso)
	if _abaixo:
		_triangulo(Vector2(meio, size.y - 1.0), 1.0, pulso)

## `sentido` -1: ponta para cima, a partir de `base_y`; 1: ponta para baixo
func _triangulo(centro: Vector2, sentido: float, alfa: float) -> void:
	var ponta := Vector2(centro.x, centro.y + (0.0 if sentido < 0.0 else 0.0))
	var topo := centro.y if sentido < 0.0 else centro.y - ALTURA
	var pontos: PackedVector2Array
	if sentido < 0.0:
		pontos = PackedVector2Array([Vector2(ponta.x - LARGURA / 2.0, topo + ALTURA), Vector2(ponta.x + LARGURA / 2.0, topo + ALTURA), Vector2(ponta.x, topo)])
	else:
		pontos = PackedVector2Array([Vector2(ponta.x - LARGURA / 2.0, topo), Vector2(ponta.x + LARGURA / 2.0, topo), Vector2(ponta.x, topo + ALTURA)])
	var sombra := PackedVector2Array()
	for p in pontos:
		sombra.append(p + Vector2(0, 1))
	draw_colored_polygon(sombra, Color(COR_SOMBRA, COR_SOMBRA.a * alfa))
	draw_colored_polygon(pontos, Color(COR, alfa))
