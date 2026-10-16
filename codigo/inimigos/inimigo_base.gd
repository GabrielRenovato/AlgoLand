extends CharacterBody2D
class_name InimigoBase

const EfeitosLuz := preload("res://codigo/efeitos/efeitos_luz.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const SementeDrop := preload("res://codigo/logica/semente_drop.gd")
const NavegacaoArena := preload("res://codigo/logica/navegacao_arena.gd")

# -----------------------------
# CONFIGURAÇÕES DE MOVIMENTO
# -----------------------------
@export var velocidade: int = 50
@export var aceleracao: float = 400.0
# Perto do centro do jogador o slime para de empurrar na direção dele
@export var raio_parada: float = 4.0
@export var desaceleracao_knockback: float = 900.0
# O slime tem cerca de 17 px; um alcance maior fazia a multidão se afastar demais
@export var alcance_separacao: float = 18.0
# Os inimigos não colidem mais entre si (máscara só do mundo): a separação é o que evita o empilhamento
@export var forca_separacao: float = 60.0
var ultima_direcao_horizontal: float = 1.0  # 1 para direita, -1 para esquerda
## Distância da origem até os pés do sprite, usada na ordem de desenho (ver Profundidade)
@export var altura_pes: float = 5.0

# -----------------------------
# CONFIGURAÇÕES DE ATAQUE
# -----------------------------
@export var tempo_recarga_ataque: float = 1.8
@export var alcance_ataque: float = 20.0   # Distância mínima para disparar a animação de ataque
var pode_atacar: bool = true
@export var dano: float = 12.0

# -----------------------------
# VARIÁVEIS DE VIDA
# -----------------------------
@export var vida: int = 30
@export var usar_barra_vida: bool = true
## Distância da origem até a barra de vida (acima da cabeça do sprite)
@export var altura_barra_vida: float = 22.0
var esta_morto: bool = false

# -----------------------------
# ESTADOS
# -----------------------------
var esta_recuando: bool = false
var esta_atacando: bool = false

# -----------------------------
# NÓS DE ANIMAÇÃO E COLISÃO
# -----------------------------
# Opcionais: o golem anima o Sprite2D por código e não tem AnimationTree
@onready var arvore_animacao: AnimationTree = get_node_or_null("AnimationTree")
@onready var estado_animacao = arvore_animacao.get("parameters/playback") if arvore_animacao else null
@onready var posicao_blend = arvore_animacao.get("parameters/run/blend_position") if arvore_animacao else Vector2.ZERO
@onready var sprite = $Texture  # Nó do sprite para efeito de piscar

var _jogador_cache: Node2D

# Navegação (só inimigos de chão)
const INTERVALO_ROTA := 0.25
const DISTANCIA_PERSEGUICAO_DIRETA := 24.0
var _agente: NavigationAgent2D
var _tempo_rota := 0.0
# Anti-travamento: se anda para um lado e a parede o segura, escorrega ao longo dela por um instante (ver _vigiar_travamento)
const TEMPO_PARADO_PARA_DESVIAR := 0.45
const TEMPO_DESVIO := 0.7
var _tempo_parado := 0.0
var _desvio_restante := 0.0
var _desvio_direcao := Vector2.ZERO
var _sinal_desvio := 1.0
var _ultimo_desvio_ms := -100000
# Sem rota para o tamanho do corpo (largou num bolsão apertado demais): depois de um tempo usa a malha dos corpos pequenos
var _tempo_sem_rota := 0.0

const COR_QUEIMANDO := Color(1.0, 0.65, 0.45)
const COR_CONGELADO := Color(0.6, 0.85, 1.0)
const COR_ATORDOADO := Color(1.0, 0.95, 0.55)

# -----------------------------
# VARIANTE MUTANTE
# -----------------------------
# Versão maior e mais forte de qualquer inimigo, sorteada pelo spawner nas ondas mais altas
const MUTANTE_ESCALA := 1.55
const MUTANTE_MULT_VIDA := 1.9
const MUTANTE_MULT_DANO := 1.35
const CoroaMutante := preload("res://codigo/efeitos/coroa_mutante.gd")
var eh_mutante: bool = false

func tornar_mutante() -> void:
	if eh_mutante or eh_chefe:
		return
	eh_mutante = true
	vida = roundi(vida * MUTANTE_MULT_VIDA)
	dano *= MUTANTE_MULT_DANO
	_aplicar_escala(MUTANTE_ESCALA)
	# Mantém a cor original; a coroa cinza acima da barra de vida identifica o mutante
	_adicionar_coroa(CoroaMutante.PALETA_CINZA, MUTANTE_ESCALA)

# A escala do nó já aumenta sprite e colisão; as distâncias medidas em coordenadas globais acompanham
# (ordem de desenho pelos pés, alcance de ataque, parada e separação). A barra e a coroa ficam em
# coordenadas locais e crescem junto com o nó
func _aplicar_escala(escala: float) -> void:
	scale *= escala
	_ajustar_agente()
	altura_pes *= escala
	alcance_ataque *= escala
	raio_parada *= escala
	alcance_separacao *= escala

func _adicionar_coroa(paleta: Dictionary, tamanho: float, altura: float = -1.0) -> void:
	var coroa := CoroaMutante.new()
	coroa.name = "CoroaMutante"
	coroa.paleta = paleta
	coroa.position = Vector2(0, -(altura_barra_vida + 4 if altura < 0.0 else altura))
	# Compensa a escala do nó para o tamanho do desenho não depender do tamanho do inimigo
	coroa.scale = Vector2.ONE * tamanho / maxf(scale.x, 0.01)
	add_child(coroa)

# -----------------------------
# VARIANTE CHEFE
# -----------------------------
# Qualquer espécie vira chefe: maior, com muita vida, barra no HUD (como o Golem), coroa dourada e,
# opcionalmente, uma habilidade própria (ver habilidade_chefe.gd)
const CHEFE_RESISTENCIA_KNOCKBACK := 0.08
const CHEFE_RECOMPENSA_MOEDAS := 250
const HabilidadeChefe := preload("res://codigo/inimigos/habilidade_chefe.gd")
var eh_chefe: bool = false
var nome_chefe: String = ""
var vida_maxima: int = 0
var recompensa_chefe: int = CHEFE_RECOMPENSA_MOEDAS
var habilidade_chefe: Node = null
var _chefe_encerrado: bool = false
## Invocado por um chefe: não conta na onda, não dá ouro nem Brasas e some quando o chefe morre
var eh_lacaio: bool = false

## Chamar antes de entrar na árvore e antes de o spawner aplicar os multiplicadores da onda
## altura_coroa: distância (em coordenadas locais) da origem até o alto da cabeça; -1 usa a da barra de vida
func tornar_chefe(nome: String, escala: float, mult_vida: float, mult_dano: float = 1.0, tipo_habilidade: String = "", altura_coroa: float = -1.0) -> void:
	if eh_chefe:
		return
	eh_chefe = true
	nome_chefe = nome
	vida = roundi(vida * mult_vida)
	dano *= mult_dano
	# A vida aparece no HUD, não na barrinha sobre a cabeça
	usar_barra_vida = false
	if has_node("HPBar"):
		get_node("HPBar").queue_free()
	_aplicar_escala(escala)
	_adicionar_coroa(CoroaMutante.PALETA_DOURADA, 1.4, altura_coroa)
	if tipo_habilidade != "":
		var habilidade := HabilidadeChefe.new()
		habilidade.name = "HabilidadeChefe"
		habilidade.tipo = tipo_habilidade
		add_child(habilidade)
		habilidade_chefe = habilidade

## Os lacaios são inimigos comuns fora da contagem da onda
func tornar_lacaio() -> void:
	eh_lacaio = true

func _iniciar_chefe() -> void:
	vida_maxima = vida
	Sons.tocar("chefe_aparece", 0.0)
	get_tree().call_group("hud", "mostrar_chefe", nome_chefe, vida, vida_maxima)

func _avisar_vida_chefe() -> void:
	get_tree().call_group("hud", "atualizar_chefe", maxi(vida, 0), vida_maxima)
	if habilidade_chefe != null and vida > 0:
		habilidade_chefe.ao_vida_mudou(vida, vida_maxima)

## Som da morte: o chefe tem o seu; lacaios invocados morrem em silêncio para não encher a luta de barulho
func _tocar_som_morte() -> void:
	if eh_chefe:
		Sons.tocar("chefe_morre", 0.0)
	elif not eh_lacaio:
		Sons.tocar("inimigo_morre", 0.12)

# Chamado por morrer() (cada espécie tem o seu): recompensa, progresso, HUD e fim das habilidades
func _ao_morrer_chefe() -> void:
	if not eh_chefe or _chefe_encerrado:
		return
	_chefe_encerrado = true
	if habilidade_chefe != null:
		habilidade_chefe.encerrar()
	DadosJogo.adicionar_moedas(recompensa_chefe)
	_registrar_chefe_no_progresso()
	get_tree().call_group("hud", "esconder_chefe")
	_tremer_camera(4.0, 0.4)

# O chefe derrotado vale Brasas e libera o checkpoint da Mística, mesmo que o jogador caia antes do fim da onda
func _registrar_chefe_no_progresso() -> void:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null:
		Progresso.registrar_chefe(gerenciador.onda_atual)

func _tremer_camera(intensidade: float, duracao: float) -> void:
	var jogador := obter_jogador()
	var camera: Camera2D = jogador.get_node_or_null("Camera2D") if jogador else null
	if camera == null:
		return
	var tween := camera.create_tween()
	var passos := 6
	for i in passos:
		var forca := intensidade * (1.0 - float(i) / passos)
		tween.tween_property(camera, "offset", Vector2(randf_range(-forca, forca), randf_range(-forca, forca)), duracao / passos)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)

