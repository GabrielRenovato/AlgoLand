extends Control

## Catálogo, encomendas diárias, desafios e coleção do Nilo.
const Desafios := preload("res://codigo/pesca/desafios_pesca.gd")
const Peixes := preload("res://codigo/pesca/peixes.gd")
var _aba := "PEIXES"
var _abas: GridContainer

const CATALOGO := "res://assets/pesca/catalogo.json"
var painel: PanelContainer
var _fechar: Button
var _grade: GridContainer
var _vender: Button
var _resumo: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://recursos/ui/tema_sidebar.tres")
	painel = PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	var moldura := preload("res://codigo/ui/estilo_interface.gd").painel(false, 12.0)
	painel.add_theme_stylebox_override("panel", moldura)
	add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	painel.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	coluna.add_child(cabecalho)
	var vara := preload("res://codigo/ui/retrato_falante.gd").new()
	vara.definir_personagem("nilo")
	vara.texture_filter = TEXTURE_FILTER_NEAREST
	vara.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vara.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vara.custom_minimum_size = Vector2(28, 28)
	cabecalho.add_child(vara)
	var titulo := Label.new()
	titulo.text = "CADERNO DE PESCA"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	_fechar = Button.new()
	_fechar.text = "FECHAR"
	_fechar.pressed.connect(func(): EventosJogo.fechar_tela_de(get_parent(), "guia_pesca"))
	cabecalho.add_child(_fechar)
	var fala := Label.new()
	fala.text = "Peixes por estacao, colecao e desafios.\nNilo refina sua vara na loja do cais, das 8h as 17h."
	fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(fala)
	var venda := HBoxContainer.new()
	coluna.add_child(venda)
	_resumo = Label.new()
	_resumo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resumo.add_theme_font_size_override("font_size", 8)
	venda.add_child(_resumo)
	_vender = Button.new()
	_vender.pressed.connect(_ao_vender)
	venda.add_child(_vender)
	_abas = GridContainer.new()
	coluna.add_child(_abas)
	for nome in ["PEIXES","DESAFIOS","COLECAO"]:
		var botao := Button.new()
		botao.text = nome
		botao.add_theme_font_size_override("font_size",8)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.pressed.connect(_trocar_aba.bind(nome))
		_abas.add_child(botao)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)
	_grade = GridContainer.new()
	_grade.columns = 3
	_grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_grade)
	var conteudo := VBoxContainer.new()
	conteudo.size_flags_horizontal = SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation",8)
	var corpo := ScrollContainer.new()
	corpo.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.follow_focus = true
	corpo.size_flags_vertical = SIZE_EXPAND_FILL
	coluna.add_child(corpo)
	corpo.add_child(conteudo)
	for filho in coluna.get_children():
		if filho != cabecalho and filho != corpo: filho.reparent(conteudo)
	rolagem.size_flags_vertical = SIZE_FILL
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resumo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preencher()
	resized.connect(_ajustar)
	_ajustar()

## Catálogo com quantos o jogador tem na bolsa (x) e já pescou (total); recomposto ao abrir e depois de vender
func _preencher() -> void:
	for filho in _grade.get_children():
		filho.queue_free()
	for botao in _abas.get_children():
		botao.disabled = botao.text == _aba
	_grade.columns = (3 if painel.size.x >= 380 else 2) if _aba == "PEIXES" else 1
	_resumo.text = "BOLSA: %d PEIXES  |  %d/%d ESPECIES" % [Fazenda.total_de_peixes(),Fazenda.peixes_pescados.size(),Peixes.DADOS.size()]
	_vender.visible = false
	if _aba == "PEDIDOS":
		_preencher_pedidos()
		return
	if _aba in ["DESAFIOS","COLECAO"]:
		_preencher_metas()
		return
	var catalogo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGO))
	for id: String in catalogo["peixes"]:
		var peixe: Dictionary = catalogo["peixes"][id]
		var linha := HBoxContainer.new()
		linha.size_flags_horizontal = SIZE_EXPAND_FILL
		linha.custom_minimum_size.y = 32
		_grade.add_child(linha)
		var icone := TextureRect.new()
		icone.texture = load(peixe["icone"])
		icone.texture_filter = TEXTURE_FILTER_NEAREST
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.custom_minimum_size = Vector2(24, 24)
		var pescados := int(Fazenda.peixes_pescados.get(id, 0))
		icone.modulate = Color.WHITE if pescados > 0 else Color(0.35, 0.35, 0.4)
		linha.add_child(icone)
		var nome := Label.new()
		nome.size_flags_horizontal = SIZE_EXPAND_FILL
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var estacoes: Array = Peixes.DADOS[id]["estacoes"]
		var epoca := "ANO TODO" if estacoes.is_empty() else "/".join(estacoes.map(func(e): return Calendario.NOMES[int(e)].substr(0,3)))
		nome.tooltip_text = "%s | %s\nPESCADOS: %d | VENDA: %d BRASAS\nUSOS: VENDA E PRATOS DO CAIO" % [Peixes.raridade(id).to_upper(),epoca,pescados,Peixes.brasas(id)]
		nome.text = "%s\n%s | VARA %d%s" % [peixe["nome"], "Mar" if peixe["ambiente"] == "mar" else "Lago",Peixes.nivel_recomendado(id),
			("  x%d" % Fazenda.quantidade_peixes(id)) if Fazenda.quantidade_peixes(id) > 0 else ""]
		nome.add_theme_font_size_override("font_size", 8)
		linha.add_child(nome)
	var valor := Fazenda.valor_dos_peixes()
	_resumo.text = "PEIXES NA BOLSA: %d  (VALEM %d BRASAS)" % [Fazenda.total_de_peixes(), valor]
	_vender.text = "VENDER TUDO"
	_vender.disabled = valor <= 0

