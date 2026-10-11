extends Area2D

## Zona de interação genérica (mesmo padrão do Merchant): aviso F/Y quando o jogador chega perto e abre a tela
## `nome_tela` pela Interface. Usada pela Fogueira (acampamento) e pelos moradores (Mística).

# Tecla/botão mostrado no aviso de interação (botão de cima do controle no padrão X-input)
const TECLA_TECLADO := "F"
const TECLA_CONTROLE := "Y"
const TEXTURA_AVISO := preload("res://UI/craftpix-net-775352-game-user-interface-pixel-art/1 Frames/Frame2.png")
const FONTE_AVISO := preload("res://UI/craftpix-net-775352-game-user-interface-pixel-art/6 Font/CraftPixNet Survival Kit.otf")

## Nome da tela registrada na Interface (ex.: "acampamento", "mistica")
@export var nome_tela: String = ""
## Posição do aviso em relação à zona
@export var deslocamento_aviso: Vector2 = Vector2(0, -23)
## Só interage entre as ondas (consulta onda_em_andamento do gerenciador)
@export var so_entre_ondas: bool = true

var jogador_perto: bool = false

var _aviso: Sprite2D
var _rotulo_tecla: Button
var _tela_aberta: bool = false

func _ready() -> void:
	add_to_group("interagiveis")
	collision_layer = 0
	collision_mask = 2
	_montar_aviso()
	body_entered.connect(_ao_corpo_entrou)
	body_exited.connect(_ao_corpo_saiu)
	EventosJogo.tela_aberta.connect(_ao_tela_aberta)
	EventosJogo.tela_fechada.connect(_ao_tela_fechada)
	Controle.modo_alterado.connect(_ao_modo_controle)
	_ao_modo_controle(Controle.usando_controle)

# Mesma moldura e escala do aviso do mercador
func _montar_aviso() -> void:
	_aviso = Sprite2D.new()
	_aviso.texture = TEXTURA_AVISO
	_aviso.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sempre acima do jogador e dos objetos (que ordenam por z pela altura dos pés)
	_aviso.z_as_relative = false
	_aviso.z_index = 900
	_aviso.position = deslocamento_aviso
	_aviso.scale = Vector2(0.538463, 0.519231)
	_aviso.visible = false
	add_child(_aviso)
	_rotulo_tecla = Button.new()
	_rotulo_tecla.flat = true
	_rotulo_tecla.focus_mode = Control.FOCUS_NONE
	_rotulo_tecla.position = Vector2(-15.1428, -15.7037)
	_rotulo_tecla.size = Vector2(32, 31)
	_rotulo_tecla.add_theme_font_override("font", FONTE_AVISO)
	_rotulo_tecla.add_theme_font_size_override("font_size", 12)
	_rotulo_tecla.pressed.connect(abrir_tela)
	_aviso.add_child(_rotulo_tecla)

func _ao_modo_controle(usando_controle: bool) -> void:
	_rotulo_tecla.text = TECLA_CONTROLE if usando_controle else TECLA_TECLADO

func _process(_delta: float) -> void:
	var disponivel := disponivel_para_interacao() and not _tela_aberta
	_aviso.visible = disponivel
	if disponivel and Input.is_action_just_pressed("open_menu"):
		abrir_tela()

## Perto do jogador, liberado e o mais próximo entre as zonas que se sobrepõem (fogueira e mercador, por exemplo)
func disponivel_para_interacao() -> bool:
	return jogador_perto and pode_interagir() and eh_o_mais_proximo(self)

## Zonas do grupo "interagiveis" (esta classe e o Merchant) podem se sobrepor: só a mais próxima do jogador age,
## para o mesmo F não abrir duas telas. Cada membro responde por disponivel_para_interacao_isolada()
static func eh_o_mais_proximo(no: Node2D) -> bool:
	var jogador: Node2D = null
	for candidato in no.get_tree().get_nodes_in_group("character"):
		if candidato is CharacterBody2D:
			jogador = candidato
			break
	if jogador == null:
		return true
	var minha := no.global_position.distance_squared_to(jogador.global_position)
	for outro in no.get_tree().get_nodes_in_group("interagiveis"):
		if outro == no or not outro.disponivel_isolada():
			continue
		if outro.global_position.distance_squared_to(jogador.global_position) < minha:
			return false
	return true

## Sem a arbitragem entre zonas
func disponivel_isolada() -> bool:
	return jogador_perto and pode_interagir()

func pode_interagir() -> bool:
	if nome_tela == "":
		return false
	if not so_entre_ondas:
		return true
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	return gerenciador == null or not gerenciador.onda_em_andamento

func abrir_tela() -> void:
	if pode_interagir():
		EventosJogo.abrir_tela.emit(nome_tela)

func fechar_tela() -> void:
	EventosJogo.fechar_tela.emit(nome_tela)

func _ao_corpo_entrou(corpo: Node2D) -> void:
	if corpo.is_in_group("character"):
		jogador_perto = true

func _ao_corpo_saiu(corpo: Node2D) -> void:
	if corpo.is_in_group("character"):
		jogador_perto = false
		_aviso.visible = false
		fechar_tela()

func _ao_tela_aberta(nome: String) -> void:
	if nome == nome_tela:
		_tela_aberta = true

func _ao_tela_fechada(nome: String) -> void:
	if nome == nome_tela:
		_tela_aberta = false
