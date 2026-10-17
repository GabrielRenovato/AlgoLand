extends ScrollContainer

## Consulta o progresso compartilhado da partida, sem aceitar nem entregar pedidos.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
var _lista: VBoxContainer
var _atualizacao_pendente := false

func _ready() -> void:
	name = "Missoes"
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	vertical_scroll_mode = SCROLL_MODE_SHOW_NEVER
	follow_focus = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 8
	offset_right = -8
	offset_top = 34
	offset_bottom = -10
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	add_child(_lista)
	Cidade.alterado.connect(_agendar)
	Fazenda.bolsas_alteradas.connect(_agendar)
	Progresso.checkpoint_alterado.connect(_agendar)
	visibility_changed.connect(_agendar)

func _agendar(_valor: Variant = null) -> void:
	if not is_visible_in_tree() or _atualizacao_pendente:
		return
	_atualizacao_pendente = true
	_atualizar.call_deferred()

func _atualizar() -> void:
	_atualizacao_pendente = false
	var foco := get_viewport().gui_get_focus_owner()
	var id_foco := str(foco.get_meta("missao", "")) if foco != null else ""
	for filho in _lista.get_children():
		filho.free()
	for id in Dados.MISSOES:
		if Cidade.missoes.get(id, {}).get("estado", "") != "aceita":
			continue
		var dados: Dictionary = Dados.MISSOES[id]
		var progresso := Cidade.progresso_missao(id)
		var cartao := PanelContainer.new()
		cartao.set_meta("missao", id)
		cartao.focus_mode = Control.FOCUS_ALL
		cartao.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "TooltipPanel"))
		cartao.draw.connect(func():
			if cartao.has_focus():
				cartao.draw_rect(Rect2(Vector2.ZERO, cartao.size), Color("f6d879"), false, 1.0)
		)
		cartao.focus_entered.connect(cartao.queue_redraw)
		cartao.focus_exited.connect(cartao.queue_redraw)
		_lista.add_child(cartao)
		var linhas := VBoxContainer.new()
		linhas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linhas.add_theme_constant_override("separation", 4)
		cartao.add_child(linhas)
		_rotulo(linhas, dados["nome"], Color("f6d879"))
		_rotulo(linhas, dados["texto"])
		_rotulo(linhas, "PROGRESSO: %d / %d" % [progresso.x, progresso.y])
		_rotulo(linhas, "RECOMPENSA: %d BRASAS" % int(dados["brasas"]))
		var morador: String = Dados.MORADORES[dados["dono"]]["nome"]
		_rotulo(linhas, ("PRONTA PARA ENTREGAR\nFALE COM " if progresso.x >= progresso.y else "PEDIDO DE ") + morador, Color("a8dfad") if progresso.x >= progresso.y else Color.WHITE)
		if id == id_foco:
			cartao.grab_focus()
	if _lista.get_child_count() == 0:
		_rotulo(_lista, "NENHUMA MISSAO ATIVA\n\nConverse com os moradores ou visite o mural da cidade para aceitar pedidos.")

func _rotulo(pai: Node, texto: String, cor := Color.WHITE) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.add_theme_color_override("font_color", cor)
	pai.add_child(rotulo)

func primeiro_cartao() -> Control:
	for filho in _lista.get_children():
		if filho.focus_mode == Control.FOCUS_ALL:
			return filho
	return null
