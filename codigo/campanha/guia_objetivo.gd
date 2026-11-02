extends CanvasLayer

## Aponta o alvo do objetivo atual: marcador sobre ele, seta na borda e distância quando está fora da tela.
## Combate usa vermelho; o resto, dourado. Some perto do alvo (o indicador F assume) e durante telas, falas e abertura.
var cena: Node2D
var _desenho: Control
var _tempo := 0.0
const MARGEM := 22.0
const OURO := Color("ffd873")
const VERMELHO := Color("ff6a4d")
const UNIDADES_POR_METRO := 16.0

func _ready() -> void:
	layer = 5
	_desenho = Control.new()
	_desenho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.draw.connect(_desenhar)
	add_child(_desenho)

func _process(delta: float) -> void:
	_tempo += delta
	_desenho.queue_redraw()

## Ponto do mundo do objetivo atual e sua cor; (INF) quando não há o que apontar nesta região.
func _alvo_atual() -> Dictionary:
	if not is_instance_valid(cena) or not is_instance_valid(cena.jogador) or cena.jogador.estaMorto: return {}
	if not cena.interface._telas_abertas.is_empty(): return {}
	for n in cena.get_children():
		if n.has_method("_encerrar") and n.get("ativa"): return {}
	var encontro: Node = cena.encontro
	if is_instance_valid(encontro) and encontro.ativa:
		if is_instance_valid(encontro.chefe) and not encontro.chefe.esta_morto:
			return {"p": encontro.chefe.global_position + Vector2(0, -52), "cor": VERMELHO, "alvo_perto": 0.0}
		return {}
	# Compartilha a mesma prioridade do cartão da missão: primeiro um objetivo da região atual;
	# só aponta a saída quando o próximo objetivo realmente pertence a outra região.
	var objetivo: Dictionary = cena.controlador.objetivo_atual()
	if objetivo.is_empty() or objetivo.regiao != cena.regiao:
		if not cena.alvos.has("saida_regiao"): return {}
		var saida: Node2D = cena.alvos.saida_regiao.no
		return {"p": saida.global_position + Vector2(0, -34), "cor": OURO, "alvo_perto": 34.0, "base": saida.global_position}
	var id: String = objetivo.alvo
	if id == "comporta_moinho" and cena.regiao == "moinho" and is_instance_valid(cena.terreno.roteiro):
		id = cena.terreno.roteiro.alvo_do_puzzle()
	if id == "criatura_inicial":
		if is_instance_valid(cena.inimigo): return {"p": cena.inimigo.global_position + Vector2(0, -34), "cor": VERMELHO, "alvo_perto": 40.0, "base": cena.inimigo.global_position}
		return {}
	if not cena.alvos.has(id): return {}
	var no: Node2D = cena.alvos[id].no
	# O baú serve de alvo à espada e ao escudo; só mostra enquanto ainda houver o que pegar nele.
	var vermelho: bool = id == "raizes_despertas"
	return {"p": no.global_position + Vector2(0, -50 if id in ["espada_inicial", "escudo_inicial"] else -34), "cor": VERMELHO if vermelho else OURO, "alvo_perto": 34.0, "base": no.global_position}

func _distancia_metros(base: Vector2) -> int:
	return roundi(cena.jogador.global_position.distance_to(base) / UNIDADES_POR_METRO)

func _area_livre() -> Rect2:
	var area := Rect2(Vector2.ZERO, _desenho.size).grow(-MARGEM)
	if is_instance_valid(cena) and is_instance_valid(cena.hud):
		var tutorial: Control = cena.hud.get_node_or_null("MiniTutorial")
		if is_instance_valid(tutorial) and tutorial.is_visible_in_tree() and is_instance_valid(tutorial._painel):
			var para_guia: Transform2D = _desenho.get_global_transform_with_canvas().affine_inverse() * tutorial._painel.get_global_transform_with_canvas()
			var painel: Rect2 = para_guia * Rect2(Vector2.ZERO, tutorial._painel.size)
			area.size.x = maxf(80.0, minf(area.end.x, painel.position.x - 16.0) - area.position.x)
	return area

