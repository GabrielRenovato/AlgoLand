extends CharacterBody2D
class_name InimigoBase

const EfeitosLuz := preload("res://Codigos/Efeitos/efeitos_luz.gd")
const Profundidade := preload("res://Codigos/Globais/profundidade.gd")

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

const COR_QUEIMANDO := Color(1.0, 0.65, 0.45)
const COR_CONGELADO := Color(0.6, 0.85, 1.0)

# -----------------------------
# VARIANTE MUTANTE
# -----------------------------
# Versão maior e mais forte de qualquer inimigo, sorteada pelo spawner nas ondas mais altas
const MUTANTE_ESCALA := 1.55
const MUTANTE_MULT_VIDA := 1.9
const MUTANTE_MULT_DANO := 1.35
const CoroaMutante := preload("res://Codigos/Efeitos/coroa_mutante.gd")
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
const HabilidadeChefe := preload("res://Codigos/Inimigos/habilidade_chefe.gd")
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

signal atingiu_jogador
signal inimigo_morreu

func _ready() -> void:
	if arvore_animacao:
		arvore_animacao.active = true
		definir_animacao("run")

	# Chefes mostram a vida no HUD em vez da barrinha sobre a cabeça
	if usar_barra_vida and not has_node("HPBar"):
		var cena_barra_hp = preload("res://cenas/barra-de-vida.tscn")
		var instancia_barra_hp = cena_barra_hp.instantiate()
		instancia_barra_hp.name = "HPBar"
		add_child(instancia_barra_hp)
		instancia_barra_hp.position = Vector2(0, -altura_barra_vida)

	if eh_chefe:
		_iniciar_chefe()

	# Inimigos de chão seguem a malha de navegação da arena para contornar lago, barraca, pedras...
	# Voadores (máscara 0) passam por cima de tudo e continuam indo em linha reta
	if collision_mask != 0:
		_agente = NavigationAgent2D.new()
		_agente.path_desired_distance = 8.0
		_agente.target_desired_distance = 6.0
		add_child(_agente)

func _physics_process(delta: float) -> void:
	if esta_morto:
		return
	_atualizar_efeitos(delta)
	if esta_morto:
		return
	_atualizar_ordem_desenho()

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
			desejada += _direcao_ate(alvo, para_alvo, delta) * velocidade * (1.0 - _lentidao)
	velocity = velocity.move_toward(desejada, aceleracao * delta)
	if velocity.length() > 1.0:
		definir_direcao_animacao(velocity)
	move_and_slide()
	aplicar_dano_contato()

# Direção do próximo ponto da rota até o jogador. Sem malha (tela inicial), sem rota ou já perto,
# volta à perseguição direta
func _direcao_ate(alvo: Node2D, para_alvo: Vector2, delta: float) -> Vector2:
	var direta := para_alvo.normalized()
	if _agente == null or para_alvo.length() < DISTANCIA_PERSEGUICAO_DIRETA:
		return direta
	_tempo_rota -= delta
	if _tempo_rota <= 0.0:
		_tempo_rota = INTERVALO_ROTA
		_agente.target_position = alvo.global_position
	if _agente.is_navigation_finished():
		return direta
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
	if not jogador:
		return
	# O corpo do jogador é só o círculo dos pés; o dano é contra a AreaDano, do tamanho do personagem
	for area in $ataque.get_overlapping_areas():
		if area.get_parent() == jogador:
			if not jogador.invulneravel:
				atingiu_jogador.emit()
			jogador.receber_dano(obter_dano(), (jogador.global_position - global_position).normalized() * 150.0)
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

func aplicar_lentidao(fracao: float, duracao: float) -> void:
	_lentidao = maxf(_lentidao, fracao)
	_lentidao_restante = duracao

func _atualizar_efeitos(delta: float) -> void:
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
	if _queimadura_restante > 0.0:
		tom = COR_QUEIMANDO
	elif _lentidao_restante > 0.0:
		tom = COR_CONGELADO
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

func obter_jogador() -> Node2D:
	if not is_instance_valid(_jogador_cache):
		_jogador_cache = get_tree().current_scene.get_node_or_null("Jogador")
	return _jogador_cache

# -------------------------------------------------
# FUNÇÃO PARA CRIAR O TEXTO DE DANO ACIMA DO INIMIGO
# -------------------------------------------------
func gerar_rotulo_dano(valor_dano: int, cor: Color = Color.WHITE) -> void:
	var cena_rotulo = preload("res://cenas/dano-flutuante.tscn")
	var instancia_rotulo = cena_rotulo.instantiate()

	instancia_rotulo.global_position = global_position - Vector2(0, 20.0 * maxf(scale.y, 1.0))

	instancia_rotulo.definir_dano(valor_dano, cor)

	get_tree().current_scene.add_child(instancia_rotulo)
