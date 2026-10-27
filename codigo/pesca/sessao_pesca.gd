extends Node2D

## Uma pescaria de um jogador (fluxo copiado do SeasonsFarm, entities/player/fishing_component.gd):
## lançar -> esperar -> o peixe belisca (aparece "!") -> apertar a tempo -> minigame de fisgada -> peixe na bolsa.
## Fica filha do jogador (some junto com ele ao trocar de cena). Apertar `rolar` cancela antes do minigame.

signal acabou

const Peixes := preload("res://codigo/pesca/peixes.gd")
const Progressao := preload("res://codigo/pesca/progressao_pesca.gd")
const Minijogo := preload("res://codigo/pesca/minijogo_pesca.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const Animacao := preload("res://codigo/pesca/animacao_pesca.gd")
const AvisoCaptura := preload("res://codigo/pesca/aviso_captura.gd")

enum Estado { LANCANDO, ESPERANDO, BELISCANDO, PUXANDO, PEGOU, CARREGANDO }

const ESPERA_MIN := 2.0
const ESPERA_MAX := 6.0
const JANELA_BELISCO := 1.5
const DURACAO_LANCE := 0.55
const INICIO_ARREMESSO := 0.28
const FIM_GESTO_ARREMESSO := 0.38
const ALCANCE := 44.0
const TEMPO_FORCA := 1.0
var forca_lancamento := 0.0

var jogador: CharacterBody2D
var ambiente := "mar"
var estado := Estado.LANCANDO
var peixe := ""
var qualidade_peixe := 0
var _xp_ganha := 0

var _frente := Vector2.DOWN
var _alvo := Vector2.ZERO          ## ponto da água, em coordenadas locais do jogador
var _tempo := 0.0
var _espera := 0.0
var _guarda_entrada := 0.3
var _tinha_movimento := true
var _minijogo: Control
var _sombra: Sprite2D
var _exclamacao: Label
var _boia_3d: Polygon2D
var _linha_3d: Line2D
var _animacao: Node2D
var _arvore_ativa := false
var _visual_visivel := true
var _ataques_bloqueados := false
var _tempo_puxao := 0.0
var _tempo_recolhimento := 0.0
const TEMPO_QUADRO_RECOLHIMENTO := 0.14
var _tempo_peixe := 0.0
var _restaurado := false
var _aviso_captura: Control

static func em_andamento(quem: Node) -> bool:
	return quem != null and quem.has_node("SessaoPesca")

static func alvo_mar(quem: Node2D, frente: Vector2, alcance: float) -> Vector2:
	var cena: Node = quem.get_node("/root/Cooperativo").cena_de(quem)
	if cena == null or not cena.has_method("alvo_pesca_mar"):
		return Vector2.INF
	return cena.alvo_pesca_mar(quem.to_global(Vector2(0, 14)), frente.normalized(), alcance)

func iniciar(quem: CharacterBody2D, direcao: Vector2, ambiente_agua: String, carregar := false) -> void:
	name = "SessaoPesca"
	jogador = quem
	ambiente = ambiente_agua
	_frente = direcao
	if carregar: estado = Estado.CARREGANDO
	# Linha na água atrás do corpo; avisos e resultado têm profundidade própria.
	z_as_relative = true
	z_index = 0
	_alvo = Vector2(0, 14) + direcao * ALCANCE
	if ambiente == "mar":
		var destino := alvo_mar(quem, direcao, ALCANCE)
		if not destino.is_finite():
			queue_free()
			return
		_alvo = quem.to_local(destino)
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
	_linha_3d = Line2D.new()
	_linha_3d.name = "LinhaVara3D"
	_linha_3d.width = 0.7
	_linha_3d.antialiased = true
	_linha_3d.default_color = Color(0.95,0.96,0.88,0.75)
	_linha_3d.visible = false
	add_child(_linha_3d)
	_boia_3d = Polygon2D.new()
	_boia_3d.polygon = PackedVector2Array([Vector2(-1,-1),Vector2(2,-1),Vector2(2,2),Vector2(-1,2)])
	_boia_3d.color = Color("d45548")
	_boia_3d.visible = false
	add_child(_boia_3d)
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
	if not carregar: Sons.tocar("enxada", 0.1, -6.0)

func _process(delta: float) -> void:
	if jogador == null or not is_instance_valid(jogador) or jogador.estaMorto or Transicao.ocupada:
		_terminar()
		return
	_tempo += delta
	_guarda_entrada = maxf(_guarda_entrada - delta, 0.0)
	var cancelar := _guarda_entrada <= 0.0 and Input.is_action_just_pressed(jogador.acao("rolar"))
	var agir := _guarda_entrada <= 0.0 and Input.is_action_just_pressed(jogador.acao("attack"))
	match estado:
		Estado.CARREGANDO:
			forca_lancamento = 1.0 - absf(1.0-fmod(_tempo/TEMPO_FORCA,2.0))
			if cancelar:
				_terminar()
				return
			if not Input.is_action_pressed(jogador.acao("attack")):
				_lancar()
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

func _lancar() -> void:
	var alcance_maximo := 64.0 if ambiente == "rio" else 120.0
	var alcance := lerpf(28.0,alcance_maximo,forca_lancamento)
	_alvo = Vector2(0,14) + _frente * alcance
	if ambiente == "mar":
		var destino := alvo_mar(jogador, _frente, alcance)
		if not destino.is_finite():
			_terminar()
			return
		_alvo = jogador.to_local(destino)
	# O lago pequeno limita a linha à água real, sem lançar a boia sobre a margem oposta.
	if ambiente == "rio":
		for lago in get_tree().get_nodes_in_group("lago_fazenda"):
			if lago.get_world_2d() != jogador.get_world_2d(): continue
			while alcance > 16 and not Geometry2D.is_point_in_polygon(lago.to_local(jogador.to_global(_alvo)),lago.poligono):
				alcance -= 1
				_alvo = Vector2(0,14) + _frente * alcance
	estado = Estado.LANCANDO
	_tempo = 0.0
	_guarda_entrada = 0.3
	Sons.tocar("enxada",0.1,-6.0)

func _esperar() -> void:
	estado = Estado.ESPERANDO
	_tempo = 0.0
	_espera = randf_range(ESPERA_MIN, ESPERA_MAX) * (1.0 - 0.002 * (Progressao.nivel(jogador) - 1))

func _beliscar() -> void:
	peixe = "pedra_vara" if preload("res://codigo/pesca/varas.gd").sortear_pedra_para(jogador) else Peixes.sortear(ambiente, Calendario.estacao(), null, Progressao.nivel(jogador))
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
	_tempo_recolhimento = 0.0
	_sacudir_vara()
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
	_tempo_recolhimento = TEMPO_QUADRO_RECOLHIMENTO

func _atualizar_animacao(delta: float) -> void:
	_tempo_puxao = maxf(0.0,_tempo_puxao-delta)
	_animacao.tensao = 0.0
	match estado:
		Estado.CARREGANDO:
			_animacao.pose(0)
		Estado.LANCANDO:
			_animacao.pose(0 if _tempo < 0.20 else (1 if _tempo < INICIO_ARREMESSO else (2 if _tempo < FIM_GESTO_ARREMESSO else 3)))
		Estado.ESPERANDO, Estado.BELISCANDO:
			_animacao.pose(2,true)
		Estado.PUXANDO:
			# Mãos e pés apoiados; a vara cede à tensão e recupera após cada puxão.
			_tempo_recolhimento += delta * (1.6 if _tempo_puxao > 0 else 1.0)
			_animacao.pose(3,true)
			_animacao.tensao = clampf(0.25+0.15*sin(_tempo_recolhimento*8.0)+0.65*sin(PI*_tempo_puxao/0.24),0.0,1.0)
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
		if not preload("res://codigo/pesca/varas.gd").receber_pedra(jogador):
			Sons.tocar("erro",0.0)
			_terminar()
			return
	else:
		var xp_antes := Progressao.xp(jogador)
		if not Fazenda.pescar(peixe,perfeita,jogador,qualidade_peixe):
			Sons.tocar("erro",0.0)
			_terminar()
			return
		_xp_ganha = Progressao.xp(jogador) - xp_antes
		preload("res://codigo/pesca/varas.gd").registrar_peixe(jogador)
	Sons.tocar("moeda", 0.05)
	if _sombra != null:
		_sombra.queue_free()
		_sombra = null

	var interface := EventosJogo.interface_de(jogador)
	if interface == null:
		_terminar()
		return
	_aviso_captura = AvisoCaptura.new()
	interface.add_child(_aviso_captura)
	_aviso_captura.iniciar(jogador, peixe, qualidade_peixe, _xp_ganha)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_aviso_captura, "modulate:a", 0.0, 0.2)
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
	if is_instance_valid(_aviso_captura): _aviso_captura.queue_free()
	_restaurar_jogador()
	if is_instance_valid(_minijogo):
		_minijogo.abortar()

