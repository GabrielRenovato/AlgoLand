extends Sprite2D
## Prévia jogável da base NPC: parado, corrida e espada nas quatro direções.
const RAIZ := "res://assets/personagens/base_vila_nativa/"
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var _jogador: Node2D
var _folhas := {}
var _acao := ""
var _linha := 0
var _tempo := 0.0
var _atacando := false

func _ready() -> void:
	name = "HeroiBaseVila"
	_jogador = get_parent()
	for acao in ["parado", "corrida", "espada"]:
		_folhas[acao] = load(RAIZ + acao + ".png")
	material = null
	texture_filter = TEXTURE_FILTER_NEAREST
	centered = false
	offset = Vector2(-40, -52)
	position.y = Profundidade.PES_JOGADOR
	z_index = 3
	process_priority = 130
	_process(0.0)

func _exit_tree() -> void:
	if is_instance_valid(_jogador):
		var original := _jogador.get_node_or_null("CompositeSprites") as CanvasItem
		if original != null:
			original.visible = true

func _process(delta: float) -> void:
	if not is_instance_valid(_jogador):
		return
	var original := _jogador.get_node("CompositeSprites") as CanvasItem
	var pesca := _jogador.has_node("SessaoPesca")
	var arco: bool = _jogador.usando_arco and _jogador.no_arco != null and _jogador.no_arco.esta_disparando()
	var reacao: bool = _jogador.no_reacao != null and _jogador.no_reacao.visible
	var sem_pose: bool = pesca or arco or reacao or _jogador.caido or _jogador.esta_em_dash
	sem_pose = sem_pose or _jogador.esta_forjando or _jogador.esta_sentado or _jogador.esta_em_acao_fazenda
	sem_pose = sem_pose or (_jogador._esta_atacando and not _jogador.usando_espada)
	var outro_visual := _jogador.has_node("HeroiGerado") or _jogador.has_node("HeroiTiny") or _jogador.has_node("HeroiCraftpix")
	if sem_pose or outro_visual:
		visible = false
		if not outro_visual:
			original.visible = not pesca
		_acao = ""
		_atacando = false
		return
	visible = true
	original.visible = false
	var atacando: bool = _jogador._esta_atacando and _jogador.usando_espada
	var acao := "espada" if atacando else ("corrida" if _jogador.velocity.length() > 2.0 else "parado")
	# A guarda usa o primeiro quadro da espada, sem inventar uma pose nova.
	if acao == "parado" and _jogador.usando_espada:
		acao = "espada"
	var direcao: Vector2 = _jogador._direcao_ataque
	var linha := 2 if direcao.y < 0 else 0
	if absf(direcao.x) > absf(direcao.y):
		linha = 3 if direcao.x < 0 else 1
	if acao != _acao or linha != _linha or atacando != _atacando:
		_tempo = 0.0
		frame = 0
		_acao = acao
		_linha = linha
		_atacando = atacando
		texture = _folhas[acao]
		hframes = 4 if acao == "parado" else 8
		vframes = 1 if acao == "parado" else 4
	_tempo += delta
	if acao == "parado":
		frame = linha
	elif acao == "corrida":
		frame = linha * 8 + int(fmod(_tempo, 0.8) / 0.1)
	elif not atacando:
		frame = linha * 8
	else:
		var progresso := clampf(_tempo / 1.2, 0.0, 0.999999)
		var temporizador: Timer = _jogador._temporizador
		if temporizador != null and not temporizador.is_stopped():
			progresso = clampf(1.0 - temporizador.time_left / temporizador.wait_time, 0.0, 0.999999)
		var instante := progresso * 1.2
		var coluna := 0 if instante < 0.5 else mini(7, 1 + int((instante - 0.5) / 0.1))
		frame = linha * 8 + coluna
