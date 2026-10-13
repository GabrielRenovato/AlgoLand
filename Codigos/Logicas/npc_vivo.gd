extends Node

## Dá vida a um NPC do Mana Seed (folha 4x8 de 32x32: "npc <tipo> <A|B> v0N.png"). Filho do NPC (um CharacterBody2D);
## anima o Sprite2D irmão e, nos perfis que andam, move o corpo.
## Linhas da folha: 0 de frente, 1 para a direita, 2 de costas, 3 para a esquerda. Cada linha é um CICLO DE ANDAR de
## 4 quadros (0 e 2 de passo, 1 e 3 de passagem); parado fica no quadro 1. As linhas de baixo são poses especiais de cada
## NPC (o mercador sentado, o bardo tocando, a mística com a bola).
##
## O que o NPC faz (perfil em PERFIS, escolhido pelo `perfil` ou pelo id_morador do pai):
##  - passeia: fica parado um tempo, escolhe um ponto perto do lugar dele e anda até lá (colide com o cenário), olhando
##    para onde vai; ao chegar, para de novo;
##  - jogador perto: para, vira para ele e espera (e não se aproxima);
##  - parado olha para os lados de vez em quando;
##  - quem tem pose especial (bardo, mística) alterna: fica nela um tempo e nas pausas passeia;
##  - cumprimento: pulinho ao jogador chegar perto (mercador).

const Profundidade := preload("res://Codigos/Globais/profundidade.gd")

## Linhas da folha por direção
const BAIXO := 0
const DIREITA := 1
const CIMA := 2
const ESQUERDA := 3
## Quadro de "parado" dentro da linha (passagem do ciclo de andar)
const QUADRO_PARADO := 1
## Camada dos obstáculos do cenário (árvores, barraca, limite da arena)
const CAMADA_OBSTACULOS := 64

## linha_base: para onde olha parado. raio_olhar: distância (px) em que repara no jogador, para e vira para ele
## (0 = não repara). É curto de propósito: o jogador nasce no acampamento a ~60 px de cada um e eles têm que andar.
## passeio: raio (px) em volta do lugar de origem em que anda (0 = não anda); vel: px/s; parado: espera entre passeios (s).
## cumprimento: pulinho ao jogador chegar perto. sentado: fica na pose da linha_base (quadro 0) e só de vez em quando
## faz um gesto curto, alternando os `quadros` quadros (mexer a mão), em vez de balançar o tempo todo.
## especial: pose própria {linha, quadros, fps, dur (min, max em s), pausa (min, max em s), ao_olhar: continua nela com o
## jogador perto?}
const PERFIS := {
	"mercador": {"linha_base": 5, "sentado": true, "quadros": 2, "sentado_fps": 3.0, "raio_olhar": 0.0, "passeio": 0.0,
			"cumprimento": true},
	"curandeira": {"linha_base": BAIXO, "raio_olhar": 38.0, "passeio": 38.0, "vel": 20.0, "parado": Vector2(2.0, 5.5), "cumprimento": true},
	"bardo": {"linha_base": BAIXO, "raio_olhar": 38.0, "passeio": 26.0, "vel": 18.0, "parado": Vector2(0.8, 2.0), "cumprimento": false,
			"especial": {"linha": 6, "quadros": 4, "fps": 5.0, "dur": Vector2(9, 15), "pausa": Vector2(4, 7), "ao_olhar": true}},
	"mistica": {"linha_base": BAIXO, "raio_olhar": 38.0, "passeio": 18.0, "vel": 16.0, "parado": Vector2(0.8, 2.0), "cumprimento": false,
			"especial": {"linha": 6, "quadros": 4, "fps": 2.5, "dur": Vector2(12, 20), "pausa": Vector2(3, 5), "ao_olhar": false}},
}
const PERFIL_PADRAO := {"linha_base": BAIXO, "raio_olhar": 38.0, "passeio": 0.0, "vel": 18.0, "parado": Vector2(2.0, 5.0), "cumprimento": false}

