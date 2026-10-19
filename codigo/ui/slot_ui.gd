extends Control

const COR_MOLDURA := Color(1.0, 0.82, 0.3, 0.9)
const COR_MOLDURA_HOVER := Color(1.0, 0.9, 0.45, 1.0)
const COR_PREENCHIMENTO_HOVER := Color(1.0, 0.85, 0.35, 0.25)
const COR_CARREGADO := Color(0.45, 0.9, 1.0, 1.0)
const COR_ICONE_VAZIO := Color(1.0, 1.0, 1.0, 0.35)
## Casa ainda bloqueada (linha extra da mochila): apagada; a última da linha leva o cadeado da folha de interface do inventário
const COR_TRANCADO := Color(0.55, 0.55, 0.6, 0.7)
const FOLHA_INTERFACE := preload("res://assets/ui/craftpix-net-420010-pixel-game-user-interface-for-platformer/1 Interface/TileMap.png")
const REGIAO_CADEADO := Rect2(152, 72, 16, 23)

@export var tipo_slot: String = "mochila"
@export var icone_vazio: Texture2D
@export var mostrar_fundo := true

var indice: int = -1
var item_atual: DadosItem
var trancado: bool = false
var _cadeado: TextureRect = null

var _arrasto_valido: bool = false
var _mouse_em_cima: bool = false
var _moldura: Control

@onready var _fundo: Panel = $Fundo
@onready var _icone_vazio: TextureRect = $IconeVazio
@onready var _item_ui: Control = $ItemUi

func _ready() -> void:
	_fundo.visible = mostrar_fundo
	_icone_vazio.texture = icone_vazio
	_icone_vazio.modulate = COR_ICONE_VAZIO
	mouse_entered.connect(_ao_mouse_entrar)
	mouse_exited.connect(_ao_mouse_sair)
	# No controle não há arrasto: o slot recebe foco e confirmar usa o item (ver _usar_com_controle)
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(_ao_foco_alterado)
	focus_exited.connect(_ao_foco_alterado)
	gui_input.connect(_ao_entrada)
	var interface := EventosJogo.interface_de(self)
	if interface != null and interface.has_signal("carregado_alterado"):
		interface.carregado_alterado.connect(_moldura_atualizar)
	# Desenhada por cima do fundo e do item; so aparece durante um arrasto compativel
	_moldura = Control.new()
	_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
	_moldura.draw.connect(_desenhar_moldura)
	add_child(_moldura)
	exibir(item_atual)

# Para a caixa de detalhe do inventário (UI e item_ui são nós internos do slot)
func item_ui() -> Control:
	return _item_ui

func exibir(item: DadosItem) -> void:
	item_atual = item
	_item_ui.visible = item != null
	_icone_vazio.visible = item == null and icone_vazio != null
	_item_ui.exibir(item)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_arrasto_valido = _dados_validos(get_viewport().gui_get_drag_data())
		_moldura.queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		_arrasto_valido = false
		_moldura.queue_redraw()

func _can_drop_data(_posicao: Vector2, dados: Variant) -> bool:
	return _dados_validos(dados)

func _drop_data(_posicao: Vector2, dados: Variant) -> void:
	var item: DadosItem = dados["item"]
	if tipo_slot == "venda_saque":
		if Saque.vender(item, EventosJogo.dono(self)) == 0:
			Sons.tocar("erro", 0.0)
		return
	if tipo_slot == "saque":
		if Saque.contem(item):
			Saque.mover(item, indice)
		elif not Saque.guardar(item, indice, EventosJogo.dono(self)):
			Sons.tocar("erro", 0.0)
		return
	if tipo_slot == "bau":
		if BauCasa.contem(item):
			BauCasa.mover(item, indice)
		elif not BauCasa.guardar(item, indice, EventosJogo.dono(self)):
			Sons.tocar("erro", 0.0)
	elif tipo_slot == "mochila":
		if Saque.contem(item):
			if not Saque.retirar(item, indice, EventosJogo.dono(self)):
				Sons.tocar("erro", 0.0)
		elif BauCasa.contem(item):
			if not BauCasa.retirar(item, indice, EventosJogo.dono(self)):
				Sons.tocar("erro", 0.0)
		else:
			EventosJogo.inventario_de(self).mover_para_mochila(item, indice)
	else:
		EventosJogo.inventario_de(self).equipar(item)

