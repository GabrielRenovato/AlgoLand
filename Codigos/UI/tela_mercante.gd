extends Control

const IconesItens := preload("res://Codigos/UI/icones_itens.gd")
const Equipamentos := preload("res://Codigos/DadosLocais/Equipamentos.gd")
const Encantamentos := preload("res://Codigos/DadosLocais/encantamentos.gd")
const Raridades := preload("res://Codigos/DadosLocais/raridades.gd")

# As fontes pixel do jogo não têm acentos nem "→"; os textos do painel usam ASCII
const PREFIXO_ARMA_LOJA := "arma:"
const CATEGORIAS_LOJA := {"totens": "TOTENS", "armas": "ARMAS"}
const COR_TEXTO_OK := Color(0.93, 0.9, 0.85)
const COR_TEXTO_BLOQUEADO := Color(1, 0.45, 0.45)
const LADO_BOTAO_ITEM := 30
# Moldura 17.png do pack: 1px transparente + contorno + 2px de borda clara + contorno interno.
# Com recuo menor o ícone cobre parte da borda e, em escala de tela não inteira, ela some de um lado
const RECUO_ICONE := 5
const LADO_AMOSTRA_COR := 6

# Equipamentos é um Node fora da árvore; guardado aqui para liberar em _exit_tree
var _equipamentos := Equipamentos.new()
var _chave_item_selecionado := ""
var _encantamento_escolhido := ""
var _botoes_encantamento: Dictionary = {}
# Botões da grade da loja agrupados por categoria ("totens" ou "armas")
var _botoes_loja: Dictionary = {"totens": [], "armas": []}
var _dica_abas: Label
# Aviso curto (validação) acima das moedas: arma que não serve, moedas que faltam...
var _mensagem: Label
var _tween_mensagem: Tween
# Botão da grade da loja que abriu o detalhe: o B volta para ele saindo do COMPRAR
var _botao_item_loja: Button

@onready var _aba_encantar: Button = %AbaEncantar
@onready var _aba_loja: Button = %AbaLoja
@onready var _aba_bigorna: Button = %AbaBigorna
@onready var _painel_encantar: Control = %Encantar
@onready var _painel_loja: Control = %Loja
@onready var _painel_bigorna: Control = %Bigorna
@onready var _slot_encantar: Control = %SlotEncantar
@onready var _rotulo_arraste_encantar: Label = %RotuloArrasteEncantar
@onready var _info_encantar: Control = %InfoEncantar
@onready var _encantamento_atual: Label = %EncantamentoAtual
@onready var _opcoes_encantamento: GridContainer = %Opcoes
@onready var _descricao_encantamento: Label = %DescricaoEncantamento
@onready var _custo_encantamento: Label = %CustoEncantamento
@onready var _botao_encantar: Button = %BotaoEncantar
@onready var _grade_itens: GridContainer = %GradeItens
@onready var _detalhe: Control = %Detalhe
@onready var _nome_item: Label = %NomeItem
@onready var _descricao_item: Label = %DescricaoItem
@onready var _preco_item: Label = %PrecoItem
@onready var _botao_comprar: Button = %BotaoComprar
@onready var _slot_bigorna: Control = %SlotBigorna
@onready var _rotulo_arraste: Label = %RotuloArraste
@onready var _info_upgrade: Control = %InfoUpgrade
@onready var _titulo_upgrade: Label = %TituloUpgrade
@onready var _atributos_upgrade: Label = %AtributosUpgrade
@onready var _requisitos_upgrade: Label = %RequisitosUpgrade
@onready var _bloqueio_upgrade: Label = %BloqueioUpgrade
@onready var _botao_melhorar: Button = %BotaoMelhorar
@onready var _aba_vender: Button = %AbaVender
@onready var _painel_vender: Control = %Vender
@onready var _slot_venda: Control = %SlotVenda
@onready var _rotulo_vender: Label = %RotuloVender
@onready var _info_venda: Control = %InfoVenda
@onready var _titulo_venda: Label = %TituloVenda
@onready var _detalhe_venda: Label = %DetalheVenda
@onready var _valor_venda: Label = %ValorVenda
@onready var _botao_vender: Button = %BotaoVender
@onready var _rotulo_moedas: Label = %RotuloMoedas
@onready var _botao_iniciar_onda: Button = %BotaoIniciarOnda

