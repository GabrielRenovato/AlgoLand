extends Node2D
## Visual jogável de teste: canônico, corrida e dois cortes aprovados.
## Mantém colisões, controles, inventário e regras do jogador real.
const RAIZ := "res://assets/personagens/raven_cartoon/"
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const CamadaEspada := preload("res://codigo/jogador/camada_espada_cartoon.gd")
const CamadaArmadura := preload("res://codigo/jogador/armadura_cartoon.gd")
const ESCALA := 0.04
const ESCALA_VISUAL := 1.08 # Corpo, armadura, espada e rastro escalam juntos, a partir dos pés.
const FATOR_VELOCIDADE_MOVIMENTO := 0.8
# Quatro recuos médios da sola: (166,95 + 267,99) / 2 × 4 ≈ 870px na folha.
const DISTANCIA_CICLO_NATIVA := 870.0
const FATOR_RITMO_CORRIDA := 0.85
const DURACAO_GOLPE := 0.49
const FIM_FASES := [0.16, 0.22, 0.29, 0.49]
# Centro dos ombros e centro da cintura medidos nos quatro desenhos aprovados.
# Coordenadas da célula 512×896; a arma segue o eixo do tronco, não o chão.
const EIXOS_TRONCO_CORRIDA := {
	"frente": [Vector4(256,350,275,480), Vector4(256,348,254,470),
		Vector4(256,353,241,480), Vector4(256,350,261,472)],
	"costas": [Vector4(256,350,256,490), Vector4(256,348,258,482),
		Vector4(256,354,263,484), Vector4(256,348,254,483)],
	"direita": [Vector4(234,350,240,490), Vector4(239,348,250,490),
		Vector4(235,360,240,491), Vector4(270,390,273,525)],
}
# Perfil: cabo acima do ombro de trás e lâmina descendo pelas costas, presa ao tronco.
var apoio_perfil := Vector2(-60, -32)
var angulo_perfil := 212.0
var encaixe_perfil_parado := Vector2(-3, -22.5)
var corpo: AnimatedSprite2D
var armadura: Node2D
var acao_atual := ""
var direcao_atual := "frente"
var _jogador: Node2D
var _recursos := {}
var _equipamentos: Array[Node2D] = []
var _arma_costas: Sprite2D
var _distancia_corrida := 0.0
var _ultima_posicao := Vector2.ZERO
var _tempo_demonstracao := 0.0
var _golpe_demonstracao := 0
var _fila_demonstracao := false
var _direcao_golpe := Vector2.DOWN

func _ready() -> void:
	name = "HeroiCartoon"
	_jogador = get_parent()
	_ultima_posicao = _jogador.global_position
	position.y = Profundidade.PES_JOGADOR
	scale = Vector2.ONE*ESCALA_VISUAL
	z_index = 3
	process_priority = 110 # Decide a apresentação antes do compositor Raven.
	corpo = AnimatedSprite2D.new()
	corpo.name = "CorpoCartoon"
	corpo.centered = false
	corpo.texture_filter = TEXTURE_FILTER_LINEAR
	add_child(corpo)
	# Carregar antes da primeira ação evita pausa ao sacar em uma direção nova.
	for arquivo in ["parado_quatro_direcoes", "corrida_quatro_direcoes", "ataque_baixo_sem_arma",
			"ataque_cima_sem_arma", "ataque_direita_sem_arma", "ataque2_baixo_sem_arma",
			"ataque2_cima_sem_arma", "ataque2_direita_sem_arma"]:
		_recursos[arquivo] = load(RAIZ+arquivo+".tres")
	_definir_recurso("parado_quatro_direcoes", "parado_frente")
	corpo.offset = Vector2(-320, -850)
	corpo.scale = Vector2.ONE*ESCALA
	for golpe in [1, 2]:
		var equipamento = CamadaEspada.new()
		corpo.add_child(equipamento)
		equipamento.configurar(corpo, "baixo", golpe)
		equipamento.visible = false
		_equipamentos.append(equipamento)
	_arma_costas = Sprite2D.new()
	_arma_costas.texture = load(RAIZ+"espada_base_cartoon.png")
	_arma_costas.centered = false
	_arma_costas.offset = Vector2(-474, -1350)
	_arma_costas.scale = _equipamentos[0].espada.scale*ESCALA
	_arma_costas.texture_filter = TEXTURE_FILTER_LINEAR
	add_child(_arma_costas)
	armadura = CamadaArmadura.new()
	corpo.add_child(armadura)
	armadura.configurar(corpo,int(get_tree().get_meta("armadura_cartoon_p2" if _jogador.eh_p2 else "armadura_cartoon_p1",0)))
	_jogador.acao_visual.connect(_ao_acao_visual)
	_process(0.0)