var _queimadura_restante := 0.0
var _queimadura_dano := 0
var _queimadura_intervalo := 0.5
var _queimadura_acumulado := 0.0
var _queimadura_cor := Color.WHITE
var _lentidao := 0.0
var _lentidao_restante := 0.0
var _congelado_restante := 0.0
var _arvore_ativa_antes_gelo := false
var _efeito_gelo: Node2D
## Atordoado (aparo perfeito e escudada do jogador): fica parado, sem atacar nem dar dano de contato. Chefes não atordoam
var _atordoado := 0.0

signal atingiu_jogador
signal inimigo_morreu

func _ready() -> void:
	if arvore_animacao:
		arvore_animacao.active = true
		definir_animacao("run")

	# Chefes mostram a vida no HUD em vez da barrinha sobre a cabeça
	if usar_barra_vida and not has_node("HPBar"):
		var cena_barra_hp = preload("res://cenas/barra_de_vida.tscn")
		var instancia_barra_hp = cena_barra_hp.instantiate()
		instancia_barra_hp.name = "HPBar"
		add_child(instancia_barra_hp)
		instancia_barra_hp.position = Vector2(0, -altura_barra_vida)

	if eh_chefe:
		_iniciar_chefe()

	# Inimigos de chão seguem a malha de navegação da arena para contornar lago, fogueira, pedras...
	# Voadores (máscara 0) passam por cima de tudo e continuam indo em linha reta
	if collision_mask != 0:
		_agente = NavigationAgent2D.new()
		_agente.path_desired_distance = 8.0
		_agente.target_desired_distance = 6.0
		add_child(_agente)
		_ajustar_agente()

