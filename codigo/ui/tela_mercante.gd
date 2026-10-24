extends Control

const IconesItens := preload("res://codigo/ui/icones_itens.gd")
const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
const Encantamentos := preload("res://codigo/dados/encantamentos.gd")
const Raridades := preload("res://codigo/dados/raridades.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")

# As fontes pixel do jogo não têm acentos nem "→"; os textos do painel usam ASCII
const LojaSementes := preload("res://codigo/dados/loja_sementes.gd")
const IconesFazenda := preload("res://codigo/ui/icones_fazenda.gd")
const PREFIXO_SEMENTE := "semente:"
const CATEGORIAS_LOJA := {"totens": "TOTENS", "sementes": "SEMENTES"}
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
# Botões da grade da loja agrupados por categoria ("totens" ou "sementes")
var _botoes_loja: Dictionary = {"totens": [], "sementes": []}
var _dica_abas: Label
## Aberta de dentro da arena (entre as ondas, sozinha ao vencer uma onda ou pelo portal da arena): abas MELHORIAS (os totens, só eles),
## BIGORNA e ENCANTAR, e um rodapé pequeno com PROXIMA ONDA e CIDADE. Na cidade é o ferreiro de sempre (loja, bigorna, encantar, vender)
var _modo_arena := false
var _conversa_guia: HBoxContainer
var _linha_abas_loja: Control
var _linha_arena: HBoxContainer
var _botao_proxima: Button
var _botao_cidade: Button
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
	# Ganhar ou gastar moeda de forja (drop do chefe, F3) refaz o custo mostrado na hora
	EventosJogo.inventario_de(self).moedas_forja_alteradas.connect(func(_quantidade: int) -> void: atualizar_painel_upgrade())
	# As peças de conjunto sobem de nível na bigorna (ouro + moeda de forja)
	var aceitos: Array[String] = _slot_bigorna.tipos_aceitos.duplicate()
	for conjunto in Conjuntos.CONJUNTOS:
		for tipo in conjunto.TIPOS:
			aceitos.append(tipo)
	_slot_bigorna.tipos_aceitos = aceitos
	_slot_encantar.pediu_item.connect(_ao_slot_vazio_confirmado.bind(_slot_encantar))
	_slot_bigorna.pediu_item.connect(_ao_slot_vazio_confirmado.bind(_slot_bigorna))
	visibility_changed.connect(_ao_visibilidade_alterada)
	_montar_opcoes_encantamento()
	_montar_loja()
	Progresso.brasas_alteradas.connect(func(_valor: int):
		if visible:
			atualizar_exibicao_moedas()
	)
	Calendario.estacao_mudou.connect(func(_estacao: int):
		_atualizar_sementes()
		if visible:
			_aplicar_modo()
	)
	_montar_dica_abas()
	_montar_rodape_arena()
	# Moedas e avanço permanecem no rodapé, enquanto os serviços rolam acima.
	_botao_iniciar_onda.get_parent().reparent($Painel/Linhas)
	_montar_conversa_guia()
	Controle.dicas_alteradas.connect(_atualizar_dicas)
	_atualizar_dicas()
	set_process(false)

func _exit_tree() -> void:
	_equipamentos.free()

func _process(_delta: float) -> void:
	var jogador := EventosJogo.dono(self)
	if jogador == null:
		return
	_botao_iniciar_onda.disabled = not _tem_arma_equipada(jogador)
	_aba_bigorna.disabled = not (jogador.usando_espada or jogador.usando_lanca or jogador.usando_arco)

func _ao_visibilidade_alterada() -> void:
	set_process(visible)
	if visible:
		var cena := Cooperativo.cena_de(self)
		var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
		_modo_arena = gerenciador != null and cena != null and cena.is_ancestor_of(gerenciador)
		_aplicar_modo()
		atualizar_exibicao_moedas()
		var primeira: Button = _aba_loja
		primeira.button_pressed = true
		_mostrar_aba(_painel_loja)
	else:
		_slot_encantar.limpar()
		_slot_bigorna.limpar()
		_slot_venda.limpar()
		if _confirmacao != null:
			_confirmacao.visible = false

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
	EventosJogo.fechar_tela_de(self, "mercante")