func _trocar_aba(nome: String) -> void:
	_aba = nome
	_preencher()
	_focar_acao.call_deferred()

func _focar_acao() -> void:
	for filho in _grade.get_children():
		if filho is Button and not filho.disabled and not filho.is_queued_for_deletion():
			filho.grab_focus()
			return
	_fechar.grab_focus()

func _texto(texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size",8)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade.add_child(rotulo)

func _acao(texto: String, executar: Callable, bloqueado: bool) -> void:
	var botao := Button.new()
	botao.text = texto
	botao.add_theme_font_size_override("font_size",8)
	botao.disabled = bloqueado
	botao.pressed.connect(func():
		if int(executar.call()) > 0:
			Sons.tocar("compra",0.0)
		_preencher())
	botao.pressed.connect(func(): _focar_acao.call_deferred())
	_grade.add_child(botao)

func _preencher_pedidos() -> void:
	_texto("PEDIDOS DO DIA %d: RENOVAM AO DORMIR. PAGAMENTO 3X A VENDA.\nENTREGAR CONSOME OS PEIXES. VENDER TUDO TAMBEM VENDE INGREDIENTES." % Calendario.dia)
	for pedido in Fazenda.pedidos_pesca():
		var entregue: bool = Fazenda.pesca_pedidos_entregues.has(pedido["id"])
		_texto("%s: %d/%d NA BOLSA | %d BRASAS" % [Peixes.nome(pedido["peixe"]),Fazenda.quantidade_peixes(pedido["peixe"]),pedido["quantidade"],pedido["brasas"]])
		_acao("ENTREGUE" if entregue else "ENTREGAR", Fazenda.entregar_pedido_pesca.bind(pedido["id"]), entregue or Fazenda.quantidade_peixes(pedido["peixe"]) < int(pedido["quantidade"]))

func _preencher_metas() -> void:
	var tabela: Dictionary = Desafios.COLECAO if _aba == "COLECAO" else Desafios.DESAFIOS
	if _aba == "COLECAO":
		_texto("MAR E LAGO, NAS QUATRO ESTACOES. VENDER OU COZINHAR CONSERVA AS DESCOBERTAS.")
	for id in tabela:
		var dados: Dictionary = tabela[id]
		var progresso: int = Fazenda.progresso_desafio_pesca(id)
		var recebido: bool = Fazenda.pesca_recompensas.has(id)
		_texto("%s: %d/%d | %d BRASAS" % [dados["nome"],mini(progresso,int(dados["meta"])),dados["meta"],dados["brasas"]])
		_acao("RECEBIDO" if recebido else "RESGATAR",Fazenda.resgatar_desafio_pesca.bind(id),recebido or progresso < int(dados["meta"]))

func _ao_vender() -> void:
	if Fazenda.vender_peixes() > 0:
		Sons.tocar("compra", 0.0)
	_preencher()

func _ajustar() -> void:
	var largura := minf(460, maxf(180, size.x - 24))
	var altura := minf(294, maxf(180, size.y - 24))
	painel.offset_left = -largura / 2
	painel.offset_right = largura / 2
	painel.offset_top = -altura / 2
	painel.offset_bottom = altura / 2
	_abas.columns = 4 if largura >= 340 else 2
	_grade.columns = (3 if largura >= 380 else 2) if _aba == "PEIXES" else 1

func focar_inicio() -> void:
	_preencher()
	_fechar.grab_focus()
