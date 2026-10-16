extends "res://codigo/logica/interagivel.gd"

## Pombo-correio: chega voando com a carta de um pedido, pousa ao lado do jogador e espera ele ler (F / A / AGIR, como
## falar com um morador). Lida a carta, vai embora. Se o jogador se afasta, voa atrás; se ele sai do lugar ou ignora o
## pombo por TEMPO_ESPERA segundos, o pombo volta (agenda_vila.gd tenta de novo mais tarde).
## Sprite: o gavião do Mana Seed com a paleta de pombo (ferramentas/cidade/gerar_pombo.gd), folha 4x8 de 32x32.

signal voltou(entregue: bool)

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const TEXTURA := preload("res://assets/npcs/pombo_correio/pombo.png")
const TEXTURA_ENVELOPE := preload("res://assets/npcs/pombo_correio/envelope.png")
## Carta sem remetente: selo roxo
const TEXTURA_ENVELOPE_MISTERIO := preload("res://assets/npcs/pombo_correio/envelope_misterio.png")
## Quadros da folha (os do gavião): voo batendo as asas, pousado de lado e a sombra
const QUADROS_VOO := [0, 1, 2, 3]
const QUADROS_POUSADO := [24, 25, 24, 26]
const QUADRO_SOMBRA := 31
## Os pés ficam a 12 px abaixo do centro do quadro
const PES := 12.0
const VELOCIDADE := 130.0
const ALTURA_VOO := 120.0
## De onde ele vem (relativo ao jogador) e onde pousa (ao lado dele, um pouco à frente)
const DISTANCIA_CHEGADA := Vector2(300, -170)
const LADO_POUSO := Vector2(20, 4)
## Longe disso do jogador, o pombo pousado voa até ele de novo
const DISTANCIA_SEGUIR := 90.0
const TEMPO_ESPERA := 90.0
const TEMPO_PARTIDA := 2.5

enum Estado { CHEGANDO, POUSADO, PARTINDO }

var missao := ""
var alvo: Node2D
var estado := Estado.CHEGANDO
var altura := ALTURA_VOO
var entregue := false
var _corpo: Sprite2D
var _sombra: Sprite2D
var _envelope: Sprite2D
var _lado := 1.0
var _tempo := 0.0
var _esperando := 0.0
var _partindo := 0.0

func _init() -> void:
	name = "PomboCorreio"
	nome_tela = "conversa_cidade"
	so_entre_ondas = false
	deslocamento_aviso = Vector2(0, -34)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 22.0
	forma.shape = circulo
	add_child(forma)
	_sombra = _sprite(TEXTURA)
	_sombra.frame = QUADRO_SOMBRA
	_sombra.modulate = Color(1, 1, 1, 0.45)
	_sombra.position = Vector2(0, -PES + 1)
	_corpo = _sprite(TEXTURA)
	_envelope = _sprite(TEXTURA_ENVELOPE)

