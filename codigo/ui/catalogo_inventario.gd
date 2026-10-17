extends "res://codigo/ui/missoes_inventario.gd"

## Grade e tooltip iguais para peixes e armas; cada vista do coop mantém os próprios controles.
var _grade_catalogo: GridContainer
var _dica: Panel
var _linhas_dica: VBoxContainer
var _pagina := 0
var _paginacao: HBoxContainer
var _pagina_texto: Label
var _anterior: Button
var _proxima: Button
var _id_dica := ""

func _ready() -> void:
	super._ready()
	_montar_dica.call_deferred()
	resized.connect(_ajustar_grade)
	visibility_changed.connect(_fechar_dica)
	get_v_scroll_bar().value_changed.connect(func(_valor):
		_fechar_dica()
		var foco := get_viewport().gui_get_focus_owner()
		if Controle.usando_controle_de(self) and foco != null and foco.has_meta("catalogo"):
			_mostrar_dica.call_deferred(String(foco.get_meta("catalogo")),foco)
	)

func _limpar_catalogo() -> void:
	_atualizacao_pendente = false
	_fechar_dica()
	_grade_catalogo = null
	_paginacao = null
	for filho in _lista.get_children(): filho.free()

func _nova_grade() -> GridContainer:
	_grade_catalogo = GridContainer.new()
	_grade_catalogo.add_theme_constant_override("h_separation",3)
	_grade_catalogo.add_theme_constant_override("v_separation",3)
	_lista.add_child(_grade_catalogo)
	_paginacao = HBoxContainer.new()
	_paginacao.alignment = BoxContainer.ALIGNMENT_CENTER
	_lista.add_child(_paginacao)
	_anterior = Button.new()
	_anterior.text = "<"
	_anterior.custom_minimum_size = Vector2(32,32)
	_anterior.pressed.connect(_trocar_pagina.bind(-1))
	_paginacao.add_child(_anterior)
	_pagina_texto = Label.new()
	_pagina_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pagina_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paginacao.add_child(_pagina_texto)
	_proxima = Button.new()
	_proxima.text = ">"
	_proxima.custom_minimum_size = Vector2(32,32)
	_proxima.pressed.connect(_trocar_pagina.bind(1))
	_paginacao.add_child(_proxima)
	_ajustar_grade.call_deferred()
	return _grade_catalogo

func _adicionar_item(id: String, textura: Texture2D, descoberto: bool, detalhes: String, acao := Callable()) -> Button:
	var slot := Button.new()
	slot.name = id
	slot.set_meta("catalogo",id)
	slot.set_meta("detalhes",detalhes)
	slot.custom_minimum_size = Vector2(32,32)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("211f30")
	estilo.border_color = Color("647081")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(2)
	slot.add_theme_stylebox_override("normal",estilo)
	var realce: StyleBoxFlat = estilo.duplicate()
	realce.border_color = Color("f6d879")
	realce.bg_color = Color("353447")
	for estado in ["hover","pressed","focus"]: slot.add_theme_stylebox_override(estado,realce)
	_grade_catalogo.add_child(slot)
	var icone := TextureRect.new()
	icone.name = "Icone"
	icone.texture = textura
	icone.texture_filter = TEXTURE_FILTER_NEAREST
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icone)
	icone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icone.offset_left = 6
	icone.offset_top = 6
	icone.offset_right = -6
	icone.offset_bottom = -6
	icone.modulate = Color.WHITE if descoberto else Color.BLACK
	slot.mouse_entered.connect(func():
		if not _usa_toque() and not Controle.usando_controle_de(self): _mostrar_dica(id,slot)
	)
	slot.mouse_exited.connect(func():
		if not _usa_toque() and not Controle.usando_controle_de(self): _fechar_dica()
	)
	slot.focus_entered.connect(func():
		if Controle.usando_controle_de(self): _mostrar_dica.call_deferred(id,slot)
	)
	slot.focus_exited.connect(_fechar_dica)
	slot.pressed.connect(func():
		var confirmar := not _usa_toque() or _id_dica == id
		_mostrar_dica(id,slot)
		if confirmar and acao.is_valid(): acao.call()
	)
	return slot