# --- Controle ---

## Chamado pela Interface ao abrir a tela: no controle, o foco começa na primeira aba
func focar_inicio() -> void:
	# Volta para a aba aberta (vindo do inventário pelo LB), não sempre para a primeira
	for aba in _aba_encantar.get_parent().get_children():
		if aba is Button and aba.button_pressed and aba.visible and not aba.disabled:
			Controle.focar(aba)
			return
	Controle.focar(_aba_loja)

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
		mostrar_mensagem("SO ARMAS, ESCUDO E PECAS DE CONJUNTO VAO NA BIGORNA")
	elif _painel_vender.visible:
		mostrar_mensagem("SO SEMENTES DA MOCHILA SE VENDEM")
	elif _painel_encantar.visible:
		var escudo: bool = origem.obter_tipo_item() == "escudo_basico"
		mostrar_mensagem("ESCUDO NAO PODE SER ENCANTADO" if escudo else "SO ARMAS DE ATAQUE PODEM SER ENCANTADAS")

## Confirmar (controle) ou clicar (mouse) no slot vazio da BIGORNA/ENCANTAR: coloca o equipado que serve (cada toque passa para o
## próximo: arma, escudo, elmo, peitoral, luvas, botas);
## sem ela, leva o foco para a primeira arma que serve na mochila (ou avisa que não há nenhuma)
func _ao_slot_vazio_confirmado(slot: Control) -> void:
	var inventario := EventosJogo.painel_do_grupo(self, "tela_inventario")
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
	if Controle.usando_controle_de(self):
		Controle.focar(candidato)
		mostrar_mensagem("ESCOLHA A ARMA E APERTE %s" % Controle.rotulo_acao("ui_accept", self))
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
	if evento.is_action_pressed("close_menu") and Controle.usando_controle_de(self) and is_instance_valid(_botao_item_loja) \
			and get_viewport().gui_get_focus_owner() == _botao_comprar:
		_botao_item_loja.grab_focus()
		get_viewport().set_input_as_handled()
		return
	# Com o foco na mochila (aberta ao lado), LB/RB são dela: o LB volta para cá
	var foco_atual := get_viewport().gui_get_focus_owner()
	if foco_atual != null and not is_ancestor_of(foco_atual) and Controle.usando_controle_de(self):
		return
	var passo := 0
	if evento.is_action_pressed("ferramenta_anterior"):
		passo = -1
	elif evento.is_action_pressed("ferramenta_proxima"):
		passo = 1
	if passo == 0:
		return
	var abas: Array[Button] = []
	for filho in _aba_encantar.get_parent().get_children():
		abas.append(filho)
	var atual := 0
	for i in abas.size():
		if abas[i].button_pressed:
			atual = i
	var novo := atual + passo
	while novo >= 0 and novo < abas.size() and (abas[novo].disabled or not abas[novo].visible):
		novo += passo
	if novo >= abas.size() and passo > 0 and Controle.usando_controle_de(self):
		# Depois da última aba, o RB passa para a mochila (que abre ao lado da loja/bigorna); o LB de lá volta
		var interface := EventosJogo.interface_de(self)
		if interface != null and interface._telas_abertas.has("inventario"):
			interface._focar_tela("inventario")
			get_viewport().set_input_as_handled()
		return
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
	var confirmar := Controle.rotulo_acao("ui_accept", self)
	if Controle.usando_controle_de(self):
		_rotulo_arraste_encantar.text = "NO INVENTARIO, APERTE %s NA ARMA PARA ENCANTAR" % confirmar
		_rotulo_arraste.text = "NO INVENTARIO, APERTE %s NA ARMA PARA COLOCAR NA BIGORNA" % confirmar
	else:
		_rotulo_arraste_encantar.text = "ARRASTE UMA ARMA DO INVENTARIO PARA ENCANTAR"
		_rotulo_arraste.text = "ARRASTE UMA ARMA DO INVENTARIO PARA A BIGORNA"
	_dica_abas.visible = Controle.usando_controle_de(self)
	_dica_abas.text = "%s / %s  ABAS  |  %s NA ULTIMA: MOCHILA" % [Controle.rotulo_acao("ferramenta_anterior", self), Controle.rotulo_acao("ferramenta_proxima", self), Controle.rotulo_acao("ferramenta_proxima", self)]