## Bloqueia (ou libera) a casa: apagada, sem receber item nem foco, com `dica` no mouse; `cadeado` desenha o cadeado nela
func definir_trancado(ativo: bool, dica: String = "", cadeado: bool = false) -> void:
	trancado = ativo
	# só o quadrado apaga: o cadeado fica nítido por cima
	_fundo.modulate = COR_TRANCADO if ativo else Color.WHITE
	tooltip_text = dica if ativo else ""
	focus_mode = Control.FOCUS_NONE if ativo else Control.FOCUS_ALL
	if cadeado and _cadeado == null:
		_cadeado = TextureRect.new()
		_cadeado.name = "Cadeado"
		var recorte := AtlasTexture.new()
		recorte.atlas = FOLHA_INTERFACE
		recorte.region = REGIAO_CADEADO
		_cadeado.texture = recorte
		_cadeado.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cadeado.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_cadeado.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_cadeado.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cadeado.offset_left = 4
		_cadeado.offset_top = 4
		_cadeado.offset_right = -4
		_cadeado.offset_bottom = -4
		add_child(_cadeado)
	if _cadeado != null:
		_cadeado.visible = ativo and cadeado

func _dados_validos(dados: Variant) -> bool:
	if trancado:
		return false
	if not (dados is Dictionary) or dados.has("slot_origem") or not (dados.get("item") is DadosItem):
		return false
	if tipo_slot == "mochila":
		return true
	var item: DadosItem = dados["item"]
	# A vara de pesca fica sempre na mochila: no baú ela se perderia e o jogo criaria outra
	if item.categoria == "vara" and tipo_slot != "mochila":
		return false
	# Baú: aceita o que está na mochila (não o que está na mão ou vestido) e trocas dentro dele
	if tipo_slot == "bau":
		return BauCasa.contem(item) or EventosJogo.inventario_de(self).indice_de(item) != -1
	# Saque da partida e a casa de venda dele: o que está no saque ou na mochila (não o que está na mão ou vestido)
	if tipo_slot == "saque" or tipo_slot == "venda_saque":
		return Saque.contem(item) or EventosJogo.inventario_de(self).indice_de(item) != -1
	# Item ja equipado nao tem celula na mochila, entao nao pode ser "equipado" de novo
	return item.categoria == tipo_slot and EventosJogo.inventario_de(self).indice_de(item) != -1 and EventosJogo.inventario_de(self).pode_equipar(item)

func _ao_foco_alterado() -> void:
	_moldura.queue_redraw()

func _moldura_atualizar() -> void:
	if _moldura != null:
		_moldura.queue_redraw()