func usa_combo_espada() -> bool:
	return _jogador.usando_espada and _jogador.id_arma_atual == "espada_basica"

func fator_velocidade_movimento() -> float:
	return FATOR_VELOCIDADE_MOVIMENTO

func distancia_ciclo_corrida() -> float:
	return DISTANCIA_CICLO_NATIVA*ESCALA*absf(global_scale.x)/FATOR_RITMO_CORRIDA

## Na fazenda o F3 demonstra os golpes sem dano e sem gastar a ferramenta ativa.
func pedir_golpe_na_fazenda() -> void:
	if not _jogador.modo_fazenda or not _pode_mostrar():
		return
	if _golpe_demonstracao > 0:
		_fila_demonstracao = true
	else:
		_golpe_demonstracao = 1
		_tempo_demonstracao = 0.0
		_direcao_golpe = _jogador._cardinal_de(_jogador.direcao_apontada())
		get_node("/root/Sons").tocar("golpe_espada")

func _ao_acao_visual(acao: String, _duracao: float, _combo: int) -> void:
	if acao == "ataque":
		_direcao_golpe = _jogador._direcao_ataque

func _pode_mostrar() -> bool:
	if _jogador.estaMorto or _jogador.caido or _jogador.esta_sentado or _jogador.esta_forjando \
			or _jogador.esta_em_dash or _jogador.esta_em_acao_fazenda:
		return false
	if _jogador.no_reacao.visible or _jogador.no_arco.esta_disparando():
		return false
	if _jogador.defesa.em_guarda() or _jogador.defesa.escudando():
		return false
	var pesca = _jogador.get_node_or_null("AnimacaoPesca")
	if pesca != null and pesca.visible:
		return false
	return not _jogador._esta_atacando or usa_combo_espada()

static func quadro_golpe(instante: float) -> int:
	for q in 4:
		if instante < FIM_FASES[q]-0.000001:
			return q
	return 3

func _definir_recurso(arquivo: String, animacao: String) -> void:
	if not _recursos.has(arquivo):
		_recursos[arquivo] = load(RAIZ+arquivo+".tres")
	if corpo.sprite_frames != _recursos[arquivo] or corpo.animation != animacao:
		corpo.sprite_frames = _recursos[arquivo]
		corpo.animation = animacao
		corpo.stop()

