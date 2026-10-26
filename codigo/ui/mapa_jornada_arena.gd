extends VBoxContainer

## Mapa das ondas/andares alcançados. Com `escolher_checkpoint`, os andares de checkpoint liberados (azuis)
## viram a entrada da partida ao tocar, com o ouro de compensação.
signal entrada_escolhida(onda: int)
var escolher_checkpoint := false
const Estilo := preload("res://codigo/ui/estilo_interface.gd")
const Slot := preload("res://codigo/ui/estilo_slot.gd")
var modo_andares := false
var recorde := 0
var entrada := 1
var _pagina := 0
var _grade: GridContainer
var _trilha: Control
var _marcos := {}
var _intervalo: Label
var _detalhe: Label
var _anterior: Button
var _legenda: HFlowContainer
var _resumo: HFlowContainer
var _compacto := false
var _proxima: Button

func preparar(alcancada: int, onda_entrada: int) -> void:
	recorde = alcancada
	entrada = onda_entrada
	_pagina = maxi(0,(maxi(recorde,entrada)-1)/10)

func _ready() -> void:
	name = "MapaJornada"
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6)
	var resumo := HFlowContainer.new()
	_resumo = resumo
	resumo.add_theme_constant_override("h_separation",12)
	add_child(resumo)
	_rotulo(resumo,"RECORDE: ANDAR %d" % recorde,Color("75452d"),10)
	_rotulo(resumo,"ENTRADA: ANDAR %d" % entrada,Color("44602c"),10)
	var navegacao := HBoxContainer.new()
	add_child(navegacao)
	_anterior = _botao(navegacao,"ANT.",_mudar_pagina.bind(-1))
	_intervalo = _rotulo(navegacao,"",Color("493629"),9)
	_intervalo.size_flags_horizontal = SIZE_EXPAND_FILL
	_intervalo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_proxima = _botao(navegacao,"PROX.",_mudar_pagina.bind(1))
	_trilha = Control.new()
	_trilha.custom_minimum_size.y = 104
	add_child(_trilha)
	_trilha.draw.connect(_desenhar_trilha)
	_grade = GridContainer.new()
	_grade.columns = 5
	_grade.add_theme_constant_override("h_separation",10)
	_grade.add_theme_constant_override("v_separation",16)
	_trilha.add_child(_grade)
	_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grade.sort_children.connect(_trilha.queue_redraw)
	_detalhe = _rotulo(self,"",Color("694f36"),8)
	var legenda := HFlowContainer.new()
	_legenda = legenda
	legenda.add_theme_constant_override("h_separation",10)
	add_child(legenda)
	_rotulo(legenda,"VERDE: ALCANCADO",Color("44602c"),8)
	_rotulo(legenda,"OURO: ENTRADA",Color("91602b"),8)
	if escolher_checkpoint:
		_rotulo(legenda,"AZUL: TOQUE PARA COMECAR AQUI",Color("3e6a8c"),8)
	_rotulo(legenda,"PRETO: AINDA NAO DESCOBERTO",Color("75452d"),8)
	_preencher()
	resized.connect(_ajustar)
	_ajustar.call_deferred()