func _physics_process(delta: float) -> void:
	if is_instance_valid(_sombra) and estado in [Estado.BELISCANDO, Estado.PUXANDO]:
		# O salto continua durante toda a disputa, sem congelar ao abrir a fisgada.
		_tempo_peixe += delta
		_sombra.frame = int(_tempo_peixe / 0.18) % _sombra.hframes

func _draw() -> void:
	if estado == Estado.CARREGANDO:
		# Medidor nativo de 48x6 px, junto à vara, com contraste e marca no limite máximo.
		draw_string(FONTE,Vector2(-24,-60),"FORCA %d%%" % roundi(forca_lancamento*100),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("fff0ce"))
		draw_rect(Rect2(-26,-57,52,10),Color("30221c"))
		draw_rect(Rect2(-24,-55,48,6),Color("685044"))
		draw_rect(Rect2(-24,-55,roundf(48*forca_lancamento),6),Color("a3df6b") if forca_lancamento < 0.85 else Color("ffd875"))
		draw_line(Vector2(22,-56),Vector2(22,-48),Color("fff0ce"),1)
		return
	if estado == Estado.PEGOU:
		return
	# Os dois quadros de preparação já contêm a boia presa à vara.
	if estado == Estado.LANCANDO and _tempo < INICIO_ARREMESSO:
		return
	var ponta: Vector2 = _animacao.ponta() if is_instance_valid(_animacao) else Vector2(0,-12)
	var boia := posicao_boia()
	var heroi := jogador.get_node_or_null("HeroiBase3D")
	if heroi == null or not heroi.visible:
		_linha_3d.visible = false
		_boia_3d.visible = false
		draw_line(ponta, boia, Color(0.95, 0.96, 0.88, 0.7), 1.0)
	if estado != Estado.LANCANDO:
		var raio := 3.0 + fmod(Time.get_ticks_msec() / 400.0, 3.0)
		draw_arc(_alvo + Vector2(0, 2), raio, 0.0, TAU, 14, Color(1, 1, 1, 0.35), 1.0)
	if heroi == null or not heroi.visible:
		draw_rect(Rect2(boia - Vector2(1, 1), Vector2(3, 3)), Color("d45548"))

