extends Node2D

## Uma pescaria de um jogador (fluxo copiado do SeasonsFarm, entities/player/fishing_component.gd):
## lançar -> esperar -> o peixe belisca (aparece "!") -> apertar a tempo -> minigame de fisgada -> peixe na bolsa.
## Fica filha do jogador (some junto com ele ao trocar de cena). Apertar `rolar` cancela antes do minigame.

signal acabou

const Peixes := preload("res://codigo/pesca/peixes.gd")
const Raridades := preload("res://codigo/dados/raridades.gd")
const Minijogo := preload("res://codigo/pesca/minijogo_pesca.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const Animacao := preload("res://codigo/pesca/animacao_pesca.gd")

enum Estado { LANCANDO, ESPERANDO, BELISCANDO, PUXANDO, PEGOU }

const ESPERA_MIN := 2.0
const ESPERA_MAX := 6.0
const JANELA_BELISCO := 1.5
const DURACAO_LANCE := 0.55
const ALCANCE := 44.0

var jogador: CharacterBody2D
var ambiente := "mar"
var estado := Estado.LANCANDO
var peixe := ""
var qualidade_peixe := 0

var _frente := Vector2.DOWN
var _alvo := Vector2.ZERO          ## ponto da água, em coordenadas locais do jogador
var _tempo := 0.0
var _espera := 0.0
var _guarda_entrada := 0.3
var _tinha_movimento := true
var _minijogo: Control
var _sombra: Sprite2D
var _exclamacao: Label
var _animacao: Node2D
var _arvore_ativa := false
var _visual_visivel := true
var _ataques_bloqueados := false
var _tempo_puxao := 0.0
var _tempo_peixe := 0.0
var _restaurado := false

static func em_andamento(quem: Node) -> bool:
	return quem != null and quem.has_node("SessaoPesca")

func iniciar(quem: CharacterBody2D, direcao: Vector2, ambiente_agua: String) -> void:
	name = "SessaoPesca"
	jogador = quem
	ambiente = ambiente_agua
	_frente = direcao
	# Linha na água atrás do corpo; avisos e resultado têm profundidade própria.
	z_as_relative = true
	z_index = 0
	_alvo = Vector2(0, 14) + direcao * ALCANCE
	quem.add_child(self)
	_tinha_movimento = quem.movimento_habilitado
	quem.movimento_habilitado = false
	quem.velocity = Vector2.ZERO
	quem.parar_para_conversa(quem.global_position + direcao * 32.0)
	_arvore_ativa = quem._arvore_animacao.active
	quem._arvore_animacao.active = false
	_visual_visivel = quem.get_node("CompositeSprites").visible
	quem.get_node("CompositeSprites").visible = false
	_ataques_bloqueados = quem.ataques_bloqueados
	quem.ataques_bloqueados = true
	_animacao = Animacao.new()
	_animacao.iniciar(quem,direcao)
	_exclamacao = Label.new()
	_exclamacao.z_as_relative = false
	_exclamacao.z_index = 900
	_exclamacao.text = "!"
	_exclamacao.add_theme_font_override("font", FONTE)
	_exclamacao.add_theme_font_size_override("font_size", 16)
	_exclamacao.add_theme_color_override("font_outline_color", Color.BLACK)
	_exclamacao.add_theme_constant_override("outline_size", 4)
	_exclamacao.position = Vector2(-6, -46)
	_exclamacao.visible = false
	add_child(_exclamacao)
	Sons.tocar("enxada", 0.1, -6.0)

func _process(delta: float) -> void:
	if jogador == null or not is_instance_valid(jogador) or jogador.estaMorto or Transicao.ocupada:
		_terminar()
		return
	_tempo += delta
	_guarda_entrada = maxf(_guarda_entrada - delta, 0.0)
	var cancelar := _guarda_entrada <= 0.0 and Input.is_action_just_pressed(jogador.acao("rolar"))
	var agir := _guarda_entrada <= 0.0 and (Input.is_action_just_pressed(jogador.acao("open_menu")) \
			or Input.is_action_just_pressed(jogador.acao("attack")))
	match estado:
		Estado.LANCANDO:
			if _tempo >= DURACAO_LANCE:
				_esperar()
		Estado.ESPERANDO:
			_espera -= delta
			if cancelar or agir:
				Sons.tocar("menu_mover", 0.0)
				_terminar()
			elif _espera <= 0.0:
				_beliscar()
		Estado.BELISCANDO:
			_espera -= delta
			if cancelar:
				_terminar()
			elif agir:
				_puxar()
			elif _espera <= 0.0:
				Sons.tocar("erro", 0.0)
				_terminar()
		Estado.PEGOU:
			if _tempo >= 0.1 and (jogador._vetor_movimento().length_squared() > 0.0625 or cancelar):
				_terminar()
				return
	_atualizar_animacao(delta)
	queue_redraw()

func _esperar() -> void:
	estado = Estado.ESPERANDO
	_tempo = 0.0
	_espera = randf_range(ESPERA_MIN, ESPERA_MAX)

func _beliscar() -> void:
	peixe = "pedra_vara" if preload("res://codigo/pesca/varas.gd").sortear_pedra_para(jogador) else Peixes.sortear(ambiente, Calendario.estacao())
	if peixe == "":
		_terminar()
		return
	estado = Estado.BELISCANDO
	_tempo = 0.0
	_espera = JANELA_BELISCO
	_exclamacao.visible = true
	_exclamacao.scale = Vector2.ZERO
	create_tween().tween_property(_exclamacao, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	Sons.tocar("pegar_semente", 0.05)
	_mostrar_sombra()

## O peixe se debatendo na água, na cor da raridade (sprites de salto do SeasonsFarm)
func _mostrar_sombra() -> void:
	_sombra = Sprite2D.new()
	_sombra.texture = load(Peixes.SALTOS[Peixes.raridade(peixe)])
	_sombra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sombra.hframes = 4
	_sombra.position = _alvo
	_sombra.modulate.a = 0.0
	add_child(_sombra)
	create_tween().tween_property(_sombra, "modulate:a", 1.0, 0.25)

func _puxar() -> void:
	estado = Estado.PUXANDO
	_exclamacao.visible = false
	var interface := EventosJogo.interface_de(jogador)
	if interface == null:
		_terminar()
		return
	_minijogo = Minijogo.new()
	interface.add_child(_minijogo)
	_minijogo.iniciar(jogador, Peixes.nome(peixe), 15.0 if peixe == "pedra_vara" else float(Peixes.DADOS[peixe]["dificuldade"]),1 if peixe == "pedra_vara" else Peixes.nivel_recomendado(peixe))
	_minijogo.terminou.connect(_ao_minijogo_terminar)
	_minijogo.puxao.connect(func(_otimo: bool) -> void: _sacudir_vara())

func _sacudir_vara() -> void:
	_tempo_puxao = 0.24

func _atualizar_animacao(delta: float) -> void:
	_tempo_puxao = maxf(0.0,_tempo_puxao-delta)
	match estado:
		Estado.LANCANDO:
			_animacao.pose(0 if _tempo < 0.20 else (1 if _tempo < 0.28 else 2))
		Estado.ESPERANDO, Estado.BELISCANDO:
			_animacao.pose(2)
		Estado.PUXANDO:
			_animacao.pose(4 if _tempo_puxao > 0.12 else (5 if _tempo_puxao > 0 else 3))
		Estado.PEGOU:
			_animacao.pose(6 if _tempo < 0.16 else 7)

func _ao_minijogo_terminar(sucesso: bool) -> void:
	var perfeita: bool = is_instance_valid(_minijogo) and _minijogo.tentativas > 0 and _minijogo.otimos == _minijogo.tentativas
	if sucesso and is_instance_valid(_minijogo):
		qualidade_peixe = preload("res://codigo/pesca/qualidade_peixe.gd").da_captura(perfeita,preload("res://codigo/pesca/varas.gd").nivel(jogador),_minijogo.otimos,_minijogo.tentativas)
	_minijogo = null
	if sucesso and is_instance_valid(jogador):
		_pegar(perfeita)
	else:
		Sons.tocar("erro", 0.0)
		_terminar()

func _pegar(perfeita := false) -> void:
	estado = Estado.PEGOU
	_tempo = 0.0
	if peixe == "pedra_vara":
		preload("res://codigo/pesca/varas.gd").receber_pedra(jogador)
	else:
		if not Fazenda.pescar(peixe,perfeita,jogador,qualidade_peixe):
			Sons.tocar("erro",0.0)
			_terminar()
			return
		preload("res://codigo/pesca/varas.gd").registrar_peixe(jogador)
	Sons.tocar("moeda", 0.05)
	if _sombra != null:
		_sombra.queue_free()
		_sombra = null

	var cartaz := Node2D.new()
	cartaz.z_as_relative = false
	cartaz.z_index = 800
	cartaz.position = Vector2(0, -38)
	cartaz.scale = Vector2.ZERO
	add_child(cartaz)
	var fundo := Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.10, 0.09, 0.14, 0.94)
	estilo.set_corner_radius_all(4)
	fundo.add_theme_stylebox_override("panel", estilo)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.position = Vector2(-44, -14)
	fundo.size = Vector2(88, 28)
	cartaz.add_child(fundo)
	var icone := Sprite2D.new()
	icone.texture = Peixes.icone(peixe)
	if peixe == "pedra_vara":
		icone.modulate = Color("8bdcf7")
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone.position = Vector2(-30, 0)
	cartaz.add_child(icone)
	var rotulo := Label.new()
	rotulo.text = Peixes.nome(peixe) + "\n" + ("REFINAMENTO" if peixe == "pedra_vara" else preload("res://codigo/pesca/qualidade_peixe.gd").NOMES[qualidade_peixe])
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", 7)
	rotulo.add_theme_color_override("font_color", Raridades.cor(Peixes.raridade(peixe)))
	rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	rotulo.add_theme_constant_override("outline_size", 2)
	rotulo.position = Vector2(-20, -10)
	cartaz.add_child(rotulo)
	var tween := create_tween()
	tween.tween_property(cartaz, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.8)
	tween.tween_property(cartaz, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_terminar)

func _terminar() -> void:
	if is_queued_for_deletion():
		return
	if _minijogo != null and is_instance_valid(_minijogo):
		_minijogo.abortar()
	_restaurar_jogador()
	acabou.emit()
	queue_free()

func _restaurar_jogador() -> void:
	if _restaurado:
		return
	_restaurado = true
	if is_instance_valid(_animacao):
		_animacao.queue_free()
	if not is_instance_valid(jogador):
		return
	jogador.movimento_habilitado = _tinha_movimento
	jogador.ataques_bloqueados = _ataques_bloqueados
	jogador._arvore_animacao.active = _arvore_ativa
	jogador.get_node("CompositeSprites").visible = _visual_visivel

func _exit_tree() -> void:
	_restaurar_jogador()
	if is_instance_valid(_minijogo):
		_minijogo.abortar()

func _physics_process(delta: float) -> void:
	if is_instance_valid(_sombra) and estado in [Estado.BELISCANDO, Estado.PUXANDO]:
		# O salto continua durante toda a disputa, sem congelar ao abrir a fisgada.
		_tempo_peixe += delta
		_sombra.frame = int(_tempo_peixe / 0.18) % _sombra.hframes

func _draw() -> void:
	if estado == Estado.PEGOU:
		return
	var ponta: Vector2 = _animacao.ponta() if is_instance_valid(_animacao) else Vector2(0,-12)
	var progresso := clampf(_tempo / DURACAO_LANCE, 0.0, 1.0) if estado == Estado.LANCANDO else 1.0
	var boia := ponta.lerp(_alvo, progresso)
	if estado == Estado.LANCANDO:
		boia.y -= sin(progresso * PI) * 22.0
	else:
		boia.y += roundf(sin(Time.get_ticks_msec() / 320.0))
		if estado == Estado.BELISCANDO:
			boia.y += 2.0 + roundf(sin(Time.get_ticks_msec() / 40.0))
	draw_line(ponta, boia, Color(0.95, 0.96, 0.88, 0.7), 1.0)
	if estado != Estado.LANCANDO:
		var raio := 3.0 + fmod(Time.get_ticks_msec() / 400.0, 3.0)
		draw_arc(_alvo + Vector2(0, 2), raio, 0.0, TAU, 14, Color(1, 1, 1, 0.35), 1.0)
	draw_rect(Rect2(boia - Vector2(1, 1), Vector2(3, 3)), Color("d45548"))
