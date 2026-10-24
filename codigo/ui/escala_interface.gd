extends Node

## Escala somente as camadas de interface, preservando mundo, câmera e caminhos dos nós.
## Corrige as âncoras dos controles diretos para o tamanho lógico da camada escalada.
const Opcoes := preload("res://codigo/globais/opcoes_jogo.gd")
## No desktop a base e 15% menor; mobile e metades estreitas mantem a legibilidade.
const BASE_DESKTOP := 0.85
const MINIMO_LOGICO := Vector2(288, 216)
var _camada: CanvasLayer
var _controles := {}
var _ultimo_fator := -1.0

## Reserva os cantos inferiores conforme o espaço físico, independentemente da escala do HUD.
static func escala_combate(tamanho: Vector2) -> float:
	return clampf(minf(tamanho.x / 390.0, tamanho.y / 300.0), 0.7, 1.0)

static func fator(no: Node) -> float:
	var eventos := no.get_node_or_null("/root/EventosJogo")
	var lado := 2 if eventos != null and eventos.eh_do_p2(no) else 1
	var tamanho := no.get_viewport().get_visible_rect().size
	var controle := no.get_node_or_null("/root/Controle")
	var desktop: bool = not OS.has_feature("mobile") and (controle == null or not controle.usando_toque) and tamanho.x >= 576
	var base: float = BASE_DESKTOP if desktop else 1.0
	return minf(Opcoes.escala_interface(lado) * base, minf(tamanho.x / MINIMO_LOGICO.x, tamanho.y / MINIMO_LOGICO.y))

static func tamanho_logico(no: Node) -> Vector2:
	return no.get_viewport().get_visible_rect().size / fator(no)

static func ligar(camada: CanvasLayer) -> void:
	var ajuste := load("res://codigo/ui/escala_interface.gd").new() as Node
	ajuste.name = "EscalaInterface"
	ajuste._camada = camada
	camada.add_child(ajuste)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100

func _process(_delta: float) -> void:
	var escala := fator(_camada)
	_camada.scale = Vector2.ONE * escala
	var diferenca := tamanho_logico(_camada) - _camada.get_viewport().get_visible_rect().size
	var presentes := {}
	for filho in _camada.get_children():
		if not filho is Control:
			continue
		var id := filho.get_instance_id()
		presentes[id] = true
		var offsets := Vector4(filho.offset_left, filho.offset_top, filho.offset_right, filho.offset_bottom)
		var anterior: Dictionary = _controles.get(id, {"aplicados": offsets, "correcao": Vector4.ZERO})
		var base := offsets
		for i in 4:
			# Mudanças feitas pela própria tela (reposicionamento/animação) passam a ser a base.
			if is_equal_approx(offsets[i], anterior["aplicados"][i]):
				base[i] -= anterior["correcao"][i]
		var correcao := Vector4(filho.anchor_left * diferenca.x, filho.anchor_top * diferenca.y, filho.anchor_right * diferenca.x, filho.anchor_bottom * diferenca.y)
		var novos := base + correcao
		if not offsets.is_equal_approx(novos):
			filho.offset_left = novos.x
			filho.offset_top = novos.y
			filho.offset_right = novos.z
			filho.offset_bottom = novos.w
		_controles[id] = {"aplicados": Vector4(filho.offset_left, filho.offset_top, filho.offset_right, filho.offset_bottom), "correcao": correcao}
	for id in _controles.keys():
		if not presentes.has(id): _controles.erase(id)
	if not is_equal_approx(escala, _ultimo_fator):
		_ultimo_fator = escala
		if _camada.has_method("_ao_escala_interface"):
			_camada.call_deferred("_ao_escala_interface")
