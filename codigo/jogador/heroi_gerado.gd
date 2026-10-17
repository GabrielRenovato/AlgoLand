extends Sprite2D

## Protótipo gerado: idle nas quatro direções, caminhada lateral e corrida completa.
## A transição é apenas visual; o movimento responde ao controle imediatamente.
const RAIZ := "res://assets/personagens/prototipos/exemplo_alta_qualidade/"
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const DURACOES_CORRIDA := [80, 80, 80, 80, 80, 80, 40, 40, 80]
const DURACOES_CORRIDA_BAIXO := [80, 60, 60, 80, 80, 80, 60, 60, 80]
const CICLO_CORRIDA_MS := 640
const RESPIRACAO_MS := 1400.0
const PREPARACAO_MS := 55.0
const TRANSICAO_CORRIDA_MS := 120.0
const TRANSICAO_ANDAR_MS := 90.0
const FASES_ESPADA := [0.0, 0.13, 0.24, 0.40, 0.62, 0.82]
const FASES_ESPADA_DIREITA := [0.0, 0.11, 0.22, 0.33, 0.44, 0.55, 0.66, 0.77, 0.88]

enum EstadoVisual { PARADO, SAINDO, MOVENDO, PARANDO }

var correndo := false
## Habilitado explicitamente no F3; na fazenda o golpe é uma prévia sem dano.
var teste_espada := false
var _espada_sprite: Sprite2D
var _mao_espada: Sprite2D
var _rastro_espada: Polygon2D
var _borda_rastro: Line2D
var _recorte_mao: AtlasTexture
var _encaixes_espada: Dictionary = {}
var _espada_lado: Texture2D
var _espada_direita: Texture2D
var _espada_cima: Texture2D
var _espada_baixo: Texture2D
var _espada_ativa := false
var _espada_demonstracao := false
var _espada_enfileirada := false
var _tempo_espada_ms := 0.0
var _duracao_espada_ms := 300.0
var _direcao_espada := Vector2.RIGHT
var _combo_espada := 1
var _jogador: Node2D
var _andar: Texture2D
var _correr: Texture2D
var _correr_cima: Texture2D
var _correr_baixo: Texture2D
var _idle_lado: Texture2D
var _idle_cima: Texture2D
var _idle_baixo: Texture2D
var _tempo_ms := 0.0
var _tempo_idle_ms := 0.0
var _tempo_transicao_ms := 0.0
var _estado_visual := EstadoVisual.PARADO
var _em_movimento := false
var _corrida_anterior := false

func _ready() -> void:
	name = "HeroiGerado"
	_jogador = get_parent()
	_andar = load(RAIZ + "andar.png")
	_correr = load(RAIZ + "correr.png")
	_correr_cima = load(RAIZ + "correr_cima.png")
	_correr_baixo = load(RAIZ + "correr_baixo.png")
	_idle_lado = load(RAIZ + "idle_lado.png")
	_idle_cima = load(RAIZ + "idle_cima.png")
	_idle_baixo = load(RAIZ + "idle_baixo.png")
	_espada_lado = load(RAIZ + "espada_lado.png")
	_espada_direita = load(RAIZ + "espada_direita.png")
	_espada_cima = load(RAIZ + "espada_cima.png")
	_espada_baixo = load(RAIZ + "espada_baixo.png")
	_encaixes_espada = JSON.parse_string(FileAccess.get_file_as_string(RAIZ + "espada_encaixes.json"))
	_espada_sprite = Sprite2D.new()
	_espada_sprite.name = "EspadaGerada"
	_espada_sprite.texture = load(RAIZ + "espada_arma.png")
	_espada_sprite.centered = false
	var pivo: Array = _encaixes_espada["arma_pivo"]
	_espada_sprite.offset = -Vector2(pivo[0], pivo[1])
	add_child(_espada_sprite)
	_recorte_mao = AtlasTexture.new()
	_mao_espada = Sprite2D.new()
	_mao_espada.name = "MaoEspadaGerada"
	_mao_espada.texture = _recorte_mao
	_mao_espada.z_index = 2
	add_child(_mao_espada)
	_rastro_espada = Polygon2D.new()
	_rastro_espada.color = Color(0.65, 0.85, 1.0, 0.6)
	add_child(_rastro_espada)
	_borda_rastro = Line2D.new()
	_borda_rastro.width = 6.0
	_borda_rastro.default_color = Color(0.95, 1.0, 1.0, 0.9)
	add_child(_borda_rastro)
	texture_filter = TEXTURE_FILTER_NEAREST
	centered = false
	offset = Vector2(-512, -704)
	scale = Vector2.ONE / 16.0
	position.y = Profundidade.PES_JOGADOR
	z_index = 3
	process_priority = 100
	_aplicar_folha()
	_process(0.0)

