extends Control
## Mercado dos aventureiros: COMPRAR (busca com filtros), VENDER (item da mochila, preço e prazo) e MEUS ANÚNCIOS.
## Abre pelo mural da vila. O correio (compras, vendas e devoluções) é retirado ao abrir e ao atualizar.

const TEMA := preload("res://recursos/ui/tema_sidebar.tres")
const Cliente := preload("res://codigo/mercado/cliente_mercado.gd")
const IconesItens := preload("res://codigo/ui/icones_itens.gd")
const EstiloSlot := preload("res://codigo/ui/estilo_slot.gd")
const Raridades := preload("res://codigo/dados/raridades.gd")
const Encantamentos := preload("res://codigo/dados/encantamentos.gd")
const COR_TITULO := Color("f5cf7a")
const COR_DETALHE := Color(0.7, 0.68, 0.64)
const CATEGORIAS := [["", "TUDO"], ["arma", "ARMAS"], ["escudo", "ESCUDOS"], ["cabeca", "ELMOS"], ["corpo", "PEITORAIS"],
	["luvas", "LUVAS"], ["botas", "BOTAS"], ["secundaria", "SECUNDARIAS"], ["material", "MATERIAIS"], ["pocao", "POCOES"],
	["comida", "COMIDAS"], ["peixe", "PEIXES"], ["colheita", "COLHEITAS"], ["semente", "SEMENTES"], ["produto", "PRODUTOS"],
	["receita", "RECEITAS"]]
const ORDENS := [["barato", "MAIS BARATOS"], ["caro", "MAIS CAROS"], ["novo", "MAIS NOVOS"]]
## Aviso de entregas fora da tela: primeira consulta logo depois de entrar no mapa, depois a cada INTERVALO_AVISO
const ESPERA_PRIMEIRO_AVISO := 15.0
const INTERVALO_AVISO := 120.0
## Última contagem avisada por arquivo de jogador: trocar de mapa recria a tela sem repetir o aviso
static var _avisados := {}

