extends Control

## A barra mostra uma fileira da mochila. A arma selecionada ocupa sua casa;
## escudo e aljava equipados ficam somente nos slots dedicados do inventário.
## Seleção por número, roda, controle ou toque, bloqueada durante ações do jogador.
## Na fazenda a mesma barra seleciona ferramentas e sementes.

const CENA_SLOT := preload("res://cenas/ui/componentes/slot_ui.tscn")
const TEMA := preload("res://recursos/ui/tema_menu.tres")
const IconesItens := preload("res://codigo/ui/icones_itens.gd")
const Raridades := preload("res://codigo/dados/raridades.gd")
const EstiloSlot := preload("res://codigo/ui/estilo_slot.gd")
## O slot do inventário tem 20 unidades e a barra usa ele do MESMO tamanho (sem ampliar: ampliar engrossa a borda e borra o pixel art)
const LADO_SLOT := 20
const ESCALA := 1
## No celular as casas ficam maiores (inteiro), para o dedo
const ESCALA_TOQUE := 2
const ESPACO_ENTRE_CASAS := 2
## Folga em volta da casa para a moldura de seleção
const FOLGA_MARCO := 1
const COR_ATIVA := Color(1, 1, 1, 1)
const COR_ESCUDO := Color(0.55, 0.8, 1.0, 1)
const COR_NOME := Color(1, 0.96, 0.82)
const COR_TECLA := Color(0.75, 0.7, 0.62)
const DURACAO_NOME := 1.8
const COR_AVISO := Color(1, 0.6, 0.5)
const COR_APAGADO := Color(0.5, 0.5, 0.55, 0.8)

## Fazenda: as casas escolhem a ferramenta em vez da arma (definido pelo HUD antes de entrar na árvore)
var modo_fazenda := false
## Fileira da mochila que a barra mostra (como o Tab do Stardew): 0 = primeira. O botão FILEIRA passa para a seguinte
var _fileira := 0
var _pagina_barra := 0
var _celula_sem_arma := -1
var _casas_por_pagina := 8
var _botao_fileira: Button

var _coluna: VBoxContainer
var _nome: Label
var _painel: PanelContainer
var _linha: HBoxContainer
var _casas: Array[Control] = []
var _tween_nome: Tween
## A aproximação usa sempre o lugar original da barra, com folga maior para voltar.
var _no_topo := false

func _ready() -> void:
	theme = TEMA
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_montar()
	resized.connect(_ajustar_paginacao)
	EventosJogo.inventario_de(self).mochila_alterada.connect(_atualizar)
	EventosJogo.inventario_de(self).equipamento_alterado.connect(_ao_equipamento_alterado)
	EventosJogo.inventario_de(self).item_alterado.connect(_ao_item_alterado)
	if modo_fazenda:
		Fazenda.ferramenta_alterada.connect(func(_f: String) -> void: _atualizar(); _mostrar_ferramenta_selecionada())
		Calendario.estacao_mudou.connect(func(_e: int) -> void: _atualizar())
		Fazenda.agua_regador_alterada.connect(func(_q: int) -> void: _atualizar())
	_atualizar()
	_mostrar_ferramenta_selecionada()

## A seleção da fazenda usa o mesmo aviso temporário das armas.
func _mostrar_ferramenta_selecionada() -> void:
	if not modo_fazenda or not is_node_ready(): return
	var texto := ""
	if EventosJogo.inventario_de(self).vara_na_mao:
		texto = "VARA - SEGURE ATAQUE E SOLTE PARA LANCAR"
	else:
		var ferramenta := Fazenda.ferramenta_de(_lado())
		if ferramenta != "": texto = nome_da_ferramenta(ferramenta)
		if ferramenta == "regador": texto += "  %d/%d" % [Fazenda.agua_regador, Fazenda.REGADOR_CAPACIDADE]
	if texto != "": _mostrar_nome(texto,COR_NOME)