func _exit_tree() -> void:
	if is_instance_valid(_jogador):
		var original := _jogador.get_node_or_null("CompositeSprites") as CanvasItem
		if original != null:
			original.visible = true

func _aplicar_folha() -> void:
	_interromper_espada()
	_corrida_anterior = correndo
	_reiniciar_estado()
	_mostrar(_idle_lado, 2, 0)

func _reiniciar_estado() -> void:
	_estado_visual = EstadoVisual.PARADO
	_em_movimento = false
	_tempo_ms = 0.0
	_tempo_idle_ms = 0.0
	_tempo_transicao_ms = 0.0

func _mostrar(folha: Texture2D, linhas: int, quadro: int) -> void:
	if is_instance_valid(_espada_sprite):
		_espada_sprite.hide()
		_mao_espada.hide()
		_rastro_espada.hide()
		_borda_rastro.hide()
	# A grade muda junto da textura: idle 2x2, andar/espada 2x3, corrida 2x5.
	if texture != folha or vframes != linhas:
		frame = 0
		texture = folha
		hframes = 2
		vframes = linhas
	frame = quadro

func velocidade_de_teste() -> float:
	return 114.0 if correndo else 64.0

func _process(delta: float) -> void:
	if is_instance_valid(_jogador) and _jogador.has_node("SessaoPesca"):
		visible = false
		_jogador.get_node("CompositeSprites").visible = false
		return

	if not is_instance_valid(_jogador):
		return
	if correndo != _corrida_anterior:
		_aplicar_folha()
	var espada_propria: bool = _espada_ativa and (_espada_demonstracao or (_jogador._esta_atacando and _jogador.usando_espada))
	var direcao: Vector2 = _direcao_espada if espada_propria else _jogador._direcao_ataque
	var acao_original: bool = _jogador.esta_forjando or _jogador.esta_sentado \
		or _jogador.esta_em_acao_fazenda or (_jogador._esta_atacando and not espada_propria) \
		or _jogador.esta_em_dash or _jogador.caido \
		or (_jogador.no_reacao != null and _jogador.no_reacao.visible)
	var lateral := absf(direcao.x) > absf(direcao.y)
	var movendo: bool = _jogador.velocity.length() > 2.0
	visible = not acao_original and (espada_propria or correndo or lateral or not movendo)
	var original := _jogador.get_node_or_null("CompositeSprites") as CanvasItem
	if original != null:
		original.visible = not visible
	if not visible:
		_interromper_espada()
		_reiniciar_estado()
		return
	if espada_propria and _processar_espada(delta):
		return
	if _espada_ativa:
		_interromper_espada()
	flip_h = lateral and direcao.x < 0
	var idle := _idle_lado if lateral else (_idle_cima if direcao.y < 0 else _idle_baixo)
	var duracao_transicao := TRANSICAO_CORRIDA_MS if correndo else TRANSICAO_ANDAR_MS
	var decorrido := maxf(delta, 0.0) * 1000.0
	if not movendo:
		if _em_movimento:
			var preparo_incompleto := _estado_visual == EstadoVisual.SAINDO and _tempo_transicao_ms < PREPARACAO_MS
			_estado_visual = EstadoVisual.PARANDO
			# Um toque curto não deve saltar para o impulso depois de soltar o controle.
			_tempo_transicao_ms = PREPARACAO_MS if preparo_incompleto else 0.0
			_tempo_idle_ms = 0.0
		_em_movimento = false
		_tempo_ms = 0.0
		if _estado_visual == EstadoVisual.PARANDO:
			_tempo_transicao_ms += decorrido
			if _tempo_transicao_ms < duracao_transicao:
				var quadro := 3 if correndo and _tempo_transicao_ms < PREPARACAO_MS else 2
				_mostrar(idle, 2, quadro)
				return
			_estado_visual = EstadoVisual.PARADO
			_tempo_idle_ms = _tempo_transicao_ms - duracao_transicao
		else:
			_tempo_idle_ms += decorrido
		var respiracao := 0 if fposmod(_tempo_idle_ms, RESPIRACAO_MS) < RESPIRACAO_MS / 2.0 else 1
		_mostrar(idle, 2, respiracao)
		return
	if not _em_movimento:
		# Retomar durante a acomodação percorre o mesmo trecho no sentido oposto.
		_tempo_transicao_ms = maxf(0.0, duracao_transicao - _tempo_transicao_ms) if _estado_visual == EstadoVisual.PARANDO else 0.0
		_estado_visual = EstadoVisual.SAINDO
	_em_movimento = true
	if _estado_visual == EstadoVisual.SAINDO:
		_tempo_transicao_ms += decorrido
		if _tempo_transicao_ms < duracao_transicao:
			var quadro := 3 if correndo and _tempo_transicao_ms >= PREPARACAO_MS else 2
			_mostrar(idle, 2, quadro)
			return
		_estado_visual = EstadoVisual.MOVENDO
		# Conserva o excedente de delta para não depender da taxa de quadros.
		_tempo_ms = _tempo_transicao_ms - duracao_transicao
	else:
		_tempo_ms += decorrido
	if not correndo:
		_mostrar(_andar, 3, floori(_tempo_ms / 160.0) % 6)
		return
	# Virar durante a corrida ou transição preserva a fase e não reinicia a preparação.
	var folha := _correr if lateral else (_correr_cima if direcao.y < 0 else _correr_baixo)
	var instante := fposmod(_tempo_ms, CICLO_CORRIDA_MS)
	var duracoes: Array = DURACOES_CORRIDA_BAIXO if folha == _correr_baixo else DURACOES_CORRIDA
	for i in duracoes.size():
		if instante < duracoes[i]:
			_mostrar(folha, 5, i)
			return
		instante -= duracoes[i]