## Arena: MELHORIAS, BIGORNA e ENCANTAR. Na cidade, compra e venda de sementes.
func _aplicar_modo() -> void:
	var abas := _aba_encantar.get_parent()
	abas.columns = 3 if _modo_arena else 2
	for aba in [_aba_loja, _aba_bigorna, _aba_encantar]:
		aba.custom_minimum_size = Vector2(64 if _modo_arena else 0, 24)
		aba.add_theme_font_size_override("font_size", 8 if _modo_arena else 10)
	_grade_itens.columns = 3 if _modo_arena else 5
	_grade_itens.size_flags_horizontal = SIZE_SHRINK_CENTER
	_grade_itens.add_theme_constant_override("h_separation", 6 if _modo_arena else 2)
	_grade_itens.add_theme_constant_override("v_separation", 6 if _modo_arena else 3)
	for botao in _botoes_loja["totens"]:
		botao.custom_minimum_size = Vector2(40,40) if _modo_arena else Vector2(LADO_BOTAO_ITEM,LADO_BOTAO_ITEM)
		botao.size_flags_horizontal = SIZE_FILL
	abas.move_child(_aba_loja, 0 if _modo_arena else 1)
	if _modo_arena:
		abas.move_child(_aba_bigorna, 1)
		abas.move_child(_aba_encantar, 2)
	else:
		abas.move_child(_aba_encantar, 0)
		abas.move_child(_aba_bigorna, 2)
	_aba_loja.text = "MELHORIAS" if _modo_arena else "SEMENTES"
	if _modo_arena:
		var largura_aba := 64.0
		for aba in [_aba_loja,_aba_bigorna,_aba_encantar]:
			largura_aba = maxf(largura_aba,aba.get_minimum_size().x)
		for aba in [_aba_loja,_aba_bigorna,_aba_encantar]:
			aba.custom_minimum_size.x = largura_aba
	_aba_encantar.visible = _modo_arena
	_aba_bigorna.visible = _modo_arena
	_aba_loja.visible = true
	_aba_vender.visible = not _modo_arena
	_aba_vender.disabled = _modo_arena
	_slot_venda.tipos_aceitos.clear()
	for planta in Fazenda.PLANTAS:
		_slot_venda.tipos_aceitos.append(PREFIXO_SEMENTE + planta)
	# Os totens só valem dentro da partida (ouro da onda): na cidade a loja vende sementes da estação, sem as abas TOTENS/ARMAS
	_linha_abas_loja.visible = false
	_mostrar_categoria_loja("totens" if _modo_arena else "sementes")
	_botao_iniciar_onda.visible = not _modo_arena
	_linha_arena.visible = _modo_arena
	_botao_iniciar_onda.text = "IR PARA A ARENA"
	var titulo: Label = $Painel/Linhas/Cabecalho/Titulo
	titulo.label_settings = titulo.label_settings.duplicate()
	titulo.label_settings.font_size = 12 if _modo_arena else 16
	titulo.text = _titulo_arena() if _modo_arena else "VENDA DO TOMAS"
	var cena_guia := Cooperativo.cena_de(self)
	_conversa_guia.visible = _modo_arena and cena_guia!=null and cena_guia.has_node("GuiaDoAndar")
	for icone in [_rotulo_moedas.get_parent().get_node("IconeMoeda"), _preco_item.get_parent().get_node("IconeMoeda")]:
		icone.visible = _modo_arena
	if not _modo_arena and _botoes_loja["sementes"].is_empty():
		_detalhe.visible = true
		_nome_item.text = "INVERNO"
		_descricao_item.text = "NAO HA SEMENTES PARA PLANTAR NESTA ESTACAO."
		_preco_item.text = ""
		_botao_comprar.disabled = true
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if _modo_arena and gerenciador != null:
		_botao_proxima.text = ("ANDAR %d" if gerenciador.is_in_group("gerenciador_andar") else "PROXIMO ANDAR (%d)") % gerenciador.onda_atual
		_botao_proxima.disabled = gerenciador.onda_em_andamento
		if gerenciador.is_in_group("gerenciador_andar"):
			_botao_proxima.custom_minimum_size = Vector2(80,24)
			_botao_cidade.custom_minimum_size = Vector2(80,24)
		var largura_acao := maxf(_botao_cidade.get_combined_minimum_size().x,_botao_proxima.get_combined_minimum_size().x)
		_botao_cidade.custom_minimum_size.x = largura_acao
		_botao_proxima.custom_minimum_size.x = largura_acao