var painel: PanelContainer
var _cliente: Node
var _saldo: Label
var _estado: Label
var _abas: Array[Button] = []
var _paginas: Array[Control] = []
var _aba := 0
var _ocupado := false
var _voltar: Button
# COMPRAR
var _lista_compra: VBoxContainer
var _botao_categoria: Button
var _botao_raridade: Button
var _botao_ordem: Button
var _rotulo_pagina: Label
var _anterior: Button
var _proxima: Button
var _categoria := 0
var _raridade := -1
var _ordem := 0
var _pagina := 0
# VENDER
var _grade_venda: GridContainer
var _nome_venda: Label
var _detalhe_venda: Label
var _preco_venda: Label
var _botao_prazo: Button
var _recebe_venda: Label
var _anunciar: Button
var _item_venda: DadosItem
var _preco := 10
var _quantidade := 1
var _linha_quantidade: HBoxContainer
var _legenda_quantidade: Label
var _rotulo_quantidade: Label
var _prazo := 0
# MEUS ANÚNCIOS
var _lista_meus: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = TEMA
	_cliente = Cliente.new()
	_cliente.name = "Cliente"
	add_child(_cliente)
	painel = PanelContainer.new()
	painel.name = "Painel"
	painel.add_theme_stylebox_override("panel", preload("res://codigo/ui/estilo_interface.gd").painel(false, 8.0))
	add_child(painel)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 8)
	painel.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	margem.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	coluna.add_child(cabecalho)
	var titulo := _rotulo("MERCADO DOS AVENTUREIROS", 8, COR_TITULO)
	titulo.size_flags_horizontal = SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	_saldo = _rotulo("", 8, COR_TITULO)
	cabecalho.add_child(_saldo)
	var linha_abas := HBoxContainer.new()
	linha_abas.add_theme_constant_override("separation", 4)
	coluna.add_child(linha_abas)
	for indice in 3:
		var aba := Button.new()
		aba.text = ["COMPRAR", "VENDER", "MEUS ANUNCIOS"][indice]
		aba.size_flags_horizontal = SIZE_EXPAND_FILL
		aba.custom_minimum_size.y = _altura_botao()
		aba.pressed.connect(_trocar_aba.bind(indice))
		linha_abas.add_child(aba)
		_abas.append(aba)
	_estado = _rotulo("", 7, COR_DETALHE)
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_estado)
	var conteudo := MarginContainer.new()
	conteudo.size_flags_vertical = SIZE_EXPAND_FILL
	coluna.add_child(conteudo)
	_paginas = [_montar_comprar(), _montar_vender(), _montar_meus()]
	for pagina in _paginas:
		conteudo.add_child(pagina)
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 8)
	coluna.add_child(botoes)
	var atualizar := _botao("ATUALIZAR", _atualizar)
	atualizar.size_flags_horizontal = SIZE_EXPAND_FILL
	botoes.add_child(atualizar)
	_voltar = _botao("VOLTAR", func() -> void: EventosJogo.fechar_tela_de(self, "mercado"))
	_voltar.size_flags_horizontal = SIZE_EXPAND_FILL
	botoes.add_child(_voltar)
	for i in _paginas.size():
		_paginas[i].visible = i == 0
		_marcar_aba(_abas[i], i == 0)
	Progresso.brasas_alteradas.connect(func(_b: int) -> void: _mostrar_saldo())
	visibility_changed.connect(_ao_abrir)
	resized.connect(_ajustar)
	_ajustar()
	var aviso := Timer.new()
	aviso.name = "AvisoCorreio"
	aviso.one_shot = false
	aviso.wait_time = ESPERA_PRIMEIRO_AVISO
	aviso.timeout.connect(func() -> void:
		aviso.wait_time = INTERVALO_AVISO
		_verificar_correio())
	add_child(aviso)
	aviso.start()

func _ajustar() -> void:
	if painel == null:
		return
	var dimensoes := Vector2(minf(460, size.x - 16), minf(320, size.y - 16))
	painel.size = dimensoes
	painel.position = ((size - dimensoes) * 0.5).floor()

func focar_inicio() -> void:
	Controle.focar(_abas[_aba])

# --- Montagem ---

func _montar_comprar() -> Control:
	var pagina := VBoxContainer.new()
	pagina.add_theme_constant_override("separation", 4)
	var filtros := HBoxContainer.new()
	filtros.add_theme_constant_override("separation", 4)
	pagina.add_child(filtros)
	_botao_categoria = _botao("", _girar_filtro.bind(0))
	_botao_raridade = _botao("", _girar_filtro.bind(1))
	_botao_ordem = _botao("", _girar_filtro.bind(2))
	for botao in [_botao_categoria, _botao_raridade, _botao_ordem]:
		botao.size_flags_horizontal = SIZE_EXPAND_FILL
		botao.add_theme_font_size_override("font_size", 7)
		filtros.add_child(botao)
	pagina.add_child(_rolagem_com(func(lista: VBoxContainer) -> void: _lista_compra = lista))
	var navegacao := HBoxContainer.new()
	navegacao.alignment = BoxContainer.ALIGNMENT_CENTER
	navegacao.add_theme_constant_override("separation", 8)
	pagina.add_child(navegacao)
	_anterior = _botao("<", _virar_pagina.bind(-1))
	_proxima = _botao(">", _virar_pagina.bind(1))
	_rotulo_pagina = _rotulo("", 7, COR_DETALHE)
	navegacao.add_child(_anterior)
	navegacao.add_child(_rotulo_pagina)
	navegacao.add_child(_proxima)
	_mostrar_filtros()
	return pagina