func _montar() -> void:
	_coluna = VBoxContainer.new()
	_coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coluna.add_theme_constant_override("separation", 2)
	# Centrada embaixo: as âncoras iguais deixam o tamanho no mínimo e a coluna cresce para cima e para os lados
	_coluna.anchor_left = 0.5
	_coluna.anchor_right = 0.5
	_coluna.anchor_top = 1.0
	_coluna.anchor_bottom = 1.0
	_coluna.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_coluna.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_coluna.offset_top = -5
	_coluna.offset_bottom = -5
	add_child(_coluna)
	_coluna.resized.connect(_posicionar_coluna)
	if not modo_fazenda:
		# Buffs comprados entre os andares: ícones logo acima da barra, com dica no mouse/toque
		var buffs := preload("res://codigo/ui/barra_buffs.gd").new()
		buffs.name = "Buffs"
		_coluna.add_child(buffs)
	_nome = _novo_rotulo(COR_NOME, 10)
	_nome.modulate.a = 0.0
	_nome.hide()
	_coluna.add_child(_nome)
	# A moldura do inventário, recortada da mesma folha de interface, sem a faixa de título (ver EstiloSlot.moldura_barra)
	_painel = PanelContainer.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_painel.add_theme_stylebox_override("panel", EstiloSlot.moldura_barra())
	_coluna.add_child(_painel)
	_linha = HBoxContainer.new()
	_casas_por_pagina = EventosJogo.inventario_de(self).COLUNAS_MOCHILA
	_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linha.alignment = BoxContainer.ALIGNMENT_CENTER
	_linha.add_theme_constant_override("separation", ESPACO_ENTRE_CASAS)
	_painel.add_child(_linha)
	for i in EventosJogo.inventario_de(self).COLUNAS_MOCHILA:
		var casa := _nova_casa(i)
		_linha.add_child(casa)
		_casas.append(casa)
	if Controle.usando_toque:
		# O celular não tem tecla/botão de fileira: um botão ao lado da barra passa para a próxima
		var lado := LADO_SLOT * ESCALA_TOQUE
		_botao_fileira = Button.new()
		_botao_fileira.focus_mode = Control.FOCUS_NONE
		_botao_fileira.custom_minimum_size = Vector2(lado, lado)
		_botao_fileira.add_theme_font_size_override("font_size", 10)
		_botao_fileira.add_to_group("toque_hud")
		_botao_fileira.pressed.connect(proxima_linha)
		_linha.add_child(_botao_fileira)
	_ajustar_paginacao.call_deferred()

func _ajustar_paginacao() -> void:
	if _linha == null: return
	var quantidade := _casas.size()
	if Controle.usando_toque:
		var escala := preload("res://codigo/ui/escala_interface.gd").fator(self)
		var lado := LADO_SLOT * ESCALA_TOQUE
		# Mantém uma fileira embaixo, com espaço para os polegares e o botão de página.
		var combate := preload("res://codigo/ui/escala_interface.gd").escala_combate(get_viewport().get_visible_rect().size)
		var disponivel := size.x - 290 * combate / escala - 16 - lado - ESPACO_ENTRE_CASAS
		quantidade = clampi(floori((disponivel + ESPACO_ENTRE_CASAS) / (lado + ESPACO_ENTRE_CASAS)), 1, _casas.size())
	if quantidade != _casas_por_pagina:
		_casas_por_pagina = quantidade
		_pagina_barra = mini(_pagina_barra, _paginas_por_fileira() - 1)
		_atualizar.call_deferred()
	_posicionar_coluna.call_deferred()

func _process(_delta: float) -> void:
	if _coluna != null: _posicionar_coluna()

