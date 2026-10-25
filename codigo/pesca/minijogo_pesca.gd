extends Control

## Minigame da fisgada, copiado do SeasonsFarm (systems/fishing/fishing_minigame.gd): um ponteiro gira no círculo e o
## jogador aperta o botão quando ele cruza a zona de acerto. Acerto enche a barra, erro esvazia: encheu = peixe fisgado,
## esvaziou = o peixe escapou. A dificuldade é progressiva: começa fácil e aperta com o tempo, até o teto do peixe.
## Fica dentro da Interface do jogador (e não numa CanvasLayer própria) para valer na metade certa da tela dividida.

signal terminou(sucesso: bool)
signal puxao(otimo: bool)

const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")

# Progresso
const PROGRESSO_MAXIMO := 100.0
var progresso := 22.0
var tentativas := 0
var otimos := 0
var dificuldade := 50.0
var equipamento: Dictionary = {}
var peixe_facil := false

# Skill check (ângulos em radianos; 0 = topo, cresce no sentido horário)
var ponteiro_base := 0.0
var percorrido := 0.0
var ponteiro_angulo := 0.0
var ponteiro_velocidade := TAU
var folga_zona := 1.5
var tamanho_zona := 0.9
var tamanho_otimo := 0.3
var check_ativo := false
var pausa_antes := 0.6

# Rampa de dificuldade
var decorrido := 0.0
var tempo_rampa := 13.0
var _errou_antes := false
const ALIVIO_APOS_ERRO := 0.30

var ganho_otimo := 18.0
var ganho_bom := 10.0
var perda_erro := 13.0

var ativo := false
var raio := 26.0
var centro := Vector2(240, 100)
var jogador: Node = null

var _titulo: Label
var _tecla_caixa: ColorRect
var _tecla_icone: TextureRect
var _tecla: Label
var _feedback: Label
var _barra_fundo: ColorRect
var _barra: ColorRect
var _dica: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tela := get_viewport().get_visible_rect().size
	centro = Vector2(tela.x * 0.65, tela.y * 0.46)
	_titulo = _rotulo(Vector2(centro.x - 60, centro.y - raio - 14), Vector2(120, 10), 7)
	_tecla_caixa = ColorRect.new()
	_tecla_caixa.color = Color(0.12, 0.12, 0.14, 0.92)
	_tecla_caixa.size = Vector2(13, 13)
	_tecla_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tecla_caixa)
	_tecla = Label.new()
	_tecla.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tecla.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_estilizar(_tecla, 8)
	_tecla_caixa.add_child(_tecla)
	_tecla_icone = TextureRect.new()
	_tecla_icone.texture = preload("res://codigo/ui/icones_toque.gd").glifo(Vector2i(15,5))
	_tecla_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tecla_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tecla_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tecla_icone.texture_filter = TEXTURE_FILTER_NEAREST
	_tecla_icone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tecla_caixa.add_child(_tecla_icone)
	_feedback = _rotulo(Vector2(centro.x - 60, centro.y + raio + 3), Vector2(120, 12), 9)
	_feedback.modulate.a = 0.0
	var barra_x := centro.x + raio + 16.0
	var barra_y := centro.y - 40.0
	_barra_fundo = ColorRect.new()
	_barra_fundo.color = Color(0.12, 0.12, 0.14, 0.85)
	_barra_fundo.size = Vector2(8, 80)
	_barra_fundo.position = Vector2(barra_x, barra_y)
	_barra_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_barra_fundo)
	_barra = ColorRect.new()
	_barra.color = Color(0.3, 0.85, 0.4)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_fundo.add_child(_barra)
	_dica = _rotulo(Vector2(barra_x - 10, barra_y + 84), Vector2(40, 10), 7)
	_dica.text = "PUXAR"
	modulate.a = 0.0

func _rotulo(posicao: Vector2, tamanho: Vector2, fonte: int) -> Label:
	var rotulo := Label.new()
	rotulo.position = posicao
	rotulo.size = tamanho
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_estilizar(rotulo, fonte)
	add_child(rotulo)
	return rotulo

func _estilizar(rotulo: Label, tamanho: int) -> void:
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", Color(1, 1, 1))
	rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	rotulo.add_theme_constant_override("outline_size", 2)

func iniciar(quem: Node, nome_peixe: String, dificuldade_peixe: float, recomendado := 1) -> void:
	jogador = quem
	equipamento = preload("res://codigo/pesca/varas.gd").parametros(dificuldade_peixe,recomendado,preload("res://codigo/pesca/varas.gd").nivel(quem))
	dificuldade = maxf(5.0, equipamento["dificuldade"] - 0.1 * (preload("res://codigo/pesca/progressao_pesca.gd").nivel(quem) - 1))
	peixe_facil = recomendado == 1
	ganho_otimo = (26.0 if peixe_facil else 18.0)*equipamento["ganho"]
	ganho_bom = (18.0 if peixe_facil else 10.0)*equipamento["ganho"]
	perda_erro = (8.0 if peixe_facil else 13.0)*equipamento["perda"]
	_titulo.text = nome_peixe
	_tecla_icone.visible = Controle.usando_toque and not EventosJogo.eh_do_p2(quem)
	_tecla.text = "" if _tecla_icone.visible else Controle.rotulo_acao("attack",quem)
	var largura := maxf(13.0, _tecla.text.length() * 6.0 + 8.0)
	_tecla_caixa.size = Vector2(largura, 13)
	_tecla_caixa.position = centro - _tecla_caixa.size / 2.0
	progresso = 32.0 if peixe_facil else 22.0
	decorrido = 0.0
	ativo = true
	check_ativo = false
	pausa_antes = 0.6
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_atualizar_barra()
	queue_redraw()

