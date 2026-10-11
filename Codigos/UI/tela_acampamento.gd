extends Control

## Fogueira: gasta Brasas em melhorias permanentes e contrata os moradores do acampamento

const COR_BRASAS := Color(1, 0.7, 0.25)
const COR_SEM_BRASAS := Color(1, 0.45, 0.45)
const COR_DESCRICAO := Color(0.75, 0.7, 0.62)
const LARGURA_NOME := 62
const LARGURA_NIVEL := 34
const LARGURA_BOTAO := 56
const TEXTURA_BRASA := preload("res://UI/icone_brasa.png")

@onready var _aba_melhorias: Button = %AbaMelhorias
@onready var _aba_moradores: Button = %AbaMoradores
@onready var _lista_melhorias: VBoxContainer = %ListaMelhorias
@onready var _lista_moradores: VBoxContainer = %ListaMoradores
@onready var _rotulo_brasas: Label = %RotuloBrasas
@onready var _rotulo_recorde: Label = %Recorde
@onready var _botao_fechar: Button = %BotaoFechar

# id -> {"nivel": Label, "botao": Button}
var _linhas_melhorias: Dictionary = {}
# id -> Button
var _botoes_moradores: Dictionary = {}

func _ready() -> void:
	_montar_melhorias()
	_montar_moradores()
	_aba_melhorias.pressed.connect(_mostrar_aba.bind(true))
	_aba_moradores.pressed.connect(_mostrar_aba.bind(false))
	_botao_fechar.pressed.connect(EventosJogo.fechar_tela.emit.bind("acampamento"))
	Progresso.brasas_alteradas.connect(_ao_progresso_alterado)
	Progresso.melhorias_alteradas.connect(_atualizar)
	visibility_changed.connect(_ao_visibilidade_alterada)
	_atualizar()

func _ao_visibilidade_alterada() -> void:
	if visible:
		_aba_melhorias.button_pressed = true
		_mostrar_aba(true)
		_atualizar()

func _ao_progresso_alterado(_brasas: int) -> void:
	_atualizar()

func _mostrar_aba(melhorias: bool) -> void:
	_lista_melhorias.visible = melhorias
	_lista_moradores.visible = not melhorias

## Chamado pela Interface ao abrir a tela: no controle, o foco começa na primeira melhoria disponível
func focar_inicio() -> void:
	Controle.focar(_primeiro_botao_ativo())

func _primeiro_botao_ativo() -> Control:
	var botoes: Array = []
	if _lista_melhorias.visible:
		for id in Progresso.ORDEM_MELHORIAS:
			botoes.append(_linhas_melhorias[id]["botao"])
	else:
		for id in Progresso.ORDEM_MORADORES:
			botoes.append(_botoes_moradores[id])
	for botao in botoes:
		if not botao.disabled:
			return botao
	return _aba_melhorias if _lista_melhorias.visible else _aba_moradores

func _montar_melhorias() -> void:
	for id in Progresso.ORDEM_MELHORIAS:
		var dados: Dictionary = Progresso.MELHORIAS[id]
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 6)
		var nome := _criar_rotulo(dados["nome"], LARGURA_NOME)
		var nivel := _criar_rotulo("", LARGURA_NIVEL)
		var descricao := _criar_rotulo(dados["descricao"], 0)
		descricao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		descricao.add_theme_color_override("font_color", COR_DESCRICAO)
		var botao := _criar_botao_brasas()
		botao.pressed.connect(_ao_comprar_melhoria.bind(id))
		for no in [nome, nivel, descricao, botao]:
			linha.add_child(no)
		_lista_melhorias.add_child(linha)
		_linhas_melhorias[id] = {"nivel": nivel, "botao": botao}

func _montar_moradores() -> void:
	for id in Progresso.ORDEM_MORADORES:
		var dados: Dictionary = Progresso.MORADORES[id]
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 6)
		var nome := _criar_rotulo(dados["nome"], 74)
		var descricao := _criar_rotulo(dados["descricao"], 0)
		descricao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		descricao.add_theme_color_override("font_color", COR_DESCRICAO)
		var botao := _criar_botao_brasas()
		botao.custom_minimum_size.x = 80
		botao.pressed.connect(_ao_contratar.bind(id))
		for no in [nome, descricao, botao]:
			linha.add_child(no)
		_lista_moradores.add_child(linha)
		_botoes_moradores[id] = botao

func _criar_rotulo(texto: String, largura: int) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.custom_minimum_size.x = largura
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return rotulo

func _criar_botao_brasas() -> Button:
	var botao := Button.new()
	# Melhoria/contratação soam (melhoria, compra ou erro) no lugar do "confirmar" genérico
	botao.set_meta(Sons.META_SOM_PROPRIO, true)
	botao.custom_minimum_size = Vector2(LARGURA_BOTAO, 18)
	botao.icon = TEXTURA_BRASA
	return botao

func _ao_comprar_melhoria(id: String) -> void:
	if not Progresso.comprar_melhoria(id):
		_piscar_sem_brasas()
		return
	Sons.tocar("melhoria", 0.0)
	_corrigir_foco()

func _ao_contratar(id: String) -> void:
	if not Progresso.contratar(id):
		_piscar_sem_brasas()
		return
	Sons.tocar("compra", 0.0)
	_corrigir_foco()

# Brasas insuficientes: o contador pisca em vermelho
func _piscar_sem_brasas() -> void:
	Sons.tocar("erro", 0.0)
	_rotulo_brasas.add_theme_color_override("font_color", COR_SEM_BRASAS)
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_callback(_rotulo_brasas.add_theme_color_override.bind("font_color", COR_BRASAS))

func _atualizar() -> void:
	if not is_node_ready():
		return
	_rotulo_brasas.text = str(Progresso.brasas)
	_rotulo_recorde.text = "RECORDE: ONDA %d" % Progresso.recorde_onda
	for id in Progresso.ORDEM_MELHORIAS:
		var linha: Dictionary = _linhas_melhorias[id]
		var nivel := Progresso.nivel(id)
		linha["nivel"].text = "NV %d/%d" % [nivel, Progresso.NIVEL_MAXIMO]
		var botao: Button = linha["botao"]
		var custo := Progresso.custo_proximo(id)
		botao.disabled = custo == -1
		botao.text = "MAX" if custo == -1 else str(custo)
		botao.icon = null if custo == -1 else TEXTURA_BRASA
		_colorir_custo(botao, custo)
	for id in Progresso.ORDEM_MORADORES:
		var botao: Button = _botoes_moradores[id]
		var contratado := Progresso.tem_morador(id)
		var custo: int = Progresso.MORADORES[id]["custo"]
		botao.disabled = contratado
		botao.text = "CONTRATADO" if contratado else str(custo)
		botao.icon = null if contratado else TEXTURA_BRASA
		_colorir_custo(botao, -1 if contratado else custo)

# Sem Brasas suficientes o custo fica vermelho (o botão continua focável, no controle)
func _colorir_custo(botao: Button, custo: int) -> void:
	var sem_brasas := custo != -1 and Progresso.brasas < custo
	for estado in ["font_color", "font_focus_color", "font_hover_color"]:
		if sem_brasas:
			botao.add_theme_color_override(estado, COR_SEM_BRASAS)
		else:
			botao.remove_theme_color_override(estado)

# O botão comprado pode ter ficado desabilitado (nível máximo ou morador contratado): o foco não pode se perder
func _corrigir_foco() -> void:
	var dono := get_viewport().gui_get_focus_owner()
	if dono is Button and (dono as Button).disabled:
		Controle.focar(_primeiro_botao_ativo())