func _botao(pai: Node, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(28,24)
	botao.pressed.connect(acao)
	pai.add_child(botao)
	return botao

func _rotulo(pai: Node, texto: String, cor: Color, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_color_override("font_color",cor)
	rotulo.add_theme_font_size_override("font_size",tamanho)
	pai.add_child(rotulo)
	if pai is FlowContainer: rotulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	return rotulo

func _mudar_pagina(passo: int) -> void:
	_pagina += passo
	_preencher()

func _preencher() -> void:
	for filho in _grade.get_children(): filho.free()
	_marcos.clear()
	var maximo := maxi(1,ceili(maxi(recorde,entrada)/10.0))
	_pagina = clampi(_pagina,0,maximo)
	_anterior.disabled = _pagina == 0
	_proxima.disabled = _pagina == maximo
	_intervalo.text = "ANDARES %d - %d" % [_pagina*10+1,_pagina*10+10]
	for celula in 10:
		var linha := celula/5
		var coluna := celula%5 if linha == 0 else 4-celula%5
		var onda := _pagina*10+linha*5+coluna+1
		var marco := Button.new()
		marco.name = "Onda%d" % onda
		marco.set_meta("onda",onda)
		marco.custom_minimum_size = Vector2(32,32)
		marco.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_CENTER
		marco.size_flags_vertical = SIZE_EXPAND | SIZE_SHRINK_CENTER
		var checkpoint := escolher_checkpoint and Progresso.checkpoints_disponiveis().has(onda)
		var cor := Color("e4bd72") if onda == entrada else (Color(0.55, 1.0, 1.9) if checkpoint else (Color("90b77c") if onda <= recorde else Color("928377")))
		marco.add_theme_stylebox_override("normal",Slot.caixa(cor))
		for estado in ["hover","pressed","focus"]: marco.add_theme_stylebox_override(estado,Slot.caixa(Color("ffe0a0")))
		marco.tooltip_text = _descricao(onda)
		marco.pressed.connect(func():
			if checkpoint and onda != entrada:
				var erro := Progresso.escolher_checkpoint(onda)
				if erro.is_empty():
					entrada = onda
					entrada_escolhida.emit(onda)
					return
				_detalhe.text = erro
				Sons.tocar("erro", 0.0)
			else:
				_detalhe.text = _descricao(onda)
			_detalhe.show())
		_grade.add_child(marco)
		_marcos[onda] = marco
		var margem := MarginContainer.new()
		margem.mouse_filter = MOUSE_FILTER_IGNORE
		marco.add_child(margem)
		margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for lado in ["left","right","top","bottom"]: margem.add_theme_constant_override("margin_"+lado,6)
		var coluna_textos := VBoxContainer.new()
		coluna_textos.mouse_filter = MOUSE_FILTER_IGNORE
		coluna_textos.alignment = BoxContainer.ALIGNMENT_CENTER
		coluna_textos.add_theme_constant_override("separation",0)
		margem.add_child(coluna_textos)
		var previa := preload("res://codigo/ui/previa_inimigos.gd").new()
		previa.name = "Inimigos"
		previa.custom_minimum_size = Vector2(16,16)
		var cenas: Array[PackedScene] = []
		if modo_andares:
			var guardiao: Dictionary = preload("res://codigo/fendas/catalogo_andares.gd").chefe(onda)
			cenas.append(load("res://cenas/inimigos/%s.tscn" % guardiao.id))
		elif onda%10 == 0:
			var chefe: Dictionary = preload("res://codigo/logica/gerenciador_de_ondas.gd").dados_chefe_para_onda(onda)
			cenas.append(load("res://cenas/inimigos/%s.tscn" % chefe.id))
		else:
			cenas = preload("res://codigo/logica/slime_spawner.gd").obter_pool_especies(onda)
		previa.preparar(cenas)
		previa.self_modulate = Color.WHITE if onda <= recorde else Color.BLACK
		coluna_textos.add_child(previa)
		if modo_andares and onda <= recorde:
			marco.tooltip_text += "\n" + preload("res://codigo/fendas/catalogo_andares.gd").dados(onda).nome.to_upper()
		if onda <= recorde:
			marco.tooltip_text += "\n"+", ".join(previa.especies).replace("_"," ").to_upper()
		var numero := _rotulo(coluna_textos,str(onda),Color("f8e6bc"),8)
		numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numero.mouse_filter = MOUSE_FILTER_IGNORE

	_detalhe.text = "TOQUE NUM ANDAR AZUL PARA COMECAR NELE (MENOS OURO QUE JOGAR DO 1)." if escolher_checkpoint and Progresso.checkpoints_disponiveis().size() > 1 else "SELECIONE UM ANDAR PARA CONSULTAR."
	_ajustar()
	_trilha.queue_redraw()

func _ajustar() -> void:
	if _grade == null: return
	_compacto = size.x < 340
	add_theme_constant_override("separation",2 if _compacto else 6)
	_trilha.custom_minimum_size.y = 68 if _compacto else 88
	_legenda.visible = not _compacto
	_detalhe.visible = not _compacto
	for rotulo in _resumo.get_children(): rotulo.add_theme_font_size_override("font_size",8 if _compacto else 10)
	for botao in [_anterior,_proxima]: botao.custom_minimum_size.y = 20 if _compacto else 24
	for marco in _marcos.values():
		marco.custom_minimum_size = Vector2(28,28) if _compacto else Vector2(32,32)
		for lado in ["left","right","top","bottom"]: marco.get_child(0).add_theme_constant_override("margin_"+lado,2 if _compacto else 3)

func _descricao(onda: int) -> String:
	var texto := "ANDAR %d%s - %s" % [onda," / GUARDIAO" if modo_andares else (" / CHEFE" if onda%10 == 0 else ""),"SUA ENTRADA" if onda == entrada else ("ALCANCADO" if onda <= recorde else "AINDA NAO ALCANCADO")]
	if escolher_checkpoint and Progresso.checkpoints_disponiveis().has(onda) and onda > 1:
		texto += " - COMECAR AQUI: +%d OURO" % Progresso.ouro_checkpoint(onda)
	return texto

func _desenhar_trilha() -> void:
	for onda in range(_pagina*10+1,_pagina*10+10):
		if not _marcos.has(onda) or not _marcos.has(onda+1): continue
		var inicio: Vector2 = _marcos[onda].position+_marcos[onda].size/2
		var fim: Vector2 = _marcos[onda+1].position+_marcos[onda+1].size/2
		var cor := Color("72935c") if onda+1 <= recorde else Color("ba9a6b")
		_trilha.draw_line(inicio+Vector2(0,1),fim+Vector2(0,1),Color("99774c"),5)
		_trilha.draw_line(inicio,fim,cor,4)
		_trilha.draw_dashed_line(inicio,fim,Color("e9d6a8"),1,3)
