extends Control

## Fala narrada (prólogo, aulas, Rosa na enfermaria, lojas fechadas): a MESMA caixa de pergaminho das conversas da cidade
## (dialogo_cidade.gd), com o busto do morador que fala, boca animada e texto aparecendo letra a letra.
signal concluido
const TEMA := preload("res://recursos/ui/tema_sidebar.tres")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const RetratoFalante := preload("res://codigo/ui/retrato_falante.gd")
const VELOCIDADE_TEXTO := 70.0
var painel: PanelContainer
var _texto: Label
var _titulo: Label
var _retrato: RetratoFalante
var _rosto: PanelContainer
var _avancar: Button
var _fechar_dialogo: Button
var _paginas: Array[String] = []
var _indice := 0
var _espera := 0.0
var _digitando: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = TEMA
	painel = PanelContainer.new()
	painel.name = "Painel"
	painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	painel.add_theme_stylebox_override("panel", _estilo_pergaminho())
	add_child(painel)
	resized.connect(_ajustar)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	painel.add_child(linha)
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 5)
	linha.add_child(coluna)
	_titulo = Label.new()
	_titulo.add_theme_font_override("font", FONTE)
	_titulo.add_theme_font_size_override("font_size", 12)
	_titulo.add_theme_color_override("font_color", Color("75452d"))
	coluna.add_child(_titulo)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texto.add_theme_font_override("font", FONTE)
	_texto.add_theme_font_size_override("font_size", 13 if Controle.usando_toque else 10)
	_texto.add_theme_color_override("font_color", Color("493629"))
	coluna.add_child(_texto)
	_avancar = Button.new()
	_avancar.add_theme_font_override("font", FONTE)
	_avancar.custom_minimum_size = Vector2(110, 32 if Controle.usando_toque else 19)
	_avancar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_avancar.add_theme_font_size_override("font_size", 9)
	_estilizar_botao(_avancar)
	_avancar.pressed.connect(avancar)
	coluna.add_child(_avancar)
	_rosto = PanelContainer.new()
	_rosto.custom_minimum_size = Vector2(66, 70)
	_rosto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fundo := _estilo_pergaminho()
	fundo.set_content_margin_all(3)
	_rosto.add_theme_stylebox_override("panel", fundo)
	var lateral := VBoxContainer.new()
	lateral.add_theme_constant_override("separation",4)
	linha.add_child(lateral)
	_fechar_dialogo = Button.new()
	_fechar_dialogo.name = "FecharDialogo"
	_fechar_dialogo.text = "X"
	_fechar_dialogo.tooltip_text = "FECHAR FALA"
	_fechar_dialogo.custom_minimum_size = Vector2(32,32) if Controle.usando_toque else Vector2(26,26)
	_fechar_dialogo.size_flags_horizontal = Control.SIZE_SHRINK_END
	_estilizar_botao(_fechar_dialogo)
	_fechar_dialogo.pressed.connect(_fechar_fala)
	lateral.add_child(_fechar_dialogo)
	lateral.add_child(_rosto)
	_retrato = RetratoFalante.new()
	_retrato.rotulo = _texto
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rosto.add_child(_retrato)
	Controle.dicas_alteradas.connect(_atualizar_botao)
	_ajustar()
	visible = false

func _estilo_pergaminho() -> StyleBoxTexture:
	return preload("res://codigo/ui/estilo_interface.gd").painel(true)

func _estilizar_botao(botao: Button) -> void:
	botao.add_theme_color_override("font_color", Color("62422c"))
	botao.add_theme_color_override("font_hover_color", Color("372418"))
	botao.add_theme_color_override("font_focus_color", Color("372418"))
	for estado in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		botao.add_theme_stylebox_override(estado, preload("res://codigo/ui/estilo_interface.gd").botao(estado))

func _ajustar() -> void:
	if painel == null:
		return
	var estreito := size.x < 360
	var margem := 8.0 if estreito else maxf(12.0, (size.x - 440.0) / 2.0)
	painel.offset_left = margem
	painel.offset_right = -margem
	painel.offset_top = -(164 if estreito else 148) if Controle.usando_toque else -(144 if estreito else 132)
	painel.offset_bottom = -8
	_rosto.custom_minimum_size = Vector2(46, 58) if estreito else Vector2(66, 70)

## `id_retrato`: morador (ids de dados_cidade.gd) cujo busto aparece ao lado; o Bento é o padrão quando ele narra
func iniciar(paginas: Array[String], narrador := "BENTO", id_retrato := "") -> void:
	if id_retrato == "" and narrador == "BENTO":
		id_retrato = "bento"
	_titulo.text = narrador.to_upper()
	var folha: String = String(Dados.MORADORES[id_retrato]["folha"]) if Dados.MORADORES.has(id_retrato) else ""
	_rosto.visible = folha != "" and ResourceLoader.exists(RetratoFalante.RAIZ + folha + ".png")
	if _rosto.visible:
		_retrato.definir_personagem(folha)
	_ajustar()
	_paginas = _paginar(paginas, _rosto.visible)
	_indice = 0
	_mostrar()

func _mostrar() -> void:
	_texto.text = _paginas[_indice]
	_espera = 0.18
	if _digitando != null and _digitando.is_valid():
		_digitando.kill()
	_texto.visible_ratio = 0.0
	_digitando = create_tween()
	_digitando.tween_property(_texto, "visible_ratio", 1.0, maxf(0.15, _texto.text.length() / VELOCIDADE_TEXTO))
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

func _fechar_fala() -> void:
	if not visible: return
	if _digitando != null and _digitando.is_valid(): _digitando.kill()
	_texto.visible_ratio = 1.0
	_indice = _paginas.size()-1
	_espera = 0.0
	avancar()

func avancar() -> void:
	if not visible or _espera > 0:
		return
	# Com o texto ainda aparecendo, o primeiro toque só completa a fala
	if _texto.visible_ratio < 1.0:
		if _digitando != null and _digitando.is_valid():
			_digitando.kill()
		_texto.visible_ratio = 1.0
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
	var estreito := size.x < 360
	var margem := 8.0 if estreito else maxf(12.0, (size.x - 440.0) / 2.0)
	var largura := maxf(70.0, size.x - margem * 2.0 - 20.0 - ((46 if estreito else 66) + (6 if estreito else 12) if com_retrato else 38.0))
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