## Ciclo de andar
const FPS_ANDAR := 6.5
## Olhadas para os lados quando parado: espera até a próxima, quanto dura
const ESPERA_OLHADA := Vector2(3.0, 8.0)
const DURACAO_OLHADA := Vector2(1.2, 2.6)
## Sentado: espera entre um gesto e outro e duração do gesto (s)
const ESPERA_GESTO := Vector2(6.0, 14.0)
const DURACAO_GESTO := Vector2(0.7, 1.3)
## Altura e duração do pulinho de cumprimento
const ALTURA_PULO := 3.0
const DURACAO_PULO := 0.28
## Distância do alvo em que conta como chegou
const CHEGOU := 1.5
## Altura dos pés em relação à origem do NPC (a profundidade acompanha quem anda)
const PES_Y := 14.0

@export var perfil: String = ""

var _corpo: CharacterBody2D
var _sprite: Sprite2D
var _cfg: Dictionary = PERFIL_PADRAO
var _tempo := 0.0
var _casa := Vector2.ZERO          # lugar de origem (centro do passeio)
var _andando := false
var _alvo := Vector2.ZERO
var _linha_andar := BAIXO
var _resta_parado := 0.0
var _linha_olhar := -1            # direção que olha parado (-1 = a base)
var _espera_olhada := 0.0
var _resta_olhada := 0.0
var _em_especial := false
var _resta_fase := 0.0
var _perto := false
var _espera_gesto := 0.0
var _resta_gesto := 0.0
var _tween: Tween
var _y_original := 0.0

func _ready() -> void:
	_corpo = get_parent() as CharacterBody2D
	_sprite = get_parent().get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		set_process(false)
		return
	var chave := perfil if perfil != "" else String(get_parent().get("id_morador"))
	_cfg = PERFIS.get(chave, PERFIL_PADRAO)
	_y_original = _sprite.position.y
	_casa = (get_parent() as Node2D).global_position
	_tempo = randf() * 10.0
	_espera_olhada = _sortear(ESPERA_OLHADA)
	_espera_gesto = _sortear(ESPERA_GESTO)
	_resta_parado = _sortear(_cfg.get("parado", Vector2(2.0, 5.0)))
	if _corpo != null and _anda():
		# Só os obstáculos do cenário (o jogador é que esbarra neles, e não o contrário)
		_corpo.collision_mask |= CAMADA_OBSTACULOS
	if _cfg.has("especial"):
		_em_especial = randf() < 0.7
		_resta_fase = _sortear(_cfg["especial"]["dur" if _em_especial else "pausa"])
	_desenhar()

func _anda() -> bool:
	return float(_cfg.get("passeio", 0.0)) > 0.0

func _process(delta: float) -> void:
	if not _sprite.is_visible_in_tree():
		return
	_tempo += delta
	_atualizar_jogador_perto()
	_atualizar_fase(delta)
	_atualizar_gesto(delta)
	if _corpo != null and _anda():
		_atualizar_passeio(delta)
	_atualizar_olhar(delta)
	_desenhar()

# O jogador está perto o bastante para o NPC reparar (e cumprimentar quando chega)
func _atualizar_jogador_perto() -> void:
	var raio := float(_cfg["raio_olhar"]) if float(_cfg["raio_olhar"]) > 0.0 else 70.0
	var jogador := _jogador()
	var perto := jogador != null and jogador.global_position.distance_to(get_parent().global_position) <= raio
	if perto and not _perto and bool(_cfg["cumprimento"]):
		_cumprimentar()
	_perto = perto

# Sentado: parado quase o tempo todo; de vez em quando um gesto curto
func _atualizar_gesto(delta: float) -> void:
	if not bool(_cfg.get("sentado", false)):
		return
	if _resta_gesto > 0.0:
		_resta_gesto -= delta
		return
	_espera_gesto -= delta
	if _espera_gesto <= 0.0:
		_resta_gesto = _sortear(DURACAO_GESTO)
		_espera_gesto = _sortear(ESPERA_GESTO)

# Na pose especial e com o jogador perto (e sem querer ficar nela) não anda; fora disso alterna parado e andando
func _pode_andar() -> bool:
	if _em_especial:
		return false
	return not (_perto and float(_cfg["raio_olhar"]) > 0.0)

func _atualizar_passeio(delta: float) -> void:
	if not _pode_andar():
		_andando = false
		return
	if not _andando:
		_resta_parado -= delta
		if _resta_parado <= 0.0:
			_escolher_alvo()
		return
	var para: Vector2 = _alvo - _corpo.global_position
	if para.length() <= CHEGOU:
		_parar()
		return
	_linha_andar = _linha_de(para)
	var colisao := _corpo.move_and_collide(para.normalized() * minf(float(_cfg["vel"]) * delta, para.length()))
	if colisao != null:
		_parar()
	_corpo.z_index = Profundidade.z_de(_corpo.to_global(Vector2(0, PES_Y)).y)

