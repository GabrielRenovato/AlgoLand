extends Sprite2D
class_name HeroiTiny

## PROTÓTIPO (pedido de 2026-10-16): corpo pré-montado do Farm RPG Tiny Asset Pack (Tori) no lugar do herói Mana Seed.
## Ligado pelo F3 → PERSONAGEM. Só cobre parado, andar, correr e golpe; as demais poses (arco, fazenda, forja, cadeira,
## reações) continuam usando o herói Mana Seed, que reaparece enquanto elas estiverem ativas.
## Folhas de 32x32 com três linhas: baixo, cima, lado (a linha de lado olha para a DIREITA; esquerda = flip_h).

const PASTA := "res://assets/personagens/tiny/tori/"
## nome: [quadros por linha, quadros por segundo, repete]
const ANIMACOES := {
	"idle": [4, 5.0, true],
	"walk": [6, 7.0, true],
	"run": [8, 9.0, true],
	"sword": [10, 24.0, false],
}
## Escala nativa: cada pixel do personagem corresponde a um pixel dos tiles de 16 px.
const ESCALA := 1.0
const MULTIPLICADOR_MOVIMENTO := 0.65
## Distância do pivô do jogador até o pé do sprite (o herói Mana Seed tem os pés ~12 px abaixo do centro)
const PES_Y := 14.0

var _jogador: Node2D
var _texturas := {}
var _animacao := ""
var _tempo := 0.0

func _ready() -> void:
	name = "HeroiTiny"
	texture_filter = TEXTURE_FILTER_NEAREST
	scale = Vector2(ESCALA, ESCALA)
	position = Vector2(0, PES_Y - 16.0 * ESCALA)
	z_index = 3
	_jogador = get_parent() as Node2D
	for nome in ANIMACOES:
		_texturas[nome] = load(PASTA + nome + ".png")
	_ocupar(true)

func _exit_tree() -> void:
	if _jogador != null and is_instance_valid(_jogador):
		_ocupar(false)

## Esconde (ou devolve) o herói Mana Seed
func _ocupar(ligado: bool) -> void:
	var antigo := _jogador.get_node_or_null("CompositeSprites") as CanvasItem
	if antigo != null:
		antigo.visible = not ligado

func _process(delta: float) -> void:
	if is_instance_valid(_jogador) and _jogador.has_node("SessaoPesca"):
		visible = false
		_jogador.get_node("CompositeSprites").visible = false
		return

	if _jogador == null:
		return
	var antigo := _jogador.get_node_or_null("CompositeSprites") as CanvasItem
	# Poses que o Tiny não tem: devolve o herói Mana Seed até acabar
	var pose_propria: bool = _jogador.esta_forjando or _jogador.esta_sentado or _jogador.esta_em_acao_fazenda \
		or (_jogador.no_arco != null and _jogador.usando_arco and _jogador.no_arco.esta_disparando()) \
		or (_jogador.no_reacao != null and _jogador.no_reacao.visible)
	visible = not pose_propria
	if antigo != null:
		antigo.visible = pose_propria
	if pose_propria:
		return
	var anim := "idle"
	if _jogador._esta_atacando:
		anim = "sword"
	elif _jogador.velocity.length() > 2.0:
		anim = "run"
	if anim != _animacao:
		_animacao = anim
		_tempo = 0.0
		texture = _texturas[anim]
		hframes = ANIMACOES[anim][0]
		vframes = 3
	_tempo += delta
	var dados: Array = ANIMACOES[_animacao]
	var quadro := int(_tempo * float(dados[1]))
	quadro = quadro % int(dados[0]) if dados[2] else mini(quadro, int(dados[0]) - 1)
	var direcao: Vector2 = _jogador._direcao_ataque
	var linha := 0
	flip_h = false
	if absf(direcao.x) > absf(direcao.y):
		linha = 2
		flip_h = direcao.x < 0.0
	elif direcao.y < 0.0:
		linha = 1
	frame = linha * hframes + quadro