func iniciar_ataque_espada(duracao: float, demonstracao := false, combo := 1) -> void:
	_reiniciar_estado()
	_espada_ativa = true
	_espada_demonstracao = demonstracao
	_espada_enfileirada = false
	_tempo_espada_ms = 0.0
	_duracao_espada_ms = maxf(1.0, duracao * 1000.0)
	_direcao_espada = _jogador._direcao_ataque
	_combo_espada = clampi(combo, 1, 3)

func _interromper_espada() -> void:
	_espada_ativa = false
	_espada_demonstracao = false
	_espada_enfileirada = false

func _processar_espada(delta: float) -> bool:
	_tempo_espada_ms += maxf(delta, 0.0) * 1000.0
	if _espada_demonstracao and _tempo_espada_ms >= _duracao_espada_ms:
		if _espada_enfileirada:
			var excedente := fposmod(_tempo_espada_ms, _duracao_espada_ms)
			iniciar_ataque_espada(0.3, true, _combo_espada % 3 + 1)
			_tempo_espada_ms = excedente
		else:
			_interromper_espada()
			return false
	var fase := clampf(_tempo_espada_ms / _duracao_espada_ms, 0.0, 1.0)
	# Os golpes encadeados já começam com a janela de contato aberta no sistema
	# original. Entram pelo corte, sem repetir a antecipação do primeiro ataque.
	if _combo_espada > 1:
		fase = 0.24 + fase * 0.76
	var lateral := absf(_direcao_espada.x) > absf(_direcao_espada.y)
	var direita := lateral and _direcao_espada.x > 0
	var fases: Array = FASES_ESPADA_DIREITA if direita else FASES_ESPADA
	var quadro := 0
	for i in fases.size():
		if fase >= fases[i]:
			quadro = i
	flip_h = lateral and _direcao_espada.x < 0
	if direita:
		# Corpo, punho e lâmina pertencem ao mesmo desenho em cada pose.
		_mostrar(_espada_direita, 5, quadro)
		return true
	var folha := _espada_lado if lateral else (_espada_cima if _direcao_espada.y < 0 else _espada_baixo)
	_mostrar(folha, 3, quadro)
	_mostrar_arma(folha, quadro, fase)
	return true

