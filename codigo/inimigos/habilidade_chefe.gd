extends Node
## Habilidade própria de um chefe (ver Inimigo-base.tornar_chefe), adicionada como nó filho dele.
## - rei_slime: a cada 25% de vida perdida solta 3 slimes ao redor
## - caranguejo: de tempos em tempos avisa (treme e pisca) e dispara uma investida na direção do jogador
## - cogumelo: explosão de esporos em área, com aviso no chão, e invocação periódica de cogumelos
## Os lacaios entram no grupo "enemy" (o jogador os acerta), mas não ligam o sinal inimigo_morreu ao
## gerenciador: não contam na onda, não dão ouro nem Brasas e somem junto com o chefe.

const TIPO_REI_SLIME := "rei_slime"
const TIPO_CARANGUEJO := "caranguejo"
const TIPO_COGUMELO := "cogumelo"

const IndicadorAtaqueScript := preload("res://codigo/efeitos/indicador_ataque.gd")
const EfeitosLuz := preload("res://codigo/efeitos/efeitos_luz.gd")
# As cenas dos lacaios carregam a base do inimigo, que pré-carrega este script: carregar em tempo de
# execução evita a referência circular
const CAMINHO_SLIME := "res://cenas/inimigos/slime.tscn"
const CAMINHO_COGUMELO := "res://cenas/inimigos/cogumelo.tscn"

@export var tipo: String = ""

# --- Rei Slime
const FRACAO_VIDA_POR_LEVA := 0.25
const SLIMES_POR_LEVA := 3
const RAIO_INVOCACAO := 34.0
## Os lacaios têm só uma fração da vida de um inimigo comum da mesma onda: são reforço, não o desafio
const FRACAO_VIDA_LACAIO := 0.6

# --- Caranguejo Colossal
const INTERVALO_INVESTIDA := 3.5
const PRIMEIRA_INVESTIDA := 2.5
const TEMPO_AVISO_INVESTIDA := 0.6
const DURACAO_INVESTIDA := 0.5
const VELOCIDADE_INVESTIDA := 230.0
const TEMPO_RECUPERACAO := 0.6
const ALCANCE_MAXIMO_INVESTIDA := 220.0
const COR_AVISO := Color(1.0, 0.45, 0.4)

# --- Cogumelo Ancião
const INTERVALO_INVOCACAO := 6.0
const PRIMEIRA_INVOCACAO := 3.5
const COGUMELOS_POR_INVOCACAO := 3
const MAX_LACAIOS := 6
const INTERVALO_ESPOROS := 4.5
const PRIMEIROS_ESPOROS := 2.0
const TEMPO_AVISO_ESPOROS := 1.0
const RAIO_ESPOROS := 78.0
const ALCANCE_GATILHO_ESPOROS := RAIO_ESPOROS
const MULT_DANO_ESPOROS := 1.7
const FORCA_ESPOROS := 220.0
const TEMPO_RECUPERACAO_ESPOROS := 0.4

enum Estado { LIVRE, AVISO, AGINDO, RECUPERANDO }

var estado: int = Estado.LIVRE
var lacaios: Array[Node2D] = []
var levas_soltas: int = 0

var _chefe: Node2D
var _tempo_restante := 0.0        # recarga da habilidade principal (investida / esporos)
var _tempo_invocacao := 0.0       # recarga da invocação do cogumelo
var _tempo_estado := 0.0
var _direcao := Vector2.DOWN
var _indicador: Node2D = null
var _encerrada := false
var _reposicao_sprite := Vector2.ZERO

func _ready() -> void:
	_chefe = get_parent() as Node2D
	match tipo:
		TIPO_CARANGUEJO:
			_tempo_restante = PRIMEIRA_INVESTIDA
		TIPO_COGUMELO:
			_tempo_restante = PRIMEIROS_ESPOROS
			_tempo_invocacao = PRIMEIRA_INVOCACAO

func _exit_tree() -> void:
	# parar_ondas() libera os inimigos sem passar por morrer(): o aviso no chão não pode ficar para trás
	if is_instance_valid(_indicador):
		_indicador.queue_free()
		_indicador = null

func _physics_process(delta: float) -> void:
	if _encerrada or _chefe == null or _chefe.esta_morto:
		return
	if _chefe.esta_congelado():
		return
	_limpar_lacaios_mortos()
	match tipo:
		TIPO_CARANGUEJO:
			_processar_caranguejo(delta)
		TIPO_COGUMELO:
			_processar_cogumelo(delta)

# -----------------------------
# Contrato com o Inimigo-base
# -----------------------------
## Enquanto verdadeiro o corpo do chefe é conduzido por mover() em vez da perseguição normal
func assumiu_movimento() -> bool:
	return estado != Estado.LIVRE and not _encerrada