func _ready() -> void:
	add_to_group("tela_mercante")
	_aba_encantar.pressed.connect(_mostrar_aba.bind(_painel_encantar))
	_aba_loja.pressed.connect(_mostrar_aba.bind(_painel_loja))
	_aba_bigorna.pressed.connect(_mostrar_aba.bind(_painel_bigorna))
	_aba_vender.pressed.connect(_mostrar_aba.bind(_painel_vender))
	_botao_vender.pressed.connect(_ao_vender_pressionado)
	_botao_vender.set_meta(Sons.META_SOM_PROPRIO, true)
	_slot_venda.item_alterado.connect(_ao_item_venda_alterado)
	_slot_venda.pediu_item.connect(_ao_slot_vazio_confirmado.bind(_slot_venda))
	%BotaoFechar.pressed.connect(_fechar)
	_botao_encantar.pressed.connect(_ao_encantar_pressionado)
	_botao_comprar.pressed.connect(_comprar_item_selecionado)
	_botao_melhorar.pressed.connect(_ao_melhorar_pressionado)
	_botao_iniciar_onda.pressed.connect(_ao_iniciar_onda_pressionado)
	# Comprar, melhorar e encantar têm som próprio (compra/melhoria/erro), no lugar do "confirmar" genérico
	for botao in [_botao_comprar, _botao_melhorar, _botao_encantar]:
		botao.set_meta(Sons.META_SOM_PROPRIO, true)
	_slot_encantar.item_alterado.connect(_ao_item_encantar_alterado)
	_slot_bigorna.item_alterado.connect(_ao_item_slot_alterado)
	_slot_encantar.pediu_item.connect(_ao_slot_vazio_confirmado.bind(_slot_encantar))
	_slot_bigorna.pediu_item.connect(_ao_slot_vazio_confirmado.bind(_slot_bigorna))
	visibility_changed.connect(_ao_visibilidade_alterada)
	_montar_opcoes_encantamento()
	_montar_loja()
	_montar_dica_abas()
	Controle.dicas_alteradas.connect(_atualizar_dicas)
	_atualizar_dicas()
	set_process(false)

func _exit_tree() -> void:
	_equipamentos.free()

func _process(_delta: float) -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador == null:
		return
	_botao_iniciar_onda.disabled = not _tem_arma_equipada(jogador)
	_aba_bigorna.disabled = not (jogador.usando_espada or jogador.usando_lanca or jogador.usando_arco)

func _ao_visibilidade_alterada() -> void:
	set_process(visible)
	if visible:
		atualizar_exibicao_moedas()
		_aba_encantar.button_pressed = true
		_mostrar_aba(_painel_encantar)
	else:
		_slot_encantar.limpar()
		_slot_bigorna.limpar()
		_slot_venda.limpar()

func _mostrar_aba(painel: Control) -> void:
	if _mensagem != null:
		_mensagem.hide()
	for aba in [_painel_encantar, _painel_loja, _painel_bigorna, _painel_vender]:
		aba.visible = aba == painel
	# Um item só pode estar num slot por vez; a aba escondida devolve o dela
	if painel != _painel_encantar:
		_slot_encantar.limpar()
	if painel != _painel_bigorna:
		_slot_bigorna.limpar()
	if painel != _painel_vender:
		_slot_venda.limpar()
	if painel == _painel_encantar:
		atualizar_painel_encantar()
	elif painel == _painel_bigorna:
		atualizar_painel_upgrade()
	elif painel == _painel_vender:
		_atualizar_venda()

func _tem_arma_equipada(jogador: Node) -> bool:
	return jogador.usando_espada or jogador.usando_lanca or jogador.usando_arco or jogador.usando_escudo

func _fechar() -> void:
	EventosJogo.fechar_tela.emit("mercante")

# --- Controle ---

## Chamado pela Interface ao abrir a tela: no controle, o foco começa na primeira aba
func focar_inicio() -> void:
	Controle.focar(_aba_encantar)

## No controle não dá para arrastar: confirmar num item do inventário o coloca na bigorna ou no
## encantamento, se uma dessas abas estiver aberta. Retorna false para o inventário usar o item normalmente
func receber_item_do_controle(origem: Control) -> bool:
	var slot := _slot_que_recebe(origem)
	if slot == null:
		_avisar_recusa(origem)
		return false
	slot.colocar_item(origem)
	return true