func _unhandled_input(evento: InputEvent) -> void:
	if not teste_espada or not is_instance_valid(_jogador) or not _jogador.modo_fazenda:
		return
	if not evento.is_action_pressed(_jogador.acao_evento("attack")) or evento.is_echo():
		return
	if _jogador.estaMorto or _jogador.caido or _jogador.esta_forjando or _jogador.esta_sentado 		or _jogador.esta_em_dash or _jogador.esta_em_acao_fazenda 		or (_jogador.no_reacao != null and _jogador.no_reacao.visible) 		or Time.get_ticks_msec() < _jogador._sem_acao_ate_ms:
		return
	if _espada_ativa:
		_espada_enfileirada = true
	else:
		iniciar_ataque_espada(0.3, true)
	get_viewport().set_input_as_handled()

func _mostrar_arma(folha: Texture2D, quadro: int, fase: float) -> void:
	var nome := "lado" if absf(_direcao_espada.x) > absf(_direcao_espada.y) else ("cima" if _direcao_espada.y < 0 else "baixo")
	var ponto: Array = _encaixes_espada[nome][quadro]
	var mao := Vector2(ponto[0], ponto[1])
	var posicao := mao - Vector2(512, 704)
	if flip_h:
		posicao.x = -posicao.x
	# Um único arco de corte; a espada é recolhida durante a recuperação,
	# como nas referências 2D, sem percorrer o golpe ao contrário.
	var extremos: Array = {"lado": [-70.0, 70.0], "baixo": [170.0, 10.0], "cima": [-10.0, -170.0]}[nome]
	var progresso := clampf((fase - 0.12) / 0.30, 0.0, 1.0)
	var angulo := deg_to_rad(lerpf(extremos[0], extremos[1], progresso))
	var desenhar := fase >= 0.12 and fase <= 0.46
	_espada_sprite.position = posicao
	_espada_sprite.rotation = PI - angulo if flip_h else angulo
	_espada_sprite.scale = Vector2(1, -1) if flip_h else Vector2.ONE
	# De costas a arma passa atrás do corpo; a mesma mão continua no lado direito.
	_espada_sprite.z_index = -1 if nome == "cima" else 1
	_espada_sprite.visible = desenhar
	_recorte_mao.atlas = folha
	_recorte_mao.region = Rect2(Vector2(quadro % 2, quadro / 2) * 1024 + mao - Vector2(20, 20), Vector2(40, 40))
	_mao_espada.position = posicao
	_mao_espada.flip_h = flip_h
	_mao_espada.visible = desenhar and nome != "cima"
	_rastro_espada.visible = desenhar
	_borda_rastro.visible = desenhar
	_rastro_espada.z_index = -2 if nome == "cima" else 0
	_borda_rastro.z_index = _rastro_espada.z_index
	var externo := PackedVector2Array()
	var interno := PackedVector2Array()
	var sentido := signf(float(extremos[1]) - float(extremos[0]))
	var extensao := deg_to_rad(55.0) * minf(1.0, progresso * 4.0)
	for i in 13:
		var t := i / 12.0
		var anterior := angulo - sentido * extensao * (1.0 - t)
		var raio := Vector2.from_angle(anterior)
		var fora := raio * 292.0
		var dentro := raio * (292.0 - sin(t * PI) * 48.0)
		if flip_h:
			fora.x = -fora.x
			dentro.x = -dentro.x
		externo.append(posicao + fora)
		interno.append(posicao + dentro)
	var poligono := externo.duplicate()
	interno.reverse()
	poligono.append_array(interno)
	_rastro_espada.polygon = poligono
	_borda_rastro.points = externo