## Título da janela entre as ondas. Depois de uma onda comum o gerenciador já avançou o contador; no estágio bônus a mesma onda espera
func _titulo_arena() -> String:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador == null:
		return "ACAMPAMENTO"
	if gerenciador.is_in_group("gerenciador_andar"):
		return "ANDAR %d CONCLUIDO" % maxi(gerenciador.onda_atual - 1, 1)
	if gerenciador.onda_bonus:
		return "BONUS CONCLUIDO"
	return "ANDAR %d CONCLUIDO" % maxi(gerenciador.onda_atual - 1, 1)

func _montar_conversa_guia() -> void:
	_conversa_guia=HBoxContainer.new()
	_conversa_guia.add_theme_constant_override("separation",8)
	_conversa_guia.name = "ConversaGuia"
	var linhas: VBoxContainer=$Painel/Linhas/Rolagem/Conteudo
	linhas.add_child(_conversa_guia)
	linhas.move_child(_conversa_guia,0)
	var retrato:=TextureRect.new()
	var recorte:=AtlasTexture.new()
	recorte.atlas=preload("res://assets/npcs/fendas/orion.png")
	recorte.region=Rect2(12,2,40,46)
	retrato.texture=recorte
	retrato.custom_minimum_size=Vector2(32,40)
	retrato.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.size_flags_vertical=SIZE_SHRINK_CENTER
	retrato.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_conversa_guia.add_child(retrato)
	var texto:=Label.new()
	texto.text="ORION - GUIA DAS FENDAS\nBom trabalho. Fortaleca-se antes da proxima passagem."
	texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	texto.size_flags_horizontal=SIZE_EXPAND_FILL
	texto.add_theme_font_size_override("font_size",8)
	texto.add_theme_color_override("font_color",Color("e6ca98"))
	texto.size_flags_vertical=SIZE_SHRINK_CENTER
	_conversa_guia.add_child(texto)
	_conversa_guia.hide()

## Rodapé pequeno do modo arena: duas ações lado a lado, sem os botões grandes
func _montar_rodape_arena() -> void:
	_linha_arena = HBoxContainer.new()
	_linha_arena.add_theme_constant_override("separation", 4)
	_linha_arena.visible = false
	_botao_cidade = Button.new()
	_botao_cidade.text = "CIDADE"
	_botao_cidade.custom_minimum_size = Vector2(0, 16)
	_botao_cidade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_botao_cidade.pressed.connect(_ao_voltar_para_cidade)
	_linha_arena.add_child(_botao_cidade)
	_botao_proxima = Button.new()
	_botao_proxima.theme_type_variation = &"BotaoPrimario"
	_botao_proxima.custom_minimum_size = Vector2(0, 16)
	_botao_proxima.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_botao_proxima.pressed.connect(_ao_proxima_onda)
	_linha_arena.add_child(_botao_proxima)
	_botao_iniciar_onda.get_parent().add_child(_linha_arena)

func _ao_proxima_onda() -> void:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador == null or gerenciador.onda_em_andamento:
		return
	_fechar()
	# Cooperativo: a janela do parceiro também fecha (a onda começou para os dois)
	for interface in get_tree().get_nodes_in_group("interface"):
		if interface.has_method("_fechar_tela") and interface._telas_abertas.has("mercante"):
			interface._fechar_tela("mercante")
	gerenciador.iniciar_onda()

## Voltar para a cidade no meio da partida encerra a partida (pedido de 2026-10-16): antes, um aviso pede confirmação.
## Ao confirmar, o desempenho vira Brasas, os totens somem e a próxima entrada começa na onda 1. O equipamento fica
## (só a morte o tira)
var _confirmacao: PanelContainer