func _posicionar_coluna() -> void:
	if not is_inside_tree(): return
	# O nome temporário aumenta o mínimo da coluna; ao sumir, os itens voltam
	# a ocupar só sua altura, sem conservar espaço vazio abaixo da moldura.
	_coluna.reset_size()
	var centro := size.x / 2.0
	if Controle.usando_toque:
		var escala := preload("res://codigo/ui/escala_interface.gd").fator(self)
		var combate := preload("res://codigo/ui/escala_interface.gd").escala_combate(get_viewport().get_visible_rect().size)
		centro -= 40 * combate / escala
	var margens := Controle.margens_seguras()
	var base := Vector2(floorf(centro - _coluna.size.x / 2.0), size.y - _coluna.size.y - 5 - margens.w)
	var jogador := EventosJogo.dono(self) as Node2D
	if jogador != null:
		# Mundo e HUD têm escalas diferentes: compara na mesma coordenada local da barra.
		var pes := jogador.get_global_transform_with_canvas().origin
		var corpo: Rect2 = get_global_transform_with_canvas().affine_inverse() * Rect2(pes + Vector2(-14,-34), Vector2(28,44))
		var alcance := Rect2(base,_coluna.size).grow(42 if _no_topo else 18)
		_no_topo = alcance.intersects(corpo)
	else:
		_no_topo = false
	if _no_topo:
		base.y = 6 + margens.y
		# Reserva os blocos fixos do HUD e suas molduras, inclusive objetivos longos e chefe.
		for nome in ["Status","CantoDireito","ObjetivoPrincipal","PainelChefe"]:
			var bloco := get_parent().get_node_or_null(nome) as Control
			if bloco != null and bloco.is_visible_in_tree():
				base.y = maxf(base.y, bloco.position.y + bloco.size.y + 6)
	_coluna.position = base.round()

func _paginas_por_fileira() -> int:
	return maxi(1,ceili(float(_casas.size()) / maxi(_casas_por_pagina,1)))

func _novo_rotulo(cor: Color, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1))
	rotulo.add_theme_constant_override("outline_size", 3)
	return rotulo

## Uma casa: o mesmo slot do inventário (slot_ui.tscn), no mesmo tamanho, com o número da tecla e a moldura de seleção. Só clicável (não recebe
## foco: o foco do controle e do teclado é das telas)
func _nova_casa(indice: int) -> Control:
	var escala := ESCALA_TOQUE if Controle.usando_toque else ESCALA
	var lado := LADO_SLOT * escala
	var casa := Control.new()
	casa.name = "Casa_%d" % (indice + 1)
	casa.custom_minimum_size = Vector2(lado, lado)
	casa.mouse_filter = Control.MOUSE_FILTER_STOP
	casa.add_to_group("toque_hud")
	casa.gui_input.connect(_ao_casa_tocada.bind(indice))
	var conteudo := Control.new()
	conteudo.name = "Conteudo"
	conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	casa.add_child(conteudo)
	var slot: Control = CENA_SLOT.instantiate()
	slot.name = "Slot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# o slot liga o foco e o mouse no _ready dele: desliga de novo depois (a casa é só da barra)
	slot.ready.connect(_preparar_slot.bind(slot))
	slot.scale = Vector2(escala, escala)
	slot.tipo_slot = "mochila"
	slot.indice = indice
	conteudo.add_child(slot)
	var marco := Panel.new()
	marco.name = "Marco"
	marco.visible = false
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.size = Vector2(lado, lado)
	conteudo.add_child(marco)
	if not Controle.usando_toque:
		# o número fica no canto de cima, pequeno, para não cobrir o ícone
		var numero := _novo_rotulo(COR_TECLA, 6)
		numero.name = "Numero"
		numero.text = str(indice + 1)
		numero.add_theme_constant_override("outline_size", 2)
		numero.position = Vector2(1, -3)
		conteudo.add_child(numero)
	return casa

## A casa da barra não recebe foco nem arrasto: o clique é da casa (escolher), a dica é dela
func _preparar_slot(slot: Control) -> void:
	slot.focus_mode = Control.FOCUS_NONE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.get_node("ItemUi").mouse_filter = Control.MOUSE_FILTER_IGNORE