## Com BIGORNA ou ENCANTAR aberta, diz por que o item confirmado não foi para o slot
func _avisar_recusa(origem: Control) -> void:
	if not is_visible_in_tree():
		return
	if _painel_bigorna.visible:
		mostrar_mensagem("SO ARMAS E ESCUDO VAO NA BIGORNA")
	elif _painel_vender.visible:
		mostrar_mensagem("SO EQUIPAMENTO DA MOCHILA SE VENDE" if InventarioJogador.indice_de(origem.dados) == -1 else "ISSO NAO SE VENDE")
	elif _painel_encantar.visible:
		var escudo: bool = origem.obter_tipo_item() == "escudo_basico"
		mostrar_mensagem("ESCUDO NAO PODE SER ENCANTADO" if escudo else "SO ARMAS DE ATAQUE PODEM SER ENCANTADAS")

## Confirmar (controle) ou clicar (mouse) no slot vazio da BIGORNA/ENCANTAR: coloca a arma equipada que serve;
## sem ela, leva o foco para a primeira arma que serve na mochila (ou avisa que não há nenhuma)
func _ao_slot_vazio_confirmado(slot: Control) -> void:
	var inventario := get_tree().get_first_node_in_group("tela_inventario")
	if inventario == null:
		return
	var equipado: Control = inventario.item_equipado_que_serve(slot)
	if equipado != null:
		slot.colocar_item(equipado)
		return
	var candidato: Control = inventario.primeiro_slot_que_serve(slot)
	var acao := "ENCANTAR" if slot == _slot_encantar else ("VENDER" if slot == _slot_venda else "MELHORAR")
	if candidato == null:
		mostrar_mensagem("VOCE NAO TEM ARMA PARA %s" % acao)
		return
	if Controle.usando_controle:
		Controle.focar(candidato)
		mostrar_mensagem("ESCOLHA A ARMA E APERTE %s" % Controle.rotulo_acao("ui_accept"))
	else:
		mostrar_mensagem("ARRASTE UMA ARMA DO INVENTARIO")

func mostrar_mensagem(texto: String) -> void:
	if _mensagem == null:
		return
	_mensagem.text = texto
	_mensagem.modulate.a = 1.0
	_mensagem.visible = true
	Sons.tocar("erro")
	if _tween_mensagem:
		_tween_mensagem.kill()
	_tween_mensagem = create_tween()
	_tween_mensagem.tween_interval(2.6)
	_tween_mensagem.tween_property(_mensagem, "modulate:a", 0.0, 0.3)
	_tween_mensagem.tween_callback(_mensagem.hide)

## Para onde o item vai se for confirmado agora ("NA BIGORNA" ou "NO ENCANTO"), ou "" se a tela não o recebe.
## O inventário usa isso para dizer o que o botão faz no item em foco
func destino_do_item(origem: Control) -> String:
	var slot := _slot_que_recebe(origem)
	if slot == _slot_bigorna:
		return "NA BIGORNA"
	if slot == _slot_venda:
		return "PARA VENDER"
	return "NO ENCANTO" if slot == _slot_encantar else ""

func _slot_que_recebe(origem: Control) -> Control:
	if not is_visible_in_tree():
		return null
	for par in [[_painel_bigorna, _slot_bigorna], [_painel_encantar, _slot_encantar], [_painel_vender, _slot_venda]]:
		var painel: Control = par[0]
		var slot: Control = par[1]
		if painel.visible and slot.aceita_item(origem):
			return slot
	return null