func _ao_voltar_para_cidade() -> void:
	if _confirmacao == null:
		_montar_confirmacao()
	_confirmacao.visible = true
	Controle.focar(_confirmacao.find_child("Ficar", true, false))

func _montar_confirmacao() -> void:
	_confirmacao = PanelContainer.new()
	_confirmacao.name = "ConfirmarCidade"
	# Filho do Painel (PanelContainer): cobre a janela inteira por cima das abas
	var moldura: StyleBoxTexture = preload("res://codigo/ui/estilo_slot.gd").moldura_barra().duplicate()
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		moldura.set_content_margin(lado, 8)
	_confirmacao.add_theme_stylebox_override("panel", moldura)
	_confirmacao.visible = false
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirmacao.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "VOLTAR PARA A CIDADE?"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 10)
	titulo.add_theme_color_override("font_color", Color("e7c884"))
	coluna.add_child(titulo)
	var aviso := Label.new()
	aviso.text = "A PARTIDA VAI SE ENCERRAR:\nSUA LUTA VIRA BRASAS, OS TOTENS SOMEM, O SAQUE\nE VENDIDO E A PROXIMA ENTRADA COMECA NO ANDAR 1.\nO EQUIPAMENTO TEMPORARIO DA ARENA E DESCARTADO.\nCONJUNTOS E RECURSOS PERMANENTES FICAM COM VOCE."
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", 8)
	coluna.add_child(aviso)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 4)
	coluna.add_child(linha)
	var ficar := Button.new()
	ficar.name = "Ficar"
	ficar.text = "FICAR"
	ficar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ficar.pressed.connect(func() -> void:
		_confirmacao.visible = false
		Controle.focar(_botao_cidade))
	linha.add_child(ficar)
	var sair := Button.new()
	sair.text = "VOLTAR E ENCERRAR"
	sair.theme_type_variation = &"BotaoPrimario"
	sair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sair.pressed.connect(_confirmar_volta_para_cidade)
	linha.add_child(sair)
	$Painel.add_child(_confirmacao)
	Sons.ligar_botoes(_confirmacao)

func _confirmar_volta_para_cidade() -> void:
	_confirmacao.visible = false
	# O que sobrou no saque é vendido (pelo preço da partida) antes de a partida fechar
	Saque.encerrar(true)
	Cooperativo.encerrar_partida_p2()
	var resultado: Dictionary = Progresso.encerrar_partida()
	InventarioJogador.reiniciar_equipamento_da_partida()
	if Cooperativo.com_dois():
		InventarioJogador2.reiniciar_equipamento_da_partida()
	DadosDosItems.resetar_precos()
	_fechar()
	Transicao.sair_da_arena(true)
	get_tree().call_group("hud", "anunciar", "PARTIDA ENCERRADA", "+%d BRASAS" % int(resultado.get("brasas", 0)), 2.5)

func _ao_iniciar_onda_pressionado() -> void:
	var jogador := EventosJogo.dono(self)
	if jogador != null and not _tem_arma_equipada(jogador):
		return
	# A arena só se alcança pelo portal: a onda começa sozinha na chegada
	_fechar()
	Transicao.entrar_na_arena()

func atualizar_exibicao_moedas() -> void:
	_rotulo_moedas.text = str(EventosJogo.moedas_de(self)) if _modo_arena else "%d BRASAS" % Progresso.brasas
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
	_atualizar_sementes()
	_mostrar_categoria_loja("totens")

func _atualizar_sementes() -> void:
	for botao in _botoes_loja["sementes"]:
		botao.free()
	_botoes_loja["sementes"].clear()
	for planta in Fazenda.plantas_da_estacao(Calendario.estacao()):
		_adicionar_botao_loja("sementes", PREFIXO_SEMENTE + planta, IconesFazenda.saco_de_semente(planta), "SEMENTES DE " + str(Fazenda.PLANTAS[planta]["nome"]))

# Abas de categorias da loja
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
	_linha_abas_loja = linha

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
	if not Controle.usando_controle_de(self):
		return
	_botao_item_loja = botao
	if _botao_comprar.disabled:
		mostrar_mensagem("MOEDAS INSUFICIENTES" if _modo_arena else "BRASAS INSUFICIENTES")
		return
	Controle.focar(_botao_comprar)

