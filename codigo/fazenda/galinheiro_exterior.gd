extends Node2D

const Criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
const ESTACOES := ["primavera","verao","outono","inverno"]
# Vãos medidos nos sprites nativos; o terceiro modelo desloca a portinha.
const ABERTURAS := [Rect2(133,117,10,11),Rect2(133,117,10,11),Rect2(134,116,10,11)]
const PIVO_IMAGEM := Vector2(112,144)
const RAIZ := "res://assets/cenario/fazenda/galinheiro/"
var imagem: Sprite2D
var colisao: CollisionShape2D
var estacao := 0
var portinha: Node2D
var _aves: Node2D
var obra: Sprite2D
var _etapa_atual := -1
var _espera_obra := 0.0

class Entrada extends "res://codigo/logica/interagivel.gd":
	func pode_interagir() -> bool:
		return (Fazenda.galinheiro.nivel > 0 or Fazenda.galinheiro.obra > 0) and super.pode_interagir()
	func abrir_tela() -> void: get_parent().entrar(Cooperativo._jogador1())
	func abrir_tela_p2() -> void: get_parent().entrar(Cooperativo.jogador2())

func _ready() -> void:
	name = "Galinheiro"
	z_index = preload("res://codigo/globais/profundidade.gd").z_de(global_position.y)
	imagem = Sprite2D.new()
	imagem.centered = false
	imagem.position = Vector2(-112,-144)
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(imagem)
	obra = Sprite2D.new()
	obra.centered = false
	obra.position = imagem.position
	obra.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(obra)
	move_child(obra,0)
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	colisao = CollisionShape2D.new()
	colisao.shape = RectangleShape2D.new()
	colisao.position = Vector2(0,-17)
	corpo.add_child(colisao)
	add_child(corpo)
	var zona := Entrada.new()
	zona.name = "Entrada"
	zona.nome_tela = "galinheiro"
	zona.so_entre_ondas = false
	zona.position = Vector2(0,12)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 24
	forma.shape = circulo
	zona.add_child(forma)
	add_child(zona)
	var chegada := Marker2D.new()
	chegada.name = "Chegada_galinheiro"
	chegada.position = Vector2(0,32)
	chegada.add_to_group("chegada")
	add_child(chegada)
	var estacoes := get_parent().get_node_or_null("Terrains/Estacoes")
	if estacoes != null:
		estacao = estacoes.estacao_atual
		estacoes.estacao_mudou.connect(_estacao_mudou)
	portinha = preload("res://codigo/fazenda/portinha_galinhas.gd").new()
	portinha.position = Vector2(25,-16)
	add_child(portinha)
	_aves = Node2D.new()
	add_child(_aves)
	Fazenda.galinheiro_alterado.connect(_atualizar)
	_atualizar()
	Fazenda.bando.configurar_quintal.call_deferred(self)

func _estacao_mudou(valor: int) -> void:
	estacao = valor
	_atualizar()

func _atualizar() -> void:
	var estado: Dictionary = Fazenda.galinheiro
	var nivel: int = estado.nivel
	if nivel == 0:
		imagem.texture = load(RAIZ+"nivel_1_%s.png" % ESTACOES[estacao])
		imagem.modulate = Color.WHITE
	else:
		imagem.texture = load(RAIZ+"nivel_%d_%s.png" % [nivel,ESTACOES[estacao]])
		imagem.modulate = Color.WHITE
	imagem.visible = nivel > 0
	colisao.set_deferred("disabled",nivel == 0 and estado.obra == 0)
	colisao.shape.size = Vector2([48,84,144,152][maxi(nivel,estado.obra)],30)
	_etapa_atual = -1
	_atualizar_obra()
	portinha.visible = nivel > 0
	var abertura: Rect2 = ABERTURAS[maxi(1,nivel)-1]
	portinha.position = abertura.position+Vector2(5,11)-PIVO_IMAGEM
	portinha.usar_folha_externa()
	Fazenda.bando.configurar_quintal(self)
	for ave in _aves.get_children():
		if ave.indice >= estado.aves.size():
			_aves.remove_child(ave)
			ave.queue_free()
	for i in estado.aves.size():
		if _aves.has_node("Galinha%d" % i):
			_aves.get_node("Galinha%d" % i).portinha = portinha.position
			continue
		var ave := preload("res://codigo/fazenda/galinha.gd").new()
		ave.indice = i
		ave.exterior = true
		ave.portinha = portinha.position
		_aves.add_child(ave)

func entrar(quem: Node2D) -> void:
	if quem == null or not quem.movimento_habilitado or Transicao.ocupada: return
	if Fazenda.galinheiro.nivel == 0:
		get_tree().call_group(quem.grupo_hud(),"avisar_barra","OBRA ATE O DIA %d. OSVALDO TRABALHA DAS 8H AS 17H." % Fazenda.galinheiro.pronto_dia if Fazenda.galinheiro.obra > 0 else "FALE COM OSVALDO PARA CONSTRUIR")
	elif Cooperativo.com_dois():
		Cooperativo.viajar_local(quem,"res://cenas/galinheiro.tscn","porta")
	else:
		Transicao.ir_para("res://cenas/galinheiro.tscn","porta")

func _process(delta: float) -> void:
	_espera_obra -= delta
	if _espera_obra <= 0:
		_espera_obra = 0.5
		_atualizar_obra()

func _atualizar_obra() -> void:
	obra.visible = Fazenda.galinheiro.obra > 0
	if not obra.visible: return
	var luz := get_parent().get_node("Iluminacao")
	var etapa := Criacao.etapa_obra(Fazenda.galinheiro,Calendario.dia,luz.hora_do_mundo())
	if etapa == _etapa_atual: return
	_etapa_atual = etapa
	obra.texture = load(RAIZ+"obra/nivel_%d_etapa_%d_%s.png" % [Fazenda.galinheiro.obra,etapa,ESTACOES[estacao]])