# LB/RB (L/R no controle Nintendo; Q/E no teclado) trocam de aba, como nos menus de jogos de console.
# O botão de voltar, saindo do COMPRAR, volta para o item da grade (só fecha a tela quando não há para onde voltar)
func _unhandled_input(evento: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if evento.is_action_pressed("close_menu") and Controle.usando_controle and is_instance_valid(_botao_item_loja) \
			and get_viewport().gui_get_focus_owner() == _botao_comprar:
		_botao_item_loja.grab_focus()
		get_viewport().set_input_as_handled()
		return
	var passo := 0
	if evento.is_action_pressed("ferramenta_anterior"):
		passo = -1
	elif evento.is_action_pressed("ferramenta_proxima"):
		passo = 1
	if passo == 0:
		return
	var abas: Array[Button] = [_aba_encantar, _aba_loja, _aba_bigorna, _aba_vender]
	var atual := 0
	for i in abas.size():
		if abas[i].button_pressed:
			atual = i
	var novo := atual + passo
	while novo >= 0 and novo < abas.size() and abas[novo].disabled:
		novo += passo
	if novo < 0 or novo >= abas.size():
		return
	abas[novo].button_pressed = true
	abas[novo].pressed.emit()
	Controle.focar(abas[novo])
	get_viewport().set_input_as_handled()

# Dica fixa embaixo do painel, só no controle: quais botões trocam de aba
func _montar_dica_abas() -> void:
	_mensagem = Label.new()
	_mensagem.visible = false
	_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mensagem.custom_minimum_size = Vector2(150, 0)
	_mensagem.add_theme_color_override("font_color", COR_TEXTO_BLOQUEADO)
	_botao_iniciar_onda.get_parent().add_child(_mensagem)
	_botao_iniciar_onda.get_parent().move_child(_mensagem, 0)
	_dica_abas = Label.new()
	_dica_abas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica_abas.modulate = Color(1, 1, 1, 0.6)
	_dica_abas.add_theme_font_size_override("font_size", 8)
	_botao_iniciar_onda.get_parent().add_child(_dica_abas)
	_botao_iniciar_onda.get_parent().move_child(_dica_abas, _botao_iniciar_onda.get_index())

# Textos que citam botões ou o mouse mudam com o modo e com o desenho do controle
func _atualizar_dicas() -> void:
	var confirmar := Controle.rotulo_acao("ui_accept")
	if Controle.usando_controle:
		_rotulo_arraste_encantar.text = "NO INVENTARIO, APERTE %s NA ARMA PARA ENCANTAR" % confirmar
		_rotulo_arraste.text = "NO INVENTARIO, APERTE %s NA ARMA PARA COLOCAR NA BIGORNA" % confirmar
	else:
		_rotulo_arraste_encantar.text = "ARRASTE UMA ARMA DO INVENTARIO PARA ENCANTAR"
		_rotulo_arraste.text = "ARRASTE UMA ARMA DO INVENTARIO PARA A BIGORNA"
	_dica_abas.visible = Controle.usando_controle
	_dica_abas.text = "%s / %s  TROCAR ABA" % [Controle.rotulo_acao("ferramenta_anterior"), Controle.rotulo_acao("ferramenta_proxima")]

func _ao_iniciar_onda_pressionado() -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador != null and not _tem_arma_equipada(jogador):
		return
	var gerenciador_ondas := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador_ondas != null:
		gerenciador_ondas.iniciar_onda()
	_fechar()

func atualizar_exibicao_moedas() -> void:
	_rotulo_moedas.text = str(DadosJogo.moedas)
	if _detalhe.visible:
		_atualizar_detalhe()
	if _painel_encantar.visible:
		atualizar_painel_encantar()

# --- Loja ---

func _montar_loja() -> void:
	_montar_abas_loja()
	for chave in DadosDosItems.itens.keys():
		var dados: Dictionary = DadosDosItems.obter_dados_item(chave)
		if dados.is_empty():
			continue
		_adicionar_botao_loja("totens", chave, load(dados["icone"]), String(dados["nome"]).to_upper())
	for tipo in Equipamentos.ARMAS_LOJA:
		_adicionar_botao_loja("armas", PREFIXO_ARMA_LOJA + tipo, IconesItens.obter_arma(tipo, get_tree()), DadosItem.NOMES[tipo])
	_mostrar_categoria_loja("totens")

# Abas TOTENS / ARMAS acima da grade
func _montar_abas_loja() -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 2)
	var grupo := ButtonGroup.new()
	for categoria in CATEGORIAS_LOJA:
		var aba := Button.new()
		aba.theme_type_variation = &"BotaoAba"
		aba.toggle_mode = true
		aba.button_group = grupo
		aba.text = CATEGORIAS_LOJA[categoria]
		aba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		aba.pressed.connect(_mostrar_categoria_loja.bind(categoria))
		aba.button_pressed = categoria == "totens"
		linha.add_child(aba)
	_grade_itens.get_parent().add_child(linha)
	_grade_itens.get_parent().move_child(linha, _grade_itens.get_index())