func _ao_focar_item_loja(chave: String) -> void:
	if Controle.usando_controle_de(self):
		_selecionar_item(chave)

func _selecionar_item(chave: String) -> void:
	_chave_item_selecionado = chave
	_detalhe.visible = true
	_atualizar_detalhe()

func _atualizar_detalhe() -> void:
	if not _modo_arena and _botoes_loja["sementes"].is_empty():
		return
	if _chave_item_selecionado.begins_with(PREFIXO_SEMENTE):
		_atualizar_detalhe_semente(_chave_item_selecionado.trim_prefix(PREFIXO_SEMENTE))
		return
	_botao_comprar.text = "COMPRAR"
	var dados: Dictionary = DadosDosItems.obter_dados_item(_chave_item_selecionado)
	if dados.is_empty():
		_detalhe.visible = false
		return
	_nome_item.text = String(dados["nome"]).to_upper()
	_descricao_item.text = String(dados["descricao"]).to_upper()
	var preco_totem := DadosDosItems.preco_para(_chave_item_selecionado, EventosJogo.dono(self))
	_preco_item.text = str(preco_totem)
	var pode_comprar: bool = EventosJogo.moedas_de(self) >= preco_totem
	_preco_item.modulate = COR_TEXTO_OK if pode_comprar else COR_TEXTO_BLOQUEADO
	_botao_comprar.disabled = not pode_comprar

func _atualizar_detalhe_semente(planta: String) -> void:
	if not planta in Fazenda.plantas_da_estacao(Calendario.estacao()):
		_detalhe.visible = false
		return
	var dados: Dictionary = Fazenda.PLANTAS[planta]
	_nome_item.text = "SEMENTES DE " + str(dados["nome"])
	_descricao_item.text = "1 SEMENTE. COLHEITA EM %d DIAS REGADOS. SO CRESCE NESTA ESTACAO." % int(dados["dias"])
	var preco := LojaSementes.preco(planta)
	_preco_item.text = "%d BRASAS" % preco
	_botao_comprar.text = "COMPRAR"
	_botao_comprar.disabled = Progresso.brasas < preco
	_preco_item.modulate = COR_TEXTO_BLOQUEADO if _botao_comprar.disabled else COR_TEXTO_OK

func _comprar_item_selecionado() -> void:
	if _chave_item_selecionado.begins_with(PREFIXO_SEMENTE):
		if _modo_arena:
			return
		var erro := LojaSementes.comprar(_chave_item_selecionado.trim_prefix(PREFIXO_SEMENTE), EventosJogo.inventario_de(self), Progresso, Calendario.estacao())
		if erro != "":
			mostrar_mensagem(erro)
			Sons.tocar("erro", 0.0)
		else:
			Sons.tocar("compra", 0.0)
		atualizar_exibicao_moedas()
		return
	var jogador := EventosJogo.dono(self)
	if not _modo_arena or jogador == null or not DadosDosItems.itens.has(_chave_item_selecionado):
		return
	if not DadosDosItems.comprar(_chave_item_selecionado, jogador):
		Sons.tocar("erro", 0.0)
		return
	Sons.tocar("compra", 0.0)
	atualizar_exibicao_moedas()
	get_tree().call_group("tela_inventario", "atualizar_atributos")

# --- Bigorna ---

func _ao_item_slot_alterado(_tem_item: bool) -> void:
	atualizar_painel_upgrade()

