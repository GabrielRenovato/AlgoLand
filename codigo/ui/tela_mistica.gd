extends Control

## Mística: escolhe a onda inicial da próxima partida (checkpoint), só antes da primeira onda.
## A cada chefe derrotado libera a onda seguinte a ele (11, 21...) e paga uma compensação em ouro.
## Mesmo visual da mochila, da loja e do caldeirão (tema_sidebar.tres, moldura do TileMap.png, título escuro no alto e o X de fechar).

const COR_DESCRICAO := Color(0.75, 0.7, 0.62)

@onready var _lista: VBoxContainer = %ListaCheckpoints
@onready var _aviso: Label = %Aviso
@onready var _botao_fechar: TextureButton = %BotaoFechar

var _grupo := ButtonGroup.new()
var _botoes: Dictionary = {}

func _ready() -> void:
	_botao_fechar.pressed.connect(EventosJogo.fechar_tela_de.bind(self, "mistica"))
	visibility_changed.connect(_ao_visibilidade_alterada)

func _ao_visibilidade_alterada() -> void:
	if visible:
		_montar()

func _gerenciador() -> Node:
	return get_tree().get_first_node_in_group("gerenciador_ondas")

func _intervalo_chefe() -> int:
	var gerenciador := _gerenciador()
	return gerenciador.intervalo_chefe if gerenciador != null else 10

## Chamado pela Interface ao abrir a tela: no controle, o foco começa na opção escolhida
func focar_inicio() -> void:
	var inicio: Control = _botoes.get(Progresso.onda_inicial, _botao_fechar)
	if inicio.disabled:
		inicio = _botao_fechar
	Controle.focar(inicio)

func _montar() -> void:
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	_botoes.clear()
	var pode := Progresso.pode_escolher_checkpoint()
	for onda in Progresso.checkpoints_disponiveis(_intervalo_chefe()):
		var botao := Button.new()
		botao.toggle_mode = true
		botao.button_group = _grupo
		botao.custom_minimum_size = Vector2(0, 18)
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var compensacao := Progresso.ouro_checkpoint(onda)
		botao.text = "ONDA %d" % onda if compensacao == 0 else "ONDA %d    +%d OURO" % [onda, compensacao]
		botao.disabled = not pode
		botao.set_pressed_no_signal(onda == Progresso.onda_inicial)
		botao.pressed.connect(_ao_escolher.bind(onda))
		_lista.add_child(botao)
		_botoes[onda] = botao
	if not pode:
		_aviso.text = "SO ANTES DA PRIMEIRA ONDA"
	elif _botoes.size() == 1:
		_aviso.text = "DERROTE UM CHEFE PARA LIBERAR MAIS"
	else:
		_aviso.text = ""

func _ao_escolher(onda: int) -> void:
	# Trocar de checkpoint devolve a compensação anterior: não pode deixar o ouro negativo
	var diferenca := Progresso.ouro_checkpoint(onda) - Progresso.ouro_compensacao
	if EventosJogo.moedas_de(self) + diferenca < 0:
		_aviso.text = "OURO INSUFICIENTE PARA TROCAR"
		Sons.tocar("erro", 0.0)
		_botoes[Progresso.onda_inicial].set_pressed_no_signal(true)
		return
	diferenca = Progresso.definir_checkpoint(onda, _intervalo_chefe())
	# Compensação da partida: vale para as duas carteiras (cooperativo)
	DadosJogo.moedas += diferenca
	DadosJogo.moedas_p2 += diferenca
	DadosJogo.atualizar_ui_moedas()
	var gerenciador := _gerenciador()
	if gerenciador != null:
		gerenciador.definir_onda_inicial(onda)
	get_tree().call_group("tela_mercante", "atualizar_exibicao_moedas")
	_aviso.text = ""