func _montar_vender() -> Control:
	var pagina := HBoxContainer.new()
	pagina.add_theme_constant_override("separation", 8)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_horizontal = SIZE_EXPAND_FILL
	rolagem.size_flags_stretch_ratio = 1.2
	rolagem.follow_focus = true
	pagina.add_child(rolagem)
	_grade_venda = GridContainer.new()
	_grade_venda.columns = 6
	_grade_venda.add_theme_constant_override("h_separation", 3)
	_grade_venda.add_theme_constant_override("v_separation", 3)
	rolagem.add_child(_grade_venda)
	var detalhe := VBoxContainer.new()
	detalhe.size_flags_horizontal = SIZE_EXPAND_FILL
	detalhe.add_theme_constant_override("separation", 4)
	pagina.add_child(detalhe)
	_nome_venda = _rotulo("ESCOLHA UM ITEM DA MOCHILA", 8, COR_TITULO)
	_nome_venda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalhe.add_child(_nome_venda)
	_detalhe_venda = _rotulo("", 7, COR_DETALHE)
	_detalhe_venda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalhe.add_child(_detalhe_venda)
	_legenda_quantidade = _legenda("QUANTIDADE")
	detalhe.add_child(_legenda_quantidade)
	_linha_quantidade = HBoxContainer.new()
	_linha_quantidade.add_theme_constant_override("separation", 2)
	detalhe.add_child(_linha_quantidade)
	for passo in [-10, -1]:
		_linha_quantidade.add_child(_botao(str(passo), _mudar_quantidade.bind(passo)))
	_rotulo_quantidade = _rotulo("", 8, COR_TITULO)
	_rotulo_quantidade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_quantidade.size_flags_horizontal = SIZE_EXPAND_FILL
	_linha_quantidade.add_child(_rotulo_quantidade)
	for passo in [1, 10]:
		_linha_quantidade.add_child(_botao("+" + str(passo), _mudar_quantidade.bind(passo)))
	detalhe.add_child(_legenda("PRECO"))
	var linha_preco := HBoxContainer.new()
	linha_preco.add_theme_constant_override("separation", 2)
	detalhe.add_child(linha_preco)
	for passo in [-10, -1]:
		linha_preco.add_child(_botao(str(passo), _mudar_preco.bind(passo)))
	_preco_venda = _rotulo("", 8, COR_TITULO)
	_preco_venda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preco_venda.size_flags_horizontal = SIZE_EXPAND_FILL
	linha_preco.add_child(_preco_venda)
	for passo in [1, 10]:
		linha_preco.add_child(_botao("+" + str(passo), _mudar_preco.bind(passo)))
	_recebe_venda = _rotulo("", 7, COR_DETALHE)
	_recebe_venda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalhe.add_child(_recebe_venda)
	var linha_acao := HBoxContainer.new()
	linha_acao.add_theme_constant_override("separation", 4)
	_botao_prazo = _botao("", _girar_prazo)
	_botao_prazo.size_flags_horizontal = SIZE_EXPAND_FILL
	linha_acao.add_child(_botao_prazo)
	_anunciar = _botao("ANUNCIAR", _ao_anunciar)
	_anunciar.size_flags_horizontal = SIZE_EXPAND_FILL
	linha_acao.add_child(_anunciar)
	detalhe.add_child(linha_acao)
	return pagina

func _montar_meus() -> Control:
	return _rolagem_com(func(lista: VBoxContainer) -> void: _lista_meus = lista)

func _rolagem_com(guardar: Callable) -> ScrollContainer:
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = SIZE_EXPAND_FILL
	rolagem.follow_focus = true
	var folga := MarginContainer.new()
	folga.size_flags_horizontal = SIZE_EXPAND_FILL
	folga.add_theme_constant_override("margin_right", 8)
	rolagem.add_child(folga)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 4)
	folga.add_child(lista)
	guardar.call(lista)
	return rolagem

# --- Abrir, atualizar e abas ---