# Vazio se não há item válido na bigorna
func _dados_upgrade() -> Dictionary:
	var item: Node = _slot_bigorna.item_atual
	var jogador := EventosJogo.dono(self)
	if item == null or jogador == null:
		return {}
	var tipo_item: String = item.obter_tipo_item()
	var peca_conjunto: bool = Conjuntos.de_tipo(tipo_item) != null
	if not peca_conjunto and not Equipamentos.FAMILIAS.has(tipo_item):
		return {}
	# O nível e a raridade são do item que está na bigorna (a instância), não do primeiro do mesmo tipo
	var nivel: int = item.dados.nivel
	var raridade: String = item.dados.raridade
	var proximo: Dictionary = Equipamentos.dados_melhoria_conjunto(nivel, raridade) if peca_conjunto else _equipamentos.obter_dados_nivel_arma(tipo_item, nivel + 1)
	# Arma ou escudo no último nível: segue com a ascensão de raridade, como as peças de conjunto
	if proximo.is_empty() and not peca_conjunto and nivel >= Equipamentos.NIVEIS_CUSTO.size():
		proximo = Equipamentos.dados_melhoria_conjunto(nivel, raridade)
	var gerenciador_ondas := get_tree().get_first_node_in_group("gerenciador_ondas")
	var onda_atual: int = gerenciador_ondas.onda_atual if gerenciador_ondas != null else int(Transicao.estado.get("onda_atual", Progresso.onda_inicial))
	var custo: int = proximo.get("custo", 0)
	var onda_necessaria: int = proximo.get("onda_necessaria", 0)
	return {
		"item": item.dados,
		"tipo_item": tipo_item,
		"nivel": nivel,
		"raridade": raridade,
		"atual": _equipamentos.obter_dados_nivel_armadura(tipo_item, nivel) if peca_conjunto else _equipamentos.obter_dados_nivel_arma(tipo_item, nivel),
		"conjunto": peca_conjunto,
		"moedas_forja": int(proximo.get("moedas_forja", 0)),
		"proximo": proximo,
		"custo": custo,
		"onda_necessaria": onda_necessaria,
		"onda_atual": onda_atual,
		"onda_ok": onda_atual >= onda_necessaria,
		"moedas_ok": EventosJogo.moedas_de(self) >= custo,
		"forja_ok": EventosJogo.inventario_de(self).moedas_forja >= int(proximo.get("moedas_forja", 0)),
	}

func atualizar_painel_upgrade() -> void:
	var dados := _dados_upgrade()
	_rotulo_arraste.visible = dados.is_empty()
	_info_upgrade.visible = not dados.is_empty()
	_botao_melhorar.text = "MELHORAR"
	if dados.is_empty():
		_botao_melhorar.disabled = true
		return

	var nome: String = dados["item"].nome()
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
	if proximo.get("ascensao", false):
		# Nível 5: sobe a raridade, os status ganham o multiplicador dela e entra um bônus aleatório novo
		var nova: String = proximo["raridade_nova"]
		_titulo_upgrade.text = "%s: %s > %s" % [nome, Raridades.nome(raridade), Raridades.nome(nova)]
		if dados["conjunto"] or dados["tipo_item"] == "escudo_basico":
			_atributos_upgrade.text = "DEF %d > %d  VIT %d > %d\n+1 BONUS ALEATORIO" % [
				Raridades.escalar(atual.get("bonus_defesa", 0), raridade), Raridades.escalar(atual.get("bonus_defesa", 0), nova),
				Raridades.escalar(atual.get("bonus_vitalidade", 0), raridade), Raridades.escalar(atual.get("bonus_vitalidade", 0), nova)]
		else:
			_atributos_upgrade.text = "DANO %d > %d\n+1 BONUS ALEATORIO" % [
				Raridades.escalar(atual.get("dano", 0), raridade), Raridades.escalar(atual.get("dano", 0), nova)]
	elif dados["conjunto"]:
		var proximo_nivel: Dictionary = _equipamentos.obter_dados_nivel_armadura(dados["tipo_item"], nivel + 1)
		_atributos_upgrade.text = "DEF %d > %d  VIT %d > %d" % [
			Raridades.escalar(atual.get("bonus_defesa", 0), raridade), Raridades.escalar(proximo_nivel.get("bonus_defesa", 0), raridade),
			Raridades.escalar(atual.get("bonus_vitalidade", 0), raridade), Raridades.escalar(proximo_nivel.get("bonus_vitalidade", 0), raridade)]
	elif dados["tipo_item"] == "escudo_basico":
		_atributos_upgrade.text = "DEF %d > %d  VIT %d > %d" % [
			Raridades.escalar(atual.get("bonus_defesa", 0), raridade), Raridades.escalar(proximo.get("bonus_defesa", 0), raridade),
			Raridades.escalar(atual.get("bonus_vitalidade", 0), raridade), Raridades.escalar(proximo.get("bonus_vitalidade", 0), raridade)]
	else:
		_atributos_upgrade.text = "DANO %d > %d" % [Raridades.escalar(atual.get("dano", 0), raridade), Raridades.escalar(proximo.get("dano", 0), raridade)]

	_requisitos_upgrade.text = "CUSTO %d MOEDAS" % dados["custo"]
	if dados["moedas_forja"] > 0:
		_requisitos_upgrade.text += "\n+ %d MOEDA DE FORJA (TEM %d)" % [dados["moedas_forja"], EventosJogo.inventario_de(self).moedas_forja]
	_requisitos_upgrade.modulate = COR_TEXTO_OK if dados["moedas_ok"] and dados["forja_ok"] else COR_TEXTO_BLOQUEADO
	_bloqueio_upgrade.visible = not dados["onda_ok"]
	if not dados["onda_ok"]:
		var faltam: int = dados["onda_necessaria"] - dados["onda_atual"]
		_bloqueio_upgrade.text = "LIBERA NO ANDAR %d (FALTA%s %d)" % [dados["onda_necessaria"], "M" if faltam > 1 else "", faltam]
	_botao_melhorar.disabled = not (dados["onda_ok"] and dados["moedas_ok"] and dados["forja_ok"])

