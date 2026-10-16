extends Control

const CENA_SLOT := preload("res://cenas/ui/componentes/slot_ui.tscn")
const IconesItens := preload("res://codigo/ui/icones_itens.gd")
const FONTE_DICA := preload("res://assets/ui/Planes_ValMore.ttf")
const LARGURA_TEXTO_INFO := 90
const GRADE_FOLHA_BONECO := Vector2i(8, 8)
const NOMES_SLOTS_EQUIPAMENTO := ["SlotCabeca", "SlotCorpo", "SlotLuvas", "SlotBotas", "SlotArma", "SlotEscudo", "SlotSecundaria"]
## Anéis e colar ainda não existem no jogo: os quadrados aparecem (com o símbolo apagado), mas não recebem foco nem item
const NOMES_SLOTS_DECORATIVOS := ["SlotAnel1", "SlotAnel2", "SlotColar"]

## A grade da mochila rola quando não cabe mais acima dos atributos (a mochila cresce com as linhas extras)
const LARGURA_BARRA_ROLAGEM := 3
const COR_TRILHO_ROLAGEM := Color("211f30")
const COR_ALCA_ROLAGEM := Color("afbbc3")
const FOLGA_SEPARADOR := 6.0
## Espaço livre abaixo dos atributos até a borda de baixo da tela
const FOLGA_BAIXO := 14.0

var _atualizacao_pendente: bool = false
var _rolagem: ScrollContainer
var _slots_mochila: Array[Control] = []
## Casas que mostram, apagada, a arma/escudo em uso que "ocupa" a casa na barra de baixo (ver EventosJogo.inventario_de(self).celulas_da_mao)
var _fantasmas: Array[Control] = []
var _slots_equipamento: Dictionary = {}
var _info_item: PanelContainer
var _info_linhas: VBoxContainer
var _aba_missoes := false
var _aba_atual := 0
var _desafios: ScrollContainer
var _botoes_abas: Array[Button] = []
var _missoes: ScrollContainer

@onready var _grade: GridContainer = $Sidebar/Painel/Mochila
@onready var _corpo: TextureRect = $Sidebar/Painel/Boneco/Corpo
@onready var _roupa: TextureRect = $Sidebar/Painel/Boneco/Roupa
@onready var _cabelo: TextureRect = $Sidebar/Painel/Boneco/Cabelo
@onready var _atributos: GridContainer = $Sidebar/Atributos

func _ready() -> void:
	add_to_group("tela_inventario")
	$Sidebar/BotaoFechar.pressed.connect(EventosJogo.fechar_tela_de.bind(self, "inventario"))
	_montar_rolagem()
	for i in EventosJogo.inventario_de(self).TAMANHO_MAXIMO:
		var slot: Control = CENA_SLOT.instantiate()
		slot.tipo_slot = "mochila"
		slot.indice = i
		_grade.add_child(slot)
		_slots_mochila.append(slot)
	for nome in NOMES_SLOTS_EQUIPAMENTO:
		var slot: Control = get_node("Sidebar/Painel/" + nome)
		_slots_equipamento[slot.tipo_slot] = slot

	for nome in NOMES_SLOTS_DECORATIVOS:
		var decorativo: Control = get_node("Sidebar/Painel/" + nome)
		decorativo.focus_mode = Control.FOCUS_NONE
		decorativo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_montar_info_item()
	_montar_abas()
	Controle.dicas_alteradas.connect(_atualizar_info_foco)
	EventosJogo.inventario_de(self).mochila_alterada.connect(_agendar_atualizacao)
	EventosJogo.inventario_de(self).equipamento_alterado.connect(_agendar_atualizacao)
	EventosJogo.inventario_de(self).item_alterado.connect(_agendar_atualizacao)
	EventosJogo.inventario_de(self).capacidade_alterada.connect(_agendar_atualizacao)
	visibility_changed.connect(_ao_visibilidade_alterada)
	_atualizar()

