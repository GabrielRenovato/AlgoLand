extends Control

const Varas := preload("res://codigo/pesca/varas.gd")
const Peixes := preload("res://codigo/pesca/peixes.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")
const Estilo := preload("res://codigo/ui/estilo_interface.gd")
var painel: PanelContainer
var _comparacao: HBoxContainer
var _etapas: HBoxContainer
var _exemplos: HBoxContainer
var _custo: Label
var _aviso: Label
var _refinar: Button
var _fechar: Button
var _mensagem := ""
var _ajuste_pendente := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = preload("res://recursos/ui/tema_sidebar.tres")
	texture_filter = TEXTURE_FILTER_NEAREST
	painel = PanelContainer.new()
	painel.add_theme_stylebox_override("panel",Estilo.painel(false,10))
	add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",6)
	painel.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	cabecalho.add_theme_constant_override("separation",8)
	coluna.add_child(cabecalho)
	var retrato := preload("res://codigo/ui/retrato_falante.gd").new()
	retrato.definir_personagem("nilo")
	retrato.custom_minimum_size = Vector2(28,28)
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cabecalho.add_child(retrato)
	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = SIZE_EXPAND_FILL
	titulos.add_theme_constant_override("separation",0)
	cabecalho.add_child(titulos)
	_rotulo(titulos,"OFICINA DO NILO",11,Color("efd8a7"))
	_rotulo(titulos,"REFINAMENTO DE VARAS",8,Color("d4b17b"))
	_fechar = Button.new()
	_fechar.text = "X"
	_fechar.custom_minimum_size = Vector2(28,28)
	_fechar.pressed.connect(func(): EventosJogo.fechar_tela_de(self,"oficina_vara"))
	cabecalho.add_child(_fechar)
	_etapas = HBoxContainer.new()
	_etapas.add_theme_constant_override("separation",4)
	coluna.add_child(_etapas)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.follow_focus = true
	rolagem.size_flags_vertical = SIZE_EXPAND_FILL
	coluna.add_child(rolagem)
	var corpo := VBoxContainer.new()
	corpo.size_flags_horizontal = SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation",6)
	rolagem.add_child(corpo)
	_comparacao = HBoxContainer.new()
	_comparacao.add_theme_constant_override("separation",8)
	corpo.add_child(_comparacao)
	_exemplos = HBoxContainer.new()
	_exemplos.add_theme_constant_override("separation",6)
	corpo.add_child(_exemplos)
	_aviso = _rotulo(corpo,"",8,Color("dcc9aa"))
	var custo_painel := PanelContainer.new()
	custo_painel.add_theme_stylebox_override("panel",Estilo.recorte(Estilo.CAMPO,5,6))
	coluna.add_child(custo_painel)
	var linha_custo := HBoxContainer.new()
	linha_custo.add_theme_constant_override("separation",6)
	custo_painel.add_child(linha_custo)
	var pedra := TextureRect.new()
	pedra.texture = preload("res://assets/ui/coletaveis/pedra_vara.png")
	pedra.custom_minimum_size = Vector2(16,16)
	pedra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pedra.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	linha_custo.add_child(pedra)
	_custo = _rotulo(linha_custo,"",8,Color("efd8a7"))
	_refinar = Button.new()
	_refinar.theme_type_variation = &"BotaoPrimario"
	_refinar.custom_minimum_size.y = 28
	_refinar.pressed.connect(_ao_refinar)
	coluna.add_child(_refinar)
	visibility_changed.connect(_ao_visibilidade)
	Fazenda.bolsas_alteradas.connect(_atualizar)
	EventosJogo.inventario_de(self).mochila_alterada.connect(_atualizar)
	painel.minimum_size_changed.connect(_agendar_ajuste)
	resized.connect(_ajustar)
	_ajustar()
	_atualizar()

