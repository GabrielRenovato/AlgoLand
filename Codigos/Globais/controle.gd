extends Node

## Acompanha se o jogador está no controle ou no teclado/mouse (o último que foi usado).
## As telas usam isso para dar foco automático aos botões só para quem joga no controle,
## e o cursor do mouse some enquanto o controle está em uso.
## Também diz como os botões estão escritos no controle em uso (Xbox, Nintendo ou PlayStation),
## para as dicas na tela baterem com as letras impressas, e faz o controle vibrar.

# preload em vez de class_name: classe global nova pode não estar no cache fora do editor
const Opcoes := preload("res://Codigos/Globais/opcoes_jogo.gd")

## Controles na tela (celular): ver Codigos/UI/controles_toque.gd. Ligam sozinhos em Android/iOS; no PC, com `-- --toque` (o mouse
## faz o papel do dedo)
const ARGUMENTO_TOQUE := "--toque"
## Como cada ação aparece escrita nos controles na tela (as dicas do jogo usam rotulo_acao)
const ROTULOS_TOQUE := {"open_menu": "AGIR", "usar_pocao": "POÇÃO", "ferramenta_anterior": "<", "ferramenta_proxima": ">",
		"attack": "ATACAR", "rolar": "ROLAR", "aparar": "DEFESA", "open_inventory": "MOCHILA"}

## Muda o modo (teclado/mouse x controle) ou o desenho dos botões: quem mostra nome de tecla deve reescrever o texto
signal dicas_alteradas
signal modo_alterado(usando_controle: bool)

## Inclinação mínima do analógico/gatilho para contar como uso do controle
const ZONA_MORTA := 0.4
## Movimento mínimo do mouse (px) para voltar ao modo teclado/mouse
const MOVIMENTO_MOUSE := 2.0

const LAYOUTS := ["xbox", "nintendo", "playstation"]
# Nomes que o sistema dá ao controle quando ele não é um Xbox. Pro Controller e Joy-Con imprimem os botões no padrão
# Nintendo (A à direita, B embaixo, X em cima, Y à esquerda). 8BitDo NÃO entra aqui: há modelos com letras de Xbox
# e modelos com letras de Nintendo e o nome não diz qual; fica Xbox e, se não bater, o jogador troca em OPÇÕES > BOTÕES
const NOMES_NINTENDO := ["nintendo", "switch", "joy-con", "joycon", "pro controller"]
# O DualShock 4 aparece no Windows só como "Wireless Controller"; por isso esse nome só vale exato (o 8BitDo Ultimate tem "Wireless Controller" no fim)
const NOMES_PLAYSTATION := ["playstation", "dualshock", "dualsense", "sony", "ps3", "ps4", "ps5"]