func _process(delta: float) -> void:
	var distancia := _ultima_posicao.distance_to(_jogador.global_position)
	_ultima_posicao = _jogador.global_position
	# Transições/teletransportes não contam como passos.
	if distancia > 64.0:
		distancia = 0.0
		_distancia_corrida = 0.0
	visible = _pode_mostrar()
	if not visible:
		_distancia_corrida = 0.0
		_golpe_demonstracao = 0
		_fila_demonstracao = false
		return
	var original: CanvasItem = _jogador.get_node("CompositeSprites")
	modulate = original.modulate*original.self_modulate
	if _golpe_demonstracao > 0:
		_tempo_demonstracao += delta
		if _tempo_demonstracao >= DURACAO_GOLPE:
			if _fila_demonstracao:
				_golpe_demonstracao = _golpe_demonstracao % 2+1
				_tempo_demonstracao -= DURACAO_GOLPE
				_fila_demonstracao = false
				get_node("/root/Sons").tocar("golpe_espada")
			else:
				_golpe_demonstracao = 0
	var golpe := _golpe_demonstracao
	var instante := _tempo_demonstracao
	if _jogador._esta_atacando and usa_combo_espada():
		golpe = clampi(_jogador._fase_combo, 1, 2)
		instante = DURACAO_GOLPE*(1.0-_jogador._temporizador.time_left/_jogador._temporizador.wait_time)
	var vetor: Vector2 = _direcao_golpe if golpe > 0 else _jogador._direcao_ataque
	var direcao := "frente"
	if absf(vetor.x) > absf(vetor.y):
		direcao = "esquerda" if vetor.x < 0 else "direita"
	elif vetor.y < 0:
		direcao = "costas"
	var acao := "espada%d" % golpe if golpe > 0 else ("correr" if _jogador.velocity.length() > 2.0 else "parado")
	if acao != "correr" or acao_atual != "correr":
		_distancia_corrida = 0.0
	if acao == "correr":
		_distancia_corrida += distancia
	acao_atual = acao
	direcao_atual = direcao
	for equipamento in _equipamentos:
		equipamento.visible = false
	if golpe > 0:
		var fonte: String = {"frente": "baixo", "costas": "cima", "direita": "direita", "esquerda": "direita"}[direcao]
		var nome := ("ataque2_" if golpe == 2 else "ataque_")+fonte
		_definir_recurso(nome+"_sem_arma", nome)
		corpo.offset = Vector2(-280 if fonte == "direita" else -320, -850)
		corpo.scale = Vector2(-ESCALA if direcao == "esquerda" else ESCALA, ESCALA)
		corpo.frame = quadro_golpe(instante)
		var equipamento = _equipamentos[golpe-1]
		equipamento.visible = true
		equipamento.definir_direcao(fonte)
	else:
		_definir_recurso("corrida_quatro_direcoes" if acao == "correr" else "parado_quatro_direcoes", acao+"_"+direcao)
		corpo.offset = Vector2(-256 if acao == "correr" else -320, -850)
		corpo.scale = Vector2.ONE*ESCALA
		if acao == "correr":
			corpo.frame = int(fposmod(_distancia_corrida/distancia_ciclo_corrida(), 1.0)*4.0)
	_arma_costas.visible = golpe == 0 and (_jogador.modo_fazenda or usa_combo_espada())
	_atualizar_arma_costas()
	armadura.atualizar()
	for equipamento in _equipamentos:
		if equipamento.visible: equipamento.atualizar()

func _atualizar_arma_costas() -> void:
	var esquerda := direcao_atual == "esquerda"
	var perfil := direcao_atual in ["direita", "esquerda"]
	var encaixe := encaixe_perfil_parado if perfil else Vector2(-3, -21)
	var angulo := deg_to_rad(angulo_perfil if perfil else 225.0)
	if acao_atual == "correr":
		var eixos: Array = EIXOS_TRONCO_CORRIDA["direita" if perfil else direcao_atual]
		var eixo: Vector4 = eixos[corpo.frame]
		var ombros := Vector2(eixo.x, eixo.y)
		var cintura := Vector2(eixo.z, eixo.w)
		var inclinacao := Vector2.UP.angle_to(ombros-cintura)
		var apoio := apoio_perfil if perfil else Vector2(-75, -25)
		encaixe = (ombros+apoio.rotated(inclinacao)-Vector2(256,850))*ESCALA
		angulo += inclinacao
		if esquerda:
			# O atlas esquerdo espelha a célula inteira (x → 511-x).
			encaixe.x = -encaixe.x-ESCALA
	elif esquerda:
		encaixe.x = -encaixe.x
	_arma_costas.position = encaixe
	_arma_costas.rotation = -angulo if esquerda else angulo
	_arma_costas.scale = Vector2(-1 if esquerda else 1,1)*_equipamentos[0].espada.scale*ESCALA
	_arma_costas.z_index = 1 if direcao_atual == "costas" else -1