func mover(delta: float) -> void:
	if tipo == TIPO_CARANGUEJO and estado == Estado.AGINDO:
		_chefe.velocity = _direcao * VELOCIDADE_INVESTIDA
	else:
		_chefe.velocity = _chefe.velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
	_chefe.move_and_slide()
	_chefe.aplicar_dano_contato()

## Chamado a cada mudança de vida do chefe
func ao_vida_mudou(vida: int, vida_maxima: int) -> void:
	if tipo != TIPO_REI_SLIME or _encerrada or vida_maxima <= 0:
		return
	var fracao := float(vida) / vida_maxima
	# Perdeu 25%, 50%, 75%: uma leva a cada limiar cruzado (vários de uma vez soltam várias levas)
	while levas_soltas < 3 and fracao <= 1.0 - FRACAO_VIDA_POR_LEVA * (levas_soltas + 1):
		levas_soltas += 1
		# O dano chega durante a física (golpes do jogador): criar corpos aí é proibido
		_soltar_slimes.call_deferred()

## Morte do chefe (ou fim das ondas): cancela avisos e derruba os lacaios
func encerrar() -> void:
	if _encerrada:
		return
	_encerrada = true
	estado = Estado.LIVRE
	_restaurar_corpo()
	if is_instance_valid(_indicador):
		_indicador.cancelar()
		_indicador = null
	for lacaio in lacaios:
		if is_instance_valid(lacaio) and not lacaio.esta_morto:
			lacaio.morrer()
	lacaios.clear()

# -----------------------------
# Rei Slime
# -----------------------------
func _soltar_slimes() -> void:
	if _encerrada or _chefe == null or _chefe.esta_morto:
		return
	if _chefe.esta_congelado():
		return
	for i in SLIMES_POR_LEVA:
		var angulo := TAU * (i + randf() * 0.4) / SLIMES_POR_LEVA
		_invocar(CAMINHO_SLIME, Vector2.from_angle(angulo) * RAIO_INVOCACAO * _chefe.scale.x * 0.6)
	EfeitosLuz.criar_flash(get_tree().current_scene, _chefe.global_position, Color(0.5, 1.0, 0.6), 1.2, 1.2, 0.4)

# -----------------------------
# Caranguejo Colossal
# -----------------------------
func _processar_caranguejo(delta: float) -> void:
	match estado:
		Estado.LIVRE:
			_tempo_restante -= delta
			if _tempo_restante <= 0.0:
				var alvo: Node2D = _chefe.obter_jogador()
				if alvo != null and _chefe.global_position.distance_to(alvo.global_position) <= ALCANCE_MAXIMO_INVESTIDA:
					iniciar_investida(alvo.global_position - _chefe.global_position)
		Estado.AVISO:
			_tempo_estado -= delta
			_tremer_corpo()
			if _tempo_estado <= 0.0:
				_restaurar_corpo()
				estado = Estado.AGINDO
				_tempo_estado = DURACAO_INVESTIDA
		Estado.AGINDO:
			_tempo_estado -= delta
			# Bateu no mundo (parede, pedra, lago): a investida acaba ali
			if _tempo_estado <= 0.0 or _chefe.get_slide_collision_count() > 0:
				estado = Estado.RECUPERANDO
				_tempo_estado = TEMPO_RECUPERACAO
		Estado.RECUPERANDO:
			_tempo_estado -= delta
			if _tempo_estado <= 0.0:
				estado = Estado.LIVRE
				_tempo_restante = INTERVALO_INVESTIDA

## A direção fica travada no início do aviso: dá tempo de o jogador sair do caminho
func iniciar_investida(direcao: Vector2) -> void:
	if estado != Estado.LIVRE or _encerrada:
		return
	_direcao = direcao.normalized() if direcao.length() > 0.01 else Vector2.DOWN
	estado = Estado.AVISO
	_tempo_estado = TEMPO_AVISO_INVESTIDA
	_chefe.definir_direcao_animacao(_direcao)
	_reposicao_sprite = _chefe.sprite.offset

# Pisca em vermelho e treme o sprite (o tom do sprite é reescrito por quadro; o do nó não)
func _tremer_corpo() -> void:
	var pulso := int(Time.get_ticks_msec() / 70) % 2 == 0
	_chefe.modulate = COR_AVISO if pulso else Color.WHITE
	_chefe.sprite.offset = _reposicao_sprite + Vector2(randf_range(-1.5, 1.5), randf_range(-0.6, 0.6))

func _restaurar_corpo() -> void:
	if _chefe == null or not is_instance_valid(_chefe):
		return
	_chefe.modulate = Color.WHITE
	if _chefe.sprite != null and tipo == TIPO_CARANGUEJO:
		_chefe.sprite.offset = _reposicao_sprite