## Com loja/baú abertos na metade estreita, reorganiza as casas em quatro colunas.
## Os slots mantêm tamanho e índices; a rolagem mostra o restante da mochila.
func ajustar_largura(largura: float) -> void:
	# A entrada anterior não pode recolocar a largura antiga ao abrir uma loja.
	var animacao: Tween = $Sidebar.get_meta("animacao_entrada") if $Sidebar.has_meta("animacao_entrada") else null
	if animacao != null and animacao.is_valid():
		animacao.kill()
	var compacta := largura < 210.0
	$Sidebar.offset_right = 0.0
	$Sidebar.offset_left = -largura
	$Sidebar.set_meta("offset_entrada", -largura)
	$Sidebar/Painel.position.x = floorf((largura - 112.0) / 2.0)
	$Sidebar/Titulo.text = "MOCHILA" if compacta else "PERSONAGEM"
	_atributos.columns = 1 if compacta else 2
	_atributos.reset_size()
	_grade.columns = 4 if compacta else EventosJogo.inventario_de(self).COLUNAS_MOCHILA
	_grade.reset_size()
	_rolagem.position.x = 11.0 if compacta else -31.0
	_atributos.position.x = 4.0 if compacta else 18.0
	_atributos.size.x = largura - (8.0 if compacta else 36.0)
	$Sidebar/Separador.offset_left = 4.0 if compacta else 14.0
	$Sidebar/Separador.offset_right = largura - (4.0 if compacta else 14.0)
	_posicionar_atributos.call_deferred()

## Chamado pela Interface ao abrir a tela: no controle, o foco começa na arma equipada (ou na mochila)
func focar_inicio() -> void:
	if _aba_atual != 0:
		var painel: ScrollContainer = _missoes if _aba_atual == 1 else _desafios
		var cartao: Control = painel.primeiro_cartao()
		Controle.focar(cartao if cartao != null else _botoes_abas[_aba_atual])
		return
	var inicio: Control = _slots_equipamento.get("arma")
	if inicio == null or inicio.item_atual == null:
		inicio = _slots_mochila[0]
		for slot in _slots_mochila:
			if slot.item_atual != null:
				inicio = slot
				break
	Controle.focar(inicio)

func _ao_visibilidade_alterada() -> void:
	if visible:
		_atualizar()

func _agendar_atualizacao(_ignorado: Variant = null) -> void:
	if _atualizacao_pendente:
		return
	_atualizacao_pendente = true
	_atualizar.call_deferred()

func _atualizar() -> void:
	_atualizacao_pendente = false
	for slot in _fantasmas:
		slot.item_ui().definir_em_uso(false)
	_fantasmas.clear()
	_atualizar_linhas_da_mochila()
	for i in _slots_mochila.size():
		_slots_mochila[i].exibir(EventosJogo.inventario_de(self).mochila[i])
		# a casa da mão: o item em uso aparece apagado, para a grade bater com a barra de baixo (ele se mexe pelo slot de equipamento)
		if EventosJogo.inventario_de(self).mochila[i] == null and EventosJogo.inventario_de(self).item_na_celula(i) != null:
			_slots_mochila[i].exibir(EventosJogo.inventario_de(self).item_na_celula(i))
			_slots_mochila[i].item_ui().definir_em_uso(true)
			_fantasmas.append(_slots_mochila[i])
	for slot in _slots_equipamento:
		_slots_equipamento[slot].exibir(EventosJogo.inventario_de(self).equipados[slot])
	_atualizar_boneco()
	atualizar_atributos()
	_atualizar_info_foco()

## As casas liberadas aparecem normais; a linha seguinte aparece bloqueada (apagada, com o cadeado na última casa e o requisito no mouse);
## o resto fica escondido. Os atributos descem junto com a grade
func _atualizar_linhas_da_mochila() -> void:
	var capacidade: int = EventosJogo.inventario_de(self).capacidade()
	var proxima: int = EventosJogo.inventario_de(self).onda_da_proxima_linha()
	var colunas: int = EventosJogo.inventario_de(self).COLUNAS_MOCHILA
	var fim_trancadas := capacidade + (colunas if proxima != -1 else 0)
	var dica := "VENCA A ONDA %d PARA LIBERAR MAIS %d ESPACOS" % [proxima, colunas]
	for i in _slots_mochila.size():
		var slot: Control = _slots_mochila[i]
		slot.visible = i < fim_trancadas
		slot.definir_trancado(i >= capacidade and i < fim_trancadas, dica, i == fim_trancadas - 1)
	_posicionar_atributos.call_deferred()