func _ao_abrir() -> void:
	if not visible:
		return
	_cliente.preparar(EventosJogo.dono(self))
	_mostrar_saldo()
	_item_venda = null
	_atualizar()

func _atualizar() -> void:
	if _ocupado:
		return
	_ocupado = true
	_estado.text = "CONSULTANDO O MERCADO..."
	await _cliente.atualizar_regras()
	var conferencia: String = await _cliente.reconciliar(EventosJogo.inventario_de(self))
	var correio: Dictionary = await _cliente.retirar_correio(EventosJogo.inventario_de(self))
	_ocupado = false
	if not visible:
		return
	_avisados[_cliente.arquivo] = 0
	var textos: Array = correio["textos"]
	if conferencia != "":
		textos.push_front(conferencia)
	if correio["pendentes"] > 0:
		textos.append("MOCHILA CHEIA: %d ENTREGA(S) AGUARDANDO" % correio["pendentes"])
	_estado.text = " | ".join(PackedStringArray(textos)) if not textos.is_empty() else str(correio["erro"])
	if not _cliente.regras.get("ligado", true):
		_estado.text = Cliente.ERROS["mercado_fechado"]
	_trocar_aba(_aba, not textos.is_empty())

func _trocar_aba(indice: int, manter_estado := false) -> void:
	_aba = indice
	for i in _abas.size():
		_marcar_aba(_abas[i], i == indice)
		_paginas[i].visible = i == indice
	if not manter_estado and not _ocupado:
		_estado.text = ""
	if not visible:
		return
	match indice:
		0: _buscar()
		1: _mostrar_mochila()
		2: _buscar_meus()

## A aba ativa usa o botão primário (verde) do tema: o estilo de aba selecionada some sobre a madeira.
## Substituições explícitas, porque trocar theme_type_variation em tempo de jogo não refaz o fundo do botão.
func _marcar_aba(aba: Button, ativa: bool) -> void:
	var variacao := &"BotaoPrimario" if ativa else &"BotaoAba"
	for estado in ["normal", "hover", "pressed", "hover_pressed"]:
		aba.add_theme_stylebox_override(estado, TEMA.get_stylebox(estado, variacao) if TEMA.has_stylebox(estado, variacao) else TEMA.get_stylebox("normal", variacao))
	for cor in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		if TEMA.has_color(cor, variacao):
			aba.add_theme_color_override(cor, TEMA.get_color(cor, variacao))

func _mostrar_saldo() -> void:
	_saldo.text = "BRASAS: %d" % Progresso.brasas

# --- COMPRAR ---

func _girar_filtro(qual: int) -> void:
	match qual:
		0: _categoria = (_categoria + 1) % CATEGORIAS.size()
		1: _raridade = (_raridade + 2) % (Raridades.ORDEM.size() + 1) - 1
		2: _ordem = (_ordem + 1) % ORDENS.size()
	_filtrar()

func _virar_pagina(passo: int) -> void:
	_pagina = maxi(_pagina + passo, 0)
	_buscar()

func _filtrar() -> void:
	_pagina = 0
	_mostrar_filtros()
	_buscar()

func _mostrar_filtros() -> void:
	_botao_categoria.text = CATEGORIAS[_categoria][1]
	_botao_raridade.text = "TODAS" if _raridade < 0 else Raridades.nome(Raridades.ORDEM[_raridade])
	_botao_ordem.text = ORDENS[_ordem][1]

