extends Control

## Carpintaria do Osvaldo no mesmo padrão da forja do Ivo: catálogo à esquerda, painel de pergaminho com os detalhes e os materiais
## à direita (tem / precisa), e um botão grande de encomenda embaixo. Substitui a conversa com botões soltos. As regras
## (custos, prazos, capacidade, brasas) continuam em codigo/fazenda/criacao_galinhas.gd; a tela só mostra e pede.
const Criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
const DadosCidade := preload("res://codigo/cidade/dados_cidade.gd")
const Atendimento := preload("res://codigo/cidade/atendimento_cidade.gd")
const Acabamento := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const Estilo := preload("res://codigo/ui/estilo_interface.gd")
const PASTA_GALINHEIRO := "res://assets/cenario/fazenda/galinheiro/"
const NOMES_MATERIAL := {"madeira": "MADEIRA", "pedra": "PEDRA", "ferro": "FERRO", "fibra": "FIBRA"}
## Catálogo: id, nome curto, nome completo, categoria (o que a tela mostra no cabeçalho do detalhe)
const ITENS := [
	{"id": "galinheiro_1", "nome": "GALINHEIRO", "completo": "GALINHEIRO", "nivel": 1, "categoria": "CONSTRUCAO"},
	{"id": "galinheiro_2", "nome": "AMPLIAR 2", "completo": "GALINHEIRO AMPLIADO", "nivel": 2, "categoria": "CONSTRUCAO"},
	{"id": "galinheiro_3", "nome": "AMPLIAR 3", "completo": "GALINHEIRO GRANDE", "nivel": 3, "categoria": "CONSTRUCAO"},
	{"id": "galinha", "nome": "GALINHA", "completo": "GALINHA", "nivel": 0, "categoria": "AVE", "acao": "comprar"},
	{"id": "galo", "nome": "GALO", "completo": "GALO", "nivel": 0, "categoria": "AVE", "acao": "comprar_galo"},
]