func _rotulo(pai: Node, texto: String, fonte: int, cor: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",fonte)
	label.add_theme_color_override("font_color",cor)
	pai.add_child(label)
	return label

func _ao_visibilidade() -> void:
	if visible:
		_mensagem = ""
		_atualizar()

func _cartao(nivel: int, legenda: String) -> void:
	var papel := PanelContainer.new()
	papel.name = "Vara"+legenda.to_pascal_case()
	papel.size_flags_horizontal = SIZE_EXPAND_FILL
	papel.add_theme_stylebox_override("panel",Estilo.painel(true,8))
	_comparacao.add_child(papel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",4)
	papel.add_child(coluna)
	var titulo := _rotulo(coluna,legenda,8,Color("805532"))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_child(linha)
	var moldura := PanelContainer.new()
	moldura.add_theme_stylebox_override("panel",preload("res://codigo/ui/estilo_slot.gd").caixa(Varas.CORES[nivel-1]))
	linha.add_child(moldura)
	var icone := TextureRect.new()
	icone.texture = Icones.icone_vara(nivel)
	icone.custom_minimum_size = Vector2(16,16)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moldura.add_child(icone)
	var nome := _rotulo(linha,"NV %d" % nivel,10,Color("493020"))
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var aptas := 0
	for id in Peixes.DADOS:
		if Peixes.nivel_recomendado(id) <= nivel: aptas += 1
	var resumo := _rotulo(coluna,"DIFICULDADE BASE: -%d\n%d ESPECIES NA FAIXA" % [8*(nivel-1),aptas],8,Color("694f36"))
	resumo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _atualizar() -> void:
	if _refinar == null or not visible: return
	for pai in [_comparacao,_etapas,_exemplos]:
		for filho in pai.get_children(): filho.free()
	var jogador := EventosJogo.dono(self)
	var nivel := Varas.nivel(jogador)
	var proximo := mini(nivel+1,Varas.MAXIMO)
	for nv in range(1,6):
		var etapa := _rotulo(_etapas,"NV %d" % nv,8,Varas.CORES[nv-1] if nv <= nivel else Color("8e806c"))
		etapa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartao(nivel,"SUA VARA")
	_cartao(proximo,"NIVEL MAXIMO" if nivel == 5 else "APOS REFINAR")
	_rotulo(_exemplos,"PEIXES DO NIVEL %d" % proximo,8,Color("d4b17b"))
	var mostrados := 0
	for id in Peixes.DADOS:
		if Peixes.nivel_recomendado(id) != proximo: continue
		var peixe := TextureRect.new()
		peixe.texture = Peixes.icone(id)
		peixe.custom_minimum_size = Vector2(16,16)
		peixe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		peixe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		peixe.tooltip_text = Peixes.nome(id)
		_exemplos.add_child(peixe)
		mostrados += 1
		if mostrados >= 4: break
	var pedras := Varas.pedras(jogador)
	var custo := Varas.custo(jogador)
	_custo.text = "%d / %d PEDRAS DE REFINAMENTO" % [pedras,custo] if nivel < 5 else "REFINAMENTO COMPLETO / %d PEDRAS NA MOCHILA" % pedras
	_custo.add_theme_color_override("font_color",Color("b2da8b") if pedras >= custo else Color("f0ad8c"))
	_refinar.text = "NIVEL MAXIMO ALCANCADO" if nivel == 5 else "REFINAR PARA NIVEL %d" % proximo
	_refinar.disabled = nivel == 5 or pedras < custo or not _oficina_aberta()
	_aviso.text = _mensagem
	if _aviso.text.is_empty():
		_aviso.text = "Sua vara esta no melhor nivel. Boas pescarias!" if nivel == 5 else ("Faltam %d pedra(s). Encontre pedras de refinamento ao pescar." % (custo-pedras) if pedras < custo else "Mais controle na fisgada de peixes exigentes. As pedras saem da sua mochila.")
	if not _oficina_aberta(): _aviso.text = "NILO ATENDE NA LOJA DO CAIS DAS 8H AS 17H."

func _oficina_aberta() -> bool:
	var cena := Cooperativo.cena_de(self)
	return cena != null and cena.get("local") == "palafita" and cena.hora_atual() >= 8 and cena.hora_atual() < 17

func _ao_refinar() -> void:
	if not _oficina_aberta():
		_atualizar()
		return
	if Varas.melhorar(EventosJogo.dono(self)):
		_mensagem = "VARA REFINADA PARA O NIVEL %d!" % Varas.nivel(EventosJogo.dono(self))
		Sons.tocar("moeda",0.0)
	_atualizar()

func _ajustar() -> void:
	if painel == null: return
	_etapas.visible = size.y >= 280
	var medida := Vector2(minf(500,size.x-16),minf(316,size.y-16))
	painel.custom_minimum_size = medida
	painel.size = medida
	painel.position = ((size-medida)/2).round()

func _agendar_ajuste() -> void:
	if _ajuste_pendente: return
	_ajuste_pendente = true
	_ajustar_apos_layout.call_deferred()

func _ajustar_apos_layout() -> void:
	_ajuste_pendente = false
	_ajustar()

func focar_inicio() -> void:
	_atualizar()
	Controle.focar(_fechar if _refinar.disabled else _refinar)
