extends Control

## Barra de baixo da arena, como a do Stardew Valley: é a PRIMEIRA LINHA DA MOCHILA (as 5 primeiras casas da grade do inventário), no mesmo
## desenho dos slots do inventário (slot_ui.tscn / item_ui.tscn, com a cor da raridade). Quem quiser uma arma ou o escudo na barra põe o item
## na primeira linha do inventário; as outras linhas só aparecem na tela da mochila.
## As casas ficam num painel só, como a barra do Stardew, na moldura da tela do inventário (o mesmo sprite, sem a faixa de título).
## A casa da arma em uso (e a do escudo em uso) continua mostrando o item, como o item na mão do Stardew: o modelo guarda essa casa em
## EventosJogo.inventario_de(self).celulas_da_mao. A arma em uso leva a moldura branca; o escudo em uso, um filete azul.
## Trocar: teclas 1 a 5 (a casa), roda do mouse e Z (ou o botão do controle: a próxima arma da barra) e tocar/clicar na casa. Não troca no
## meio de um golpe, com uma tela aberta nem morto.
## Ao ir para uma arma de duas mãos (lança, arco) o escudo volta para a casa dele; ao voltar para uma de uma mão a barra o põe de novo.
## Na fazenda (modo_fazenda, ligado pelo HUD) é a MESMA barra: escolher a casa de uma ferramenta (enxada, regador, machadinha, picareta) ou de uma semente
## da estação a torna a ferramenta ativa (Fazenda.ferramenta, moldura branca); arma e escudo não fazem nada lá e ficam apagados, como
## ferramentas e sementes na arena. Também mostra os avisos da fazenda (FORA DA AREA DE PLANTIO...).

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

var _coluna: VBoxContainer
var _nome: Label
var _painel: PanelContainer
var _linha: HBoxContainer
var _casas: Array[Control] = []
var _tween_nome: Tween
var _escudo_guardado = null

func _ready() -> void:
	theme = TEMA
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_montar()
	EventosJogo.inventario_de(self).mochila_alterada.connect(_atualizar)
	EventosJogo.inventario_de(self).equipamento_alterado.connect(_ao_equipamento_alterado)
	EventosJogo.inventario_de(self).item_alterado.connect(_ao_item_alterado)
	if modo_fazenda:
		Fazenda.ferramenta_alterada.connect(func(_f: String) -> void: _atualizar(); _nome_fixo())
		Calendario.estacao_mudou.connect(func(_e: int) -> void: _atualizar())
		Fazenda.agua_regador_alterada.connect(func(_q: int) -> void: _atualizar(); _nome_fixo())
	_atualizar()
	_nome_fixo()

## Na fazenda o nome da ferramenta ativa fica sempre acima da barra (no celular é a descrição da semente: o tempo de crescimento)
func _nome_fixo() -> void:
	if not modo_fazenda or not is_node_ready():
		return
	if _tween_nome != null and _tween_nome.is_valid():
		return   # um aviso está na tela: ele mesmo volta ao nome
	_nome.text = nome_da_ferramenta(Fazenda.ferramenta_de(_lado())) if Fazenda.ferramenta_de(_lado()) != "" else ""
	if Fazenda.ferramenta_de(_lado()) == "regador":
		_nome.text += "  %d/%d" % [Fazenda.agua_regador, Fazenda.REGADOR_CAPACIDADE]
	_nome.add_theme_color_override("font_color", COR_NOME)
	_nome.modulate.a = 1.0

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
	_nome = _novo_rotulo(COR_NOME, 10)
	_nome.modulate.a = 0.0
	_coluna.add_child(_nome)
	# A moldura do inventário, recortada da mesma folha de interface, sem a faixa de título (ver EstiloSlot.moldura_barra)
	_painel = PanelContainer.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_painel.add_theme_stylebox_override("panel", EstiloSlot.moldura_barra())
	_coluna.add_child(_painel)
	_linha = HBoxContainer.new()
	_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linha.alignment = BoxContainer.ALIGNMENT_CENTER
	_linha.add_theme_constant_override("separation", ESPACO_ENTRE_CASAS)
	_painel.add_child(_linha)
	for i in EventosJogo.inventario_de(self).COLUNAS_MOCHILA:
		var casa := _nova_casa(i)
		_linha.add_child(casa)
		_casas.append(casa)

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

