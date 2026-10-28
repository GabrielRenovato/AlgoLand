extends CharacterBody2D
## Adversário do duelo na tela local. Tem só os campos do jogador que o visual 3D
## (heroi_base_3d.gd e módulos) lê, preenchidos pelo estado que chega da rede; não carrega save,
## mochila nem sessões. É alvo dos golpes (grupo "enemy", camada 4): o acerto vira um evento
## e quem apanha resolve defesa, aparo e dano no próprio jogo (arena_duelo.gd).
signal golpeado(dano: int, empurrao: Vector2)
## O meu aparo perfeito o pegou (defesa_jogador.gd chama empurrar + atordoar nos inimigos próximos).
signal atordoado_por_mim(duracao: float, empurrao: Vector2)

const DefesaJogador := preload("res://codigo/jogador/defesa_jogador.gd")
const ALCANCE_ACAO_FAZENDA := 14.0

class FazendaRemota extends Node:
	var acao_atual := ""
class ArcoRemoto extends RefCounted:
	var disparando := false
	var _direcao_disparo := Vector2.DOWN
	func esta_disparando() -> bool: return disparando
class ReacaoRemota extends RefCounted:
	var visible := false
	var pose_atual := ""

# Campos lidos pelo visual 3D.
var apelido := "?"
var aparencia_raven: Dictionary = {}
var roupas_3d: Dictionary = {}
var eh_p2 := false
var estaMorto := false
var caido := false
var esta_sentado := false
var _tempo_sentado := 0.0
var _frente_sentado := 0
var _lado_sentado := 1
var esta_forjando := false
var esta_em_acao_fazenda := false
var modo_fazenda := false
var esta_em_dash := false
var duracao_dash := 0.15
var _esta_atacando := false
var _fase_combo := 0
var _direcao_ataque := Vector2.DOWN
var _direcao_golpe_3d := Vector2.DOWN
var _direcao_apontada := Vector2.DOWN
var id_arma_atual := "espada_basica"
var usando_espada := true
var usando_escudo := false
var usando_lanca := false
var usando_arco := false
var pecas_cavaleiro := 0
var roupa_atual = null
var inventario = null
var defesa: Node
var no_fazenda: FazendaRemota
var no_arco := ArcoRemoto.new()
var no_reacao := ReacaoRemota.new()
var _temporizador: Timer
var hp := 1
var hp_maximo := 1

var _alvo := Vector2.ZERO
var _tem_estado := false
## Interpolação com atraso fixo: desenha o adversário ATRASO s no passado, entre dois pacotes reais.
## Sem isso, cada pacote que chega fora do ritmo (Wi-Fi/4G) vira um tranco na tela.
const ATRASO := 0.10
const EXTRAPOLACAO_MAX := 0.15
var _amostras: Array = [] # [tempo_local_s, posicao, velocidade]
var _empurrao_pendente := Vector2.ZERO
## O adversário está atordoado (estado "atd"): estrelas sobre a cabeça.
var atordoado := false
var _estrelas: Label

func _init() -> void:
	name = "AdversarioRemoto"
	z_index = 1 # Mesma camada do jogador na arena.
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 0
	var forma := CollisionShape2D.new()
	var capsula := CapsuleShape2D.new()
	capsula.radius = 6.0
	capsula.height = 18.0
	forma.shape = capsula
	forma.position = Vector2(0, -8)
	add_child(forma)
	# O visual 3D esconde o sprite 2D do jogador; aqui é só um nó vazio com o mesmo nome.
	var sprites := Node2D.new()
	sprites.name = "CompositeSprites"
	sprites.visible = false
	add_child(sprites)
	_temporizador = Timer.new()
	_temporizador.one_shot = true
	add_child(_temporizador)
	no_fazenda = FazendaRemota.new()
	add_child(no_fazenda)
	defesa = DefesaJogador.new()
	defesa.jogador = null
	_estrelas = Label.new()
	_estrelas.text = "* * *"
	_estrelas.position = Vector2(-14, -58)
	_estrelas.add_theme_font_size_override("font_size", 10)
	_estrelas.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	_estrelas.add_theme_color_override("font_outline_color", Color(0.13, 0.08, 0.14))
	_estrelas.add_theme_constant_override("outline_size", 3)
	_estrelas.z_index = 20
	_estrelas.visible = false
	add_child(_estrelas)

## Perfil da sala (conexao_duelo.gd: perfil_do): monta o visual com roupas, cabelo, cores e armas.
func configurar(perfil: Dictionary) -> void:
	apelido = str(perfil.get("apelido", "?"))
	aparencia_raven = perfil.get("aparencia_raven", {})
	roupas_3d = perfil.get("roupas_3d", {})
	id_arma_atual = str(perfil.get("arma", "espada_basica"))
	usando_espada = bool(perfil.get("espada", true))
	usando_escudo = bool(perfil.get("escudo", false))
	usando_lanca = bool(perfil.get("lanca", false))
	usando_arco = bool(perfil.get("arco", false))
	hp_maximo = maxi(1, int(perfil.get("hp_maximo", 1)))
	hp = hp_maximo
	var heroi = preload("res://codigo/jogador/heroi_base_3d.gd").new()
	heroi.pecas_visiveis = int(perfil.get("pecas", 15))
	add_child(heroi)

