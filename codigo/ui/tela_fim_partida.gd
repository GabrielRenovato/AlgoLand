extends Control

const IconesItens := preload("res://codigo/ui/icones_itens.gd")

@onready var _aviso_recorde: Label = %AvisoRecorde
@onready var _valor_onda: Label = %ValorOnda
@onready var _valor_abates: Label = %ValorAbates
@onready var _valor_ouro: Label = %ValorOuro
@onready var _valor_chefes: Label = %ValorChefes
@onready var _valor_brasas: Label = %ValorBrasas
@onready var _detalhe_brasas: Label = %DetalheBrasas
@onready var _botao_voltar: Button = %BotaoVoltar

func _ready() -> void:
	_botao_voltar.pressed.connect(_ao_voltar_pressionado)
	visibility_changed.connect(_ao_visibilidade_alterada)

func _ao_visibilidade_alterada() -> void:
	if visible:
		_preencher(Progresso.ultimo_resultado)

func _preencher(resultado: Dictionary) -> void:
	_aviso_recorde.visible = bool(resultado.get("novo_recorde", false))
	_valor_onda.text = str(resultado.get("onda", 0))
	_valor_abates.text = str(resultado.get("abates", 0))
	_valor_ouro.text = str(resultado.get("ouro", 0))
	_valor_chefes.text = str(resultado.get("chefes", 0))
	_valor_brasas.text = "+%d BRASAS" % int(resultado.get("brasas", 0))
	var bardo := int(resultado.get("brasas_bardo", 0))
	_detalhe_brasas.visible = bardo > 0
	_detalhe_brasas.text = "BASE %d + BARDO %d" % [int(resultado.get("brasas_base", 0)), bardo]

## Chamado pela Interface ao abrir a tela. Aqui o foco vale também no teclado: Enter/Espaço confirmam o botão
func focar_inicio() -> void:
	_botao_voltar.grab_focus()

## Reinicia o jogador com o kit inicial, fecha a tela e leva o jogador para a enfermaria
func _ao_voltar_pressionado() -> void:
	var jogador := EventosJogo.dono(self)
	if jogador != null:
		jogador.reiniciar_para_nova_partida()
	EventosJogo.fechar_tela_de(self, "fim_partida")
	# Depois de cair, o jogador acorda na enfermaria da Rosa (no prólogo, volta pelo caminho de sempre)
	if get_tree().get_first_node_in_group("gerenciador_ondas") != null:
		if Introducao.ativa():
			Transicao.sair_da_arena()
		else:
			Transicao.acordar_na_enfermaria()