func _mostrar_categoria_loja(categoria: String) -> void:
	for chave in _botoes_loja:
		for botao in _botoes_loja[chave]:
			botao.visible = chave == categoria
	# O item selecionado pode ser de outra categoria
	_detalhe.visible = false
	_chave_item_selecionado = ""

func _adicionar_botao_loja(categoria: String, chave: String, textura: Texture2D, nome: String) -> void:
	var botao := Button.new()
	botao.theme_type_variation = &"BotaoSlot"
	botao.custom_minimum_size = Vector2(LADO_BOTAO_ITEM, LADO_BOTAO_ITEM)
	# Ícone como filho com recuo: o icon do Button ignora a margem e cobre a moldura
	var icone := TextureRect.new()
	icone.texture = textura
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icone.offset_left = RECUO_ICONE
	icone.offset_top = RECUO_ICONE
	icone.offset_right = -RECUO_ICONE
	icone.offset_bottom = -RECUO_ICONE
	botao.add_child(icone)
	botao.tooltip_text = nome
	botao.pressed.connect(_ao_confirmar_item_loja.bind(chave, botao))
	# No controle não há mouse sobre o item: o detalhe aparece ao focar, e o botão de baixo só compra
	botao.focus_entered.connect(_ao_focar_item_loja.bind(chave))
	_grade_itens.add_child(botao)
	_botoes_loja[categoria].append(botao)

# Mouse: só seleciona e mostra o detalhe. Controle: seleciona e leva o foco direto para COMPRAR (ou avisa o que falta)
func _ao_confirmar_item_loja(chave: String, botao: Button) -> void:
	_selecionar_item(chave)
	if not Controle.usando_controle:
		return
	_botao_item_loja = botao
	if _botao_comprar.disabled:
		mostrar_mensagem("MOEDAS INSUFICIENTES")
		return
	Controle.focar(_botao_comprar)

func _ao_focar_item_loja(chave: String) -> void:
	if Controle.usando_controle:
		_selecionar_item(chave)

func _selecionar_item(chave: String) -> void:
	_chave_item_selecionado = chave
	_detalhe.visible = true
	_atualizar_detalhe()

func _atualizar_detalhe() -> void:
	if _chave_item_selecionado.begins_with(PREFIXO_ARMA_LOJA):
		_atualizar_detalhe_arma(_chave_item_selecionado.trim_prefix(PREFIXO_ARMA_LOJA))
		return
	_botao_comprar.text = "COMPRAR"
	var dados: Dictionary = DadosDosItems.obter_dados_item(_chave_item_selecionado)
	if dados.is_empty():
		_detalhe.visible = false
		return
	_nome_item.text = String(dados["nome"]).to_upper()
	_descricao_item.text = String(dados["descricao"]).to_upper()
	_preco_item.text = str(dados["preco"])
	var pode_comprar: bool = DadosJogo.moedas >= int(dados["preco"])
	_preco_item.modulate = COR_TEXTO_OK if pode_comprar else COR_TEXTO_BLOQUEADO
	_botao_comprar.disabled = not pode_comprar

func _atualizar_detalhe_arma(tipo: String) -> void:
	var definicao: Dictionary = Equipamentos.ARMAS_LOJA[tipo]
	var ja_possui: bool = InventarioJogador.buscar_por_tipo(tipo) != null
	_nome_item.text = DadosItem.NOMES[tipo]
	var tipo_arma := "ARCO DE DUAS MAOS" if definicao.get("duas_maos", false) else "ARMA DE UMA MAO"
	_descricao_item.text = "%s  DANO BASE %d  EVOLUI ATE NV 5" % [tipo_arma, definicao["dano"][0]]
	if int(definicao.get("flechas", 1)) > 1:
		# o arco longo: o dano é de cada flecha
		_descricao_item.text = "%s  %d FLECHAS POR TIRO, MAIS LENTO  DANO BASE %d CADA  EVOLUI ATE NV 5" % [tipo_arma, int(definicao["flechas"]), definicao["dano"][0]]
	_preco_item.text = str(definicao["preco"])
	var pode_comprar: bool = DadosJogo.moedas >= int(definicao["preco"])
	_preco_item.modulate = COR_TEXTO_OK if pode_comprar else COR_TEXTO_BLOQUEADO
	_botao_comprar.text = "COMPRADA" if ja_possui else "COMPRAR"
	_botao_comprar.disabled = ja_possui or not pode_comprar