func posicao_boia() -> Vector2:
	if estado == Estado.LANCANDO:
		# A boia já saiu da vara: mudar a pose do braço não move sua trajetória.
		var progresso := clampf((_tempo-INICIO_ARREMESSO)/(DURACAO_LANCE-INICIO_ARREMESSO),0.0,1.0)
		var origem: Vector2 = _animacao.ponta_arremesso() if is_instance_valid(_animacao) else Vector2(0,-12)
		var boia := origem.lerp(_alvo,progresso)
		boia.y -= sin(progresso*PI)*22.0
		return boia
	var boia := _alvo+Vector2(0,roundf(sin(Time.get_ticks_msec()/320.0)))
	if estado == Estado.BELISCANDO:
		boia.y += 2.0+roundf(sin(Time.get_ticks_msec()/40.0))
	return boia

## Executa depois dos modificadores: o cabo e a linha usam a mesma pose final.
func sincronizar_linha_3d() -> void:
	if not is_instance_valid(_linha_3d) or not is_instance_valid(_animacao): return
	_linha_3d.visible = estado not in [Estado.CARREGANDO,Estado.PEGOU] and not (estado==Estado.LANCANDO and _tempo<INICIO_ARREMESSO)
	_boia_3d.visible = _linha_3d.visible
	if not _linha_3d.visible: return
	if estado==Estado.LANCANDO: _animacao.fixar_arremesso_3d()
	var inicio: Vector2 = _animacao.ponta()
	var fim := posicao_boia()
	_boia_3d.position = fim
	# Pequena folga sob gravidade; tensionar estica o fio sem mover suas pontas.
	var folga: float = minf(4.0,inicio.distance_to(fim)*0.06)*(1.0-_animacao.tensao)
	var pontos := PackedVector2Array()
	for i in 13:
		var t := i/12.0
		pontos.append(inicio.lerp(fim,t)+Vector2(0,4.0*t*(1.0-t)*folga))
	_linha_3d.points = pontos