## Refaz as casas a partir da primeira linha da mochila (muda ao comprar, pegar, trocar, mover no inventário ou evoluir uma arma)
func _atualizar() -> void:
	if not is_node_ready():
		return
	for i in _casas.size():
		var item: DadosItem = EventosJogo.inventario_de(self).item_na_celula(i)
		var casa := _casas[i]
		var slot: Control = casa.get_node("Conteudo/Slot")
		slot.exibir(item)
		casa.tooltip_text = _texto_da_casa(item)
		var de_fazenda: bool = item != null and (item.categoria == "ferramenta" or item.categoria == "semente")
		var pode: bool
		if modo_fazenda:
			# Na fazenda: a ferramenta ativa leva a moldura; arma, escudo e semente fora da estação ficam apagados
			_marcar(casa, de_fazenda and item.tipo == Fazenda.ferramenta_de(_lado()), false)
			pode = item == null or (de_fazenda and Fazenda.ferramentas(_lado()).has(item.tipo))
		else:
			var em_uso: bool = item != null and EventosJogo.inventario_de(self).slot_de(item) != ""
			_marcar(casa, em_uso and item.categoria == "arma", em_uso and item.categoria == "escudo")
			# a arma que não dá para usar agora (arco sem aljava...) fica apagada; ferramenta e semente só servem na fazenda
			pode = item == null or em_uso or (not de_fazenda and EventosJogo.inventario_de(self).pode_equipar(item))
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
	if not _pode_trocar():
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and not evento.is_command_or_control_pressed():
		var tecla: int = evento.physical_keycode
		if tecla >= KEY_1 and tecla < KEY_1 + _casas.size():
			if escolher(tecla - KEY_1):
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
	if indice < 0 or indice >= _casas.size() or not _pode_trocar():
		return false
	var item = EventosJogo.inventario_de(self).item_na_celula(indice)
	if item == null:
		return false
	if modo_fazenda:
		return _escolher_na_fazenda(item)
	if item.categoria == "ferramenta" or item.categoria == "semente":
		return false
	if item.categoria == "escudo":
		return _usar_escudo(item)
	if item.categoria != "arma" or item == EventosJogo.inventario_de(self).equipados.get("arma"):
		return false
	var escudo_antes = EventosJogo.inventario_de(self).equipados.get("escudo")
	# Troca rápida: a arma muda na hora, sem a pose de guardar a anterior e sacar a nova
	var jogador := EventosJogo.dono(self)
	jogador.set("troca_sem_pose", true)
	var equipou: bool = EventosJogo.inventario_de(self).equipar(item)
	if equipou:
		# Duas mãos tira o escudo; uma mão devolve o que ficou guardado
		if item.duas_maos and escudo_antes != null:
			_escudo_guardado = escudo_antes
		elif not item.duas_maos and _escudo_guardado != null and EventosJogo.inventario_de(self).equipados.get("escudo") == null \
				and EventosJogo.inventario_de(self).indice_de(_escudo_guardado) != -1:
			EventosJogo.inventario_de(self).equipar(_escudo_guardado)
			_escudo_guardado = null
	jogador.set("troca_sem_pose", false)
	if not equipou:
		Sons.tocar("erro", 0.0)
		_mostrar_nome("%s: NAO DA PARA USAR" % item.nome(), Color(1, 0.6, 0.5))
		return false
	Sons.tocar("menu_confirmar", 0.0)
	_mostrar_nome("%s NV %d" % [item.nome(), item.nivel], item.cor_raridade() if item.raridade != "comum" else COR_NOME)
	return true