## A grade vai para dentro de uma rolagem no mesmo lugar (só a barra vertical, fina, nas cores da moldura do inventário)
func _montar_rolagem() -> void:
	var painel := _grade.get_parent()
	_rolagem = ScrollContainer.new()
	_rolagem.name = "RolagemMochila"
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# no controle, a rolagem acompanha a casa em foco
	_rolagem.follow_focus = true
	_rolagem.position = _grade.position
	painel.add_child(_rolagem)
	painel.move_child(_rolagem, _grade.get_index())
	painel.remove_child(_grade)
	_rolagem.add_child(_grade)
	var barra := _rolagem.get_v_scroll_bar()
	barra.custom_minimum_size.x = LARGURA_BARRA_ROLAGEM
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = COR_TRILHO_ROLAGEM
	var alca := StyleBoxFlat.new()
	alca.bg_color = COR_ALCA_ROLAGEM
	barra.add_theme_stylebox_override("scroll", trilho)
	barra.add_theme_stylebox_override("scroll_focus", trilho)
	for estado in ["grabber", "grabber_highlight", "grabber_pressed"]:
		barra.add_theme_stylebox_override(estado, alca)

## A grade ocupa o que precisa até o espaço que sobra acima dos atributos; passando disso, rola. Separador e atributos ficam logo abaixo
func _posicionar_atributos() -> void:
	var conteudo := _grade.get_combined_minimum_size()
	var topo: float = _rolagem.get_parent().position.y + _rolagem.position.y
	var altura_atributos: float = _atributos.get_combined_minimum_size().y
	var disponivel: float = $Sidebar.size.y - topo - FOLGA_SEPARADOR * 2.0 - altura_atributos - FOLGA_BAIXO
	var altura := minf(conteudo.y, maxf(disponivel, 20.0))
	var rola := altura < conteudo.y
	_rolagem.custom_minimum_size = Vector2(conteudo.x + (LARGURA_BARRA_ROLAGEM + 1 if rola else 0), altura)
	_rolagem.size = _rolagem.custom_minimum_size
	var separador: Control = $Sidebar/Separador
	separador.position.y = topo + altura + FOLGA_SEPARADOR
	_atributos.position.y = separador.position.y + FOLGA_SEPARADOR

# Equipar e comprar mudam as estatísticas do Jogador; espera um frame para ele recalcular
func atualizar_atributos() -> void:
	if not is_node_ready() or not is_inside_tree() or get_tree() == null:
		return
	await get_tree().process_frame
	if not is_inside_tree() or get_tree() == null:
		return
	var jogador := EventosJogo.dono(self)
	if jogador == null:
		return
	var est = jogador.estatisticas
	var valores := [
		["VIDA", "%d/%d" % [jogador.hp_atual, est.hp_maximo]], ["DANO", str(est.dano_ataque)],
		["FOR", str(est.forca)], ["DEF", str(est.defesa)],
		["AGI", str(est.agilidade)], ["VIT", str(est.vitalidade)],
		["INT", str(est.inteligencia)], ["SOR", str(est.sorte)],
	]
	var rotulos := _atributos.get_children()
	if rotulos.size() != valores.size():
		for filho in rotulos:
			filho.free()
		rotulos.clear()
		for i in valores.size():
			var rotulo := Label.new()
			rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_atributos.add_child(rotulo)
			rotulos.append(rotulo)
	for i in valores.size():
		rotulos[i].text = "%s %s" % valores[i]

