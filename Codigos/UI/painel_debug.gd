extends CanvasLayer

## Painel de testes (só em build de debug, ou seja, rodando pelo editor): F3 abre/fecha.
## Troca a estação e o clima na hora e solta raios, para conferir os visuais sem jogar várias ondas.
## Os botões não pegam foco do teclado/controle, então o jogador continua andando com o painel aberto.
## Obs.: o início de cada onda sorteia o clima de novo, por cima do que foi escolhido aqui.

const TEMA := preload("res://recursos/ui/tema_menu.tres")
const CAMADA := 90
const ESTACOES := ["PRIMAVERA", "VERAO", "OUTONO", "INVERNO"]
# Mesma ordem do enum Estado de Codigos/Design/clima.gd
const CLIMAS := ["LIMPO", "NUBLADO", "CHUVA LEVE", "CHUVA FORTE", "TEMPESTADE", "NEVE LEVE", "NEVE FORTE"]
const AVISO_RAIO_TESTE := 1.0

var _painel: PanelContainer
var _rotulo_estado: Label

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_painel.visible = false

# A estação troca com fade e a onda pode sortear outro clima: o rótulo acompanha enquanto o painel está aberto
func _process(_delta: float) -> void:
	if _painel != null and _painel.visible:
		_atualizar_estado()

func _unhandled_key_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_F3:
		_painel.visible = not _painel.visible
		get_viewport().set_input_as_handled()

func _montar() -> void:
	_painel = PanelContainer.new()
	_painel.theme = TEMA
	_painel.position = Vector2(4, 70)
	add_child(_painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 2)
	_painel.add_child(coluna)

	coluna.add_child(_rotulo("DEBUG  (F3 FECHA)"))
	_rotulo_estado = _rotulo("")
	_rotulo_estado.modulate = Color(1, 0.85, 0.4)
	coluna.add_child(_rotulo_estado)

	coluna.add_child(_rotulo("ESTACAO"))
	var grade_estacoes := GridContainer.new()
	grade_estacoes.columns = 2
	coluna.add_child(grade_estacoes)
	for i in ESTACOES.size():
		grade_estacoes.add_child(_botao(ESTACOES[i], _ao_estacao.bind(i)))

	coluna.add_child(_rotulo("CLIMA"))
	var grade_climas := GridContainer.new()
	grade_climas.columns = 2
	coluna.add_child(grade_climas)
	for i in CLIMAS.size():
		grade_climas.add_child(_botao(CLIMAS[i], _ao_clima.bind(i)))

	coluna.add_child(_botao("RAIO AGORA", _ao_raio))

func _rotulo(texto: String) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	return rotulo

func _botao(texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.focus_mode = Control.FOCUS_NONE
	botao.pressed.connect(acao)
	return botao

func _estacoes() -> Node:
	var cena := get_tree().current_scene
	return cena.find_child("Estacoes", true, false) if cena else null

func _clima() -> Node:
	return get_tree().get_first_node_in_group("clima")

func _ao_estacao(indice: int) -> void:
	var estacoes := _estacoes()
	if estacoes == null:
		return
	estacoes.definir_estacao(indice)

func _ao_clima(estado: int) -> void:
	var clima := _clima()
	if clima == null:
		return
	clima.definir_clima(estado)

## Solta um raio perto do jogador (ou de um inimigo), com o aviso no chão, em qualquer clima
func _ao_raio() -> void:
	var clima := _clima()
	if clima == null or clima.get("_jogador") == null:
		return
	clima.criar_raio(clima.sortear_ponto_raio(), AVISO_RAIO_TESTE)

func _atualizar_estado() -> void:
	var estacoes := _estacoes()
	var clima := _clima()
	var texto_estacao := "-"
	var texto_clima := "-"
	if estacoes != null:
		texto_estacao = ESTACOES[clampi(estacoes.estacao_atual, 0, ESTACOES.size() - 1)]
	if clima != null:
		texto_clima = CLIMAS[clampi(clima.clima_atual, 0, CLIMAS.size() - 1)]
	_rotulo_estado.text = "%s / %s" % [texto_estacao, texto_clima]
