extends Control

## Confirmação "DORMIR?" da cama da casa. SIM fecha a tela e faz a noite passar (Transicao.dormir: fade, Calendario.dormir,
## cura total, salvamento e o jogador acorda ao lado da cama); NAO só fecha.

@onready var _detalhe: Label = %Detalhe
@onready var _botao_sim: Button = %BotaoSim
@onready var _botao_nao: Button = %BotaoNao

func _ready() -> void:
	_botao_sim.pressed.connect(_ao_sim)
	_botao_nao.pressed.connect(_ao_nao)
	visibility_changed.connect(_ao_visibilidade_alterada)

func _ao_visibilidade_alterada() -> void:
	if visible:
		_detalhe.text = "AMANHA: %s" % _texto_amanha()

# A data do dia seguinte (a mesma conta do Calendario, sem avançar nada)
func _texto_amanha() -> String:
	var proximo: int = Calendario.dia + 1
	var dia_na_estacao: int = (proximo - 1) % Calendario.DIAS_POR_ESTACAO + 1
	return "%s - DIA %d" % [Calendario.NOMES[Calendario.estacao(proximo)], dia_na_estacao]

## Chamado pela Interface ao abrir a tela. O foco vale também no teclado: Enter/Espaço confirmam o botão
func focar_inicio() -> void:
	_botao_sim.grab_focus()

func _ao_sim() -> void:
	EventosJogo.fechar_tela.emit("dormir")
	Transicao.dormir("cama")

func _ao_nao() -> void:
	EventosJogo.fechar_tela.emit("dormir")
