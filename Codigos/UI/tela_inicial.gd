extends Node2D

# preload em vez de class_name: classe global nova pode nao estar no cache fora do editor
const Opcoes := preload("res://Codigos/Globais/opcoes_jogo.gd")
const SpritesCompostos := preload("res://Codigos/Jogador/Sprites-compostos.gd")

const CENA_JOGO := "res://cenas/cenario.tscn"
const CENA_CUSTOMIZACAO := "res://cenas/customizacao-de-personagem.tscn"
const VALORES_FPS := [30, 60, 120, 0]
const ROTULOS_FPS := ["30", "60", "120", "SEM LIMITE"]
const BRILHO_FOCO := Color(1.15, 1.15, 1.15)

@export var caminho_save_personagem := "user://configuracao_jogador.json"
@export var caminho_save_inventario := "user://inventario.json"

@onready var titulo: Label = %Titulo
@onready var personagem: Node2D = %Personagem
@onready var sprite_corpo: Sprite2D = %Corpo
@onready var sprite_roupa: Sprite2D = %Roupa
@onready var sprite_cabelo: Sprite2D = %Cabelo
@onready var menu: VBoxContainer = %Menu
@onready var botao_continuar: Button = %BotaoContinuar
@onready var botao_novo_jogo: Button = %BotaoNovoJogo
@onready var botao_opcoes: Button = %BotaoOpcoes
@onready var botao_creditos: Button = %BotaoCreditos
@onready var botao_sair: Button = %BotaoSair
@onready var painel_opcoes: Control = %PainelOpcoes
@onready var botao_voltar_opcoes: Button = %BotaoVoltarOpcoes
@onready var painel_creditos: Control = %PainelCreditos
@onready var botao_voltar_creditos: Button = %BotaoVoltarCreditos
@onready var confirmar_novo_jogo: Control = %ConfirmarNovoJogo
@onready var botao_sim: Button = %BotaoSim
@onready var botao_nao: Button = %BotaoNao
@onready var transicao: ColorRect = %Transicao
@onready var escurecer: ColorRect = %Escurecer

var _opcoes: Dictionary
var _linhas: Array = []
var _painel_aberto: Control = null
var _botao_origem: Button = null
var _saindo := false

func _ready() -> void:
	_opcoes = Opcoes.carregar()
	Opcoes.aplicar(_opcoes)
	_montar_personagem()
	_animar_titulo()
	_animar_respiracao()
	_montar_opcoes()
	_montar_menu()
	_fade_entrada()
	# Fogo no máximo: a tela inicial é sempre crepúsculo
	get_tree().call_group("luzes_noturnas", "set", "multiplicador_noite", 1.0)

func _unhandled_input(evento: InputEvent) -> void:
	if _saindo or _painel_aberto == null:
		return
	if evento.is_action_pressed("close_menu"):
		_fechar_painel()
		get_viewport().set_input_as_handled()

func tem_save() -> bool:
	return FileAccess.file_exists(caminho_save_personagem) or FileAccess.file_exists(caminho_save_inventario)

func _montar_menu() -> void:
	botao_continuar.visible = tem_save()
	var botoes: Array[Button] = [botao_continuar, botao_novo_jogo, botao_opcoes, botao_creditos, botao_sair,
			botao_voltar_opcoes, botao_voltar_creditos, botao_sim, botao_nao]
	for botao in botoes:
		_configurar_botao(botao)
	botao_continuar.pressed.connect(_ao_continuar)
	botao_novo_jogo.pressed.connect(_ao_novo_jogo)
	botao_opcoes.pressed.connect(_abrir_painel.bind(painel_opcoes, botao_opcoes, %BotaoVolumeMenos))
	botao_creditos.pressed.connect(_abrir_painel.bind(painel_creditos, botao_creditos, botao_voltar_creditos))
	botao_sair.pressed.connect(_ao_sair)
	botao_voltar_opcoes.pressed.connect(_fechar_painel)
	botao_voltar_creditos.pressed.connect(_fechar_painel)
	botao_sim.pressed.connect(_ao_confirmar_novo_jogo)
	botao_nao.pressed.connect(_fechar_painel)
	var primeiro := botao_continuar if botao_continuar.visible else botao_novo_jogo
	primeiro.grab_focus()
	# Depois do foco inicial, para a tela não abrir com um "tick"; mover o foco e confirmar soam
	Sons.ligar_botoes(self)