func _ao_melhorar_pressionado() -> void:
	var jogador := EventosJogo.dono(self)
	var dados := _dados_upgrade()
	if jogador == null or dados.is_empty() or dados["proximo"].is_empty() or not (dados["onda_ok"] and dados["moedas_ok"] and dados["forja_ok"]):
		Sons.tocar("erro", 0.0)
		return
	if dados["moedas_forja"] > 0 and not EventosJogo.inventario_de(self).gastar_moeda_forja(dados["moedas_forja"]):
		Sons.tocar("erro", 0.0)
		return
	var inventario_ui := EventosJogo.painel_do_grupo(self, "tela_inventario")
	if inventario_ui != null:
		inventario_ui.esquecer_item_puxado()
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
	return LojaSementes.valor_venda(item.dados)

func _atualizar_venda() -> void:
	var item: Node = _slot_venda.item_atual
	_rotulo_vender.visible = item == null
	_info_venda.visible = item != null
	_botao_vender.disabled = item == null
	if item == null:
		return
	var dados: DadosItem = item.dados
	_titulo_venda.text = dados.nome()
	_titulo_venda.add_theme_color_override("font_color", dados.cor_raridade())
	var detalhe := "%d SEMENTE(S) NA PILHA" % dados.quantidade
	_detalhe_venda.text = detalhe
	_valor_venda.text = "VALE %d BRASAS" % _valor_do_item_venda()

func _ao_vender_pressionado() -> void:
	var item: Node = _slot_venda.item_atual
	if _modo_arena or item == null or item.dados == null:
		return
	var dados: DadosItem = item.dados
	_slot_venda.limpar()
	if LojaSementes.vender(dados, EventosJogo.inventario_de(self), Progresso) == 0:
		Sons.tocar("erro", 0.0)
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
	var pode := EventosJogo.moedas_de(self) >= custo
	_custo_encantamento.text = "CUSTO %d MOEDAS" % custo
	_custo_encantamento.modulate = COR_TEXTO_OK if pode else COR_TEXTO_BLOQUEADO
	_botao_encantar.text = "MELHORAR" if proximo > 1 else "ENCANTAR"
	_botao_encantar.disabled = not pode

func _ao_encantar_pressionado() -> void:
	var item = _item_encantar()
	var jogador := EventosJogo.dono(self)
	if item == null or jogador == null or _encantamento_escolhido == "":
		return
	var proximo := _proximo_nivel_encantamento(item)
	var custo := Encantamentos.custo(proximo)
	if proximo > Encantamentos.NIVEL_MAXIMO or EventosJogo.moedas_de(self) < custo:
		Sons.tocar("erro", 0.0)
		return
	jogador.gastar_moedas(custo)
	Sons.tocar("melhoria", 0.0)
	EventosJogo.inventario_de(self).encantar(item, _encantamento_escolhido)
	EventosJogo.inventario_de(self).salvar()
	atualizar_exibicao_moedas()
	atualizar_painel_encantar()