# --- O que cada casa mostra ------------------------------------------------------------------------------------------

func _ao_equipamento_alterado(slot: String) -> void:
	if slot == "arma" or slot == "escudo":
		_atualizar()

func _ao_item_alterado(_item) -> void:
	_atualizar()

## Índice da casa na mochila para a casa `i` da barra (na fileira que está à mostra)
func _celula(i: int) -> int:
	return _fileira * EventosJogo.inventario_de(self).COLUNAS_MOCHILA + _pagina_barra * _casas_por_pagina + i

func _quantas_linhas() -> int:
	return maxi(floori(float(EventosJogo.inventario_de(self).capacidade()) / EventosJogo.inventario_de(self).COLUNAS_MOCHILA), 1)

## Passa pelas páginas da fileira e pelas fileiras da mochila, dando a volta.
func proxima_linha() -> bool:
	if _quantas_linhas() * _paginas_por_fileira() < 2:
		return false
	_pagina_barra += 1
	if _pagina_barra >= _paginas_por_fileira():
		_pagina_barra = 0
		_fileira = (_fileira + 1) % _quantas_linhas()
	_atualizar()
	Sons.tocar("menu_mover", 0.0, -3.0)
	_mostrar_nome("BARRA %d/%d" % [_fileira * _paginas_por_fileira() + _pagina_barra + 1, _quantas_linhas() * _paginas_por_fileira()], COR_NOME)
	return true

## Refaz as casas a partir da fileira à mostra da mochila (muda ao comprar, pegar, trocar, mover no inventário ou evoluir uma arma)
func _atualizar() -> void:
	if not is_node_ready():
		return
	var jogador := EventosJogo.dono(self)
	if jogador != null and jogador.picareta_arena_ativa and EventosJogo.inventario_de(self).buscar_por_tipo("picareta") == null:
		jogador.picareta_arena_ativa = false
	_fileira = clampi(_fileira, 0, _quantas_linhas() - 1)
	if _botao_fileira != null:
		_botao_fileira.visible = _quantas_linhas() * _paginas_por_fileira() > 1
		_botao_fileira.text = "%d/%d" % [_fileira * _paginas_por_fileira() + _pagina_barra + 1, _quantas_linhas() * _paginas_por_fileira()]
	_ajustar_paginacao()
	for i in _casas.size():
		var casa := _casas[i]
		casa.visible = i < _casas_por_pagina
		if not casa.visible: continue
		var dentro_da_fileira := _pagina_barra * _casas_por_pagina + i < _casas.size()
		var item: DadosItem = EventosJogo.inventario_de(self).item_na_celula(_celula(i)) if dentro_da_fileira else null
		var slot: Control = casa.get_node("Conteudo/Slot")
		slot.indice = _celula(i)
		slot.exibir(item)
		casa.tooltip_text = _texto_da_casa(item)
		var de_fazenda: bool = item != null and (item.categoria == "ferramenta" or item.categoria == "semente" or item.tipo == "produto:feno")
		var pode: bool
		if modo_fazenda:
			# Na fazenda: a ferramenta ativa leva a moldura; arma, escudo e semente fora da estação ficam apagados
			var vara_ativa: bool = EventosJogo.inventario_de(self).vara_na_mao
			_marcar(casa, (de_fazenda and not vara_ativa and item.tipo == Fazenda.ferramenta_de(_lado())) or (item != null and item.categoria == "vara" and vara_ativa), false)
			pode = item == null or item.categoria == "vara" or (de_fazenda and Fazenda.ferramentas(_lado()).has(item.tipo))
		else:
			var em_uso: bool = item != null and EventosJogo.inventario_de(self).slot_de(item) != ""
			var inv = EventosJogo.inventario_de(self)
			_marcar(casa, (em_uso and item.categoria == "arma" and not inv.vara_na_mao) or (item != null and item.categoria == "vara" and inv.vara_na_mao), em_uso and item.categoria == "escudo")
			var dono := EventosJogo.dono(self)
			var picareta: bool = dono != null and dono.picareta_arena_ativa and inv.buscar_por_tipo("picareta") != null
			if picareta: _marcar(casa,item!=null and item.tipo=="picareta",false)
			elif inv.equipados.get("arma") == null and not inv.vara_na_mao:
				_marcar(casa,_celula(i) == _celula_sem_arma,false)
			# Armas indisponiveis e sementes ficam apagadas; a picareta tambem pode ser usada na arena.
			pode = item == null or em_uso or (item.categoria == "vara") or (not de_fazenda and EventosJogo.inventario_de(self).pode_equipar(item))
		pode = pode or (item != null and (item.categoria in ["receita","comida"] or item.tipo == "produto:feno"))
		if not modo_fazenda and item != null and item.tipo=="picareta":
			var dono := EventosJogo.dono(self)
			pode = dono != null and get_tree().get_nodes_in_group("mineracao_arena").any(func(no): return no.get_world_2d()==dono.get_world_2d())
		slot.get_node("ItemUi/Icone").modulate = Color.WHITE if pode else COR_APAGADO
		_mostrar_agua(casa, item)

