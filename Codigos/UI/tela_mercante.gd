extends Control

const IconesItens := preload("res://Codigos/UI/icones_itens.gd")
const Equipamentos := preload("res://Codigos/DadosLocais/Equipamentos.gd")
const Encantamentos := preload("res://Codigos/DadosLocais/encantamentos.gd")

# As fontes pixel do jogo não têm acentos nem "→"; os textos do painel usam ASCII
const NOMES_UPGRADE := {"espada_basica": "ESPADA", "lanca_basica": "LANCA", "escudo_basico": "ESCUDO"}
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
@onready var _rotulo_moedas: Label = %RotuloMoedas
@onready var _botao_iniciar_onda: Button = %BotaoIniciarOnda

func _ready() -> void:
	add_to_group("tela_mercante")
	_aba_encantar.pressed.connect(_mostrar_aba.bind(_painel_encantar))
	_aba_loja.pressed.connect(_mostrar_aba.bind(_painel_loja))
	_aba_bigorna.pressed.connect(_mostrar_aba.bind(_painel_bigorna))
	%BotaoFechar.pressed.connect(_fechar)
	_botao_encantar.pressed.connect(_ao_encantar_pressionado)
	_botao_comprar.pressed.connect(_comprar_item_selecionado)
	_botao_melhorar.pressed.connect(_ao_melhorar_pressionado)
	_botao_iniciar_onda.pressed.connect(_ao_iniciar_onda_pressionado)
	_slot_encantar.item_alterado.connect(_ao_item_encantar_alterado)
	_slot_bigorna.item_alterado.connect(_ao_item_slot_alterado)
	visibility_changed.connect(_ao_visibilidade_alterada)
	_montar_opcoes_encantamento()
	_montar_loja()
	set_process(false)

func _exit_tree() -> void:
	_equipamentos.free()

func _process(_delta: float) -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador == null:
		return
	_botao_iniciar_onda.disabled = not _tem_arma_equipada(jogador)
	_aba_bigorna.disabled = not (jogador.usando_espada or jogador.usando_lanca)

func _ao_visibilidade_alterada() -> void:
	set_process(visible)
	if visible:
		atualizar_exibicao_moedas()
		_aba_encantar.button_pressed = true
		_mostrar_aba(_painel_encantar)
	else:
		_slot_encantar.limpar()
		_slot_bigorna.limpar()

func _mostrar_aba(painel: Control) -> void:
	for aba in [_painel_encantar, _painel_loja, _painel_bigorna]:
		aba.visible = aba == painel
	# Um item só pode estar num slot por vez; a aba escondida devolve o dela
	if painel != _painel_encantar:
		_slot_encantar.limpar()
	if painel != _painel_bigorna:
		_slot_bigorna.limpar()
	if painel == _painel_encantar:
		atualizar_painel_encantar()
	elif painel == _painel_bigorna:
		atualizar_painel_upgrade()
func _tem_arma_equipada(jogador: Node) -> bool:
	return jogador.usando_espada or jogador.usando_lanca or jogador.usando_escudo

func _fechar() -> void:
	EventosJogo.fechar_tela.emit("mercante")

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
	for chave in DadosDosItems.itens.keys():
		var dados: Dictionary = DadosDosItems.obter_dados_item(chave)
		if dados.is_empty():
			continue
		var botao := Button.new()
		botao.theme_type_variation = &"BotaoSlot"
		botao.custom_minimum_size = Vector2(LADO_BOTAO_ITEM, LADO_BOTAO_ITEM)
		# Ícone como filho com recuo: o icon do Button ignora a margem e cobre a moldura
		var icone := TextureRect.new()
		icone.texture = load(dados["icone"])
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icone.offset_left = RECUO_ICONE
		icone.offset_top = RECUO_ICONE
		icone.offset_right = -RECUO_ICONE
		icone.offset_bottom = -RECUO_ICONE
		botao.add_child(icone)
		botao.tooltip_text = String(dados["nome"]).to_upper()
		botao.pressed.connect(_selecionar_item.bind(chave))
		_grade_itens.add_child(botao)

func _selecionar_item(chave: String) -> void:
	_chave_item_selecionado = chave
	_detalhe.visible = true
	_atualizar_detalhe()

func _atualizar_detalhe() -> void:
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

func _comprar_item_selecionado() -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	var dados: Dictionary = DadosDosItems.itens.get(_chave_item_selecionado, {})
	if jogador == null or dados.is_empty():
		return
	var preco: int = dados.get("preco", 0)
	if DadosJogo.moedas < preco:
		return
	jogador.gastar_moedas(preco)
	jogador.aplicar_efeitos_item(dados)
	jogador.itens_comprados.append(dados.duplicate())
	dados["preco"] = int(round(preco * DadosDosItems.FATOR_PRECO_RECOMPRA))
	atualizar_exibicao_moedas()
	get_tree().call_group("tela_inventario", "atualizar_atributos")

# --- Bigorna ---

func _ao_item_slot_alterado(_tem_item: bool) -> void:
	atualizar_painel_upgrade()

func _nivel_atual_do_item(jogador: Node, tipo_item: String) -> int:
	match tipo_item:
		"espada_basica":
			return jogador.nivel_espada
		"lanca_basica":
			return jogador.nivel_lanca
		"escudo_basico":
			return jogador.nivel_escudo
	return 0

# Vazio se não há item válido na bigorna
func _dados_upgrade() -> Dictionary:
	var item: Node = _slot_bigorna.item_atual
	var jogador := IconesItens.obter_jogador(get_tree())
	if item == null or jogador == null or not NOMES_UPGRADE.has(item.obter_tipo_item()):
		return {}
	var tipo_item: String = item.obter_tipo_item()
	var nivel: int = _nivel_atual_do_item(jogador, tipo_item)
	var proximo: Dictionary = _equipamentos.obter_dados_nivel_arma(tipo_item, nivel + 1)
	var gerenciador_ondas := get_tree().get_first_node_in_group("gerenciador_ondas")
	var onda_atual: int = gerenciador_ondas.onda_atual if gerenciador_ondas != null else 0
	var custo: int = proximo.get("custo", 0)
	var onda_necessaria: int = proximo.get("onda_necessaria", 0)
	return {
		"tipo_item": tipo_item,
		"nivel": nivel,
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

	var nome: String = NOMES_UPGRADE[dados["tipo_item"]]
	var nivel: int = dados["nivel"]
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
			atual.get("bonus_defesa", 0), proximo.get("bonus_defesa", 0),
			atual.get("bonus_vitalidade", 0), proximo.get("bonus_vitalidade", 0)]
	else:
		_atributos_upgrade.text = "DANO %d > %d" % [atual.get("dano", 0), proximo.get("dano", 0)]

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
		return
	jogador.gastar_moedas(dados["custo"])
	atualizar_exibicao_moedas()
	jogador.iniciar_forja(dados["tipo_item"])
	_slot_bigorna.limpar()
	await get_tree().create_timer(0.1).timeout
	_fechar()

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
		return
	jogador.gastar_moedas(custo)
	InventarioJogador.encantar(item, _encantamento_escolhido)
	InventarioJogador.salvar()
	atualizar_exibicao_moedas()
	atualizar_painel_encantar()