func _apertou() -> bool:
	if jogador == null:
		return false
	return Input.is_action_just_pressed(jogador.acao("attack"))

func _process(delta: float) -> void:
	if not ativo:
		return
	decorrido += delta
	if pausa_antes > 0.0:
		pausa_antes -= delta
		if pausa_antes <= 0.0:
			_novo_check()
		return
	if check_ativo:
		percorrido += ponteiro_velocidade * delta
		ponteiro_angulo = ponteiro_base + percorrido
		if _apertou():
			_resolver_aperto()
		elif percorrido >= folga_zona + tamanho_zona + 0.12 or percorrido >= TAU:
			_resolver("erro", -perda_erro, Color(1, 0.3, 0.3))
		queue_redraw()

func _novo_check() -> void:
	var d := clampf(dificuldade / 100.0, 0.0, 1.0)
	var rampa := clampf(decorrido / tempo_rampa, 0.0, 1.0)
	var efetiva := rampa * (0.20 + 0.80 * d)
	if _errou_antes:
		efetiva = maxf(efetiva - ALIVIO_APOS_ERRO, 0.0)
	_errou_antes = false
	tamanho_zona = lerpf(1.35 if peixe_facil else 1.0, 0.65 if peixe_facil else 0.30, efetiva)*float(equipamento.get("zona",1.0))
	tamanho_otimo = tamanho_zona * 0.35
	ponteiro_velocidade = lerpf(TAU * 0.55, TAU * 1.5, efetiva)*float(equipamento.get("velocidade",1.0))
	ponteiro_base = randf() * TAU
	folga_zona = randf_range(TAU * 0.28, TAU * 0.92 - tamanho_zona)
	percorrido = 0.0
	ponteiro_angulo = ponteiro_base
	check_ativo = true
	queue_redraw()

func _resolver_aperto() -> void:
	var relativo := percorrido - folga_zona
	if relativo >= 0.0 and relativo <= tamanho_otimo:
		_resolver("otimo", ganho_otimo, Color(0.3, 1.0, 0.45))
	elif relativo >= 0.0 and relativo <= tamanho_zona:
		_resolver("bom", ganho_bom, Color(0.95, 0.9, 0.35))
	else:
		_resolver("erro", -perda_erro, Color(1.0, 0.3, 0.3))

func _resolver(tipo: String, valor: float, cor: Color) -> void:
	tentativas += 1
	if tipo == "otimo":
		otimos += 1
	progresso = clampf(progresso + valor, 0.0, PROGRESSO_MAXIMO)
	check_ativo = false
	_errou_antes = tipo == "erro"
	if tipo != "erro":
		puxao.emit(tipo == "otimo")
		Sons.tocar("acerto", 0.1)
	else:
		Sons.tocar("erro", 0.0)
	_feedback.text = {"otimo": "OTIMO!", "bom": "BOM", "erro": "ERROU"}.get(tipo, "")
	_feedback.modulate = cor
	_feedback.modulate.a = 1.0
	create_tween().tween_property(_feedback, "modulate:a", 0.0, 0.5).set_delay(0.15)
	_atualizar_barra()
	queue_redraw()
	if progresso >= PROGRESSO_MAXIMO:
		_encerrar(true)
	elif progresso <= 0.0:
		_encerrar(false)
	else:
		pausa_antes = 0.45

func _atualizar_barra() -> void:
	var fracao := progresso / PROGRESSO_MAXIMO
	var altura := _barra_fundo.size.y * fracao
	_barra.size = Vector2(_barra_fundo.size.x, altura)
	_barra.position = Vector2(0, _barra_fundo.size.y - altura)
	if fracao > 0.66:
		_barra.color = Color(0.3, 0.85, 0.4)
	elif fracao > 0.33:
		_barra.color = Color(0.9, 0.85, 0.3)
	else:
		_barra.color = Color(0.9, 0.45, 0.3)

func _draw() -> void:
	if not ativo:
		return
	draw_circle(centro, raio + 5.0, Color(0, 0, 0, 0.33))
	draw_arc(centro, raio, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 2.0, true)
	if check_ativo:
		var inicio := (ponteiro_base + folga_zona) - PI / 2.0
		draw_arc(centro, raio, inicio, inicio + tamanho_zona, 18, Color(0.95, 0.8, 0.2, 0.95), 4.0, true)
		draw_arc(centro, raio, inicio, inicio + tamanho_otimo, 10, Color(1, 1, 1, 1), 4.0, true)
		var direcao := Vector2(sin(ponteiro_angulo), -cos(ponteiro_angulo))
		draw_line(centro + direcao * (raio - 6.0), centro + direcao * (raio + 4.0), Color(0.95, 0.2, 0.2), 2.0)

func _encerrar(sucesso: bool) -> void:
	if not ativo:
		return
	ativo = false
	check_ativo = false
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		terminou.emit(sucesso)
		queue_free())

## Cancela por fora (jogador saiu, morreu, trocou de cena): some sem emitir resultado
func abortar() -> void:
	ativo = false
	queue_free()
