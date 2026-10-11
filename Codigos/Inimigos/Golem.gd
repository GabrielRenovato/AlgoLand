extends "Inimigo-base.gd"

const NOME := "GOLEM DE PEDRA"
# Folhas de 128x128 em 4 linhas: frente, costas, esquerda, direita
const LINHAS_DIRECAO := 4
const ANIMACOES := {
	"run": {"textura": preload("res://inimigos/golem/run/Golem1_Run_full.png"), "quadros": 8, "fps": 8.0, "repete": true},
	"attack": {"textura": preload("res://inimigos/golem/attack/Golem1_Attack_full.png"), "quadros": 9, "fps": 10.0, "repete": false},
	"dead": {"textura": preload("res://inimigos/golem/death/Golem1_Death_full.png"), "quadros": 8, "fps": 10.0, "repete": false},
}
# Quadro em que o punho bate no chão; os 5 anteriores (0,5s) são o aviso para o jogador sair com o dash
const QUADRO_IMPACTO := 5
# Empurrão recebido é uma fração do normal: o chefe não pode ser jogado longe
const RESISTENCIA_KNOCKBACK := 0.08
const IndicadorAtaqueScript := preload("res://Codigos/Efeitos/indicador_ataque.gd")

@export var dano_impacto: float = 25.0
@export var raio_impacto: float = 64.0
@export var forca_impacto: float = 260.0
@export var recompensa_moedas: int = 250

var _animacao := "run"
var _quadro := 0.0
var _linha := 0
var _atacando := false
var _impacto_feito := false
var _indicador: Node2D = null

func _ready() -> void:
	super()
	vida_maxima = vida
	_tocar("run")
	get_tree().call_group("hud", "mostrar_chefe", NOME, vida, vida_maxima)
	Sons.tocar("chefe_aparece", 0.0)

func _physics_process(delta: float) -> void:
	_animar(delta)
	if esta_morto:
		return
	if _atacando:
		_atualizar_efeitos(delta)
		_atualizar_ordem_desenho()
		velocity = Vector2.ZERO
		move_and_slide()
		aplicar_dano_contato()
		return
	super(delta)
	var alvo := obter_jogador()
	if alvo and pode_atacar and global_position.distance_to(alvo.global_position) < alcance_ataque:
		_iniciar_ataque(alvo)

func obter_dano_impacto() -> int:
	# O spawner multiplica "dano" pela onda; o impacto acompanha a mesma proporção
	return roundi(dano_impacto * dano / 15.0)

func receber_dano(quantidade_dano: int, forca_knockback: Vector2 = Vector2.ZERO) -> void:
	if esta_morto:
		return
	if forca_knockback == Vector2.ZERO:
		var jogador := obter_jogador()
		forca_knockback = (global_position - jogador.global_position).normalized() if jogador else Vector2.ZERO
	super(quantidade_dano, forca_knockback * RESISTENCIA_KNOCKBACK)
	_avisar_vida()

func receber_dano_efeito(quantidade_dano: int, cor: Color) -> void:
	super(quantidade_dano, cor)
	_avisar_vida()

func _avisar_vida() -> void:
	get_tree().call_group("hud", "atualizar_chefe", maxi(vida, 0), vida_maxima)

func gerar_rotulo_dano(valor_dano: int, cor: Color = Color.WHITE) -> void:
	var cena_rotulo = preload("res://cenas/dano-flutuante.tscn")
	var instancia_rotulo = cena_rotulo.instantiate()
	instancia_rotulo.global_position = global_position - Vector2(0, 52)
	instancia_rotulo.definir_dano(valor_dano, cor)
	get_tree().current_scene.add_child(instancia_rotulo)

func morrer() -> void:
	if esta_morto:
		return
	if is_instance_valid(_indicador):
		_indicador.cancelar()
		_indicador = null
	esta_morto = true
	_atacando = false
	velocity = Vector2.ZERO
	$colision_body.set_deferred("disabled", true)
	$ataque.set_deferred("monitoring", false)
	_tocar("dead")
	Sons.tocar("chefe_morre", 0.0)
	DadosJogo.adicionar_moedas(recompensa_moedas)
	_registrar_chefe_no_progresso()
	get_tree().call_group("hud", "esconder_chefe")
	_tremer_camera(4.0, 0.4)
	await get_tree().create_timer(1.2).timeout
	emit_signal("inimigo_morreu")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _exit_tree() -> void:
	if is_instance_valid(_indicador):
		_indicador.queue_free()
		_indicador = null

func definir_animacao(nome_animacao: String) -> void:
	# A base pede "run" depois de levar dano; durante o soco a animação não pode ser cortada
	if _atacando or esta_morto:
		return
	_tocar(nome_animacao)

func definir_direcao_animacao(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		_linha = 2 if dir.x < 0 else 3
	else:
		_linha = 0 if dir.y > 0 else 1

func _iniciar_ataque(alvo: Node2D) -> void:
	_atacando = true
	pode_atacar = false
	_impacto_feito = false
	definir_direcao_animacao(alvo.global_position - global_position)
	_tocar("attack")
	_iniciar_indicador_ataque()

func _iniciar_indicador_ataque() -> void:
	if is_instance_valid(_indicador):
		_indicador.queue_free()
		_indicador = null
	var ind := IndicadorAtaqueScript.new()
	var pai: Node = get_parent() if get_parent() else get_tree().current_scene
	if pai:
		pai.add_child(ind)
		ind.configurar(global_position, raio_impacto)
		_indicador = ind

func _impacto() -> void:
	_impacto_feito = true
	if is_instance_valid(_indicador):
		_indicador.detonar_impacto()
		_indicador = null
	_tremer_camera(3.0, 0.25)
	var jogador := obter_jogador()
	if jogador and global_position.distance_to(jogador.global_position) < raio_impacto:
		var direcao := (jogador.global_position - global_position).normalized()
		jogador.receber_dano(obter_dano_impacto(), direcao * forca_impacto)

func _fim_ataque() -> void:
	_atacando = false
	if is_instance_valid(_indicador):
		_indicador.cancelar()
		_indicador = null
	_tocar("run")
	await get_tree().create_timer(tempo_recarga_ataque).timeout
	pode_atacar = true

func _tocar(nome: String) -> void:
	if _animacao == nome and nome != "attack":
		return
	_animacao = nome
	_quadro = 0.0
	var dados: Dictionary = ANIMACOES[nome]
	sprite.texture = dados["textura"]
	sprite.hframes = dados["quadros"]
	sprite.vframes = LINHAS_DIRECAO
	_aplicar_quadro()

func _animar(delta: float) -> void:
	var dados: Dictionary = ANIMACOES[_animacao]
	var quadros: int = dados["quadros"]
	_quadro += dados["fps"] * delta
	if dados["repete"]:
		_quadro = fmod(_quadro, quadros)
	elif _quadro >= quadros:
		_quadro = quadros - 0.001
		if _animacao == "attack" and _atacando:
			_fim_ataque()
	if _animacao == "attack" and _atacando and not _impacto_feito:
		if is_instance_valid(_indicador):
			var prog := clampf(_quadro / float(QUADRO_IMPACTO), 0.0, 1.0)
			_indicador.atualizar_progresso(prog)
		if int(_quadro) >= QUADRO_IMPACTO:
			_impacto()
	_aplicar_quadro()

func _aplicar_quadro() -> void:
	var quadros: int = ANIMACOES[_animacao]["quadros"]
	sprite.frame = _linha * quadros + mini(int(_quadro), quadros - 1)
