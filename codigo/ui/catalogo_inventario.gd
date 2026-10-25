extends "res://codigo/ui/missoes_inventario.gd"

## Grade paginada e tooltip padrão; cada vista do coop mantém os próprios controles.
var _grade_catalogo: GridContainer
var colunas_maximas := 5
var _lado_casa := 32.0
var _dica: PanelContainer
var _area_dica: Control
var _rolagem_dica: ScrollContainer
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
	_grade_catalogo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade_catalogo.add_theme_constant_override("h_separation",3)
	_grade_catalogo.add_theme_constant_override("v_separation",3)
	_lista.add_child(_grade_catalogo)
	_paginacao = HBoxContainer.new()
	_paginacao.alignment = BoxContainer.ALIGNMENT_CENTER
	_lista.add_child(_paginacao)
	_anterior = Button.new()
	_anterior.text = "ANT."
	preload("res://codigo/ui/estilo_inicio_detalhado.gd").botao(_anterior,false,16.0)
	_anterior.custom_minimum_size = Vector2(32,32)
	_anterior.pressed.connect(_trocar_pagina.bind(-1))
	_paginacao.add_child(_anterior)
	_pagina_texto = Label.new()
	_pagina_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pagina_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paginacao.add_child(_pagina_texto)
	_proxima = Button.new()
	_proxima.text = "PROX."
	preload("res://codigo/ui/estilo_inicio_detalhado.gd").botao(_proxima,false,16.0)
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
	slot.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	preload("res://codigo/ui/estilo_inicio_detalhado.gd").casa(slot)
	_grade_catalogo.add_child(slot)
	var icone := TextureRect.new()
	icone.name = "Icone"
	icone.texture = textura
	icone.texture_filter = TEXTURE_FILTER_NEAREST
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icone)
	icone.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icone.offset_left = -8
	icone.offset_top = -8
	icone.offset_right = 8
	icone.offset_bottom = 8
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
		_grade_catalogo.columns = clampi(int((size.x-4)/35.0),1,colunas_maximas)
		_lado_casa = 32.0
		for slot in _grade_catalogo.get_children(): slot.custom_minimum_size.y = _lado_casa
		_aplicar_pagina.call_deferred()
	_fechar_dica()

func _por_pagina() -> int:
	var linhas := maxi(1,int((size.y-_grade_catalogo.position.y-38)/(_lado_casa+3)))
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
	var ancestral := get_parent()
	while ancestral != null and ancestral.name != "Sidebar": ancestral = ancestral.get_parent()
	_area_dica = ancestral as Control
	if _area_dica == null: return
	_dica = PanelContainer.new()
	_dica.name = "TooltipCatalogo"
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica.z_index = 30
	_estilizar_dica()
	_area_dica.add_child(_dica)
	_rolagem_dica = ScrollContainer.new()
	_rolagem_dica.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dica.add_child(_rolagem_dica)
	_linhas_dica = VBoxContainer.new()
	_linhas_dica.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_linhas_dica.add_theme_constant_override("separation",4)
	_rolagem_dica.add_child(_linhas_dica)
	_dica.hide()

func _estilizar_dica() -> void:
	preload("res://codigo/ui/estilo_inicio_detalhado.gd").painel(_dica,true,10)

func _mostrar_dica(id: String, slot: Control) -> void:
	if not is_instance_valid(_dica) or not is_visible_in_tree(): return
	_id_dica = id
	for filho in _linhas_dica.get_children(): filho.free()
	var largura := minf(220,_area_dica.size.x-20)
	var altura := 20.0
	var largura_texto := largura-24-_rolagem_dica.get_v_scroll_bar().get_combined_minimum_size().x
	var item_ui := preload("res://codigo/ui/item_ui.gd")
	var textos := String(slot.get_meta("detalhes","")).split("\n")
	for i in textos.size():
		if textos[i].is_empty(): continue
		var rotulo := item_ui.linha_dica(textos[i],Color("493020") if i == 0 else Color("65472f"))
		rotulo.custom_minimum_size.x = largura_texto
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 0 and _usa_toque():
			var cabecalho := HBoxContainer.new()
			_linhas_dica.add_child(cabecalho)
			rotulo.custom_minimum_size.x = 0
			cabecalho.add_child(rotulo)
			var fechar := Button.new()
			fechar.text = "X"
			fechar.custom_minimum_size = Vector2(24,24)
			fechar.pressed.connect(_fechar_dica)
			cabecalho.add_child(fechar)
		else:
			_linhas_dica.add_child(rotulo)
		var fonte := rotulo.get_theme_font("font")
		altura += maxf(fonte.get_height(10),fonte.get_multiline_string_size(textos[i],HORIZONTAL_ALIGNMENT_LEFT,largura_texto,10).y)+4
		if i == 0:
			var separador := HSeparator.new()
			_linhas_dica.add_child(separador)
			altura += 5
	altura = minf(altura,_area_dica.size.y-20)
	_rolagem_dica.custom_minimum_size = Vector2(largura_texto,altura-20)
	_dica.custom_minimum_size = Vector2(largura,altura)
	_dica.size = Vector2(largura,altura)
	_dica.show()
	_posicionar_dica.call_deferred(slot)

func _posicionar_dica(slot: Control) -> void:
	# A quebra de linha precisa da largura real antes de medir e posicionar o painel.
	await get_tree().process_frame
	if not is_instance_valid(slot) or not is_instance_valid(_dica) or not _dica.visible: return
	var altura := minf(_linhas_dica.get_combined_minimum_size().y+20,_area_dica.size.y-20)
	_rolagem_dica.custom_minimum_size.y = altura-20
	_dica.custom_minimum_size.y = altura
	_dica.size.y = altura
	await get_tree().process_frame
	if not is_instance_valid(slot) or not is_instance_valid(_dica): return
	var retangulo := slot.get_global_rect()
	var ponto := retangulo.end-_area_dica.global_position+Vector2(4,4)
	if ponto.y+_dica.size.y > _area_dica.size.y-10:
		ponto.y = retangulo.position.y-_area_dica.global_position.y-_dica.size.y-4
	_dica.position = Vector2(clampf(ponto.x,10,maxf(10,_area_dica.size.x-_dica.size.x-10)),clampf(ponto.y,10,maxf(10,_area_dica.size.y-_dica.size.y-10)))

func _fechar_dica() -> void:
	_id_dica = ""
	if is_instance_valid(_dica): _dica.hide()