# -----------------------------
# Cogumelo Ancião
# -----------------------------
func _processar_cogumelo(delta: float) -> void:
	_tempo_invocacao -= delta
	if _tempo_invocacao <= 0.0:
		_tempo_invocacao = INTERVALO_INVOCACAO
		invocar_cogumelos()
	match estado:
		Estado.LIVRE:
			_tempo_restante -= delta
			if _tempo_restante <= 0.0:
				var alvo: Node2D = _chefe.obter_jogador()
				if alvo != null and _chefe.global_position.distance_to(alvo.global_position) <= ALCANCE_GATILHO_ESPOROS:
					iniciar_esporos()
		Estado.AVISO:
			_tempo_estado -= delta
			if is_instance_valid(_indicador):
				_indicador.atualizar_progresso(1.0 - clampf(_tempo_estado / TEMPO_AVISO_ESPOROS, 0.0, 1.0))
			if _tempo_estado <= 0.0:
				_detonar_esporos()
		Estado.RECUPERANDO:
			_tempo_estado -= delta
			if _tempo_estado <= 0.0:
				estado = Estado.LIVRE
				_tempo_restante = INTERVALO_ESPOROS

func iniciar_esporos() -> void:
	if estado != Estado.LIVRE or _encerrada:
		return
	estado = Estado.AVISO
	_tempo_estado = TEMPO_AVISO_ESPOROS
	if is_instance_valid(_indicador):
		_indicador.queue_free()
	var ind := IndicadorAtaqueScript.new()
	var pai: Node = _chefe.get_parent() if _chefe.get_parent() else get_tree().current_scene
	pai.add_child(ind)
	ind.configurar(_chefe.global_position, RAIO_ESPOROS)
	_indicador = ind

func _detonar_esporos() -> void:
	if is_instance_valid(_indicador):
		_indicador.detonar_impacto()
		_indicador = null
	_chefe._tremer_camera(2.5, 0.2)
	for jogador in _chefe.jogadores_vivos():
		if _chefe.global_position.distance_to(jogador.global_position) < RAIO_ESPOROS:
			var direcao: Vector2 = (jogador.global_position - _chefe.global_position).normalized()
			jogador.receber_dano(roundi(_chefe.dano * MULT_DANO_ESPOROS), direcao * FORCA_ESPOROS)
	estado = Estado.RECUPERANDO
	_tempo_estado = TEMPO_RECUPERACAO_ESPOROS

func invocar_cogumelos() -> void:
	if _encerrada or _chefe == null or _chefe.esta_morto:
		return
	var espaco := MAX_LACAIOS - lacaios.size()
	for i in mini(COGUMELOS_POR_INVOCACAO, espaco):
		var angulo := TAU * (i + randf() * 0.4) / COGUMELOS_POR_INVOCACAO
		_invocar(CAMINHO_COGUMELO, Vector2.from_angle(angulo) * RAIO_INVOCACAO * _chefe.scale.x * 0.7)
	EfeitosLuz.criar_flash(get_tree().current_scene, _chefe.global_position, Color(0.8, 0.6, 1.0), 1.0, 1.2, 0.4)

# -----------------------------
# Lacaios
# -----------------------------
func _invocar(caminho_cena: String, deslocamento: Vector2) -> Node2D:
	var cena: PackedScene = load(caminho_cena)
	var lacaio: Node2D = cena.instantiate()
	lacaio.name = "Lacaio_" + str(randi() % 100000)
	lacaio.position = _chefe.global_position + deslocamento
	lacaio.tornar_lacaio()
	# Mesma regra do spawner: vida, dano e velocidade crescem com a onda
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null and is_instance_valid(gerenciador.gerador) and gerenciador.gerador.has_method("aplicar_atributos"):
		gerenciador.gerador.aplicar_atributos(lacaio, gerenciador.multiplicador_vida_inimigo, gerenciador.multiplicador_dano_inimigo)
	lacaio.vida = maxi(1, roundi(lacaio.vida * FRACAO_VIDA_LACAIO))
	var pai: Node = _chefe.get_parent() if _chefe.get_parent() else get_tree().current_scene
	pai.add_child(lacaio)
	if lacaio.has_node("HPBar"):
		var barra = lacaio.get_node("HPBar")
		barra.vida_maxima = lacaio.vida
		barra.definir_vida_atual(lacaio.vida)
	lacaio.add_to_group("enemy")
	lacaios.append(lacaio)
	return lacaio

func _limpar_lacaios_mortos() -> void:
	for i in range(lacaios.size() - 1, -1, -1):
		if not is_instance_valid(lacaios[i]) or lacaios[i].esta_morto:
			lacaios.remove_at(i)

func quantidade_lacaios() -> int:
	_limpar_lacaios_mortos()
	return lacaios.size()