## Barrinha azul embaixo da casa do regador: quanta água sobrou (enche no lago da fazenda)
func _mostrar_agua(casa: Control, item) -> void:
	var barra := casa.get_node_or_null("AguaRegador") as ColorRect
	var regador: bool = modo_fazenda and item != null and item.tipo == "regador"
	if not regador:
		if barra != null:
			barra.visible = false
		return
	if barra == null:
		barra = ColorRect.new()
		barra.name = "AguaRegador"
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		casa.add_child(barra)
	var fracao := float(Fazenda.agua_regador) / float(Fazenda.REGADOR_CAPACIDADE)
	barra.visible = true
	barra.color = Color(0.4, 0.75, 1.0) if fracao > 0.0 else Color(1.0, 0.4, 0.35)
	var lado: Vector2 = casa.size if casa.size.x > 0 else casa.custom_minimum_size
	barra.position = Vector2(3, lado.y - 4)
	barra.size = Vector2(maxf((lado.x - 6) * fracao, 2.0), 2)

## Dica da casa (mouse): nome, nível e raridade; semente com a quantidade e o tempo de crescimento
func _texto_da_casa(item) -> String:
	if item == null:
		return ""
	if item.empilhavel() and item.categoria != "semente":
		return "%s x%d" % [item.nome(), item.quantidade]
	if item.categoria == "semente":
		return "%s x%d - CRESCE EM %s" % [item.nome(), item.quantidade, Fazenda.texto_crescimento(item.planta())]
	if item.categoria == "ferramenta":
		return item.nome()
	return "%s NV %d %s" % [item.nome(), item.nivel, Raridades.nome(item.raridade)]

## Moldura branca por fora (arma em uso) ou filete azul (escudo em uso)
func _marcar(casa: Control, arma: bool, escudo: bool) -> void:
	var conteudo: Control = casa.get_node("Conteudo")
	var marco: Panel = conteudo.get_node("Marco")
	marco.visible = arma or escudo
	if not (arma or escudo):
		return
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(1, 1, 1, 0.0)
	estilo.set_border_width_all(1)
	estilo.border_color = COR_ATIVA if arma else COR_ESCUDO
	estilo.set_corner_radius_all(3)
	estilo.set_expand_margin_all(FOLGA_MARCO)
	marco.add_theme_stylebox_override("panel", estilo)

# --- Trocar de arma --------------------------------------------------------------------------------------------------

func _ao_casa_tocada(evento: InputEvent, indice: int) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		escolher(indice)
		accept_event()