func _buscar() -> void:
	if _ocupado:
		return
	var filtros := {"ordem": ORDENS[_ordem][0]}
	if CATEGORIAS[_categoria][0] != "":
		filtros["categoria"] = CATEGORIAS[_categoria][0]
	if _raridade >= 0:
		filtros["raridade"] = Raridades.ORDEM[_raridade]
	_ocupado = true
	var r: Dictionary = await _cliente.buscar(filtros, _pagina)
	_ocupado = false
	if not visible or _aba != 0:
		return
	_limpar(_lista_compra)
	if not r["ok"]:
		_estado.text = r["erro"]
		return
	var anuncios: Array = r["dados"].get("anuncios", [])
	if anuncios.is_empty():
		_lista_compra.add_child(_rotulo("NENHUM ANUNCIO ENCONTRADO", 7, COR_DETALHE))
	for anuncio in anuncios:
		var item := DadosItem.de_dict(anuncio.get("item", {}))
		var detalhe := "%s  |  POR %s  |  %s" % [_atributos(item), str(anuncio.get("vendedor", "")), _restante(str(anuncio.get("expira_em", "")))]
		var comprar := _botao("COMPRAR", Callable())
		comprar.pressed.connect(_ao_comprar.bind(anuncio, comprar))
		_lista_compra.add_child(_linha(item, detalhe, "%d BRASAS" % int(anuncio.get("preco", 0)), comprar))
	_anterior.disabled = _pagina == 0
	_proxima.disabled = not bool(r["dados"].get("mais", false))
	_rotulo_pagina.text = "PAGINA %d" % (_pagina + 1)

## Primeiro toque pede confirmação; o segundo compra
func _ao_comprar(anuncio: Dictionary, botao: Button) -> void:
	if _ocupado:
		return
	if not botao.has_meta("confirmar"):
		botao.set_meta("confirmar", true)
		botao.text = "CONFIRMAR?"
		return
	_ocupado = true
	_estado.text = "COMPRANDO..."
	var r: Dictionary = await _cliente.comprar(anuncio, EventosJogo.inventario_de(self))
	_ocupado = false
	if not visible:
		return
	if not r["ok"]:
		_estado.text = r["erro"]
		_buscar()
		return
	_atualizar()

# --- VENDER ---

func _mostrar_mochila() -> void:
	_limpar(_grade_venda)
	var inventario := EventosJogo.inventario_de(self)
	for item in inventario.mochila:
		if item == null or not Cliente.pode_anunciar(item):
			continue
		var botao := Button.new()
		botao.custom_minimum_size = Vector2(28, 28)
		botao.icon = IconesItens.obter(item, get_tree())
		botao.expand_icon = true
		botao.tooltip_text = Cliente.resumo(item)
		botao.add_theme_stylebox_override("normal", EstiloSlot.caixa_raridade(item.raridade))
		botao.pressed.connect(_escolher_item.bind(item))
		if item.empilhavel() and item.quantidade > 1:
			var quantos := _rotulo(str(item.quantidade), 6, Color.WHITE)
			quantos.add_theme_constant_override("outline_size", 3)
			quantos.add_theme_color_override("font_outline_color", Color.BLACK)
			quantos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			quantos.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			quantos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			quantos.offset_right = -2
			quantos.mouse_filter = MOUSE_FILTER_IGNORE
			botao.add_child(quantos)
		_grade_venda.add_child(botao)
	if _grade_venda.get_child_count() == 0:
		_grade_venda.add_child(_rotulo("NADA PARA ANUNCIAR", 7, COR_DETALHE))
	if _item_venda != null and inventario.indice_de(_item_venda) == -1:
		_item_venda = null
	_mostrar_venda()

func _escolher_item(item: DadosItem) -> void:
	_item_venda = item
	_quantidade = item.quantidade if item.empilhavel() else 1
	_mostrar_venda()

func _mudar_quantidade(passo: int) -> void:
	if _item_venda == null:
		return
	_quantidade = clampi(_quantidade + passo, 1, _item_venda.quantidade)
	_mostrar_venda()

func _mudar_preco(passo: int) -> void:
	_preco = clampi(_preco + passo, int(_cliente.regras.get("preco_min", 1)), int(_cliente.regras.get("preco_max", 9999)))
	_mostrar_venda()

func _girar_prazo() -> void:
	_prazo = (_prazo + 1) % maxi(_horas().size(), 1)
	_mostrar_venda()

