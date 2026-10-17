extends "res://codigo/logica/interagivel.gd"

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const ESTACOES := ["primavera", "verao", "outono", "inverno"]
var sprite: Sprite2D
var cavalo: Sprite2D
var visual: Node2D
var _saida := 0.0
var _na_estrada := false
var _visibilidades: Dictionary = {}

func _init() -> void:
	nome_tela = "comercio"
	so_entre_ondas = false
	deslocamento_aviso = Vector2(0, -68)
	var zona := CollisionShape2D.new()
	var area := RectangleShape2D.new()
	area.size = Vector2(106, 64)
	zona.shape = area
	zona.position.y = 10
	add_child(zona)
	visual = preload("res://codigo/comercio/conjunto_carroca.gd").new()
	visual.name = "ConjuntoVisual"
	add_child(visual)
	sprite = visual.sprite
	cavalo = visual.cavalo
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 32
	corpo.collision_mask = 0
	var base := CollisionShape2D.new()
	var ret := RectangleShape2D.new()
	ret.size = Vector2(74, 20)
	base.shape = ret
	base.position = Vector2(-4, -10)
	corpo.add_child(base)
	var base_cavalo := CollisionShape2D.new()
	base_cavalo.name = "BaseCavalo"
	var ret_cavalo := RectangleShape2D.new()
	ret_cavalo.size = Vector2(52, 16)
	base_cavalo.shape = ret_cavalo
	base_cavalo.position = Vector2(80, -8)
	corpo.add_child(base_cavalo)
	add_child(corpo)

func _ready() -> void:
	super._ready()
	z_as_relative = false
	z_index = Profundidade.z_de(global_position.y)
	Calendario.estacao_mudou.connect(atualizar_estacao)
	Comercio.alterado.connect(_ao_estado)
	atualizar_estacao(Calendario.estacao())
	_ao_estado()

func atualizar_pelagem() -> void:
	visual.atualizar_pelagem()

func atualizar_estacao(estacao: int) -> void:
	visual.atualizar_estacao(estacao)

func _ao_estado() -> void:
	atualizar_pelagem()
	var embarcados := Comercio.em_viagem and not Comercio.em_combate
	if embarcados:
		visual.embarcar_jogadores()
		for jogador in [Cooperativo._jogador1(), Cooperativo.jogador2()]:
			if is_instance_valid(jogador):
				var aparencia: Node2D = jogador.get_node("CompositeSprites")
				if not _visibilidades.has(aparencia):
					_visibilidades[aparencia] = aparencia.visible
				aparencia.hide()
	else:
		visual.definir_ocupantes([])
		_restaurar_jogadores()
	var estrada := Comercio.em_viagem and not Comercio.em_combate and Comercio.etapa < Comercio.eventos.size()
	if estrada and not _na_estrada:
		_saida = 0.0
	_na_estrada = estrada
	if not estrada:
		visual.position = Vector2.ZERO
		visual.visible = not Comercio.em_viagem or Comercio.em_combate
		visual.definir_movimento(false)
	else:
		visual.visible = _saida < 2.4
		visual.definir_movimento(true)

func _process(delta: float) -> void:
	super._process(delta)
	if _na_estrada:
		_saida += delta
		visual.position.x = roundf(24.0 * minf(_saida, 2.4))
		visual.visible = _saida < 2.4

func pode_interagir() -> bool:
	return not Transicao.ocupada and (not Comercio.em_viagem or Comercio.em_combate) and super.pode_interagir()

func fechar_tela() -> void:
	# A saída da área durante a luta não pode descartar a viagem compartilhada.
	if Comercio.em_viagem or not is_inside_tree():
		return
	super.fechar_tela()

func _restaurar_jogadores() -> void:
	for aparencia in _visibilidades:
		if is_instance_valid(aparencia):
			aparencia.visible = _visibilidades[aparencia]
	_visibilidades.clear()

func _exit_tree() -> void:
	_restaurar_jogadores()