func _unhandled_input(evento: InputEvent) -> void:
	if Controle.digitando and evento is InputEventKey: return
	if not _pode_trocar():
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and not evento.is_command_or_control_pressed():
		var tecla: int = evento.physical_keycode
		if tecla >= KEY_1 and tecla < KEY_1 + _casas.size():
			if escolher(tecla - KEY_1):
				get_viewport().set_input_as_handled()
			return
	if evento.is_action_pressed("fileira_proxima"):
		if proxima_linha():
			get_viewport().set_input_as_handled()
		return
	# No controle o RB troca a arma na arena; na fazenda o mesmo RB é a próxima ferramenta (plantio.gd)
	if evento.is_action_pressed("arma_proxima") and not (modo_fazenda and evento is InputEventJoypadButton):
		if trocar(1):
			get_viewport().set_input_as_handled()
	elif evento is InputEventMouseButton and evento.pressed and (evento.button_index == MOUSE_BUTTON_WHEEL_UP or evento.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if trocar(-1 if evento.button_index == MOUSE_BUTTON_WHEEL_UP else 1):
			get_viewport().set_input_as_handled()

## Quem pode trocar agora: jogador vivo, solto (sem tela aberta, golpe, esquiva ou ação de fazenda em andamento)
func _pode_trocar() -> bool:
	var jogador := EventosJogo.dono(self)
	if jogador == null or not _coluna.visible:
		return false
	return not bool(jogador.get("estaMorto")) and bool(jogador.get("movimento_habilitado")) and not bool(jogador.get("_esta_atacando")) \
			and not bool(jogador.get("esta_em_dash")) and not bool(jogador.get("esta_sentado")) and not bool(jogador.get("esta_em_acao_fazenda")) \
			and get_viewport().gui_get_focus_owner() == null

## Usa o item da casa `indice` (0-based): arma equipa; escudo equipa ou guarda de novo. Devolve true se mudou algo
func escolher(indice: int) -> bool:
	if indice < 0 or indice >= _casas_por_pagina or _pagina_barra * _casas_por_pagina + indice >= _casas.size() or not _pode_trocar():
		return false
	var item = EventosJogo.inventario_de(self).item_na_celula(_celula(indice))
	var dono_item := EventosJogo.dono(self)
	dono_item.set_meta("item_uso", "produto:feno" if item != null and item.tipo == "produto:feno" else "")
	if item == null:
		return _selecionar_sem_arma(indice) if not modo_fazenda else false
	if item.categoria == "comida":
		var mensagem: String = EventosJogo.inventario_de(self).usar_comida(item)
		Sons.tocar("menu_confirmar" if mensagem.is_empty() else "erro",0.0)
		_mostrar_nome("REFEICAO ATIVA" if mensagem.is_empty() else mensagem,COR_NOME)
		return mensagem.is_empty()
	if item.categoria == "receita":
		var mensagem: String = EventosJogo.inventario_de(self).usar_receita(item)
		Sons.tocar("menu_confirmar" if mensagem == "" else "erro", 0.0)
		_mostrar_nome("RECEITA APRENDIDA" if mensagem == "" else mensagem, COR_NOME)
		return mensagem == ""
	if item.categoria == "vara":
		return _usar_vara(item)
	if modo_fazenda:
		return _escolher_na_fazenda(item)
	var dono := EventosJogo.dono(self)
	if item.tipo == "picareta" and get_tree().get_nodes_in_group("mineracao_arena").any(func(no): return no.get_world_2d()==dono.get_world_2d()):
		if EventosJogo.inventario_de(self).vara_na_mao: EventosJogo.inventario_de(self).definir_vara_na_mao(false)
		dono.picareta_arena_ativa = not dono.picareta_arena_ativa
		_atualizar()
		_mostrar_nome("PICARETA NA MAO" if dono.picareta_arena_ativa else "PICARETA GUARDADA",COR_NOME)
		Sons.tocar("menu_confirmar",0)
		return true
	if item.categoria == "ferramenta" or item.categoria == "semente":
		return _selecionar_sem_arma(indice)
	if item.categoria in ["arma","escudo","vara"] and dono.picareta_arena_ativa:
		dono.picareta_arena_ativa = false
		_atualizar()
		if item == EventosJogo.inventario_de(self).equipados.get("arma"):
			Sons.tocar("menu_confirmar",0)
			return true
	if item.categoria == "vara":
		return _usar_vara(item)
	if item.categoria == "escudo":
		return _usar_escudo(item)
	if item.categoria != "arma":
		return _selecionar_sem_arma(indice)
	if item == EventosJogo.inventario_de(self).equipados.get("arma"):
		# Já é a arma em uso: se a vara estava na mão, só guarda a vara
		if EventosJogo.inventario_de(self).vara_na_mao:
			EventosJogo.inventario_de(self).definir_vara_na_mao(false)
			Sons.tocar("menu_confirmar", 0.0)
			return true
		return false
	# Troca rápida: a arma muda na hora, sem a pose de guardar a anterior e sacar a nova
	var jogador := EventosJogo.dono(self)
	jogador.set("troca_sem_pose", true)
	var equipou: bool = EventosJogo.inventario_de(self).equipar(item)
	jogador.set("troca_sem_pose", false)
	if not equipou:
		Sons.tocar("erro", 0.0)
		_mostrar_nome("%s: NAO DA PARA USAR" % item.nome(), Color(1, 0.6, 0.5))
		return false
	Sons.tocar("menu_confirmar", 0.0)
	_mostrar_nome("%s NV %d" % [item.nome(), item.nivel], item.cor_raridade() if item.raridade != "comum" else COR_NOME)
	return true

## Casas vazias e itens sem ataque guardam a arma anterior, mantendo escudo e aljava nos slots.
func _selecionar_sem_arma(indice: int) -> bool:
	var inv = EventosJogo.inventario_de(self)
	var jogador := EventosJogo.dono(self)
	jogador.troca_sem_pose = true
	var guardou: bool = inv.equipados.get("arma") == null or inv.desequipar("arma")
	jogador.troca_sem_pose = false
	if not guardou: return false
	inv.definir_vara_na_mao(false)
	jogador.picareta_arena_ativa = false
	_celula_sem_arma = _celula(indice)
	_atualizar()
	var item = inv.item_na_celula(_celula(indice))
	_mostrar_nome(item.nome() if item != null else "MAOS VAZIAS",COR_NOME)
	return true

## Fazenda: ferramenta ou semente da estação vira a ferramenta ativa; arma e escudo não fazem nada aqui
func _escolher_na_fazenda(item) -> bool:
	if item.categoria != "ferramenta" and item.categoria != "semente" and item.tipo != "produto:feno":
		return false
	if not Fazenda.ferramentas(_lado()).has(item.tipo):
		Sons.tocar("erro", 0.0)
		mostrar_aviso(Fazenda.MSG_FORA_ESTACAO)
		return false
	EventosJogo.inventario_de(self).definir_vara_na_mao(false)
	if item.tipo != Fazenda.ferramenta_de(_lado()):
		Fazenda.definir_ferramenta(item.tipo, _lado())
		Sons.tocar("menu_mover", 0.0, -3.0)
	_mostrar_nome(nome_da_ferramenta(item.tipo), item.cor_raridade() if item.raridade != "comum" else COR_NOME)
	return true

## Nome da ferramenta para a barra: "ENXADA", "SEMENTE: TOMATE - CRESCE EM 4 DIAS"
static func nome_da_ferramenta(tipo: String) -> String:
	if tipo == "produto:feno": return "FENO - ATAQUE PARA JOGAR NO COMEDOURO"
	if tipo.begins_with(Fazenda.PREFIXO_SEMENTE):
		var id := tipo.trim_prefix(Fazenda.PREFIXO_SEMENTE)
		return "SEMENTE: %s - CRESCE EM %s" % [String(Fazenda.PLANTAS[id]["nome"]), Fazenda.texto_crescimento(id)]
	return String(DadosItem.NOMES.get(tipo, tipo.to_upper()))

## Aviso da fazenda (por que a ferramenta não pôde ser usada), no lugar do nome
func mostrar_aviso(texto: String) -> void:
	_mostrar_nome(texto, COR_AVISO)

## Vara de pesca: escolher a casa dela põe a vara na mão (e escolher de novo guarda); a arma volta ao escolher outra casa
func _usar_vara(vara) -> bool:
	var inventario = EventosJogo.inventario_de(self)
	inventario.definir_vara_na_mao(not inventario.vara_na_mao)
	Sons.tocar("menu_confirmar", 0.0)
	_mostrar_nome("%s NA MAO" % vara.nome() if inventario.vara_na_mao else "VARA GUARDADA", COR_NOME)
	return true

## O escudo sai da barra para o slot dedicado; duas mãos apenas suspendem seu efeito.
func _usar_escudo(escudo) -> bool:
	if escudo == EventosJogo.inventario_de(self).equipados.get("escudo"):
		Sons.tocar("menu_confirmar", 0.0)
		return EventosJogo.inventario_de(self).desequipar("escudo")
	if not EventosJogo.inventario_de(self).equipar(escudo):
		Sons.tocar("erro", 0.0)
		_mostrar_nome("NAO FOI POSSIVEL EQUIPAR O ESCUDO", Color(1, 0.6, 0.5))
		return false
	Sons.tocar("menu_confirmar", 0.0)
	_mostrar_nome("%s NV %d" % [escudo.nome(), escudo.nivel], escudo.cor_raridade() if escudo.raridade != "comum" else COR_NOME)
	return true

## Passa para a arma seguinte (+1) ou anterior (-1) da barra, dando a volta; pula as casas vazias e o escudo.
## Na fazenda passa a ferramenta (a mesma ordem do Q/E)
func trocar(passo: int) -> bool:
	if modo_fazenda:
		if Fazenda.ferramentas(_lado()).size() < 2:
			return false
		EventosJogo.inventario_de(self).definir_vara_na_mao(false)
		Fazenda.trocar_ferramenta(passo, _lado())
		Sons.tocar("menu_mover", 0.0, -3.0)
		_mostrar_nome(nome_da_ferramenta(Fazenda.ferramenta_de(_lado())), COR_NOME)
		return true
	var casas_de_arma: Array[int] = []
	var atual := -1
	for i in mini(_casas_por_pagina, _casas.size() - _pagina_barra * _casas_por_pagina):
		var item = EventosJogo.inventario_de(self).item_na_celula(_celula(i))
		if item != null and (item.categoria == "arma" or item.categoria == "vara"):
			casas_de_arma.append(i)
			var vara_na_mao: bool = EventosJogo.inventario_de(self).vara_na_mao
			if (item.categoria == "vara" and vara_na_mao) or (item == EventosJogo.inventario_de(self).equipados.get("arma") and not vara_na_mao):
				atual = casas_de_arma.size() - 1
	if casas_de_arma.is_empty() or (casas_de_arma.size() == 1 and atual != -1):
		return false
	var destino := posmod((atual if atual != -1 else 0) + passo, casas_de_arma.size())
	return escolher(casas_de_arma[destino])

func _mostrar_nome(texto: String, cor: Color) -> void:
	_nome.show()
	_nome.text = texto
	_nome.add_theme_color_override("font_color", cor)
	if _tween_nome != null and _tween_nome.is_valid():
		_tween_nome.kill()
	_nome.modulate.a = 1.0
	_tween_nome = create_tween()
	_tween_nome.tween_interval(DURACAO_NOME)
	_tween_nome.tween_property(_nome, "modulate:a", 0.0, 0.4)
	_tween_nome.tween_callback(func() -> void: _nome.hide(); _tween_nome = null)

## 1 = jogador 1, 2 = jogador 2 do cooperativo (cada um com a própria ferramenta)
func _lado() -> int:
	return 2 if EventosJogo.eh_do_p2(self) else 1