func _configurar_botao(botao: Button) -> void:
	botao.set_meta("texto_base", botao.text)
	botao.focus_entered.connect(_destacar.bind(botao, true))
	botao.focus_exited.connect(_destacar.bind(botao, false))
	botao.mouse_entered.connect(botao.grab_focus)

func _destacar(botao: Button, ativo: bool) -> void:
	var texto_base: String = botao.get_meta("texto_base")
	botao.text = "> " + texto_base if ativo else texto_base
	botao.modulate = BRILHO_FOCO if ativo else Color.WHITE

func _montar_opcoes() -> void:
	var volumes: Array = []
	var rotulos_volume: Array = []
	for i in 11:
		volumes.append(i / 10.0)
		rotulos_volume.append("%d%%" % (i * 10))
	var indice_fps := VALORES_FPS.find(_opcoes["max_fps"])
	_adicionar_linha("volume", volumes, rotulos_volume, roundi(float(_opcoes["volume"]) * 10.0),
			%BotaoVolumeMenos, %ValorVolume, %BotaoVolumeMais)
	_adicionar_linha("tela_cheia", [false, true], ["NAO", "SIM"], 1 if _opcoes["tela_cheia"] else 0,
			%BotaoTelaCheiaMenos, %ValorTelaCheia, %BotaoTelaCheiaMais)
	_adicionar_linha("max_fps", VALORES_FPS, ROTULOS_FPS, indice_fps if indice_fps != -1 else 1,
			%BotaoFpsMenos, %ValorFps, %BotaoFpsMais)
	for i in _linhas.size():
		var anterior: Dictionary = _linhas[maxi(i - 1, 0)]
		var proxima: Dictionary = _linhas[i + 1] if i + 1 < _linhas.size() else {}
		var linha: Dictionary = _linhas[i]
		for lado in ["menos", "mais"]:
			var botao: Button = linha[lado]
			botao.focus_neighbor_top = (anterior[lado] as Button).get_path()
			var abaixo: Button = proxima[lado] if not proxima.is_empty() else botao_voltar_opcoes
			botao.focus_neighbor_bottom = abaixo.get_path()
	botao_voltar_opcoes.focus_neighbor_top = (_linhas[_linhas.size() - 1]["menos"] as Button).get_path()

func _adicionar_linha(chave: String, valores: Array, rotulos: Array, indice: int, menos: Button, rotulo_valor: Label, mais: Button) -> void:
	var linha := {"chave": chave, "valores": valores, "rotulos": rotulos, "indice": indice,
			"rotulo": rotulo_valor, "menos": menos, "mais": mais}
	var numero := _linhas.size()
	_linhas.append(linha)
	rotulo_valor.text = rotulos[indice]
	menos.pressed.connect(_mudar_linha.bind(numero, -1))
	mais.pressed.connect(_mudar_linha.bind(numero, 1))
	for botao in [menos, mais]:
		botao.gui_input.connect(_ao_entrada_linha.bind(numero))

func _ao_entrada_linha(evento: InputEvent, numero: int) -> void:
	if evento.is_action_pressed("ui_left"):
		_mudar_linha(numero, -1)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("ui_right"):
		_mudar_linha(numero, 1)
		get_viewport().set_input_as_handled()

