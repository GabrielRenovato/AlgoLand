extends Control

const CENA_SLOT := preload("res://cenas/ui/componentes/slot_ui.tscn")
const IconesItens := preload("res://Codigos/UI/icones_itens.gd")
const LADO_QUADRO_BONECO := 64
const NOMES_SLOTS_EQUIPAMENTO := ["SlotCabeca", "SlotCorpo", "SlotLuvas", "SlotBotas", "SlotArma", "SlotEscudo", "SlotSecundaria"]

var _atualizacao_pendente: bool = false
var _slots_mochila: Array[Control] = []
var _slots_equipamento: Dictionary = {}

@onready var _grade: GridContainer = $Sidebar/Painel/Mochila
@onready var _corpo: TextureRect = $Sidebar/Painel/Boneco/Corpo
@onready var _roupa: TextureRect = $Sidebar/Painel/Boneco/Roupa
@onready var _cabelo: TextureRect = $Sidebar/Painel/Boneco/Cabelo
@onready var _atributos: GridContainer = $Sidebar/Atributos

func _ready() -> void:
	add_to_group("tela_inventario")
	$Sidebar/BotaoFechar.pressed.connect(EventosJogo.fechar_tela.emit.bind("inventario"))
	for i in InventarioJogador.TAMANHO_MOCHILA:
		var slot: Control = CENA_SLOT.instantiate()
		slot.tipo_slot = "mochila"
		slot.indice = i
		_grade.add_child(slot)
		_slots_mochila.append(slot)
	for nome in NOMES_SLOTS_EQUIPAMENTO:
		var slot: Control = get_node("Sidebar/Painel/" + nome)
		_slots_equipamento[slot.tipo_slot] = slot

	InventarioJogador.mochila_alterada.connect(_agendar_atualizacao)
	InventarioJogador.equipamento_alterado.connect(_agendar_atualizacao)
	InventarioJogador.item_alterado.connect(_agendar_atualizacao)
	visibility_changed.connect(_ao_visibilidade_alterada)
	_atualizar()

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
	for i in _slots_mochila.size():
		_slots_mochila[i].exibir(InventarioJogador.mochila[i])
	for slot in _slots_equipamento:
		_slots_equipamento[slot].exibir(InventarioJogador.equipados[slot])
	_atualizar_boneco()
	atualizar_atributos()

# Equipar e comprar mudam as estatísticas do Jogador; espera um frame para ele recalcular
func atualizar_atributos() -> void:
	if not is_node_ready() or not is_inside_tree() or get_tree() == null:
		return
	await get_tree().process_frame
	if not is_inside_tree() or get_tree() == null:
		return
	var jogador := IconesItens.obter_jogador(get_tree())
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
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador == null:
		return
	_corpo.texture = _quadro(jogador.sprite_corpo.texture, 0)
	_roupa.texture = _quadro(jogador.sprite_roupa.texture, 0)
	# O boneco antigo usava o quadro 1 no cabelo
	_cabelo.texture = _quadro(jogador.sprite_cabelo.texture, 1)
	_cabelo.modulate = jogador.cor_cabelo

func _quadro(textura: Texture2D, indice_quadro: int) -> Texture2D:
	if textura == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = textura
	atlas.region = Rect2(indice_quadro * LADO_QUADRO_BONECO, 0, LADO_QUADRO_BONECO, LADO_QUADRO_BONECO)
	return atlas