func _horas() -> Array:
	var horas = _cliente.regras.get("horas", [24, 48])
	return horas if horas is Array and not horas.is_empty() else [24]

func _mostrar_venda() -> void:
	_preco = clampi(_preco, int(_cliente.regras.get("preco_min", 1)), int(_cliente.regras.get("preco_max", 9999)))
	_prazo = clampi(_prazo, 0, _horas().size() - 1)
	_preco_venda.text = "%d BRASAS" % _preco
	_botao_prazo.text = "PRAZO %dH" % int(_horas()[_prazo])
	_nome_venda.text = _item_venda.nome() if _item_venda != null else "ESCOLHA UM ITEM DA MOCHILA"
	var pilha := _item_venda != null and _item_venda.empilhavel() and _item_venda.quantidade > 1
	_linha_quantidade.visible = pilha
	_legenda_quantidade.visible = pilha
	if _item_venda != null:
		_quantidade = clampi(_quantidade, 1, _item_venda.quantidade)
	_rotulo_quantidade.text = "%d DE %d" % [_quantidade, _item_venda.quantidade] if pilha else ""
	_detalhe_venda.text = ("" if _item_venda.empilhavel() else _atributos(_item_venda)) if _item_venda != null else ""
	_recebe_venda.text = "TAXA PARA ANUNCIAR: %d BRASA(S)\nVOCE RECEBE %d SE VENDER (TAXA DE %d%%)" % [
		int(_cliente.regras.get("taxa_anuncio", 0)), _cliente.liquido(_preco), int(_cliente.regras.get("taxa_venda_pct", 0))]
	_anunciar.disabled = _item_venda == null
	_anunciar.text = "ANUNCIAR"
	_anunciar.remove_meta("confirmar")

func _ao_anunciar() -> void:
	if _ocupado or _item_venda == null:
		return
	if not _anunciar.has_meta("confirmar"):
		_anunciar.set_meta("confirmar", true)
		_anunciar.text = "CONFIRMAR?"
		return
	_ocupado = true
	_estado.text = "ANUNCIANDO..."
	var r: Dictionary = await _cliente.anunciar(_item_venda, EventosJogo.inventario_de(self), _preco, int(_horas()[_prazo]), _quantidade)
	_ocupado = false
	if not visible:
		return
	_estado.text = "ANUNCIO PUBLICADO!" if r["ok"] else r["erro"]
	if r["ok"]:
		_item_venda = null
	_mostrar_mochila()

# --- MEUS ANÚNCIOS ---

func _buscar_meus() -> void:
	if _ocupado:
		return
	_ocupado = true
	var r: Dictionary = await _cliente.meus()
	_ocupado = false
	if not visible or _aba != 2:
		return
	_limpar(_lista_meus)
	if not r["ok"]:
		_estado.text = r["erro"]
		return
	if (r["dados"] as Array).is_empty():
		_lista_meus.add_child(_rotulo("VOCE NAO TEM ANUNCIOS", 7, COR_DETALHE))
	for anuncio in r["dados"]:
		var item := DadosItem.de_dict(anuncio.get("item", {}))
		var estado := str(anuncio.get("estado", ""))
		var situacao: String = {"aberto": _restante(str(anuncio.get("expira_em", ""))), "vendido": "VENDIDO",
			"cancelado": "CANCELADO", "expirado": "EXPIRADO"}.get(estado, estado.to_upper())
		var acao: Button = null
		if estado == "aberto":
			acao = _botao("CANCELAR", Callable())
			acao.pressed.connect(_ao_cancelar.bind(int(anuncio.get("id", 0)), acao))
		_lista_meus.add_child(_linha(item, "%s  |  %s" % [_atributos(item), situacao], "%d BRASAS" % int(anuncio.get("preco", 0)), acao))