func _desenhar() -> void:
	var alvo := _alvo_atual()
	var transformacao := cena.get_viewport().get_canvas_transform() if is_instance_valid(cena) else Transform2D.IDENTITY
	var escala: float = transformacao.get_scale().x
	_arena(transformacao, escala)
	if alvo.is_empty(): return
	var cor: Color = alvo.cor
	var mundo: Vector2 = alvo.p
	var base: Vector2 = alvo.get("base", mundo)
	var distancia: float = cena.jogador.global_position.distance_to(base)
	# Perto do alvo o indicador F já aparece; o marcador fica só para o caminho.
	if distancia < float(alvo.alvo_perto) + 6.0 and alvo.alvo_perto > 0.0: return
	var tela: Vector2 = transformacao * mundo
	var area := _area_livre()
	var pulso := 0.5 + 0.5 * sin(_tempo * 4.0)
	if area.has_point(tela):
		var salto := Vector2(0, -3.0 * pulso)
		var p := tela + salto
		_desenho.draw_colored_polygon(PackedVector2Array([p + Vector2(0, 7), p + Vector2(-6, -2), p + Vector2(6, -2)]), Color(cor, 0.95))
		_desenho.draw_polyline(PackedVector2Array([p + Vector2(0, 7), p + Vector2(-6, -2), p + Vector2(6, -2), p + Vector2(0, 7)]), Color(0, 0, 0, 0.8), 1.0)
		_desenho.draw_arc(transformacao * base, (9.0 + 5.0 * pulso) * escala, 0.0, TAU, 28, Color(cor, 0.55 - 0.3 * pulso), 1.5)
		_texto(p + Vector2(0, -6), "%d m" % _distancia_metros(base), cor)
	else:
		var centro := area.get_center()
		var direcao := (tela - centro).normalized()
		var fator := 1e9
		if absf(direcao.x) > 0.001: fator = minf(fator, (area.size.x * 0.5) / absf(direcao.x))
		if absf(direcao.y) > 0.001: fator = minf(fator, (area.size.y * 0.5) / absf(direcao.y))
		var ponta := centro + direcao * fator
		var lado := direcao.orthogonal()
		var forma := PackedVector2Array([ponta + direcao * 7, ponta - direcao * 5 + lado * 6, ponta - direcao * 5 - lado * 6])
		_desenho.draw_colored_polygon(forma, Color(cor, 0.75 + 0.25 * pulso))
		_desenho.draw_polyline(PackedVector2Array([forma[0], forma[1], forma[2], forma[0]]), Color(0, 0, 0, 0.8), 1.0)
		_texto(ponta - direcao * 18 + Vector2(0, 3), "%d m" % _distancia_metros(base), cor)

## Anel vermelho da arena enquanto as raízes estão despertas.
func _arena(transformacao: Transform2D, escala: float) -> void:
	var encontro: Node = cena.encontro
	if not is_instance_valid(encontro) or not encontro.ativa or not cena.terreno.dados.alvos.has("raizes_despertas"): return
	var o: Array = cena.terreno.dados.alvos.raizes_despertas.p
	var centro: Vector2 = transformacao * Vector2(o[0], o[1])
	var pulso := 0.5 + 0.5 * sin(_tempo * 3.0)
	_desenho.draw_arc(centro, 175.0 * escala, 0.0, TAU, 96, Color(VERMELHO, 0.28 + 0.2 * pulso), 1.5)

func _texto(posicao: Vector2, texto: String, cor: Color) -> void:
	var fonte := ThemeDB.fallback_font
	var tamanho := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	var p := posicao - Vector2(tamanho.x * 0.5, 0)
	_desenho.draw_string(fonte, p + Vector2(1, 1), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.9))
	_desenho.draw_string(fonte, p, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cor)