func _sprite(textura: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = textura
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if textura == TEXTURA:
		sprite.hframes = 4
		sprite.vframes = 8
	add_child(sprite)
	return sprite

func _ready() -> void:
	super._ready()
	Cidade.carta_lida.connect(_ao_carta_lida)
	if missao.begins_with("misterio"):
		_envelope.texture = TEXTURA_ENVELOPE_MISTERIO
	if is_instance_valid(alvo):
		_lado = 1.0 if randf() < 0.5 else -1.0
		global_position = alvo.global_position + Vector2(DISTANCIA_CHEGADA.x * _lado, DISTANCIA_CHEGADA.y)
	_desenhar()

func _process(delta: float) -> void:
	_tempo += delta
	match estado:
		Estado.CHEGANDO: _voar_ate_o_alvo(delta)
		Estado.POUSADO: _esperar(delta)
		Estado.PARTINDO: _partir(delta)
	_desenhar()
	super._process(delta)

func _alvo_presente() -> bool:
	return is_instance_valid(alvo) and alvo.is_inside_tree() and alvo.get_world_2d() == get_world_2d()

func _ponto_de_pouso() -> Vector2:
	var lado := signf(global_position.x - alvo.global_position.x)
	return alvo.global_position + Vector2(LADO_POUSO.x * (lado if lado != 0.0 else 1.0), LADO_POUSO.y)

func _voar_ate_o_alvo(delta: float) -> void:
	if not _alvo_presente():
		ir_embora()
		return
	var destino := _ponto_de_pouso()
	var falta := destino - global_position
	var distancia := falta.length()
	# Desce conforme chega: pousa junto com o último passo
	altura = minf(altura, ALTURA_VOO * clampf(distancia / 220.0, 0.0, 1.0))
	if distancia <= VELOCIDADE * delta:
		global_position = destino
		altura = 0.0
		estado = Estado.POUSADO
		_esperando = 0.0
		return
	_lado = signf(falta.x) if absf(falta.x) > 1.0 else _lado
	global_position += falta / distancia * VELOCIDADE * delta

func _esperar(delta: float) -> void:
	if not _alvo_presente():
		ir_embora()
		return
	if _tela_aberta:
		return
	_esperando += delta
	if _esperando >= TEMPO_ESPERA:
		ir_embora()
	elif global_position.distance_to(alvo.global_position) > DISTANCIA_SEGUIR:
		estado = Estado.CHEGANDO
		altura = 24.0
	else:
		# Pousado, olha para o jogador
		_lado = signf(alvo.global_position.x - global_position.x) if absf(alvo.global_position.x - global_position.x) > 2.0 else _lado

func ir_embora() -> void:
	if estado == Estado.PARTINDO:
		return
	estado = Estado.PARTINDO
	_partindo = 0.0
	_aviso.visible = false

func _partir(delta: float) -> void:
	_partindo += delta
	altura += 90.0 * delta
	global_position += Vector2(_lado * VELOCIDADE * delta, -40.0 * delta)
	if _partindo >= TEMPO_PARTIDA:
		set_process(false)
		voltou.emit(entregue)
		queue_free()

func _desenhar() -> void:
	var voando := estado != Estado.POUSADO
	var quadros: Array = QUADROS_VOO if voando else QUADROS_POUSADO
	var fps := 10.0 if voando else 3.0
	_corpo.frame = quadros[int(_tempo * fps) % quadros.size()]
	# A folha olha para a direita
	_corpo.flip_h = _lado < 0.0
	_corpo.position = Vector2(0, -PES - altura)
	_envelope.visible = not entregue
	# Voando, a carta vai presa nos pés; pousado, fica no chão à frente dele
	_envelope.position = Vector2(0, -altura - 1) if voando else Vector2(_lado * 9.0, -2)
	_sombra.visible = altura > 0.5 or not voando
	if voando:
		z_as_relative = false
		z_index = 850
	else:
		z_as_relative = false
		z_index = Profundidade.z_de(global_position.y)

# --- Interação: abre a carta na caixa de conversa de quem pegou -----------------------------------------------------

func pode_interagir() -> bool:
	return pode_interagir_para(Cooperativo._jogador1())

func pode_interagir_para(jogador: Node2D) -> bool:
	return estado == Estado.POUSADO and not entregue and jogador != null and jogador.get_world_2d() == get_world_2d() \
		and jogador.movimento_habilitado and not bool(jogador.get("esta_sentado")) and not Transicao.ocupada

func abrir_tela() -> void:
	if pode_interagir():
		Cidade.abrir_carta(Cooperativo._jogador1(), missao)

func abrir_tela_p2() -> void:
	if pode_interagir_para(Cooperativo.jogador2()):
		Cidade.abrir_carta(Cooperativo.jogador2(), missao)

## Afastar-se não fecha a carta (a caixa de conversa trava o movimento enquanto aberta)
func fechar_tela() -> void:
	pass

func _ao_tela_aberta(nome: String) -> void:
	if nome == nome_tela and Cidade.carta_aberta == missao:
		_tela_aberta = true

func _ao_carta_lida(id: String) -> void:
	if id != missao:
		return
	entregue = true
	_tela_aberta = false
	ir_embora()
