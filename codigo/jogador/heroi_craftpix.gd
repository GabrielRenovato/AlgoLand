extends Sprite2D
## Visual original CraftPix; ações ausentes retornam temporariamente à base existente.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var _jogador: Node2D
var _dados: Dictionary
var _texturas := {}
var _animacao := ""
var _direcao := ""
var _tempo := 0.0

func _ready() -> void:
	name = "HeroiCraftpix"
	_jogador = get_parent()
	_dados = JSON.parse_string(FileAccess.get_file_as_string("res://assets/personagens/craftpix_npcs/animacoes.json"))
	texture_filter = TEXTURE_FILTER_NEAREST
	centered = false
	offset = Vector2(-32, -44)
	position.y = Profundidade.PES_JOGADOR
	scale = Vector2.ONE
	z_index = 3
	process_priority = 110
	_process(0.0)

func _exit_tree() -> void:
	if is_instance_valid(_jogador):
		_jogador.get_node("CompositeSprites").visible = true

func _process(delta: float) -> void:
	if not is_instance_valid(_jogador):
		return
	var original := _jogador.get_node("CompositeSprites") as CanvasItem
	var pesca := _jogador.has_node("SessaoPesca")
	var outra_base := _jogador.has_node("HeroiTiny") or _jogador.has_node("HeroiGerado")
	var arco: bool = _jogador.no_arco != null and _jogador.usando_arco and _jogador.no_arco.esta_disparando()
	var sem_pose: bool = _jogador.esta_forjando or _jogador.esta_sentado or _jogador.esta_em_acao_fazenda or arco or _jogador.esta_em_dash
	sem_pose = sem_pose or (_jogador._esta_atacando and not _jogador.usando_espada)
	if pesca or outra_base or sem_pose:
		visible = false
		if not outra_base:
			original.visible = not pesca
		_animacao = ""
		return
	visible = true
	original.visible = false
	var armado: bool = _jogador.usando_espada
	var nome := "sword_idle" if armado else "unarmed_idle"
	if _jogador.caido:
		nome = "sword_death" if armado else "unarmed_death"
	elif _jogador.no_reacao != null and _jogador.no_reacao.visible:
		nome = "sword_hurt" if armado else "unarmed_hurt"
	elif _jogador._esta_atacando:
		nome = "sword_attack"
	elif _jogador.velocity.length() > 2.0:
		nome = "sword_run" if armado else "unarmed_run"
	var vetor: Vector2 = _jogador._direcao_ataque
	var direcao := "front"
	if absf(vetor.x) > absf(vetor.y):
		direcao = "side_left" if vetor.x < 0 else "side_right"
	elif vetor.y < 0:
		direcao = "back"
	if nome != _animacao or direcao != _direcao:
		_tempo = 0.0
		_animacao = nome
		_direcao = direcao
		if not _texturas.has(nome):
			_texturas[nome] = load(_dados[nome].folha)
		frame = 0
		texture = _texturas[nome]
		hframes = texture.get_width() / int(_dados[nome].quadro)
		var pivo: Array = _dados[nome].pivo
		offset = -Vector2(pivo[0], pivo[1])
		vframes = 4
	_tempo += delta
	var info: Dictionary = _dados[nome].direcoes[direcao]
	var duracoes: Array = info.duracoes
	var total := 0.0
	for duracao in duracoes:
		total += float(duracao)
	if nome == "sword_attack" and _jogador._temporizador != null and not _jogador._temporizador.is_stopped():
		_tempo = total * (1.0 - _jogador._temporizador.time_left / _jogador._temporizador.wait_time)
	var instante := minf(_tempo, total - 0.0001) if nome.ends_with("death") or nome.ends_with("hurt") or nome.ends_with("attack") else fmod(_tempo, total)
	var coluna := 0
	while coluna < duracoes.size() - 1 and instante >= float(duracoes[coluna]):
		instante -= float(duracoes[coluna])
		coluna += 1
	frame = int(info.linha) * hframes + coluna