func _escolher_alvo() -> void:
	var raio := float(_cfg["passeio"])
	# Pelo menos metade do raio de distância da origem, para o passeio ser visível (nada de passinho de um quadro só)
	_alvo = _casa + Vector2.from_angle(randf() * TAU) * raio * randf_range(0.5, 1.0)
	_andando = true
	_linha_olhar = -1
	_resta_olhada = 0.0

func _parar() -> void:
	_andando = false
	_resta_parado = _sortear(_cfg.get("parado", Vector2(2.0, 5.0)))
	_linha_olhar = _linha_andar

# Parado: olha para o jogador se ele está perto, senão olha em volta de vez em quando
func _atualizar_olhar(delta: float) -> void:
	if _andando or bool(_cfg.get("sentado", false)):
		return
	if _perto and float(_cfg["raio_olhar"]) > 0.0:
		_linha_olhar = _linha_para_jogador()
		_resta_olhada = 0.0
		_espera_olhada = _sortear(ESPERA_OLHADA)
		return
	if _resta_olhada > 0.0:
		_resta_olhada -= delta
		if _resta_olhada <= 0.0:
			_linha_olhar = -1
		return
	_espera_olhada -= delta
	if _espera_olhada <= 0.0:
		_linha_olhar = [DIREITA, ESQUERDA, DIREITA, ESQUERDA, CIMA][randi() % 5]
		_resta_olhada = _sortear(DURACAO_OLHADA)
		_espera_olhada = _sortear(ESPERA_OLHADA)

# Alterna a pose especial (tocar, olhar a bola) e as pausas (em que passeia)
func _atualizar_fase(delta: float) -> void:
	if not _cfg.has("especial"):
		return
	_resta_fase -= delta
	if _resta_fase <= 0.0:
		_em_especial = not _em_especial
		_resta_fase = _sortear(_cfg["especial"]["dur" if _em_especial else "pausa"])
		if _em_especial:
			_andando = false

func _desenhar() -> void:
	var especial_agora := _em_especial and _cfg.has("especial") and (not _perto or bool(_cfg["especial"]["ao_olhar"]))
	var linha: int
	var coluna: int
	if bool(_cfg.get("sentado", false)):
		linha = int(_cfg["linha_base"])
		coluna = int(_tempo * float(_cfg["sentado_fps"])) % int(_cfg["quadros"]) if _resta_gesto > 0.0 else 0
	elif especial_agora:
		var esp: Dictionary = _cfg["especial"]
		linha = int(esp["linha"])
		coluna = int(_tempo * float(esp["fps"])) % int(esp["quadros"])
	elif _andando:
		linha = _linha_andar
		coluna = int(_tempo * FPS_ANDAR) % 4
	else:
		linha = _linha_olhar if _linha_olhar >= 0 else int(_cfg["linha_base"])
		coluna = QUADRO_PARADO
	_sprite.frame = linha * _sprite.hframes + coluna

# Linha da folha para olhar na direção `d`
func _linha_de(d: Vector2) -> int:
	if absf(d.x) > absf(d.y) * 1.2:
		return DIREITA if d.x > 0.0 else ESQUERDA
	return BAIXO if d.y > 0.0 else CIMA

func _linha_para_jogador() -> int:
	var jogador := _jogador()
	if jogador == null:
		return BAIXO
	return _linha_de(jogador.global_position - get_parent().global_position)

func _cumprimentar() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_sprite.position.y = _y_original
	_tween = create_tween()
	_tween.tween_property(_sprite, "position:y", _y_original - ALTURA_PULO, DURACAO_PULO / 2.0).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sprite, "position:y", _y_original, DURACAO_PULO / 2.0).set_ease(Tween.EASE_IN)

func _jogador() -> Node2D:
	var cena := get_tree().current_scene if is_inside_tree() else null
	return cena.get_node_or_null("Jogador") as Node2D if cena != null else null

static func _sortear(faixa: Vector2) -> float:
	return randf_range(faixa.x, faixa.y)
