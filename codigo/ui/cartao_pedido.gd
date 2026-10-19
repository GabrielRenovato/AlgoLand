extends RefCounted

const Dados := preload("res://codigo/cidade/dados_cidade.gd")

static func criar(id: String, cidade: Node, quem: Node = null) -> PanelContainer:
	var pedido: Dictionary = Dados.MISSOES[id]
	var morador: Dictionary = Dados.MORADORES[pedido["dono"]]
	var cartao := PanelContainer.new()
	# O cartão não pode consumir o arrasto antes de chegar à lista rolável.
	cartao.mouse_filter = Control.MOUSE_FILTER_PASS
	cartao.name = "Pedido_"+id
	cartao.set_meta("missao",id)
	cartao.add_theme_stylebox_override("panel",preload("res://codigo/ui/estilo_interface.gd").painel(true,10.0))
	var linhas := VBoxContainer.new()
	linhas.name = "Conteudo"
	linhas.add_theme_constant_override("separation",5)
	cartao.add_child(linhas)
	var cabecalho := HBoxContainer.new()
	cabecalho.add_theme_constant_override("separation",6)
	linhas.add_child(cabecalho)
	var retrato := preload("res://codigo/ui/retrato_falante.gd").new()
	retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	retrato.definir_personagem(morador["folha"])
	retrato.custom_minimum_size = Vector2(28,28)
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cabecalho.add_child(retrato)
	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulos)
	rotulo(titulos,pedido["nome"],Color("493020"),10)
	rotulo(titulos,"PEDIDO DE "+morador["nome"],Color("805532"),8)
	rotulo(linhas,pedido["texto"])
	rotulo(linhas,"RECOMPENSA: %d BRASAS  +  2 AMIZADE" % pedido["brasas"],Color("7e4d22"),8)
	var estado: String = cidade.missoes.get(id,{}).get("estado","disponivel")
	if estado == "aceita":
		var progresso: Vector2i = cidade.progresso_missao(id,quem)
		rotulo(linhas,"PROGRESSO: %d / %d" % [progresso.x,progresso.y],Color("44602c"))
		rotulo(linhas,("PRONTA PARA ENTREGAR\n" if progresso.x >= progresso.y else "")+"CONVERSE COM "+morador["nome"]+" PARA ENTREGAR.",Color("694f36"),8)
	elif estado == "concluida":
		rotulo(linhas,"PEDIDO CONCLUIDO",Color("44602c"),8)
	return cartao

static func rotulo(pai: Node, texto: String, cor := Color("493629"), tamanho := 9) -> Label:
	var label := Label.new()
	label.text = texto
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color",cor)
	label.add_theme_font_size_override("font_size",tamanho)
	pai.add_child(label)
	return label