func _atualizar_boneco() -> void:
	var jogador := EventosJogo.dono(self)
	if jogador == null:
		return
	_corpo.texture = _quadro(jogador.sprite_corpo.texture, 0)
	_roupa.texture = _quadro(jogador.sprite_roupa.texture, 0)
	_cabelo.texture = _quadro(jogador.sprite_cabelo.texture, 0)
	_cabelo.modulate = jogador.cor_cabelo

func _quadro(textura: Texture2D, indice_quadro: int) -> Texture2D:
	if textura == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = textura
	var tamanho := textura.get_size() / Vector2(GRADE_FOLHA_BONECO)
	var celula := Vector2(indice_quadro % GRADE_FOLHA_BONECO.x, indice_quadro / GRADE_FOLHA_BONECO.x)
	atlas.region = Rect2(celula * tamanho, tamanho)
	return atlas

# --- Detalhe do item em foco (controle) ---

# No mouse a dica aparece ao passar por cima; no controle não existe "por cima", então o item em foco
# mostra a mesma dica numa caixa fixa embaixo, com o que o botão de confirmar faz nele
func _montar_info_item() -> void:
	_info_item = PanelContainer.new()
	_info_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_item.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "TooltipPanel"))
	_info_item.visible = false
	$Sidebar.add_child(_info_item)
	# Colada embaixo e crescendo para cima, com a altura que o texto pedir
	_info_item.anchor_left = 0.0
	_info_item.anchor_right = 1.0
	_info_item.anchor_top = 1.0
	_info_item.anchor_bottom = 1.0
	_info_item.offset_left = 14.0
	_info_item.offset_right = -14.0
	_info_item.offset_top = -11.0
	_info_item.offset_bottom = -10.0
	_info_item.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_linhas = VBoxContainer.new()
	_info_linhas.add_theme_constant_override("separation", 0)
	_info_item.add_child(_info_linhas)
	var todos: Array = _slots_mochila + _slots_equipamento.values()
	for slot in todos:
		slot.focus_entered.connect(_atualizar_info_foco)
		slot.focus_exited.connect(_atualizar_info_foco.call_deferred)

func _atualizar_info_foco() -> void:
	if _info_item == null:
		return
	var foco := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var slot: Control = foco if foco != null and $Sidebar.is_ancestor_of(foco) and "item_atual" in foco else null
	if not Controle.usando_controle_de(self) or slot == null or slot.item_atual == null:
		_info_item.visible = false
		return
	for filho in _info_linhas.get_children():
		_info_linhas.remove_child(filho)
		filho.queue_free()
	var dica: Control = slot.item_ui().tooltip_do_item()
	if dica != null:
		_info_linhas.add_child(dica)
	var verbo := _verbo_do_item(slot)
	if verbo != "":
		var acao := Label.new()
		acao.text = "%s %s" % [Controle.rotulo_acao("ui_accept", self), verbo]
		# A caixa tem a largura da barra lateral: o texto quebra em vez de empurrar a caixa para fora
		acao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		acao.custom_minimum_size = Vector2(LARGURA_TEXTO_INFO, 0)
		acao.add_theme_font_override("font", FONTE_DICA)
		acao.add_theme_font_size_override("font_size", 10)
		acao.add_theme_color_override("font_color", Color(0.93, 0.9, 0.85))
		_info_linhas.add_child(acao)
	_info_item.visible = true

# O que confirmar faz no item (a mesma regra de slot_ui._usar_com_controle)
func _verbo_do_item(slot: Control) -> String:
	if slot.item_ui().em_uso:
		return ""
	var mercante := EventosJogo.painel_do_grupo(self, "tela_mercante")
	if mercante != null:
		var destino: String = mercante.destino_do_item(slot.item_ui())
		if destino != "":
			return "COLOCAR " + destino
	if not slot.item_atual.categoria in ["arma", "escudo", "cabeca", "corpo", "luvas", "botas"]:
		return ""
	return "EQUIPAR" if slot.tipo_slot == "mochila" else "DESEQUIPAR"

# --- Ajuda para o ferreiro (BIGORNA/ENCANTAR) ---