func _comprar_arma(tipo: String) -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	var preco: int = Equipamentos.ARMAS_LOJA[tipo]["preco"]
	if jogador == null or DadosJogo.moedas < preco or InventarioJogador.buscar_por_tipo(tipo) != null:
		Sons.tocar("erro", 0.0)
		return
	if not InventarioJogador.adicionar_arma_nova(tipo):
		Sons.tocar("erro", 0.0)
		return
	jogador.gastar_moedas(preco)
	Sons.tocar("compra", 0.0)
	InventarioJogador.salvar()
	atualizar_exibicao_moedas()

func _comprar_item_selecionado() -> void:
	if _chave_item_selecionado.begins_with(PREFIXO_ARMA_LOJA):
		_comprar_arma(_chave_item_selecionado.trim_prefix(PREFIXO_ARMA_LOJA))
		return
	var jogador := IconesItens.obter_jogador(get_tree())
	var dados: Dictionary = DadosDosItems.itens.get(_chave_item_selecionado, {})
	if jogador == null or dados.is_empty():
		return
	var preco: int = dados.get("preco", 0)
	if DadosJogo.moedas < preco:
		Sons.tocar("erro", 0.0)
		return
	jogador.gastar_moedas(preco)
	Sons.tocar("compra", 0.0)
	jogador.aplicar_efeitos_item(dados)
	jogador.itens_comprados.append(dados.duplicate())
	dados["preco"] = int(round(preco * DadosDosItems.FATOR_PRECO_RECOMPRA))
	atualizar_exibicao_moedas()
	get_tree().call_group("tela_inventario", "atualizar_atributos")

# --- Bigorna ---

func _ao_item_slot_alterado(_tem_item: bool) -> void:
	atualizar_painel_upgrade()

# Vazio se não há item válido na bigorna
func _dados_upgrade() -> Dictionary:
	var item: Node = _slot_bigorna.item_atual
	var jogador := IconesItens.obter_jogador(get_tree())
	if item == null or jogador == null or not Equipamentos.FAMILIAS.has(item.obter_tipo_item()):
		return {}
	var tipo_item: String = item.obter_tipo_item()
	# O nível e a raridade são do item que está na bigorna (a instância), não do primeiro do mesmo tipo
	var nivel: int = item.dados.nivel
	var raridade: String = item.dados.raridade
	var proximo: Dictionary = _equipamentos.obter_dados_nivel_arma(tipo_item, nivel + 1)
	var gerenciador_ondas := get_tree().get_first_node_in_group("gerenciador_ondas")
	var onda_atual: int = gerenciador_ondas.onda_atual if gerenciador_ondas != null else 0
	var custo: int = proximo.get("custo", 0)
	var onda_necessaria: int = proximo.get("onda_necessaria", 0)
	return {
		"item": item.dados,
		"tipo_item": tipo_item,
		"nivel": nivel,
		"raridade": raridade,
		"atual": _equipamentos.obter_dados_nivel_arma(tipo_item, nivel),
		"proximo": proximo,
		"custo": custo,
		"onda_necessaria": onda_necessaria,
		"onda_atual": onda_atual,
		"onda_ok": onda_atual >= onda_necessaria,
		"moedas_ok": DadosJogo.moedas >= custo,
	}