func _usa_toque() -> bool:
	return Controle.usando_toque and not EventosJogo.eh_do_p2(self)

func _ajustar_grade() -> void:
	if is_instance_valid(_grade_catalogo):
		_grade_catalogo.columns = maxi(1,int((size.x-4)/35.0))
		_aplicar_pagina.call_deferred()
	_fechar_dica()

func _por_pagina() -> int:
	var linhas := maxi(1,int((size.y-_grade_catalogo.position.y-38)/35.0))
	return linhas*_grade_catalogo.columns

func _aplicar_pagina() -> void:
	if not is_instance_valid(_grade_catalogo) or not is_instance_valid(_paginacao): return
	var quantidade := _grade_catalogo.get_child_count()
	var capacidade := _por_pagina()
	var paginas := maxi(1,ceili(float(quantidade)/capacidade))
	_pagina = clampi(_pagina,0,paginas-1)
	for i in quantidade:
		_grade_catalogo.get_child(i).visible = i>=_pagina*capacidade and i<(_pagina+1)*capacidade
	_paginacao.visible = paginas>1
	_pagina_texto.text = "%d / %d" % [_pagina+1,paginas]
	_anterior.disabled = _pagina==0
	_proxima.disabled = _pagina+1>=paginas
	scroll_vertical = 0

func _trocar_pagina(passo: int) -> void:
	_pagina += passo
	_fechar_dica()
	_aplicar_pagina()
	if Controle.usando_controle_de(self):
		_grade_catalogo.get_child(_pagina*_por_pagina()).grab_focus()

func _montar_dica() -> void:
	_dica = Panel.new()
	_dica.name = "TooltipCatalogo"
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica.z_index = 30
	# A mesma moldura TooltipPanel e as mesmas linhas do ItemUI da mochila.
	_dica.add_theme_stylebox_override("panel",get_theme_stylebox("panel","TooltipPanel"))
	get_parent().add_child(_dica)
	_linhas_dica = VBoxContainer.new()
	_linhas_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linhas_dica.add_theme_constant_override("separation",0)
	_dica.add_child(_linhas_dica)
	_linhas_dica.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_linhas_dica.offset_left = 7
	_linhas_dica.offset_right = -7
	_linhas_dica.offset_top = 5
	_linhas_dica.offset_bottom = -7
	_dica.hide()

func _mostrar_dica(id: String, slot: Control) -> void:
	if not is_instance_valid(_dica) or not is_visible_in_tree(): return
	_id_dica = id
	for filho in _linhas_dica.get_children(): filho.free()
	var largura := minf(180,get_parent().size.x-12)
	var altura := 12.0
	var item_ui := preload("res://codigo/ui/item_ui.gd")
	var textos := String(slot.get_meta("detalhes","")).split("\n")
	for i in textos.size():
		var rotulo := item_ui.linha_dica(textos[i],Color("f6d879") if i==0 else item_ui.COR_DICA_DETALHE)
		rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rotulo.custom_minimum_size.x = largura-14
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_linhas_dica.add_child(rotulo)
		var fonte := rotulo.get_theme_font("font")
		altura += maxf(fonte.get_height(10),fonte.get_multiline_string_size(textos[i],HORIZONTAL_ALIGNMENT_LEFT,largura-14,10).y)
	_dica.size = Vector2(largura,altura)
	_dica.show()
	_posicionar_dica.call_deferred(slot)

func _posicionar_dica(slot: Control) -> void:
	if not is_instance_valid(slot) or not is_instance_valid(_dica): return
	var pai := get_parent() as Control
	var retangulo := slot.get_global_rect()
	var ponto := retangulo.end-pai.global_position+Vector2(4,4)
	if ponto.y+_dica.size.y > pai.size.y-8:
		ponto.y = retangulo.position.y-pai.global_position.y-_dica.size.y-4
	_dica.position = Vector2(clampf(ponto.x,6,maxf(6,pai.size.x-_dica.size.x-6)),clampf(ponto.y,38,maxf(38,pai.size.y-_dica.size.y-8)))

func _fechar_dica() -> void:
	_id_dica = ""
	if is_instance_valid(_dica): _dica.hide()