## Item (nó do slot) equipado que o slot do ferreiro aceita: arma primeiro, depois escudo; null se não há
func item_equipado_que_serve(destino: Control) -> Control:
	for categoria in ["arma", "escudo"]:
		var slot: Control = _slots_equipamento.get(categoria)
		if slot != null and slot.item_atual != null and not slot.item_ui().em_uso and destino.aceita_item(slot.item_ui()):
			return slot.item_ui()
	return null

## Primeiro slot da mochila com um item que o slot do ferreiro aceita; null se não há
func primeiro_slot_que_serve(destino: Control) -> Control:
	for slot in _slots_mochila:
		if slot.item_atual != null and not slot.item_ui().em_uso and destino.aceita_item(slot.item_ui()):
			return slot
	return null

## As abas pertencem à interface de cada jogador; os pedidos seguem o progresso da partida.
func _montar_abas() -> void:
	$Sidebar/Painel.position.y = 32
	var linha := HBoxContainer.new()
	linha.name = "Abas"
	linha.theme = preload("res://recursos/ui/tema_sidebar.tres")
	$Sidebar.add_child(linha)
	linha.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	linha.offset_left = 6
	linha.offset_right = -6
	linha.offset_top = 14
	linha.offset_bottom = 32
	linha.add_theme_constant_override("separation", 2)
	var grupo := ButtonGroup.new()
	for i in 3:
		var botao := Button.new()
		botao.tooltip_text = ["ITENS", "MISSOES ATIVAS", "DESAFIOS DE ARMAS"] [i]
		botao.custom_minimum_size.y = 18
		var icone := preload("res://codigo/ui/icone_aba_inventario.gd").new()
		icone.tipo = i
		botao.add_child(icone)
		icone.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icone.position = Vector2(-5, -5)
		icone.size = Vector2(10, 10)
		botao.theme_type_variation = &"BotaoAba"
		botao.toggle_mode = true
		botao.button_group = grupo
		botao.button_pressed = i == 0
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.pressed.connect(selecionar_pagina.bind(i))
		linha.add_child(botao)
		_botoes_abas.append(botao)
	_missoes = preload("res://codigo/ui/missoes_inventario.gd").new()
	_missoes.theme = preload("res://recursos/ui/tema_sidebar.tres")
	_missoes.visible = false
	$Sidebar.add_child(_missoes)
	_missoes.offset_top = 38
	_desafios = preload("res://codigo/ui/desafios_inventario.gd").new()
	_desafios.theme = _missoes.theme
	_desafios.visible = false
	$Sidebar.add_child(_desafios)
	_desafios.offset_top = 38
	linha.tooltip_text = "%s / %s: trocar aba" % [Controle.rotulo_acao("ferramenta_anterior", self), Controle.rotulo_acao("ferramenta_proxima", self)]

func selecionar_aba(missoes: bool) -> void:
	selecionar_pagina(1 if missoes else 0)

func selecionar_pagina(indice: int) -> void:
	_aba_atual = clampi(indice, 0, 2)
	_aba_missoes = _aba_atual == 1
	_botoes_abas[_aba_atual].button_pressed = true
	$Sidebar/Painel.visible = _aba_atual == 0
	_atributos.visible = _aba_atual == 0
	$Sidebar/Separador.visible = _aba_atual == 0
	_missoes.visible = _aba_atual == 1
	_desafios.visible = _aba_atual == 2
	_info_item.visible = false

func _unhandled_input(evento: InputEvent) -> void:
	if not is_visible_in_tree() or EventosJogo.interface_de(self)._telas_abertas != ["inventario"]:
		return
	var passo := 0
	if evento.is_action_pressed("ferramenta_anterior"):
		passo = -1
	elif evento.is_action_pressed("ferramenta_proxima"):
		passo = 1
	if passo != 0:
		selecionar_pagina(posmod(_aba_atual + passo, 3))
		Controle.focar(_botoes_abas[_aba_atual])
		get_viewport().set_input_as_handled()