## Fazenda: ferramenta ou semente da estação vira a ferramenta ativa; arma e escudo não fazem nada aqui
func _escolher_na_fazenda(item) -> bool:
	if item.categoria != "ferramenta" and item.categoria != "semente":
		return false
	if not Fazenda.ferramentas(_lado()).has(item.tipo):
		Sons.tocar("erro", 0.0)
		mostrar_aviso(Fazenda.MSG_FORA_ESTACAO)
		return false
	if item.tipo != Fazenda.ferramenta_de(_lado()):
		Fazenda.definir_ferramenta(item.tipo, _lado())
		Sons.tocar("menu_mover", 0.0, -3.0)
	_mostrar_nome(nome_da_ferramenta(item.tipo), item.cor_raridade() if item.raridade != "comum" else COR_NOME)
	return true

## Nome da ferramenta para a barra: "ENXADA", "SEMENTE: TOMATE - CRESCE EM 4 DIAS"
static func nome_da_ferramenta(tipo: String) -> String:
	if tipo.begins_with(Fazenda.PREFIXO_SEMENTE):
		var id := tipo.trim_prefix(Fazenda.PREFIXO_SEMENTE)
		return "SEMENTE: %s - CRESCE EM %s" % [String(Fazenda.PLANTAS[id]["nome"]), Fazenda.texto_crescimento(id)]
	return String(DadosItem.NOMES.get(tipo, tipo.to_upper()))

## Aviso da fazenda (por que a ferramenta não pôde ser usada), no lugar do nome
func mostrar_aviso(texto: String) -> void:
	_mostrar_nome(texto, COR_AVISO)

## Escudo: em uso, guarda de volta na casa dele; guardado, equipa (se a arma deixar)
func _usar_escudo(escudo) -> bool:
	if escudo == EventosJogo.inventario_de(self).equipados.get("escudo"):
		_escudo_guardado = null
		Sons.tocar("menu_confirmar", 0.0)
		return EventosJogo.inventario_de(self).desequipar("escudo")
	if not EventosJogo.inventario_de(self).equipar(escudo):
		Sons.tocar("erro", 0.0)
		_mostrar_nome("ESCUDO: ARMA DE DUAS MAOS", Color(1, 0.6, 0.5))
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
		Fazenda.trocar_ferramenta(passo, _lado())
		Sons.tocar("menu_mover", 0.0, -3.0)
		_mostrar_nome(nome_da_ferramenta(Fazenda.ferramenta_de(_lado())), COR_NOME)
		return true
	var casas_de_arma: Array[int] = []
	var atual := -1
	for i in _casas.size():
		var item = EventosJogo.inventario_de(self).item_na_celula(i)
		if item != null and item.categoria == "arma":
			casas_de_arma.append(i)
			if item == EventosJogo.inventario_de(self).equipados.get("arma"):
				atual = casas_de_arma.size() - 1
	if casas_de_arma.is_empty() or (casas_de_arma.size() == 1 and atual != -1):
		return false
	var destino := posmod((atual if atual != -1 else 0) + passo, casas_de_arma.size())
	return escolher(casas_de_arma[destino])

func _mostrar_nome(texto: String, cor: Color) -> void:
	_nome.text = texto
	_nome.add_theme_color_override("font_color", cor)
	if _tween_nome != null and _tween_nome.is_valid():
		_tween_nome.kill()
	_nome.modulate.a = 1.0
	_tween_nome = create_tween()
	_tween_nome.tween_interval(DURACAO_NOME)
	if modo_fazenda:
		# o aviso some e volta o nome da ferramenta ativa
		_tween_nome.tween_callback(func() -> void: _tween_nome = null; _nome_fixo())
		return
	_tween_nome.tween_property(_nome, "modulate:a", 0.0, 0.4)

## 1 = jogador 1, 2 = jogador 2 do cooperativo (cada um com a própria ferramenta)
func _lado() -> int:
	return 2 if EventosJogo.eh_do_p2(self) else 1