func _physics_process(delta: float) -> void:
	if esta_morto:
		return
	_atualizar_efeitos(delta)
	if esta_morto:
		return
	_atualizar_ordem_desenho()
	if esta_congelado():
		velocity = Vector2.ZERO
		return

	if _atordoado > 0.0:
		_atordoado -= delta
		velocity = velocity.move_toward(Vector2.ZERO, desaceleracao_knockback * delta)
		move_and_slide()
		return

	# Investida e conjurações do chefe: a habilidade comanda o corpo enquanto durarem
	if habilidade_chefe != null and habilidade_chefe.assumiu_movimento():
		habilidade_chefe.mover(delta)
		return

	if esta_recuando:
		velocity = velocity.move_toward(Vector2.ZERO, desaceleracao_knockback * delta)
		move_and_slide()
		return

	var desejada := calcular_separacao()
	var alvo := obter_jogador()
	if alvo:
		var para_alvo := alvo.global_position - global_position
		if para_alvo.length() > raio_parada:
			var rumo := _direcao_ate(alvo, para_alvo, delta)
			if _desvio_restante > 0.0:
				_desvio_restante -= delta
				rumo = _desvio_direcao
			desejada += rumo * velocidade * (1.0 - _lentidao)
			_alvo_do_rumo = para_alvo.normalized()
	velocity = velocity.move_toward(desejada, aceleracao * delta)
	if velocity.length() > 1.0:
		definir_direcao_animacao(velocity)
	move_and_slide()
	_vigiar_travamento(delta, desejada)
	aplicar_dano_contato()

