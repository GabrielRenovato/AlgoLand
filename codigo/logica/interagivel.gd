extends Area2D

## Zona de interação genérica (mesmo padrão do Merchant): aviso F/Y quando o jogador chega perto e abre a tela
## `nome_tela` pela Interface. Usada pela Fogueira (acampamento) e pelos moradores (Mística).

const TEXTURA_AVISO := preload("res://assets/ui/craftpix-net-775352-game-user-interface-pixel-art/1 Frames/Frame2.png")
# Planes_ValMore: o Y da CraftPixNet Survival Kit se parece com um "y" minúsculo nas letras de botão do controle
const FONTE_AVISO := preload("res://assets/ui/Planes_ValMore.ttf")

## Nome da tela registrada na Interface (ex.: "acampamento", "mistica")
@export var nome_tela: String = ""
## Posição do aviso em relação à zona
@export var deslocamento_aviso: Vector2 = Vector2(0, -23)
## Só interage entre as ondas (consulta onda_em_andamento do gerenciador)
@export var so_entre_ondas: bool = true

var jogador_perto: bool = false
## Cooperativo: o jogador 2 também interage (com o botão dele), e a tela abre na metade dele
var p2_perto: bool = false

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
	Controle.dicas_alteradas.connect(_atualizar_tecla)
	_atualizar_tecla()

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

# F no teclado; no controle, o botão como está escrito nele (Y no Xbox, X no 8BitDo)
func _atualizar_tecla() -> void:
	_rotulo_tecla.text = Controle.rotulo_acao("open_menu")
	# Texto de toque ("AGIR") é mais comprido que uma tecla: fonte menor para caber no botão de 32 px
	_rotulo_tecla.add_theme_font_size_override("font_size", 12 if _rotulo_tecla.text.length() <= 2 else 7)

func _process(_delta: float) -> void:
	var p1 := Cooperativo._jogador1()
	var p2 := Cooperativo.jogador2()
	# Sentado, o F/Y só levanta: nenhuma zona em volta oferece outra coisa
	var disponivel := disponivel_para_interacao() and not _tela_aberta and not _sentado(p1)
	var para_p2 := disponivel_para_p2()
	_aviso.visible = disponivel or para_p2
	var pode_pedir: bool = p1 != null and p1.pode_iniciar_interacao()
	if disponivel and pode_pedir and Input.is_action_just_pressed("open_menu"):
		abrir_tela()
	elif para_p2 and InputMap.has_action("p2_open_menu") and Input.is_action_just_pressed("p2_open_menu"):
		abrir_tela_p2()

static func _sentado(jogador: Node) -> bool:
	return jogador != null and bool(jogador.get("esta_sentado"))

func _p2_livre() -> bool:
	var p2 := Cooperativo.jogador2()
	return p2 != null and p2.movimento_habilitado and not p2.estaMorto and not _sentado(p2) and p2.pode_iniciar_interacao()

## O jogador 2 pode usar esta zona agora: perto, livre e ela é a escolhida entre as que se sobrepõem em volta DELE
## (sem isso todas as zonas perto dele mostravam o aviso e o mesmo botão abria todas de uma vez)
func disponivel_para_p2() -> bool:
	var p2 := Cooperativo.jogador2()
	return p2_perto and _p2_livre() and pode_interagir_para(p2) and eh_o_mais_proximo(self, p2)

## O jogador 2 pediu: a tela abre na interface dele (as zonas que fazem outra coisa, como portas, reescrevem)
func abrir_tela_p2() -> void:
	if pode_interagir_para(Cooperativo.jogador2()):
		EventosJogo.abrir_tela_para(Cooperativo.jogador2(), nome_tela)

## Objetos com estado por jogador (como assentos) validam quem realmente pediu a interação.
func pode_interagir_para(_jogador: Node2D) -> bool:
	return pode_interagir()

## Perto do jogador, liberado e o mais próximo entre as zonas que se sobrepõem (fogueira e mercador, por exemplo)
func disponivel_para_interacao() -> bool:
	return jogador_perto and pode_interagir() and eh_o_mais_proximo(self)

## Zonas do grupo "interagiveis" (esta classe e o Merchant) podem se sobrepor: só uma age por jogador, para o mesmo
## F não abrir duas telas. Vence a de maior prioridade_interacao() (assento vazio passa na frente do morador sentado ao
## lado) e, empatadas, a mais próxima. Sem `jogador`, a disputa é em volta do jogador 1.
static func eh_o_mais_proximo(no: Node2D, jogador: Node2D = null) -> bool:
	if jogador == null:
		for candidato in no.get_tree().get_nodes_in_group("character"):
			if candidato is CharacterBody2D:
				jogador = candidato
				break
	if jogador == null:
		return true
	if jogador.get_world_2d() != no.get_world_2d():
		return true
	var eh_p2 := jogador.is_in_group("jogador2")
	var minha_prioridade := _prioridade(no)
	var minha := no.global_position.distance_squared_to(jogador.global_position)
	for outro in no.get_tree().get_nodes_in_group("interagiveis"):
		if outro == no or outro.get_world_2d() != no.get_world_2d():
			continue
		if eh_p2:
			if not outro.has_method("disponivel_isolada_p2") or not outro.disponivel_isolada_p2():
				continue
		elif not outro.disponivel_isolada():
			continue
		var prioridade := _prioridade(outro)
		if prioridade != minha_prioridade:
			if prioridade > minha_prioridade:
				return false
			continue
		if outro.global_position.distance_squared_to(jogador.global_position) < minha:
			return false
	return true

static func _prioridade(no: Node) -> int:
	return int(no.prioridade_interacao()) if no.has_method("prioridade_interacao") else 0

## Peso na disputa entre zonas sobrepostas (0 = só a distância decide)
func prioridade_interacao() -> int:
	return 0

## Sem a arbitragem entre zonas
func disponivel_isolada() -> bool:
	return jogador_perto and pode_interagir()

## Idem, para o jogador 2
func disponivel_isolada_p2() -> bool:
	return p2_perto and _p2_livre() and pode_interagir_para(Cooperativo.jogador2())

func pode_interagir() -> bool:
	if not Introducao.permite_interacao(self):
		return false
	# No meio do refino na bigorna nada abre por perto (o portal cancelava a animação)
	var jogador := Cooperativo.jogador_no_ambiente(self)
	if jogador != null and bool(jogador.get("esta_forjando")):
		return false
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
	elif corpo.is_in_group("jogador2"):
		p2_perto = true

func _ao_corpo_saiu(corpo: Node2D) -> void:
	if corpo.is_in_group("jogador2"):
		p2_perto = false
		return
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
