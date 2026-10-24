extends Node

## Estado temporário da Medusa, sem alterar atributos, equipamento ou save.
const PEDRA := preload("res://recursos/personagens/petrificacao.gdshader")
const IMUNIDADE_APOS_PEDRA := 4.0
var restante := 0.0
var imunidade := 0.0
var _materiais: Dictionary = {}
var _arvore_ativa := true
var _casca: Sprite2D
var _tempo_casca := 0.0
var _quebrando := false
var _rotulo: Label
var _fatal := false
var _esfarelando := false
var _tempo_esfarelar := 0.0
var corpo_esfarelado := false
var _raven: CanvasItem
var _raven_processava := true
var _raven_visivel := true

func aplicar(duracao: float, fatal: bool = false) -> bool:
	var jogador := get_parent()
	if jogador.estaMorto or _fatal or duracao <= 0:
		return false
	if not fatal and (jogador.esta_em_dash or restante > 0 or imunidade > 0):
		return false
	if not _materiais.is_empty():
		liberar()
	_fatal = fatal
	_esfarelando = false
	jogador.defesa.cancelar()
	jogador.cancelar_acao_fazenda()
	jogador.no_arco.parar_disparo()
	jogador.no_reacao.hide()
	jogador._cancelar_acoes_em_andamento()
	jogador.animar()
	_raven = jogador.get_node_or_null("HeroiRaven")
	if is_instance_valid(_raven):
		_raven_processava = _raven.is_processing()
		_raven_visivel = _raven.visible
		_raven.set_process(false)
	_arvore_ativa = jogador._arvore_animacao.active
	jogador._arvore_animacao.active = false
	var material_pedra := ShaderMaterial.new()
	material_pedra.shader = PEDRA
	for camada: Sprite2D in jogador.find_children("*", "Sprite2D", true, false):
		_materiais[camada] = camada.material
		camada.material = material_pedra
	restante = minf(duracao, 4.0)
	_tempo_casca = 0
	_quebrando = false
	if is_instance_valid(_casca):
		_casca.queue_free()
	_casca = Sprite2D.new()
	_casca.texture = load("res://assets/efeitos/medusa/petrificacao.png")
	_casca.hframes = 6
	_casca.scale = Vector2.ONE * 0.5
	_casca.position = Vector2(0, -2)
	_casca.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_casca.z_index = 5
	jogador.add_child(_casca)
	_rotulo = Label.new()
	_rotulo.text = "PEDRA FATAL" if fatal else "PETRIFICADO"
	_rotulo.position = Vector2(-28, -34)
	_rotulo.z_index = 6
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo.add_theme_font_override("font", load("res://assets/ui/Planes_ValMore.ttf"))
	_rotulo.add_theme_font_size_override("font_size", 8)
	_rotulo.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	_rotulo.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	_rotulo.add_theme_constant_override("outline_size", 1)
	jogador.add_child(_rotulo)
	return true

func atualizar(delta: float) -> bool:
	imunidade = maxf(0, imunidade - delta)
	_tempo_casca += delta
	if _esfarelando:
		_tempo_esfarelar += delta
		if is_instance_valid(_casca):
			_casca.frame = mini(5, 2 + int(_tempo_esfarelar * 8))
		if _tempo_esfarelar >= 0.5:
			get_parent().receber_hitkill_chefe()
		return true
	if restante > 0:
		restante = maxf(0, restante - delta)
		if is_instance_valid(_casca):
			_casca.frame = mini(1, int(_tempo_casca * 10)) if _tempo_casca < 0.2 else 2 + int(_tempo_casca * 4) % 2
		if restante <= 0:
			if _fatal:
				corpo_esfarelado = true
				get_parent().get_node("CompositeSprites").hide()
				var raven := get_parent().get_node_or_null("HeroiRaven")
				if raven != null:
					raven.hide()
				_esfarelando = true
				_tempo_esfarelar = 0
				_casca.texture = load("res://assets/efeitos/medusa/cascalho.png")
				_casca.position = Vector2(0, 8)
				_casca.frame = 2
				return true
			else:
				liberar()
		else:
			return true
	if _quebrando and is_instance_valid(_casca):
		_casca.frame = 4 if _tempo_casca < 0.15 else 5
		if _tempo_casca >= 0.3:
			_casca.queue_free()
			_casca = null
			_quebrando = false
	return false

func liberar() -> void:
	var jogador := get_parent()
	if restante <= 0 and _materiais.is_empty():
		return
	restante = 0
	imunidade = IMUNIDADE_APOS_PEDRA
	for camada in _materiais:
		if is_instance_valid(camada):
			camada.material = _materiais[camada]
	_materiais.clear()
	if not corpo_esfarelado:
		_restaurar_raven()
	if is_instance_valid(jogador) and is_instance_valid(jogador._arvore_animacao):
		jogador._arvore_animacao.active = _arvore_ativa
		jogador.velocity = Vector2.ZERO
		jogador._knockback = Vector2.ZERO
		jogador.temporizador_knockback = 0
	if _esfarelando and not jogador.estaMorto:
		jogador.get_node("CompositeSprites").show()
	_quebrando = not _fatal
	if _fatal and is_instance_valid(_casca):
		# O corpo permanece oculto; fica apenas o cascalho no chão após o golpe fatal.
		_casca.frame = 5
	_fatal = false
	_esfarelando = false
	_tempo_casca = 0
	if is_instance_valid(_rotulo):
		_rotulo.queue_free()
	_rotulo = null

func _exit_tree() -> void:
	limpar()

func limpar() -> void:
	liberar()
	corpo_esfarelado = false
	_restaurar_raven()
	if is_instance_valid(_casca):
		_casca.queue_free()
	_casca = null
	if is_instance_valid(_rotulo):
		_rotulo.queue_free()
	_rotulo = null
	imunidade = 0
	_quebrando = false

func _restaurar_raven() -> void:
	if is_instance_valid(_raven):
		_raven.set_process(_raven_processava)
		_raven.visible = _raven_visivel