var _alvo_do_rumo := Vector2.ZERO

## Classe de navegação do corpo (0 = comum, 1 = médio, 2 = grande): a malha da arena tem uma por tamanho (ver navegacao_arena.gd). Conta
## a metade do lado maior do retângulo do corpo (ele não gira) vezes a escala: mutantes, o golem e os chefes são maiores que o comum
func classe_de_navegacao() -> int:
	var meio := NavegacaoArena.RAIOS_AGENTE[0]
	var corpo := get_node_or_null("colision_body") as CollisionShape2D
	if corpo != null and corpo.shape is RectangleShape2D:
		meio = maxf(corpo.shape.size.x, corpo.shape.size.y) * 0.5 * maxf(absf(scale.x), absf(scale.y))
	elif corpo != null and corpo.shape is CircleShape2D:
		meio = corpo.shape.radius * maxf(absf(scale.x), absf(scale.y))
	for i in NavegacaoArena.RAIOS_AGENTE.size():
		if meio <= NavegacaoArena.RAIOS_AGENTE[i] + 0.5:
			return i
	return NavegacaoArena.RAIOS_AGENTE.size() - 1

# Põe o agente na camada de navegação do tamanho do corpo (chamar de novo se a escala mudar)
func _ajustar_agente() -> void:
	if _agente == null:
		return
	var classe := classe_de_navegacao()
	_agente.navigation_layers = 1 << classe
	_agente.radius = NavegacaoArena.RAIOS_AGENTE[classe]
	_agente.path_desired_distance = maxf(8.0, NavegacaoArena.RAIOS_AGENTE[classe] * 0.6)

# O corpo quer andar mas quase não sai do lugar (encostado numa árvore, pedra, fogueira...): depois de um instante escorrega ao longo da
# parede (tangente à superfície em que bateu, para o lado do jogador) por TEMPO_DESVIO; de novo em seguida, troca de lado
func _vigiar_travamento(delta: float, desejada: Vector2) -> void:
	var quer := desejada.length() > velocidade * 0.4
	var andou := get_real_velocity().length()
	if not quer or andou > desejada.length() * 0.3 or esta_recuando or _desvio_restante > 0.0:
		_tempo_parado = maxf(_tempo_parado - delta * 2.0, 0.0)
		return
	_tempo_parado += delta
	if _tempo_parado < TEMPO_PARADO_PARA_DESVIAR or get_slide_collision_count() == 0:
		return
	var normal := get_slide_collision(0).get_normal()
	var tangente := normal.orthogonal()
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_desvio_ms < 2500:
		_sinal_desvio = -_sinal_desvio   # o lado de antes não resolveu: tenta o outro
	else:
		_sinal_desvio = 1.0 if tangente.dot(_alvo_do_rumo) >= 0.0 else -1.0
	_ultimo_desvio_ms = agora
	_desvio_direcao = (tangente * _sinal_desvio + normal * 0.35).normalized()
	_desvio_restante = TEMPO_DESVIO
	_tempo_parado = 0.0