## Lido pelo heroi_base_3d no _ready: só as roupas vêm "do save".
func carregar_de_json() -> Dictionary:
	return {"roupas_3d": roupas_3d}

func direcao_apontada() -> Vector2:
	return _direcao_apontada

func posicionar(ponto: Vector2) -> void:
	global_position = ponto
	_alvo = ponto
	_amostras.clear()

## Estado enviado pelo outro jogo (arena_duelo.gd: estado_local) a ~15 Hz.
func aplicar_estado(e: Dictionary) -> void:
	_alvo = Vector2(float(e.get("x", _alvo.x)), float(e.get("y", _alvo.y)))
	velocity = Vector2(float(e.get("vx", 0)), float(e.get("vy", 0)))
	_amostras.append([Time.get_ticks_msec() / 1000.0, _alvo, velocity])
	while _amostras.size() > 12: _amostras.pop_front()
	if not _tem_estado:
		global_position = _alvo
		_tem_estado = true
	atordoado = bool(e.get("atd", false))
	_estrelas.visible = atordoado
	var atacando := bool(e.get("a", false))
	var combo := int(e.get("c", 0))
	# O cronômetro do golpe só recomeça num golpe novo; depois corre sozinho (o visual lê o progresso dele).
	if atacando and (not _esta_atacando or combo != _fase_combo) and float(e.get("tl", 0)) > 0.0:
		_temporizador.start(float(e.tl))
	_esta_atacando = atacando
	_fase_combo = combo
	_direcao_ataque = _vetor(e.get("da"), _direcao_ataque)
	_direcao_golpe_3d = _vetor(e.get("d3"), _direcao_golpe_3d)
	_direcao_apontada = _vetor(e.get("dp"), _direcao_apontada)
	esta_em_dash = bool(e.get("dash", false))
	defesa.estado = int(e.get("def", 0))
	defesa.direcao_guarda = _vetor(e.get("dg"), defesa.direcao_guarda)
	defesa._tempo = float(e.get("gt", 0.0))
	defesa._indice = int(e.get("gi", 0))
	defesa._pausa = float(e.get("gp", 0.0))
	defesa._inicio_guarda_ms = Time.get_ticks_msec() - int(float(e.get("gh", 0.0)) * 1000.0)
	no_arco.disparando = bool(e.get("ar", false))
	no_arco._direcao_disparo = _vetor(e.get("ad"), no_arco._direcao_disparo)
	no_reacao.visible = bool(e.get("rf", false))
	no_reacao.pose_atual = "ferido" if no_reacao.visible else ""
	caido = bool(e.get("cai", false))
	estaMorto = bool(e.get("morto", false))
	hp = int(e.get("hp", hp))
	hp_maximo = maxi(1, int(e.get("hpm", hp_maximo)))
	id_arma_atual = str(e.get("arma", id_arma_atual))
	usando_espada = bool(e.get("es", usando_espada))
	usando_escudo = bool(e.get("ec", usando_escudo))
	usando_lanca = bool(e.get("la", usando_lanca))
	usando_arco = bool(e.get("arc", usando_arco))

static func _vetor(valor, padrao: Vector2) -> Vector2:
	if valor is Array and valor.size() == 2: return Vector2(float(valor[0]), float(valor[1]))
	return padrao

func _physics_process(delta: float) -> void:
	if not _amostras.is_empty():
		global_position = _posicao_interpolada(Time.get_ticks_msec() / 1000.0 - ATRASO)
	if esta_sentado: _tempo_sentado += delta
	if atordoado: _estrelas.position.x = -14 + sin(Time.get_ticks_msec() / 120.0) * 2.0

func _posicao_interpolada(t: float) -> Vector2:
	var primeira: Array = _amostras[0]
	if t <= float(primeira[0]): return primeira[1]
	for i in range(1, _amostras.size()):
		var a: Array = _amostras[i - 1]
		var b: Array = _amostras[i]
		if t <= float(b[0]):
			var f := (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return (a[1] as Vector2).lerp(b[1], f)
	# Faltou pacote: segue pela última velocidade por pouco tempo, depois espera parado.
	var ultima: Array = _amostras.back()
	return (ultima[1] as Vector2) + (ultima[2] as Vector2) * minf(t - float(ultima[0]), EXTRAPOLACAO_MAX)

## Golpe local acertou o adversário: avisa a arena, que manda o evento pela rede.
func receber_dano(dano: int, forca_knockback: Vector2 = Vector2.ZERO) -> void:
	if estaMorto or caido: return
	golpeado.emit(dano, forca_knockback)

func receber_dano_efeito(dano: int, _cor: Color = Color.WHITE) -> void:
	receber_dano(dano)

## Chamados pelo meu aparo perfeito (defesa_jogador.gd: _aparo_perfeito), nesta ordem.
func empurrar(forca: Vector2) -> void:
	_empurrao_pendente = forca

func atordoar(duracao: float) -> void:
	if estaMorto or caido: return
	atordoado_por_mim.emit(duracao, _empurrao_pendente)
	_empurrao_pendente = Vector2.ZERO