# Rótulo de cada botão físico (índice do Godot, que é pela posição) em cada desenho de controle
const ROTULOS_BOTAO := {
	"xbox": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
			JOY_BUTTON_BACK: "VIEW", JOY_BUTTON_START: "MENU",
			JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"},
	"nintendo": {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
			JOY_BUTTON_BACK: "-", JOY_BUTTON_START: "+",
			JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"},
	"playstation": {JOY_BUTTON_A: "X", JOY_BUTTON_B: "O", JOY_BUTTON_X: "QUAD", JOY_BUTTON_Y: "TRI",
			JOY_BUTTON_BACK: "SHARE", JOY_BUTTON_START: "OPTIONS",
			JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"},
}
const ROTULOS_GATILHO := {
	"xbox": {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"},
	"nintendo": {JOY_AXIS_TRIGGER_LEFT: "ZL", JOY_AXIS_TRIGGER_RIGHT: "ZR"},
	"playstation": {JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2"},
}
const ROTULOS_DIRECIONAL := {JOY_BUTTON_DPAD_UP: "CIMA", JOY_BUTTON_DPAD_DOWN: "BAIXO",
		JOY_BUTTON_DPAD_LEFT: "ESQ", JOY_BUTTON_DPAD_RIGHT: "DIR"}

var usando_controle := false
## Jogando com os controles na tela
var usando_toque := false
## Direção do joystick virtual (tamanho de 0 a 1); zero quando solto
var vetor_toque := Vector2.ZERO
## "auto" decide pelo nome do controle; ou "xbox", "nintendo", "playstation" para fixar (OPÇÕES)
var preferencia_layout := "auto"
var vibracao_ligada := true
## Desenho dos botões em uso agora (resultado de preferencia_layout)
var layout := "xbox"
## Controle que foi usado por último (para ler o nome e fazer vibrar)
var dispositivo := 0

func _ready() -> void:
	usando_toque = OS.has_feature("mobile") or ARGUMENTO_TOQUE in OS.get_cmdline_user_args() or ARGUMENTO_TOQUE in OS.get_cmdline_args()
	if usando_toque:
		_tirar_mouse_das_acoes()
	var opcoes := Opcoes.carregar()
	preferencia_layout = opcoes["layout_controle"]
	vibracao_ligada = opcoes["vibracao"]
	Input.joy_connection_changed.connect(_ao_conexao_alterada)
	_atualizar_layout()

# O toque vira clique do mouse (para os menus), e o clique é "attack"/"aparar": sem isso, tocar num botão de menu atacaria
func _tirar_mouse_das_acoes() -> void:
	for acao in ["attack", "aparar"]:
		for evento in InputMap.action_get_events(acao):
			if evento is InputEventMouseButton:
				InputMap.action_erase_event(acao, evento)

## Para onde o jogador quer andar: o joystick da tela, ou o teclado/analógico (vetor de até tamanho 1, não normalizado)
func vetor_movimento() -> Vector2:
	if vetor_toque != Vector2.ZERO:
		return vetor_toque
	return Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))

## Margens (esquerda, cima, direita, baixo) em unidades da tela do jogo que o celular reserva para recortes da câmera, cantos
## arredondados e barras do sistema. No PC é tudo zero. A interface empurra os textos das bordas para dentro dessa folga
func margens_seguras() -> Vector4:
	# No PC (modo --toque) a janela é menor que a tela: a "área segura" do monitor não diz nada sobre ela
	if not (usando_toque and OS.has_feature("mobile")):
		return Vector4.ZERO
	var janela := Vector2(DisplayServer.window_get_size())
	var visivel := get_viewport().get_visible_rect().size
	if janela.x <= 0.0 or visivel.x <= 0.0:
		return Vector4.ZERO
	var escala := janela.x / visivel.x
	var segura := DisplayServer.get_display_safe_area()
	if segura.size == Vector2i.ZERO:
		return Vector4.ZERO
	var tela := Vector2(DisplayServer.screen_get_size())
	var esquerda := maxf(float(segura.position.x), 0.0)
	var cima := maxf(float(segura.position.y), 0.0)
	var direita := maxf(tela.x - float(segura.end.x), 0.0)
	var baixo := maxf(tela.y - float(segura.end.y), 0.0)
	return Vector4(esquerda, cima, direita, baixo) / escala

func _input(evento: InputEvent) -> void:
	var do_controle: bool = evento is InputEventJoypadButton \
			or (evento is InputEventJoypadMotion and absf(evento.axis_value) > ZONA_MORTA)
	var do_teclado: bool = evento is InputEventKey or evento is InputEventMouseButton \
			or (evento is InputEventMouseMotion and evento.relative.length() > MOVIMENTO_MOUSE)
	if do_controle and evento.device != dispositivo:
		dispositivo = evento.device
		_atualizar_layout()
	if do_controle and not usando_controle:
		_definir(true)
	elif do_teclado and usando_controle:
		_definir(false)

func _definir(valor: bool) -> void:
	usando_controle = valor
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if valor else Input.MOUSE_MODE_VISIBLE
	modo_alterado.emit(valor)
	dicas_alteradas.emit()

## Dá foco ao nó só quando o jogador está no controle (no mouse/teclado nada muda)
func focar(no: Control) -> void:
	if usando_controle and is_instance_valid(no) and no.is_visible_in_tree():
		no.grab_focus()

# --- Desenho dos botões ---

## Troca a preferência (OPÇÕES): "auto", "xbox", "nintendo" ou "playstation"
func definir_preferencia_layout(valor: String) -> void:
	preferencia_layout = valor
	_atualizar_layout()

func _ao_conexao_alterada(_id: int, _conectado: bool) -> void:
	_atualizar_layout()

func _atualizar_layout() -> void:
	var novo := preferencia_layout if preferencia_layout in LAYOUTS else _detectar_layout()
	if novo == layout:
		return
	layout = novo
	dicas_alteradas.emit()

func _detectar_layout() -> String:
	if not Input.get_connected_joypads().has(dispositivo):
		return "xbox"
	return layout_pelo_nome(Input.get_joy_name(dispositivo))

## Desenho dos botões pelo nome que o sistema dá ao controle (Xbox quando não reconhece)
static func layout_pelo_nome(nome_controle: String) -> String:
	var nome := nome_controle.to_lower()
	for parte in NOMES_NINTENDO:
		if nome.contains(parte):
			return "nintendo"
	for parte in NOMES_PLAYSTATION:
		if nome.contains(parte):
			return "playstation"
	if nome == "wireless controller":
		return "playstation"
	return "xbox"

## Como o botão do controle (índice JOY_BUTTON_*) está escrito no controle em uso
func rotulo_botao(botao: JoyButton) -> String:
	if ROTULOS_DIRECIONAL.has(botao):
		return ROTULOS_DIRECIONAL[botao]
	return ROTULOS_BOTAO[layout].get(botao, "")

## Como o jogador chama a ação agora: o botão do controle (se está no controle) ou a tecla do teclado
func rotulo_acao(acao: String) -> String:
	if usando_toque:
		return ROTULOS_TOQUE.get(acao, "")
	if not InputMap.has_action(acao):
		return ""
	var eventos := InputMap.action_get_events(acao)
	if usando_controle:
		for evento in eventos:
			if evento is InputEventJoypadButton:
				return rotulo_botao(evento.button_index)
		for evento in eventos:
			if evento is InputEventJoypadMotion and ROTULOS_GATILHO[layout].has(evento.axis):
				return ROTULOS_GATILHO[layout][evento.axis]
	for evento in eventos:
		if evento is InputEventKey:
			var tecla: Key = evento.keycode
			if tecla == KEY_NONE:
				tecla = DisplayServer.keyboard_get_keycode_from_physical(evento.physical_keycode)
			return OS.get_keycode_string(tecla).to_upper()
	return ""

# --- Vibração ---

## Faz o controle em uso vibrar (motor fraco e forte de 0 a 1). Só no modo controle e com a opção ligada
func vibrar(fraca: float, forte: float, duracao: float) -> void:
	if not usando_controle or not vibracao_ligada:
		return
	if not Input.get_connected_joypads().has(dispositivo):
		return
	Input.start_joy_vibration(dispositivo, clampf(fraca, 0.0, 1.0), clampf(forte, 0.0, 1.0), duracao)