func atualizar_painel_upgrade() -> void:
	var dados := _dados_upgrade()
	_rotulo_arraste.visible = dados.is_empty()
	_info_upgrade.visible = not dados.is_empty()
	_botao_melhorar.text = "MELHORAR"
	if dados.is_empty():
		_botao_melhorar.disabled = true
		return

	var nome: String = DadosItem.NOMES[dados["tipo_item"]]
	var nivel: int = dados["nivel"]
	var raridade: String = dados["raridade"]
	_titulo_upgrade.add_theme_color_override("font_color", Raridades.cor(raridade))
	var atual: Dictionary = dados["atual"]
	var proximo: Dictionary = dados["proximo"]
	if proximo.is_empty():
		_titulo_upgrade.text = "%s NV %d" % [nome, nivel]
		_atributos_upgrade.text = "NIVEL MAXIMO"
		_requisitos_upgrade.text = ""
		_bloqueio_upgrade.visible = false
		_botao_melhorar.text = "MAXIMO"
		_botao_melhorar.disabled = true
		return

	_titulo_upgrade.text = "%s NV %d > %d" % [nome, nivel, nivel + 1]
	if dados["tipo_item"] == "escudo_basico":
		_atributos_upgrade.text = "DEF %d > %d  VIT %d > %d" % [
			Raridades.escalar(atual.get("bonus_defesa", 0), raridade), Raridades.escalar(proximo.get("bonus_defesa", 0), raridade),
			Raridades.escalar(atual.get("bonus_vitalidade", 0), raridade), Raridades.escalar(proximo.get("bonus_vitalidade", 0), raridade)]
	else:
		_atributos_upgrade.text = "DANO %d > %d" % [Raridades.escalar(atual.get("dano", 0), raridade), Raridades.escalar(proximo.get("dano", 0), raridade)]

	_requisitos_upgrade.text = "CUSTO %d MOEDAS" % dados["custo"]
	_requisitos_upgrade.modulate = COR_TEXTO_OK if dados["moedas_ok"] else COR_TEXTO_BLOQUEADO
	_bloqueio_upgrade.visible = not dados["onda_ok"]
	if not dados["onda_ok"]:
		var faltam: int = dados["onda_necessaria"] - dados["onda_atual"]
		_bloqueio_upgrade.text = "LIBERA NA ONDA %d (FALTA%s %d)" % [dados["onda_necessaria"], "M" if faltam > 1 else "", faltam]
	_botao_melhorar.disabled = not (dados["onda_ok"] and dados["moedas_ok"])

func _ao_melhorar_pressionado() -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	var dados := _dados_upgrade()
	if jogador == null or dados.is_empty() or dados["proximo"].is_empty() or not (dados["onda_ok"] and dados["moedas_ok"]):
		Sons.tocar("erro", 0.0)
		return
	jogador.gastar_moedas(dados["custo"])
	Sons.tocar("melhoria", 0.0)
	atualizar_exibicao_moedas()
	jogador.iniciar_forja(dados["item"])
	_slot_bigorna.limpar()
	await get_tree().create_timer(0.1).timeout
	_fechar()

# --- Vender ---

func _ao_item_venda_alterado(_tem_item: bool) -> void:
	_atualizar_venda()

## O que o mercador paga pelo item do slot de venda
func _valor_do_item_venda() -> int:
	var item: Node = _slot_venda.item_atual
	if item == null or item.dados == null:
		return 0
	return Equipamentos.preco_venda(item.dados.tipo, item.dados.raridade, item.dados.nivel)

func _atualizar_venda() -> void:
	var item: Node = _slot_venda.item_atual
	_rotulo_vender.visible = item == null
	_info_venda.visible = item != null
	_botao_vender.disabled = item == null
	if item == null:
		return
	var dados: DadosItem = item.dados
	_titulo_venda.text = "%s NV %d" % [dados.nome(), dados.nivel]
	_titulo_venda.add_theme_color_override("font_color", dados.cor_raridade())
	var detalhe := dados.nome_raridade()
	for id in dados.afixos:
		detalhe += "  " + Raridades.texto_afixo(id, dados.afixos[id])
	_detalhe_venda.text = detalhe
	_valor_venda.text = "VALE %d MOEDAS" % _valor_do_item_venda()

func _ao_vender_pressionado() -> void:
	var item: Node = _slot_venda.item_atual
	if item == null or item.dados == null or not InventarioJogador.remover_da_mochila(item.dados):
		Sons.tocar("erro", 0.0)
		return
	var valor := _valor_do_item_venda()
	_slot_venda.limpar()
	DadosJogo.adicionar_moedas(valor)
	InventarioJogador.salvar()
	atualizar_exibicao_moedas()
	_atualizar_venda()

# --- Encantar ---

func _montar_opcoes_encantamento() -> void:
	var grupo := ButtonGroup.new()
	for tipo in Encantamentos.TIPOS:
		var botao := Button.new()
		botao.theme_type_variation = &"BotaoAba"
		botao.toggle_mode = true
		botao.button_group = grupo
		botao.text = Encantamentos.nome(tipo)
		botao.icon = _amostra_cor(Encantamentos.cor(tipo))
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.pressed.connect(_escolher_encantamento.bind(tipo))
		_opcoes_encantamento.add_child(botao)
		_botoes_encantamento[tipo] = botao