# Direção do próximo ponto da rota até o jogador. Sem malha (tela inicial), sem rota ou já perto (e sem obstáculo no meio),
# volta à perseguição direta
func _direcao_ate(alvo: Node2D, para_alvo: Vector2, delta: float) -> Vector2:
	var direta := para_alvo.normalized()
	if _agente == null:
		return direta
	if para_alvo.length() < DISTANCIA_PERSEGUICAO_DIRETA and not test_move(global_transform, direta * minf(para_alvo.length(), DISTANCIA_PERSEGUICAO_DIRETA)):
		return direta
	_tempo_rota -= delta
	if _tempo_rota <= 0.0:
		_tempo_rota = INTERVALO_ROTA
		_agente.target_position = alvo.global_position
	if _agente.is_navigation_finished():
		# "Chegou" longe do jogador = sem rota para este tamanho: passa para a malha dos corpos pequenos
		if para_alvo.length() > 3.0 * DISTANCIA_PERSEGUICAO_DIRETA:
			_tempo_sem_rota += delta
			if _tempo_sem_rota > 1.0 and _agente.navigation_layers != 1:
				_agente.navigation_layers = 1
				_tempo_sem_rota = 0.0
		return direta
	_tempo_sem_rota = 0.0
	var ate_proximo := _agente.get_next_path_position() - global_position
	return ate_proximo.normalized() if ate_proximo.length() > 0.5 else direta

# Quem está mais abaixo na tela é desenhado na frente (jogador, árvores e objetos usam a mesma escala)
func _atualizar_ordem_desenho() -> void:
	z_index = Profundidade.z_de(global_position.y + altura_pes)

func calcular_separacao() -> Vector2:
	var vetor_repulsao := Vector2.ZERO
	for outro in get_tree().get_nodes_in_group("enemy"):
		if outro == self:
			continue
		var diff: Vector2 = global_position - outro.global_position
		var dist := diff.length()
		if dist >= alcance_separacao:
			continue
		# Slimes sobrepostos têm diff zero: sem um empurrão aleatório a normalização gera NaN
		if dist < 0.01:
			vetor_repulsao += Vector2.from_angle(randf() * TAU)
			continue
		vetor_repulsao += (diff / dist) * (1.0 - dist / alcance_separacao)
	return (vetor_repulsao * forca_separacao).limit_length(forca_separacao)

# Os i-frames do jogador impedem dano a cada frame e o empilhamento de vários slimes
func aplicar_dano_contato() -> void:
	var jogador := obter_jogador()
	if not jogador or esta_atordoado():
		return
	# O corpo do jogador é só o círculo dos pés; o dano é contra a AreaDano, do tamanho do personagem
	# Qualquer jogador encostado leva o dano (no cooperativo, não só o alvo)
	for area in $ataque.get_overlapping_areas():
		var tocado: Node = area.get_parent()
		if tocado == jogador or (tocado != null and tocado.is_in_group("jogadores") and not bool(tocado.get("estaMorto"))):
			if not tocado.invulneravel:
				atingiu_jogador.emit()
			tocado.receber_dano(obter_dano(), (tocado.global_position - global_position).normalized() * 150.0)
			return