func _mudar_linha(numero: int, passo: int) -> void:
	var linha: Dictionary = _linhas[numero]
	var indice := clampi(linha["indice"] + passo, 0, linha["valores"].size() - 1)
	if indice == linha["indice"]:
		return
	linha["indice"] = indice
	(linha["rotulo"] as Label).text = linha["rotulos"][indice]
	_opcoes[linha["chave"]] = linha["valores"][indice]
	_aplicar_e_salvar_opcoes()

func _aplicar_e_salvar_opcoes() -> void:
	Opcoes.aplicar(_opcoes)
	Opcoes.salvar(_opcoes)

func _abrir_painel(painel: Control, origem: Button, foco: Control) -> void:
	if _saindo:
		return
	_painel_aberto = painel
	_botao_origem = origem
	menu.hide()
	escurecer.show()
	painel.show()
	foco.grab_focus()

func _fechar_painel() -> void:
	if _saindo or _painel_aberto == null:
		return
	_painel_aberto.hide()
	_painel_aberto = null
	escurecer.hide()
	menu.show()
	_botao_origem.grab_focus()

func _ao_continuar() -> void:
	if FileAccess.file_exists(caminho_save_personagem):
		_trocar_cena(CENA_JOGO)
	else:
		_trocar_cena(CENA_CUSTOMIZACAO)

func _ao_novo_jogo() -> void:
	if tem_save():
		# Foca NAO por segurança: SIM apaga o progresso
		_abrir_painel(confirmar_novo_jogo, botao_novo_jogo, botao_nao)
	else:
		Progresso.apagar()
		_trocar_cena(CENA_CUSTOMIZACAO)

func _ao_confirmar_novo_jogo() -> void:
	if _saindo:
		return
	for caminho in [caminho_save_personagem, caminho_save_inventario]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	# Brasas, melhorias e moradores também recomeçam do zero (apaga user://progresso.json)
	Progresso.apagar()
	InventarioJogador.limpar()
	DadosJogo.resetar_moedas()
	_trocar_cena(CENA_CUSTOMIZACAO)

func _ao_sair() -> void:
	if _saindo:
		return
	get_tree().quit()

func _trocar_cena(caminho: String) -> void:
	if _saindo:
		return
	_saindo = true
	transicao.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(transicao, "modulate:a", 1.0, 0.35)
	await tween.finished
	get_tree().change_scene_to_file(caminho)

func _fade_entrada() -> void:
	transicao.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(transicao, "modulate:a", 0.0, 0.5)

func _animar_titulo() -> void:
	var y_base := titulo.position.y
	titulo.position.y = y_base - 3.0
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(titulo, "position:y", y_base + 3.0, 1.6)
	tween.tween_property(titulo, "position:y", y_base - 3.0, 1.6)

func _animar_respiracao() -> void:
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(personagem, "scale:y", 1.02, 1.2)
	tween.tween_property(personagem, "scale:y", 1.0, 1.2)

func _montar_personagem() -> void:
	var cabelo := 0
	var roupa := 0
	var cor := Color.WHITE
	if FileAccess.file_exists(caminho_save_personagem):
		var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho_save_personagem))
		if dados is Dictionary:
			cabelo = int(dados.get("cabelo_atual", 0))
			roupa = int(dados.get("roupa_atual", 0))
			var dict_cor = dados.get("cor_cabelo")
			if dict_cor is Dictionary:
				cor = Color(dict_cor.get("r", 1.0), dict_cor.get("g", 1.0), dict_cor.get("b", 1.0), dict_cor.get("a", 1.0))
	var compostos = SpritesCompostos.new()
	sprite_corpo.texture = compostos.folha_sprite_corpo[0]
	sprite_cabelo.texture = compostos.folha_sprite_cabelo.get(cabelo, compostos.folha_sprite_cabelo[0])
	sprite_roupa.texture = compostos.folha_sprite_roupa.get(roupa, compostos.folha_sprite_roupa[0])
	compostos.free()
	sprite_cabelo.modulate = cor