func _amostra_cor(cor: Color) -> Texture2D:
	var imagem := Image.create(LADO_AMOSTRA_COR, LADO_AMOSTRA_COR, false, Image.FORMAT_RGBA8)
	imagem.fill(Color(0.13, 0.12, 0.18))
	imagem.fill_rect(Rect2i(1, 1, LADO_AMOSTRA_COR - 2, LADO_AMOSTRA_COR - 2), cor)
	return ImageTexture.create_from_image(imagem)

func _ao_item_encantar_alterado(_tem_item: bool) -> void:
	_encantamento_escolhido = ""
	var item = _item_encantar()
	# Já encantada: pré-seleciona o elemento atual para subir de nível
	if item != null and item.encantamento != "":
		_encantamento_escolhido = item.encantamento
	for tipo in _botoes_encantamento:
		_botoes_encantamento[tipo].set_pressed_no_signal(tipo == _encantamento_escolhido)
	atualizar_painel_encantar()

func _escolher_encantamento(tipo: String) -> void:
	_encantamento_escolhido = tipo
	atualizar_painel_encantar()

func _item_encantar():
	var origem: Node = _slot_encantar.item_atual
	if origem == null or not ("dados" in origem):
		return null
	return origem.dados

# Nível que a arma terá depois de encantar com o elemento escolhido
func _proximo_nivel_encantamento(item) -> int:
	return item.nivel_encantamento + 1 if item.encantamento == _encantamento_escolhido else 1

func atualizar_painel_encantar() -> void:
	var item = _item_encantar()
	_rotulo_arraste_encantar.visible = item == null
	_info_encantar.visible = item != null
	if item == null:
		return
	if item.encantamento == "":
		_encantamento_atual.text = "SEM ENCANTAMENTO"
		_encantamento_atual.modulate = COR_TEXTO_OK
	else:
		_encantamento_atual.text = "ATUAL: %s NV %d" % [Encantamentos.nome(item.encantamento), item.nivel_encantamento]
		_encantamento_atual.modulate = Encantamentos.cor(item.encantamento)
	if _encantamento_escolhido == "":
		_descricao_encantamento.text = "ESCOLHA UM ELEMENTO"
		_custo_encantamento.text = ""
		_botao_encantar.text = "ENCANTAR"
		_botao_encantar.disabled = true
		return
	var proximo := _proximo_nivel_encantamento(item)
	if proximo > Encantamentos.NIVEL_MAXIMO:
		_descricao_encantamento.text = Encantamentos.descricao(_encantamento_escolhido, item.nivel_encantamento)
		_custo_encantamento.text = "NIVEL MAXIMO"
		_custo_encantamento.modulate = COR_TEXTO_OK
		_botao_encantar.text = "MAXIMO"
		_botao_encantar.disabled = true
		return
	var custo := Encantamentos.custo(proximo)
	var substitui: bool = item.encantamento != "" and item.encantamento != _encantamento_escolhido
	_descricao_encantamento.text = "NV %d: %s" % [proximo, Encantamentos.descricao(_encantamento_escolhido, proximo)]
	if substitui:
		_descricao_encantamento.text += "\nSUBSTITUI %s" % Encantamentos.nome(item.encantamento)
	var pode := DadosJogo.moedas >= custo
	_custo_encantamento.text = "CUSTO %d MOEDAS" % custo
	_custo_encantamento.modulate = COR_TEXTO_OK if pode else COR_TEXTO_BLOQUEADO
	_botao_encantar.text = "MELHORAR" if proximo > 1 else "ENCANTAR"
	_botao_encantar.disabled = not pode

func _ao_encantar_pressionado() -> void:
	var item = _item_encantar()
	var jogador := IconesItens.obter_jogador(get_tree())
	if item == null or jogador == null or _encantamento_escolhido == "":
		return
	var proximo := _proximo_nivel_encantamento(item)
	var custo := Encantamentos.custo(proximo)
	if proximo > Encantamentos.NIVEL_MAXIMO or DadosJogo.moedas < custo:
		Sons.tocar("erro", 0.0)
		return
	jogador.gastar_moedas(custo)
	Sons.tocar("melhoria", 0.0)
	InventarioJogador.encantar(item, _encantamento_escolhido)
	InventarioJogador.salvar()
	atualizar_exibicao_moedas()
	atualizar_painel_encantar()