func _ao_entrada(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_accept"):
		_usar_com_controle()
		accept_event()
	elif evento.is_action_pressed("colher") and tipo_slot in ["mochila", "arma", "escudo", "cabeca", "corpo", "luvas", "botas", "secundaria", "bau", "saque"]:
		mover_com_controle()
		accept_event()

## Mover no controle: Y pega o item da casa em foco; Y em outra casa solta o item ali (a mesma regra do arrasto, inclusive troca);
## Y na própria casa devolve. A casa do item "na mão" fica com a moldura azul
func mover_com_controle() -> void:
	var interface := EventosJogo.interface_de(self)
	if interface == null or not interface.has_method("definir_carregado") or trancado:
		return
	var carregado: DadosItem = interface.item_carregado
	if carregado == null:
		if item_atual != null and not _item_ui.em_uso:
			interface.definir_carregado(item_atual)
		return
	if carregado == item_atual:
		interface.definir_carregado(null)
		return
	var dados := {"item": carregado}
	if not _dados_validos(dados):
		Sons.tocar("erro", 0.0)
		return
	_drop_data(Vector2.ZERO, dados)
	interface.definir_carregado(null)

## O item em foco está "na mão" (para a tela mostrar o que o Y faz)
func esta_carregado() -> bool:
	var interface := EventosJogo.interface_de(self)
	return interface != null and "item_carregado" in interface and interface.item_carregado != null and interface.item_carregado == item_atual

# Com a bigorna/encantamento abertos o item vai para o slot do mercador; senão, mochila equipa e
# equipamento volta para a mochila. Armas, escudo e armaduras seguem a mesma regra do arrasto.
func _usar_com_controle() -> void:
	if item_atual == null or trancado:
		return
	var interface := EventosJogo.interface_de(self)
	if interface != null:
		var tela := interface._telas["inventario"] as Control
		if tela.tentar_excluir_item(item_atual): return
	if _item_ui.em_uso:
		var ferreiro := EventosJogo.painel_do_grupo(self, "tela_mercante")
		if ferreiro != null and ferreiro.is_visible_in_tree():
			ferreiro.mostrar_mensagem("ESSA ARMA JA ESTA NO FERREIRO")
		return
	if _trocar_com_bau():
		return
	var mercante := EventosJogo.painel_do_grupo(self, "tela_mercante")
	if mercante != null and mercante.is_visible_in_tree() and mercante.receber_item_do_controle(_item_ui):
		return
	_equipar_ou_desequipar()

## Com o baú aberto, confirmar (ou o botão direito) passa o item para o outro lado. false se o baú não está aberto
func _trocar_com_bau() -> bool:
	if item_atual != null and item_atual.categoria == "vara":
		return false
	# Saque da partida: confirmar no saque leva para a mochila
	if tipo_slot == "saque" and item_atual != null:
		if not Saque.retirar(item_atual, -1, EventosJogo.dono(self)):
			Sons.tocar("erro", 0.0)
		return true
	var bau := EventosJogo.painel_do_grupo(self, "tela_bau")
	if bau == null or not bau.is_visible_in_tree() or item_atual == null:
		return false
	var foi := false
	if tipo_slot == "bau":
		foi = BauCasa.retirar(item_atual, -1, EventosJogo.dono(self))
	elif tipo_slot == "mochila":
		foi = BauCasa.guardar(item_atual, -1, EventosJogo.dono(self))
	else:
		return false
	if not foi:
		Sons.tocar("erro", 0.0)
	return true

## Clique com o botão direito do mouse: equipa o item da mochila (ou desequipa o do slot de equipamento), mesmo com o ferreiro aberto
func equipar_com_botao_direito() -> void:
	if item_atual == null or trancado or _item_ui.em_uso:
		return
	# Botão direito no saque vende
	if tipo_slot == "saque":
		Saque.vender(item_atual, EventosJogo.dono(self))
		return
	if _trocar_com_bau():
		return
	_equipar_ou_desequipar()

func _equipar_ou_desequipar() -> void:
	if item_atual.categoria == "receita" and tipo_slot == "mochila":
		var mensagem: String = EventosJogo.inventario_de(self).usar_receita(item_atual)
		Sons.tocar("compra" if mensagem.is_empty() else "erro", 0.0)
		get_tree().call_group("hud_p2" if EventosJogo.eh_do_p2(self) else "hud_p1", "anunciar", "RECEITA APRENDIDA" if mensagem.is_empty() else mensagem, "FABRIQUE COM O IVO" if mensagem.is_empty() else "", 2.0)
		return
	if not item_atual.categoria in ["arma", "escudo", "secundaria", "cabeca", "corpo", "luvas", "botas"]:
		return
	if tipo_slot == "mochila":
		if not EventosJogo.inventario_de(self).equipar(item_atual):
			Sons.tocar("erro", 0.0)
	else:
		EventosJogo.inventario_de(self).desequipar(tipo_slot)

## No co-op o Godot solta o foco desta metade quando o parceiro foca algo; a Interface guarda o foco lógico
func _tem_foco() -> bool:
	if has_focus():
		return true
	var interface := EventosJogo.interface_de(self) if is_inside_tree() else null
	return interface != null and interface.has_method("foco_atual") and interface.foco_atual() == self

func _desenhar_moldura() -> void:
	if _tem_foco():
		var foco := Rect2(Vector2.ZERO, size)
		_moldura.draw_rect(foco, COR_PREENCHIMENTO_HOVER)
		_moldura.draw_rect(foco.grow(-0.5), COR_MOLDURA_HOVER, false, 1.0)
	if esta_carregado():
		_moldura.draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), COR_CARREGADO, false, 2.0)
	# Na grade da mochila so a celula sob o mouse acende, senao a grade inteira piscaria
	if not _arrasto_valido or (tipo_slot == "mochila" and not _mouse_em_cima):
		return
	var retangulo := Rect2(Vector2.ZERO, size)
	if _mouse_em_cima:
		_moldura.draw_rect(retangulo, COR_PREENCHIMENTO_HOVER)
	_moldura.draw_rect(retangulo.grow(-0.5), COR_MOLDURA_HOVER if _mouse_em_cima else COR_MOLDURA, false, 1.0)

func _ao_mouse_entrar() -> void:
	_mouse_em_cima = true
	_moldura.queue_redraw()

func _ao_mouse_sair() -> void:
	_mouse_em_cima = false
	_moldura.queue_redraw()
