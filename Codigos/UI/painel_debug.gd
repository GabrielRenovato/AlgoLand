extends CanvasLayer

## Painel de testes (só em build de debug, ou seja, rodando pelo editor): F3 abre/fecha.
## Troca a estação e o clima na hora e solta raios, para conferir os visuais sem jogar várias ondas.
## Os botões não pegam foco do teclado/controle, então o jogador continua andando com o painel aberto.
## Obs.: o início de cada onda sorteia o clima de novo, por cima do que foi escolhido aqui. Os botões de estação
## só mexem no visual na hora (o calendário não muda); PASSAR DIA avança o calendário de verdade (como dormir).

const TEMA := preload("res://recursos/ui/tema_menu.tres")
const CAMADA := 90
const ESTACOES := ["PRIMAVERA", "VERAO", "OUTONO", "INVERNO"]
# Mesma ordem do enum Estado de Codigos/Design/clima.gd
const CLIMAS := ["LIMPO", "NUBLADO", "CHUVA LEVE", "CHUVA FORTE", "TEMPESTADE", "NEVE LEVE", "NEVE FORTE"]
const AVISO_RAIO_TESTE := 1.0
# [texto do botão, ação em fazenda_jogador.gd]
const ACOES_FAZENDA := [["ENXADA", "enxada"], ["MACHADO", "machado"], ["PICARETA", "picareta"],
	["PLANTAR", "plantar"], ["REGAR", "regar"], ["COLHER", "colher"]]

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
	var geral := VBoxContainer.new()
	geral.add_theme_constant_override("separation", 2)
	_painel.add_child(geral)

	geral.add_child(_rotulo("DEBUG  (F3 FECHA)"))
	_rotulo_estado = _rotulo("")
	_rotulo_estado.modulate = Color(1, 0.85, 0.4)
	geral.add_child(_rotulo_estado)

	# Duas colunas para caber na altura da tela: estação e clima | raio e fazenda
	var colunas := HBoxContainer.new()
	colunas.add_theme_constant_override("separation", 8)
	geral.add_child(colunas)
	var esquerda := VBoxContainer.new()
	esquerda.add_theme_constant_override("separation", 2)
	colunas.add_child(esquerda)
	var direita := VBoxContainer.new()
	direita.add_theme_constant_override("separation", 2)
	colunas.add_child(direita)

	esquerda.add_child(_rotulo("ESTACAO"))
	esquerda.add_child(_grade(ESTACOES.map(func(nome): return [nome, _ao_estacao.bind(ESTACOES.find(nome))])))
	esquerda.add_child(_rotulo("CLIMA"))
	var botoes_clima: Array = []
	for i in CLIMAS.size():
		botoes_clima.append([CLIMAS[i], _ao_clima.bind(i)])
	esquerda.add_child(_grade(botoes_clima))

	direita.add_child(_rotulo("CALENDARIO"))
	direita.add_child(_botao("PASSAR DIA", _ao_passar_dia))
	direita.add_child(_rotulo("TEMPESTADE"))
	direita.add_child(_botao("RAIO AGORA", _ao_raio))
	# A ação sai virada para a última direção em que o jogador andou
	direita.add_child(_rotulo("ANIMACOES"))
	direita.add_child(_grade(ACOES_FAZENDA.map(func(par): return [par[0], _ao_acao_fazenda.bind(par[1])])))
	direita.add_child(_rotulo("PLANTIO"))
	direita.add_child(_grade([["+100 OURO", _ao_ouro], ["SEMENTES", _ao_sementes],
		["COLHEITA", _ao_colheita], ["POCOES", _ao_pocoes],
		["CRESCER 1 DIA", _ao_crescer], ["REGAR TUDO", _ao_regar_tudo]]))

## Grade de 2 colunas com um botão por par [texto, Callable]
func _grade(botoes: Array) -> GridContainer:
	var grade := GridContainer.new()
	grade.columns = 2
	for par in botoes:
		grade.add_child(_botao(par[0], par[1]))
	return grade

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

## Avança o calendário um dia (o que dormir faz, sem cura nem fade); a estação visual acompanha se ela virar
func _ao_passar_dia() -> void:
	Calendario.dormir()

func _ao_ouro() -> void:
	DadosJogo.moedas += 100
	DadosJogo.atualizar_ui_moedas()

## 5 sementes de cada planta da estação atual (no inverno não há nenhuma)
func _ao_sementes() -> void:
	Fazenda.dar_sementes_debug()

## 5 de cada planta na bolsa de colheita (para testar o caldeirão)
func _ao_colheita() -> void:
	Fazenda.dar_colheita_debug()

## 3 poções de cada tipo (para testar o cinto na arena)
func _ao_pocoes() -> void:
	Fazenda.dar_pocoes_debug()

## As plantas vivas crescem 1 dia sem precisar regar nem dormir
func _ao_crescer() -> void:
	Fazenda.crescer_um_dia_debug()

func _ao_regar_tudo() -> void:
	Fazenda.regar_tudo_debug()

func _ao_acao_fazenda(acao: String) -> void:
	for no in get_tree().get_nodes_in_group("character"):
		if no is CharacterBody2D and no.has_method("acao_fazenda"):
			no.acao_fazenda(acao)
			return

func _atualizar_estado() -> void:
	var estacoes := _estacoes()
	var clima := _clima()
	var texto_estacao := "-"
	var texto_clima := "-"
	if estacoes != null:
		texto_estacao = ESTACOES[clampi(estacoes.estacao_atual, 0, ESTACOES.size() - 1)]
	if clima != null:
		texto_clima = CLIMAS[clampi(clima.clima_atual, 0, CLIMAS.size() - 1)]
	_rotulo_estado.text = "%s / %s / %s" % [texto_estacao, texto_clima, Calendario.texto_data()]