func receber_dano(quantidade_dano: int, forca_knockback: Vector2 = Vector2.ZERO) -> void:
	if esta_morto:
		return

	vida -= quantidade_dano

	gerar_rotulo_dano(quantidade_dano)

	if has_node("HPBar"):
		get_node("HPBar").atualizar_barra(vida)
	if eh_chefe:
		_avisar_vida_chefe()

	if vida <= 0:
		morrer()
		return

	Sons.tocar("acerto", 0.12, -2.0 if eh_chefe else 0.0)
	if not esta_atacando:
		definir_animacao("run")

	if forca_knockback == Vector2.ZERO:
		var jogador := obter_jogador()
		if jogador:
			forca_knockback = (global_position - jogador.global_position).normalized() * 300.0
	if eh_chefe:
		forca_knockback *= CHEFE_RESISTENCIA_KNOCKBACK

	# A velocidade decai no _physics_process, então o slime não desliza em linha reta
	esta_recuando = true
	velocity = forca_knockback

	await get_tree().create_timer(0.2).timeout
	esta_recuando = false

	piscar_dano()

	await get_tree().create_timer(0.5).timeout
	if not esta_atacando:
		definir_animacao("run")

# Dano de encantamento (queimadura, raio): sem knockback nem piscar, senão o slime trava a cada tick
func receber_dano_efeito(quantidade_dano: int, cor: Color) -> void:
	if esta_morto:
		return
	vida -= quantidade_dano
	gerar_rotulo_dano(quantidade_dano, cor)
	if has_node("HPBar"):
		get_node("HPBar").atualizar_barra(vida)
	if eh_chefe:
		_avisar_vida_chefe()
	if vida <= 0:
		morrer()

func aplicar_queimadura(dano_tick: int, intervalo: float, duracao: float, cor: Color) -> void:
	_queimadura_dano = dano_tick
	_queimadura_intervalo = intervalo
	_queimadura_restante = duracao
	_queimadura_cor = cor

## Deixa o inimigo parado e inofensivo por `duracao` segundos. Chefes (os que viraram chefe e o golem) ignoram
func atordoar(duracao: float) -> void:
	if esta_morto or SementeDrop.eh_chefe(self):
		return
	_atordoado = maxf(_atordoado, duracao)

## Empurra o inimigo sem dano (o aparo perfeito do jogador). Chefes mal se mexem
func empurrar(forca: Vector2, duracao: float = 0.2) -> void:
	if esta_morto:
		return
	if SementeDrop.eh_chefe(self):
		forca *= 0.1
	esta_recuando = true
	velocity = forca
	await get_tree().create_timer(duracao).timeout
	esta_recuando = false

func esta_atordoado() -> bool:
	return _atordoado > 0.0 or esta_congelado()

func esta_congelado() -> bool:
	return _congelado_restante > 0.0

func aplicar_congelamento(duracao: float) -> void:
	if esta_morto or duracao <= 0:
		return
	if not esta_congelado() and arvore_animacao:
		_arvore_ativa_antes_gelo = arvore_animacao.active
		arvore_animacao.active = false
	_congelado_restante = maxf(_congelado_restante, duracao)
	velocity = Vector2.ZERO
	if not is_instance_valid(_efeito_gelo):
		_efeito_gelo = load("res://codigo/efeitos/congelamento.gd").new()
		_efeito_gelo.name = "GeloMordomo"
		add_child(_efeito_gelo)
	else:
		_efeito_gelo.renovar()
	sprite.modulate = Color(COR_CONGELADO, sprite.modulate.a)

func _descongelar() -> void:
	_congelado_restante = 0.0
	if arvore_animacao:
		arvore_animacao.active = _arvore_ativa_antes_gelo
	if is_instance_valid(_efeito_gelo):
		_efeito_gelo.descongelar()

func _limpar_gelo_morte() -> void:
	if esta_congelado():
		_descongelar()
	if is_instance_valid(_efeito_gelo):
		_efeito_gelo.queue_free()
	sprite.modulate = Color(Color.WHITE, sprite.modulate.a)

func aplicar_lentidao(fracao: float, duracao: float) -> void:
	_lentidao = maxf(_lentidao, fracao)
	_lentidao_restante = duracao

