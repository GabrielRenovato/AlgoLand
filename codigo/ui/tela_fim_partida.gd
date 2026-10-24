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

var _ranking_titulo: Label
var _ranking_lista: Label
var _ranking_aviso: Label

func _ready() -> void:
	_botao_voltar.pressed.connect(_ao_voltar_pressionado)
	visibility_changed.connect(_ao_visibilidade_alterada)
	_montar_ranking()

func _ao_visibilidade_alterada() -> void:
	if visible:
		_preencher(Progresso.ultimo_resultado)
		_atualizar_ranking()

func _montar_ranking() -> void:
	var conteudo := _botao_voltar.get_parent()
	var posicao := _botao_voltar.get_index()
	_ranking_titulo = Label.new()
	_ranking_titulo.text = "RANKING GLOBAL - ANDAR"
	_ranking_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ranking_lista = Label.new()
	_ranking_lista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ranking_aviso = Label.new()
	_ranking_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ranking_aviso.add_theme_color_override("font_color", Color(0.9, 0.5, 0.4))
	var separador := HSeparator.new()
	for no: Control in [separador, _ranking_titulo, _ranking_lista, _ranking_aviso]:
		conteudo.add_child(no)
		conteudo.move_child(no, posicao)
		posicao += 1
	Ranking.lista_atualizada.connect(_mostrar_lista)
	_perfil().envio_concluido.connect(_ao_envio_concluido)

func _atualizar_ranking() -> void:
	var ativo: bool = Ranking.disponivel()
	for no: Control in [_ranking_titulo, _ranking_lista, _ranking_aviso, _ranking_titulo.get_parent().get_child(_ranking_titulo.get_index() - 1)]:
		no.visible = ativo
	if not ativo:
		return
	_ranking_aviso.text = ""
	_ranking_lista.text = "CARREGANDO..."
	if not _perfil().ocupado():
		Ranking.buscar()

func _ao_envio_concluido(erro: String) -> void:
	if not visible:
		return
	_ranking_aviso.text = erro
	Ranking.buscar()

func _mostrar_lista(lista: Array) -> void:
	if lista.is_empty():
		_ranking_lista.text = "SEM DADOS NO MOMENTO"
		return
	var linhas: PackedStringArray = []
	for i in lista.size():
		var linha: Dictionary = lista[i]
		linhas.append("%d. %s - %d" % [i + 1, linha.get("apelido", "?"), int(linha.get("andar", 0))])
	_ranking_lista.text = "\n".join(linhas)

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

func _perfil() -> Node:
	return Ranking.para_jogador(EventosJogo.dono(self))