var _abas: HBoxContainer
var _catalogo: VBoxContainer
var _papel: PanelContainer
var _compacto := false
var _aba_detalhes := false
var painel: PanelContainer
var _selecionado := "galinheiro_1"
var _mensagem := ""
var _botoes := {}
var _nome: Label
var _dados: Label
var _icone: TextureRect
var _custos: VBoxContainer
var _titulo_materiais: Label
var _situacao: Label
var _encomendar: Button
var _fechar: Button
var _legenda: Label
var _resumo: Label
var _espera := 0.0
var _estado_anterior := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://recursos/ui/tema_sidebar.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel = PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.add_theme_stylebox_override("panel", Estilo.painel(false, 10.0))
	add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	painel.add_child(coluna)
	# Cabeçalho: ícone da madeira, nome da oficina, expediente e fechar
	var cabecalho := HBoxContainer.new()
	cabecalho.add_theme_constant_override("separation", 8)
	coluna.add_child(cabecalho)
	var emblema := TextureRect.new()
	emblema.texture = load("res://assets/ui/coletaveis/madeira.png")
	emblema.custom_minimum_size = Vector2(28, 28)
	emblema.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblema.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cabecalho.add_child(emblema)
	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = SIZE_EXPAND_FILL
	titulos.add_theme_constant_override("separation", 0)
	cabecalho.add_child(titulos)
	var titulo := _rotulo(titulos, 11)
	titulo.text = "CARPINTARIA DO OSVALDO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda = _rotulo(titulos, 8)
	_legenda.text = "8H AS 17H"
	_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda.add_theme_color_override("font_color", Color("e4bd72"))
	_fechar = Button.new()
	_fechar.text = "X"
	_fechar.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fechar.custom_minimum_size = Vector2(32, 32)
	_fechar.pressed.connect(func(): EventosJogo.fechar_tela_de(get_parent(), "carpintaria"))
	cabecalho.add_child(_fechar)
	_abas = HBoxContainer.new()
	_abas.add_theme_constant_override("separation",4)
	coluna.add_child(_abas)
	for texto in ["OBRAS E AVES","MATERIAIS"]:
		var aba := Button.new()
		aba.text = texto
		aba.size_flags_horizontal = SIZE_EXPAND_FILL
		aba.custom_minimum_size.y = 22
		aba.pressed.connect(_mostrar_detalhes.bind(texto=="MATERIAIS"))
		_abas.add_child(aba)
	# Corpo: catálogo (esquerda) e pergaminho de detalhes (direita)
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 8)
	coluna.add_child(corpo)
	var catalogo := VBoxContainer.new()
	_catalogo = catalogo
	catalogo.size_flags_horizontal = SIZE_EXPAND_FILL
	catalogo.add_theme_constant_override("separation", 4)
	corpo.add_child(catalogo)
	_resumo = _rotulo(catalogo, 8)
	_resumo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grade := GridContainer.new()
	grade.columns = 2
	grade.size_flags_horizontal = SIZE_EXPAND_FILL
	grade.add_theme_constant_override("h_separation", 4)
	grade.add_theme_constant_override("v_separation", 4)
	catalogo.add_child(grade)
	var grupo := ButtonGroup.new()
	for item: Dictionary in ITENS:
		var botao := Button.new()
		botao.alignment = HORIZONTAL_ALIGNMENT_CENTER
		botao.toggle_mode = true
		botao.button_group = grupo
		botao.theme_type_variation = &"BotaoAba"
		botao.custom_minimum_size = Vector2(0, 36)
		botao.size_flags_horizontal = SIZE_EXPAND_FILL
		var margem := MarginContainer.new()
		margem.name = "Conteudo"
		margem.mouse_filter = MOUSE_FILTER_IGNORE
		botao.add_child(margem)
		margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for lado in ["left", "right", "top", "bottom"]:
			margem.add_theme_constant_override("margin_" + lado, 4)
		var linha := HBoxContainer.new()
		linha.mouse_filter = MOUSE_FILTER_IGNORE
		linha.add_theme_constant_override("separation", 4)
		margem.add_child(linha)
		var icone := TextureRect.new()
		icone.name = "Icone"
		icone.texture = _textura_do_item(item)
		icone.custom_minimum_size = Vector2(20, 20)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.size_flags_vertical = SIZE_SHRINK_CENTER
		icone.mouse_filter = MOUSE_FILTER_IGNORE
		linha.add_child(icone)
		var nome := _rotulo(linha, 7)
		nome.name = "Nome"
		nome.text = item["nome"]
		nome.max_lines_visible = 2
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nome.size_flags_vertical = SIZE_EXPAND_FILL
		nome.add_theme_color_override("font_color", Color("34292c"))
		nome.mouse_filter = MOUSE_FILTER_IGNORE
		botao.pressed.connect(_abrir_item.bind(item["id"]))
		grade.add_child(botao)
		_botoes[item["id"]] = botao
	var papel := PanelContainer.new()
	_papel = papel
	papel.size_flags_horizontal = SIZE_EXPAND_FILL
	papel.size_flags_stretch_ratio = 1.35
	papel.add_theme_stylebox_override("panel", Estilo.painel(true, 10.0))
	corpo.add_child(papel)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.follow_focus = true
	papel.add_child(rolagem)
	var detalhes := VBoxContainer.new()
	detalhes.size_flags_horizontal = SIZE_EXPAND_FILL
	detalhes.add_theme_constant_override("separation", 2)
	rolagem.add_child(detalhes)
	var previa := HBoxContainer.new()
	previa.add_theme_constant_override("separation", 6)
	detalhes.add_child(previa)
	var moldura := PanelContainer.new()
	moldura.add_theme_stylebox_override("panel", preload("res://codigo/ui/estilo_slot.gd").caixa())
	previa.add_child(moldura)
	_icone = TextureRect.new()
	_icone.custom_minimum_size = Vector2(40, 40)
	_icone.size_flags_vertical = SIZE_SHRINK_CENTER
	_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moldura.add_child(_icone)
	var nomes := VBoxContainer.new()
	nomes.size_flags_horizontal = SIZE_EXPAND_FILL
	previa.add_child(nomes)
	_nome = _rotulo(nomes, 10)
	_nome.add_theme_color_override("font_color", Color("493020"))
	_dados = _rotulo(nomes, 8)
	_dados.add_theme_color_override("font_color", Color("805532"))
	_titulo_materiais = _rotulo(detalhes, 8)
	_titulo_materiais.add_theme_color_override("font_color", Color("805532"))
	_custos = VBoxContainer.new()
	_custos.add_theme_constant_override("separation", 3)
	detalhes.add_child(_custos)
	_situacao = _rotulo(detalhes, 8)
	_situacao.add_theme_color_override("font_color", Color("65472f"))
	_encomendar = Button.new()
	_encomendar.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_encomendar.theme_type_variation = &"BotaoPrimario"
	_encomendar.custom_minimum_size.y = 32
	_encomendar.pressed.connect(_ao_encomendar)
	coluna.add_child(_encomendar)
	for botao in [_fechar, _encomendar] + _botoes.values() + _abas.get_children():
		Acabamento.botao(botao, botao == _encomendar, 16)
		botao.add_theme_font_size_override("font_size", 8)
	Fazenda.galinheiro_alterado.connect(_atualizar)
	Fazenda.bolsas_alteradas.connect(_atualizar)
	Progresso.brasas_alteradas.connect(func(_b): _atualizar())
	EventosJogo.inventario_de(self).mochila_alterada.connect(_atualizar)
	visibility_changed.connect(_ao_visibilidade)
	resized.connect(_ajustar)
	painel.minimum_size_changed.connect(_agendar_ajuste)
	_ajustar()
	_selecionar(_item_sugerido())