func _atualizar_efeitos(delta: float) -> void:
	if esta_congelado():
		_congelado_restante = maxf(0.0, _congelado_restante - delta)
		if not esta_congelado():
			_descongelar()
	if _lentidao_restante > 0.0:
		_lentidao_restante -= delta
		if _lentidao_restante <= 0.0:
			_lentidao = 0.0
	if _queimadura_restante > 0.0:
		_queimadura_restante -= delta
		_queimadura_acumulado += delta
		if _queimadura_acumulado >= _queimadura_intervalo:
			_queimadura_acumulado -= _queimadura_intervalo
			receber_dano_efeito(_queimadura_dano, _queimadura_cor)
	var tom := Color.WHITE
	if esta_congelado():
		tom = COR_CONGELADO
	elif _queimadura_restante > 0.0:
		tom = COR_QUEIMANDO
	elif _lentidao_restante > 0.0:
		tom = COR_CONGELADO
	elif _atordoado > 0.0:
		tom = COR_ATORDOADO
	sprite.modulate = Color(tom, sprite.modulate.a)

func piscar_dano() -> void:
	for i in range(5):
		sprite.modulate.a = 0.3
		await get_tree().create_timer(0.1).timeout
		sprite.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout

func morrer() -> void:
	if esta_morto:
		return
	esta_morto = true
	_limpar_gelo_morte()
	_tocar_som_morte()
	_ao_morrer_chefe()
	EfeitosLuz.criar_flash(get_tree().current_scene, global_position, Color(0.6, 1.0, 0.6), 1.4, 0.9, 0.35)
	definir_animacao("dead")
	await get_tree().create_timer(0.2).timeout
	emit_signal("inimigo_morreu")
	queue_free()

func definir_animacao(nome_animacao: String) -> void:
	if not arvore_animacao or not estado_animacao:
		return
	if estado_animacao.get_current_node() == nome_animacao:
		return
	estado_animacao.travel(nome_animacao)

func definir_direcao_animacao(dir: Vector2) -> void:
	if not arvore_animacao:
		return
	if dir.x < 0:
		ultima_direcao_horizontal = -1.0
	elif dir.x > 0:
		ultima_direcao_horizontal = 1.0

	posicao_blend.x = ultima_direcao_horizontal
	posicao_blend.y = 0
	arvore_animacao.set("parameters/run/blend_position", posicao_blend)

func obter_dano() -> int:
	return int(dano)

## Alvo: o jogador de pé mais próximo (no cooperativo são dois), revisto a cada meio segundo para não ficar trocando
var _proxima_escolha_alvo := 0
func obter_jogador() -> Node2D:
	var agora := Time.get_ticks_msec()
	if agora >= _proxima_escolha_alvo or not is_instance_valid(_jogador_cache) or bool(_jogador_cache.get("estaMorto")):
		_proxima_escolha_alvo = agora + 500
		var melhor: Node2D = null
		var menor := INF
		for jogador in get_tree().get_nodes_in_group("jogadores"):
			if not (jogador is Node2D) or bool(jogador.get("estaMorto")):
				continue
			var distancia := global_position.distance_squared_to(jogador.global_position)
			if distancia < menor:
				menor = distancia
				melhor = jogador
		if melhor == null:
			melhor = get_tree().current_scene.get_node_or_null("Jogador")
		_jogador_cache = melhor
	return _jogador_cache

# -------------------------------------------------
# FUNÇÃO PARA CRIAR O TEXTO DE DANO ACIMA DO INIMIGO
# -------------------------------------------------
func gerar_rotulo_dano(valor_dano: int, cor: Color = Color.WHITE) -> void:
	var cena_rotulo = preload("res://cenas/dano_flutuante.tscn")
	var instancia_rotulo = cena_rotulo.instantiate()

	instancia_rotulo.global_position = global_position - Vector2(0, 20.0 * maxf(scale.y, 1.0))

	instancia_rotulo.definir_dano(valor_dano, cor)

	get_tree().current_scene.add_child(instancia_rotulo)