func _ao_cancelar(anuncio_id: int, botao: Button) -> void:
	if _ocupado:
		return
	if not botao.has_meta("confirmar"):
		botao.set_meta("confirmar", true)
		botao.text = "CONFIRMAR?"
		return
	_ocupado = true
	var r: Dictionary = await _cliente.cancelar(anuncio_id)
	_ocupado = false
	if not visible:
		return
	if not r["ok"]:
		_estado.text = r["erro"]
	_atualizar()

# --- Peças ---

func _linha(item: DadosItem, detalhe: String, preco: String, acao: Button) -> Control:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	var moldura := Panel.new()
	moldura.custom_minimum_size = Vector2(24, 24)
	moldura.add_theme_stylebox_override("panel", EstiloSlot.caixa_raridade(item.raridade))
	linha.add_child(moldura)
	var icone := TextureRect.new()
	icone.texture = IconesItens.obter(item, get_tree())
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.texture_filter = TEXTURE_FILTER_NEAREST
	icone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	moldura.add_child(icone)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 0)
	linha.add_child(textos)
	var nome := _rotulo(Cliente.resumo(item) if item.empilhavel() else item.nome(), 8, item.cor_raridade())
	nome.clip_text = true
	textos.add_child(nome)
	var linha_detalhe := _rotulo(detalhe, 6, COR_DETALHE)
	linha_detalhe.clip_text = true
	textos.add_child(linha_detalhe)
	linha.add_child(_rotulo(preco, 7, COR_TITULO))
	if acao != null:
		acao.add_theme_font_size_override("font_size", 7)
		linha.add_child(acao)
	return linha

func _atributos(item: DadosItem) -> String:
	if item.empilhavel():
		return "x%d" % item.quantidade
	var partes: Array[String] = ["NV %d %s" % [item.nivel, Raridades.nome(item.raridade)]]
	if item.encantamento != "":
		partes.append("%s %d" % [Encantamentos.nome(item.encantamento), item.nivel_encantamento])
	for afixo in item.afixos:
		partes.append(Raridades.nome_afixo(afixo))
	return "  ".join(partes)

## "23H" / "40MIN" até o fim do anúncio (o banco manda a data em UTC)
static func _restante(expira_em: String) -> String:
	if expira_em.length() < 19:
		return ""
	var fim := Time.get_unix_time_from_datetime_string(expira_em.substr(0, 19))
	var segundos := int(fim - Time.get_unix_time_from_system())
	if segundos <= 0:
		return "ENCERRANDO"
	return "%dH" % (segundos / 3600) if segundos >= 3600 else "%dMIN" % maxi(segundos / 60, 1)

func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo

func _botao(texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size.y = _altura_botao()
	if acao.is_valid():
		botao.pressed.connect(acao)
	return botao

func _legenda(texto: String) -> Label:
	return _rotulo(texto, 6, COR_DETALHE)

func _altura_botao() -> float:
	return 32.0 if Controle.usando_toque else 24.0

func _limpar(lista: Container) -> void:
	for filho in lista.get_children():
		lista.remove_child(filho)
		filho.queue_free()

# --- Aviso fora da tela ---

## Entregas novas no correio viram um aviso no HUD do dono (só quando a contagem sobe, para não repetir a cada mapa)
func _verificar_correio() -> void:
	if visible or _ocupado or not Ranking.disponivel() or Introducao.ativa():
		return
	_cliente.preparar(EventosJogo.dono(self))
	var quantas: int = await _cliente.contar_correio()
	if quantas < 0 or visible:
		return
	var antes := int(_avisados.get(_cliente.arquivo, 0))
	_avisados[_cliente.arquivo] = quantas
	if quantas <= antes:
		return
	var hud := get_tree().get_first_node_in_group("hud_p2" if EventosJogo.eh_do_p2(self) else "hud_p1")
	if hud != null and hud.has_method("avisar_mercado"):
		hud.avisar_mercado("MERCADO: %d ENTREGA(S) NO MURAL DA VILA" % quantas)