func _rotulo(pai: Node, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.size_flags_horizontal = SIZE_EXPAND_FILL
	pai.add_child(rotulo)
	return rotulo

var _ajuste_pendente := false

## Refaz o tamanho depois que o conteúdo mudou (o texto quebra em linhas e o mínimo do painel muda)
func _agendar_ajuste() -> void:
	if _ajuste_pendente:
		return
	_ajuste_pendente = true
	_ajustar_apos_layout.call_deferred()

func _ajustar_apos_layout() -> void:
	_ajuste_pendente = false
	_ajustar()

## Mesmo dimensionamento da forja: o painel acompanha o tamanho deste controle, com modo compacto em telas pequenas (celular)
func _ajustar() -> void:
	if painel == null or _encomendar == null:
		return
	var compacto := size.x < 540.0 or size.y < 280.0
	_compacto = compacto
	_resumo.visible = not compacto
	_icone.get_parent().visible = not compacto
	_dados.visible = not compacto
	_situacao.visible = not compacto
	_titulo_materiais.visible = not compacto
	_nome.add_theme_font_size_override("font_size", 8 if compacto else 10)
	_papel.add_theme_stylebox_override("panel", Estilo.painel(true, 6 if compacto else 10))
	_custos.add_theme_constant_override("separation",1 if compacto else 3)
	for linha in _custos.get_children():
		if linha.get_child(0) is TextureRect: linha.get_child(0).custom_minimum_size = Vector2.ONE*(12 if compacto else 16)
		for filho in linha.get_children():
			if filho is Label: filho.add_theme_font_size_override("font_size", 7 if compacto else 8)
	_mostrar_detalhes(_aba_detalhes)
	_legenda.visible = not compacto
	_fechar.custom_minimum_size = Vector2(24, 24) if compacto else Vector2(32, 32)
	_encomendar.custom_minimum_size.y = 28 if compacto else 32
	painel.add_theme_stylebox_override("panel", Estilo.painel(false, 8 if compacto else 10))
	for botao in _botoes.values():
		botao.custom_minimum_size = Vector2(0, 30 if compacto else 36)
	var medida := Vector2(minf(560.0, size.x - 16.0), minf(300.0, size.y - 16.0))
	painel.custom_minimum_size = medida
	painel.size = medida
	painel.position = ((size - medida) / 2.0).round()

func _abrir_item(id: String) -> void:
	_selecionar(id)
	_mostrar_detalhes(true)

func _mostrar_detalhes(aberto: bool) -> void:
	_aba_detalhes = aberto
	_abas.visible = _compacto
	_catalogo.visible = not _compacto or not aberto
	_papel.visible = not _compacto or aberto
	_encomendar.visible = not _compacto or aberto

func _ao_visibilidade() -> void:
	if visible:
		_mensagem = ""
		_selecionar(_item_sugerido())
		_mostrar_detalhes(false)

## Abre já no que o jogador provavelmente quer: o próximo nível do galinheiro, ou a galinha se ele já está pronto
func _item_sugerido() -> String:
	var estado: Dictionary = Fazenda.galinheiro
	if int(estado.nivel) < 3 and int(estado.obra) == 0:
		return "galinheiro_%d" % (int(estado.nivel) + 1)
	return "galinha" if int(estado.nivel) > 0 else "galinheiro_1"

func _textura_do_item(item: Dictionary) -> Texture2D:
	var id: String = item["id"]
	if id.begins_with("galinheiro"):
		return load(PASTA_GALINHEIRO + "interior_%d.png" % int(item["nivel"]))
	# As folhas das aves têm vários quadros de 16x16: o primeiro é a ave de frente
	var recorte := AtlasTexture.new()
	recorte.atlas = load(PASTA_GALINHEIRO + ("galo.png" if id == "galo" else "galinha_white.png"))
	recorte.region = Rect2(0, 0, 16, 16)
	return recorte

func _item(id: String) -> Dictionary:
	for item: Dictionary in ITENS:
		if item["id"] == id:
			return item
	return ITENS[0]

func _selecionar(id: String) -> void:
	_selecionado = id
	_mensagem = ""
	_atualizar()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = 0.25
	var estado := _situacao_expediente()
	if estado != _estado_anterior:
		_estado_anterior = estado
		_atualizar()

## "" quando o Osvaldo atende; senão o motivo (fora do horário, ainda não voltou ao balcão)
func _situacao_expediente() -> String:
	return Atendimento.impedimento(Cooperativo.cena_de(self), "osvaldo", "carpintaria")

func _atualizar() -> void:
	if not is_instance_valid(_nome):
		return
	var item := _item(_selecionado)
	var estado: Dictionary = Fazenda.galinheiro
	var nivel := int(estado.nivel)
	var obra := int(estado.obra)
	var inventario := EventosJogo.inventario_de(self)
	_nome.text = item["completo"]
	_icone.texture = _textura_do_item(item)
	for id in _botoes:
		_botoes[id].set_pressed_no_signal(id == _selecionado)
	_resumo.text = "GALINHEIRO: NIVEL %d" % nivel if nivel > 0 else "SEM GALINHEIRO AINDA"
	for filho in _custos.get_children():
		filho.free()
	var construcao: bool = item["categoria"] == "CONSTRUCAO"
	var nivel_item := int(item["nivel"])
	var motivo := ""
	if construcao:
		_titulo_materiais.text = "MATERIAIS NA MOCHILA"
		_dados.text = "CONSTRUCAO - NIVEL %d\nPRAZO: %d DIA%s - ABRIGA %d AVES" % [nivel_item, Criacao.PRAZOS[nivel_item], "S" if Criacao.PRAZOS[nivel_item] != 1 else "", Criacao.CAPACIDADES[nivel_item]]
		for material in Criacao.CUSTOS[nivel_item]:
			var precisa: int = Criacao.CUSTOS[nivel_item][material]
			var tem: int = inventario.quantidade_tipo("material:" + material)
			_linha_custo(String(NOMES_MATERIAL.get(material, material.to_upper())), "res://assets/ui/coletaveis/%s.png" % material, tem, precisa)
		if obra > 0:
			motivo = "OBRA DO NIVEL %d EM ANDAMENTO - PRONTA NO DIA %d" % [obra, int(estado.pronto_dia)]
		elif nivel_item <= nivel:
			motivo = "JA CONSTRUIDO"
		elif nivel_item != nivel + 1:
			motivo = "CONSTRUA O NIVEL %d ANTES" % (nivel + 1)
		else:
			for material in Criacao.CUSTOS[nivel_item]:
				if inventario.quantidade_tipo("material:" + material) < Criacao.CUSTOS[nivel_item][material]:
					motivo = "FALTAM MATERIAIS NA SUA MOCHILA"
					break
		_encomendar.text = "CONSTRUIR" if nivel == 0 else "AMPLIAR"
	else:
		_titulo_materiais.text = "CUSTO"
		_dados.text = "AVE - %d BRASAS\nGALINHEIRO: %d / %d AVES" % [Criacao.PRECO_GALINHA, estado.aves.size() + int(int(estado.incubacao) >= 0), Criacao.CAPACIDADES[nivel]]
		_linha_custo("BRASAS", "res://assets/ui/fazenda/brasa.png" if ResourceLoader.exists("res://assets/ui/fazenda/brasa.png") else "", Progresso.brasas, Criacao.PRECO_GALINHA)
		if nivel == 0:
			motivo = "CONSTRUA O GALINHEIRO PRIMEIRO"
		elif estado.aves.size() + int(int(estado.incubacao) >= 0) >= Criacao.CAPACIDADES[nivel]:
			motivo = "GALINHEIRO CHEIO. AMPLIE PARA RECEBER MAIS AVES"
		elif Progresso.brasas < Criacao.PRECO_GALINHA:
			motivo = "FALTAM BRASAS"
		_encomendar.text = "COMPRAR"
	var expediente := _situacao_expediente()
	_situacao.text = _mensagem
	if _mensagem.is_empty():
		_situacao.text = motivo if motivo != "" else ("Os materiais saem da sua mochila. O Osvaldo trabalha na sua fazenda das 8h as 17h." if construcao else "A ave vai direto para o seu galinheiro.")
	if expediente != "":
		_situacao.text = expediente
	_encomendar.disabled = motivo != "" or expediente != ""
	_encomendar.tooltip_text = expediente if expediente != "" else motivo

func _linha_custo(nome: String, caminho_icone: String, tem: int, precisa: int) -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	_custos.add_child(linha)
	if caminho_icone != "" and ResourceLoader.exists(caminho_icone):
		var icone := TextureRect.new()
		icone.texture = load(caminho_icone)
		icone.custom_minimum_size = Vector2.ONE*(12 if _compacto else 16)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		linha.add_child(icone)
	var rotulo := _rotulo(linha, 7 if _compacto else 8)
	rotulo.text = nome
	rotulo.add_theme_color_override("font_color", Color("493629"))
	var quantidade := Label.new()
	quantidade.text = "%d / %d" % [tem, precisa]
	quantidade.add_theme_font_size_override("font_size", 7 if _compacto else 8)
	quantidade.add_theme_color_override("font_color", Color("44602c") if tem >= precisa else Color("9a3d32"))
	quantidade.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	linha.add_child(quantidade)

func _ao_encomendar() -> void:
	var expediente := _situacao_expediente()
	if expediente != "":
		_mensagem = expediente
		_atualizar()
		return
	var item := _item(_selecionado)
	var acao: String = "construir" if item["categoria"] == "CONSTRUCAO" else String(item["acao"])
	var erro := Criacao.executar(Fazenda, EventosJogo.dono(self), acao)
	if erro != "":
		_mensagem = erro
	elif acao == "construir":
		_mensagem = "COMBINADO! Termino no dia %d, das 8h as 17h na sua fazenda." % int(Fazenda.galinheiro.pronto_dia)
		Sons.tocar("compra", 0.05)
	else:
		_mensagem = "A AVE JA ESTA NO SEU GALINHEIRO!"
		Sons.tocar("compra", 0.05)
	_atualizar()
