extends RefCounted

## Ficha curta do catálogo: hierarquia própria em vez de um parágrafo por atributo.
const Peixes := preload("res://codigo/pesca/peixes.gd")
const Progressao := preload("res://codigo/pesca/progressao_pesca.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const TEXTO := Color("fff0ce")
const SUAVE := Color("c6ac86")

static func _texto(texto: String, tamanho := 8, cor := TEXTO) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo

static func preencher(coluna: VBoxContainer, id: String, quem: Node, fechar: Callable) -> void:
	coluna.add_theme_constant_override("separation", 3)
	var cabecalho := HBoxContainer.new()
	cabecalho.name = "CabecalhoPeixe"
	cabecalho.add_theme_constant_override("separation", 8)
	coluna.add_child(cabecalho)
	var retrato := PanelContainer.new()
	retrato.custom_minimum_size = Vector2(36, 36)
	var moldura := StyleBoxFlat.new()
	moldura.bg_color = Color("211b20")
	moldura.border_color = preload("res://codigo/dados/raridades.gd").cor(Peixes.raridade(id)).darkened(0.25)
	moldura.set_border_width_all(1)
	moldura.set_corner_radius_all(3)
	moldura.content_margin_left = 2
	moldura.content_margin_right = 2
	moldura.content_margin_top = 2
	moldura.content_margin_bottom = 2
	retrato.add_theme_stylebox_override("panel", moldura)
	cabecalho.add_child(retrato)
	var icone := TextureRect.new()
	icone.name = "IconePeixe"
	icone.texture = Peixes.icone(id)
	icone.custom_minimum_size = Vector2(32, 32)
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	retrato.add_child(icone)
	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulos.add_theme_constant_override("separation", 2)
	cabecalho.add_child(titulos)
	var titulo := _texto(Peixes.nome(id), 9)
	titulo.name = "NomePeixe"
	titulos.add_child(titulo)
	var ambiente := "MAR" if Peixes.catalogo()[id]["ambiente"] == "mar" else "AGUA DOCE"
	titulos.add_child(_texto(ambiente + " | " + Peixes.raridade(id).to_upper(), 7, SUAVE))
	var estacoes: Array = Peixes.DADOS[id]["estacoes"]
	var epoca := "ANO TODO" if estacoes.is_empty() else "/".join(estacoes.map(func(e): return Calendario.NOMES[int(e)].substr(0, 3)))
	var liberado := Progressao.nivel(quem) >= Peixes.nivel_pesca(id)
	var faixa := PanelContainer.new()
	faixa.name = "RequisitoPeixe"
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("25463d") if liberado else Color("4b3547")
	fundo.set_corner_radius_all(2)
	for lado in [SIDE_LEFT, SIDE_RIGHT]: fundo.set_content_margin(lado, 5)
	for lado in [SIDE_TOP, SIDE_BOTTOM]: fundo.set_content_margin(lado, 3)
	faixa.add_theme_stylebox_override("panel", fundo)
	coluna.add_child(faixa)
	faixa.add_child(_texto("NV %d %s | %s" % [Peixes.nivel_pesca(id), "LIBERADO" if liberado else "BLOQUEADO", epoca], 7, Color("bde4c3") if liberado else Color("e7c6e1")))
	var atributos := HBoxContainer.new()
	atributos.name = "AtributosPeixe"
	atributos.add_theme_constant_override("separation", 6)
	coluna.add_child(atributos)
	atributos.add_child(_texto("VARA NV %d" % Peixes.nivel_recomendado(id), 7, SUAVE))
	var xp := _texto("%d XP" % Progressao.experiencia_peixe(id), 7)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atributos.add_child(xp)
	var venda := _texto("%d BRASAS" % Peixes.brasas(id), 7, Color("f5d18b"))
	venda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	atributos.add_child(venda)
	var rodape := HBoxContainer.new()
	rodape.name = "RodapePeixe"
	rodape.add_theme_constant_override("separation", 6)
	coluna.add_child(rodape)
	var contagens := _texto("BOLSA %d | PESCADOS %d" % [Fazenda.quantidade_peixes(id, quem), int(Fazenda.peixes_pescados.get(id, 0))], 7, SUAVE)
	contagens.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rodape.add_child(contagens)
	var botao := Button.new()
	botao.name = "FecharFicha"
	botao.set_meta("fechar_no_fluxo", true)
	botao.text = "FECHAR"
	botao.custom_minimum_size = Vector2(44, 24)
	botao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preload("res://codigo/ui/estilo_inicio_detalhado.gd").botao(botao, false, 16.0)
	botao.add_theme_font_size_override("font_size", 7)
	botao.pressed.connect(fechar)
	rodape.add_child(botao)
