extends Control

signal concluido
const TEMA := preload("res://recursos/ui/tema_sidebar.tres")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
var painel: PanelContainer
var _texto: Label
var _titulo: Label
var _retrato: TextureRect
var _avancar: Button
var _paginas: Array[String] = []
var _indice := 0
var _espera := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = TEMA
	painel = PanelContainer.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	painel.anchor_left = 0.08
	painel.anchor_right = 0.92
	painel.offset_left = 0
	painel.offset_right = 0
	if get_viewport().has_meta("dono"):
		painel.anchor_left = 0.0
		painel.anchor_right = 1.0
		painel.offset_left = 8
		painel.offset_right = -8
	painel.offset_top = -124 if Controle.usando_toque else -112
	painel.offset_bottom = -8
	# Mesma moldura de pixel art das telas da cidade e do inventário.
	var moldura: StyleBoxTexture = preload("res://codigo/ui/estilo_slot.gd").moldura_barra().duplicate()
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		moldura.set_content_margin(lado, 8)
	painel.add_theme_stylebox_override("panel", moldura)
	add_child(painel)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	painel.add_child(linha)
	_retrato = TextureRect.new()
	_retrato.custom_minimum_size = Vector2(44, 56)
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_retrato.texture_filter = TEXTURE_FILTER_NEAREST
	linha.add_child(_retrato)
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(coluna)
	_titulo = Label.new()
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titulo.add_theme_font_override("font", FONTE)
	_titulo.add_theme_font_size_override("font_size", 12)
	_titulo.add_theme_color_override("font_color", Color("e7c884"))
	coluna.add_child(_titulo)
	_texto = Label.new()
	_texto.add_theme_font_override("font", FONTE)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 13 if Controle.usando_toque else 12)
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(_texto)
	_avancar = Button.new()
	_avancar.add_theme_font_override("font", FONTE)
	_avancar.custom_minimum_size = Vector2(124, 28 if Controle.usando_toque else 24)
	_avancar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_avancar.add_theme_font_size_override("font_size", 10)
	_avancar.pressed.connect(avancar)
	coluna.add_child(_avancar)
	Controle.dicas_alteradas.connect(_atualizar_botao)
	visible = false

## `id_retrato`: morador (ids de dados_cidade.gd) cujo rosto aparece ao lado; o Bento é o padrão quando ele narra
func iniciar(paginas: Array[String], narrador := "BENTO", id_retrato := "") -> void:
	if id_retrato == "" and narrador == "BENTO":
		id_retrato = "bento"
	_paginas = _paginar(paginas, id_retrato != "")
	_indice = 0
	_titulo.text = narrador.to_upper()
	_retrato.visible = id_retrato != ""
	if _retrato.visible:
		var retrato := AtlasTexture.new()
		retrato.atlas = load(Dados.caminho_sprite(id_retrato))
		# Primeira célula da folha (parado, de frente); cada morador tem sua grade
		var grade: Array = Dados.geometria_sprite(id_retrato)["grade"]
		var celula := Vector2(retrato.atlas.get_width() / float(grade[0]), retrato.atlas.get_height() / float(grade[1]))
		retrato.region = Rect2(Vector2.ZERO, celula)
		_retrato.texture = retrato
	_mostrar()

func _mostrar() -> void:
	_texto.text = _paginas[_indice]
	_espera = 0.18
	_atualizar_botao()

func _atualizar_botao() -> void:
	_avancar.text = "%s  %s" % [Controle.rotulo_acao("ui_accept", self), "CONTINUAR" if _indice < _paginas.size() - 1 else "ENTENDI"]
	_avancar.text = _avancar.text.strip_edges()

func focar_inicio() -> void:
	Controle.focar(_avancar)

func _process(delta: float) -> void:
	_espera = maxf(0, _espera - delta)

func _input(evento: InputEvent) -> void:
	if not visible or evento.is_echo():
		return
	if not Introducao.ativa() and evento.is_action_pressed("close_menu"):
		get_viewport().set_input_as_handled()
		_indice = _paginas.size() - 1
		avancar()
	elif evento.is_action_pressed("open_menu") or evento.is_action_pressed("attack") or evento.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		avancar()

func avancar() -> void:
	if not visible or _espera > 0:
		return
	_indice += 1
	if _indice >= _paginas.size():
		EventosJogo.fechar_tela_de(self, "introducao")
		concluido.emit()
	else:
		_mostrar()

## Divide por largura real da fonte para aumentar as letras sem cortar falas no celular.
func _paginar(falas: Array[String], com_retrato: bool) -> Array[String]:
	var paginas: Array[String] = []
	var largura := get_viewport_rect().size.x * 0.84 - 20 - (54 if com_retrato else 0)
	var tamanho := _texto.get_theme_font_size("font_size")
	for fala in falas:
		var linhas: Array[String] = []
		var linha := ""
		for palavra in fala.split(" ", false):
			var candidata := palavra if linha.is_empty() else linha + " " + palavra
			if not linha.is_empty() and FONTE.get_string_size(candidata, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > largura:
				linhas.append(linha)
				linha = palavra
				if linhas.size() == 3:
					paginas.append("\n".join(linhas))
					linhas.clear()
			else:
				linha = candidata
		if not linha.is_empty():
			linhas.append(linha)
		if not linhas.is_empty():
			paginas.append("\n".join(linhas))
	return paginas
