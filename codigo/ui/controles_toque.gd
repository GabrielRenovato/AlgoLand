extends CanvasLayer

## Controles na tela para jogar no celular, no estilo do Wild Rift:
##  - à esquerda, um joystick flutuante: onde o dedo encosta (metade esquerda da tela) nasce a base e a direção vai para
##    Controle.vetor_toque (o jogador anda por Controle.vetor_movimento());
##  - à direita embaixo, o botão grande de ATACAR (na fazenda vira USAR a ferramenta) e, em arco acima e à esquerda dele, os
##    botões de DEFESA (segurar), ROLAR, POÇÃO (COLHER na fazenda) e AGIR (a tecla F: conversar, abrir, sentar...);
##  - um botão pequeno para abrir a MOCHILA. Trocar a ferramenta (fazenda) e a poção (arena) é tocando na barra do HUD embaixo.
## Cada botão manda uma InputEventAction com o nome da ação do jogo (attack, rolar, aparar...), então o jogador e as telas não
## sabem que é toque. Multitoque: o joystick e os botões funcionam ao mesmo tempo, cada um com o seu dedo.
## Só existe com Controle.usando_toque (Android/iOS, ou `-- --toque` no PC, onde o mouse faz o papel do dedo). Some quando uma
## tela (mochila, loja...) está aberta, porque aí o toque é dos menus (o X de fechar delas é ajustado em Interface).

const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const IconesFazenda := preload("res://codigo/ui/icones_fazenda.gd")
const Pocoes := preload("res://codigo/dados/pocoes.gd")
## Ícones dos botões: glifos brancos de pixel art do pacote "Cute RPG - Icons" (PixyMoon), no tamanho original (1 para 1 na tela
## do jogo). As folhas do Cute RPG trazem o glifo sobre um ladrilho colorido: fica só o branco, e a cor
## do botão é a nossa. O ataque na fazenda mostra a ferramenta escolhida e a poção mostra a poção escolhida do cinto
const FOLHA_GLIFOS := "res://assets/ui/Cute RPG - Icons (1)/Cute RPG - Icons/32x32/CuteRPG_Icons01.png"
const LADO_GLIFO := 32
const MOLDURA_GLIFO := 4
## Lado do glifo recortado
const LADO_MIOLO := 24.0
## (coluna, linha) de cada glifo na folha
const GLIFO_ATAQUE := Vector2i(11, 3)
const GLIFO_DEFESA := Vector2i(11, 6)
const GLIFO_ROLAR := Vector2i(14, 6)
const GLIFO_AGIR := Vector2i(15, 5)
const GLIFO_ITENS := Vector2i(14, 8)   # o saco amarrado
## Lado dos ícones de pixel art de 16 px (poção, ferramenta): o dobro, inteiro
const LADO_ICONE_16 := 32.0
const COR_SEM_POCAO := Color(0.45, 0.45, 0.5)

## Raios em unidades da tela do jogo (576x324 de altura fixa; 1 unidade é perto de 1 dp num celular deitado)
const RAIO_ATAQUE := 34.0
const RAIO_HABILIDADE := 22.0
const RAIO_PEQUENO := 15.0
const RAIO_MOCHILA := 19.0
const RAIO_JOYSTICK := 40.0
const RAIO_HASTE := 16.0
const ZONA_MORTA := 0.18
## Folga ao redor de cada botão onde o dedo ainda conta como nele
const FOLGA_TOQUE := 8.0
const MARGEM := 16.0
## Distância e ângulo (graus, 180 = esquerda, 270 = cima) das habilidades em torno do botão de ataque
const RAIO_ARCO := 78.0
const OPACIDADE := 0.5
const OPACIDADE_APERTADO := 0.9

const COR_ATAQUE := Color(0.85, 0.3, 0.25)
const COR_DEFESA := Color(0.3, 0.55, 0.9)
const COR_ROLAR := Color(0.35, 0.75, 0.4)
const COR_POCAO := Color(0.7, 0.4, 0.85)
const COR_AGIR := Color(0.95, 0.8, 0.3)
const COR_NEUTRA := Color(0.6, 0.6, 0.65)

## acao, rótulo, centro (preenchido por _organizar), raio, cor, onde aparece ("" = sempre, "arena", "fazenda")
var _botoes: Array[Dictionary] = []

var _tela: Control
## Por cima dos ícones (os textos que ficam sobre eles)
var _sobre: Control
var _tamanho := Vector2(576, 324)
## Os botões aparecem (nenhuma tela aberta)
var _ativo := true
var _telas_abertas: Dictionary = {}
var _modo_mouse := false
var _tempo_conferir := 0.0

# Dedos: índice do dedo -> botão (Dictionary de _botoes) ou o joystick
var _dedos: Dictionary = {}
var _dedo_joystick := -1
var _base_joystick := Vector2.ZERO
var _haste_joystick := Vector2.ZERO

func _ready() -> void:
	# Abaixo das telas (camada 10 da Interface)
	layer = 9
	_modo_mouse = not OS.has_feature("mobile")
	_tela = Control.new()
	_tela.name = "Tela"
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	_sobre = Control.new()
	_sobre.name = "Sobre"
	_sobre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sobre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sobre.draw.connect(_desenhar_sobre)
	add_child(_sobre)
	_criar_botoes()
	get_viewport().size_changed.connect(_organizar)
	_organizar()
	EventosJogo.tela_aberta.connect(_ao_tela_aberta)
	EventosJogo.tela_fechada.connect(_ao_tela_fechada)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _criar_botoes() -> void:
	_botoes = [
		{"acao": &"attack", "rotulo": "ATACAR", "raio": RAIO_ATAQUE, "cor": COR_ATAQUE, "onde": "", "segura": false, "textura": _glifo(GLIFO_ATAQUE), "lado": LADO_MIOLO},
		{"acao": &"aparar", "rotulo": "DEFESA", "raio": RAIO_HABILIDADE, "cor": COR_DEFESA, "onde": "arena", "angulo": 184.0, "segura": true, "textura": _glifo(GLIFO_DEFESA), "lado": LADO_MIOLO},
		{"acao": &"rolar", "rotulo": "ROLAR", "raio": RAIO_HABILIDADE, "cor": COR_ROLAR, "onde": "", "angulo": 218.0, "segura": false, "textura": _glifo(GLIFO_ROLAR), "lado": LADO_MIOLO},
		{"acao": &"usar_pocao", "rotulo": "POÇÃO", "raio": RAIO_HABILIDADE, "cor": COR_POCAO, "onde": "arena", "angulo": 252.0, "segura": false, "textura": Pocoes.icone("cura"), "lado": LADO_ICONE_16},
		{"acao": &"colher", "rotulo": "COLHER", "raio": RAIO_HABILIDADE, "cor": COR_AGIR, "onde": "fazenda", "angulo": 252.0, "segura": false},
		{"acao": &"open_menu", "rotulo": "", "raio": RAIO_HABILIDADE, "cor": COR_AGIR, "onde": "", "angulo": 286.0, "segura": false, "textura": _glifo(GLIFO_AGIR), "lado": LADO_MIOLO},
		{"acao": &"open_inventory", "rotulo": "ITENS", "raio": RAIO_MOCHILA, "cor": COR_NEUTRA, "onde": "", "canto": true, "segura": false, "textura": _glifo(GLIFO_ITENS), "lado": LADO_MIOLO},
		# Pausa (opções, voltar ao menu, sair): logo abaixo do botão de itens, sem ícone (o texto "II" é desenhado)
		{"acao": &"pausar", "rotulo": "II", "raio": RAIO_MOCHILA * 0.8, "cor": COR_NEUTRA, "onde": "", "canto": true, "canto_abaixo": 1, "segura": false},
	]
	for botao in _botoes:
		botao["centro"] = Vector2.ZERO
		botao["apertado"] = false
		botao["visivel"] = true
		botao["quantidade"] = -1
		if botao.has("textura"):
			var icone := TextureRect.new()
			icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icone.stretch_mode = TextureRect.STRETCH_SCALE
			icone.texture = botao["textura"]
			icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_tela.add_child(icone)
			botao["icone"] = icone

func _redesenhar() -> void:
	_tela.queue_redraw()
	_sobre.queue_redraw()

# Só o branco do glifo da folha do Cute RPG: o ladrilho colorido e a moldura branca de 4 px em volta somem (o glifo ocupa o miolo de 24 px)
func _glifo(celula: Vector2i) -> Texture2D:
	return preload("res://codigo/ui/icones_toque.gd").glifo(celula)

# Põe cada ícone no centro do botão (e some com ele quando o botão some ou a tela está tomada por um menu)
func _atualizar_icones() -> void:
	for botao in _botoes:
		var icone: TextureRect = botao.get("icone")
		if icone == null:
			continue
		icone.visible = _ativo and botao["visivel"]
		var lado: float = float(botao["lado"])
		icone.size = Vector2(lado, lado)
		icone.pivot_offset = icone.size / 2.0
		# Posição inteira e sem escala: pixel art só fica nítida em pixels inteiros
		icone.position = (botao["centro"] - icone.size / 2.0).round()
		var cor := Color.WHITE
		if botao["acao"] == &"usar_pocao" and int(botao["quantidade"]) == 0:
			cor = COR_SEM_POCAO
		icone.modulate = Color(cor, OPACIDADE_APERTADO if botao["apertado"] else 0.85)

# Posições a partir do tamanho da tela (o jogo estica na largura em celulares mais compridos)
func _organizar() -> void:
	_tamanho = get_viewport().get_visible_rect().size
	# Recorte da câmera e cantos arredondados (esquerda, cima, direita, baixo)
	var margens: Vector4 = Controle.margens_seguras() * preload("res://codigo/ui/escala_interface.gd").fator(self)
	var ataque := Vector2(_tamanho.x - MARGEM - RAIO_ATAQUE - 6.0 - margens.z, _tamanho.y - MARGEM - RAIO_ATAQUE - 4.0 - margens.w)
	for botao in _botoes:
		if botao.has("angulo"):
			botao["centro"] = ataque + Vector2.from_angle(deg_to_rad(botao["angulo"])) * RAIO_ARCO
		elif botao.has("desloc"):
			botao["centro"] = ataque + botao["desloc"]
		elif botao.get("canto", false):
			botao["centro"] = Vector2(_tamanho.x - MARGEM - RAIO_MOCHILA - margens.z, 96.0 + margens.y + int(botao.get("canto_abaixo", 0)) * (RAIO_MOCHILA * 2.0 + 8.0))
		else:
			botao["centro"] = ataque
	_atualizar_icones()
	_redesenhar()

func _process(delta: float) -> void:
	_tempo_conferir -= delta
	if _tempo_conferir > 0.0:
		return
	_tempo_conferir = 0.2
	_definir_ativo(_telas_abertas.is_empty() and not Introducao.acompanhando and not get_tree().paused)
	var jogador := EventosJogo.dono(self)
	var na_fazenda: bool = jogador != null and bool(jogador.get("modo_fazenda"))
	for botao in _botoes:
		var onde: String = botao["onde"]
		var aparece := onde == "" or (onde == "arena" and not na_fazenda) or (onde == "fazenda" and na_fazenda)
		if botao["visivel"] != aparece:
			botao["visivel"] = aparece
			if not aparece:
				_largar_botao(botao)
	_botoes[0]["rotulo"] = "USAR" if na_fazenda else "ATACAR"
	_atualizar_icones_dinamicos(jogador, na_fazenda)
	_atualizar_icones()
	_redesenhar()

# Na fazenda o botão grande mostra a ferramenta escolhida; a poção mostra a escolhida do cinto e quantas restam
func _atualizar_icones_dinamicos(jogador: Node, na_fazenda: bool) -> void:
	var ataque := _botoes[0]
	var icone: TextureRect = ataque["icone"]
	ataque["lado"] = LADO_ICONE_16 if na_fazenda else LADO_MIOLO
	icone.texture = IconesFazenda.da_ferramenta(Fazenda.ferramenta) if na_fazenda else ataque["textura"]
	var grau: int=preload("res://codigo/dados/melhorias_ferramentas.gd").nivel(EventosJogo.inventario_de(self),Fazenda.ferramenta)
	icone.material = preload("res://codigo/dados/ferramentas_madeira.gd").do_tipo(Fazenda.ferramenta,grau) if na_fazenda else null
	var pocao := _botao_da_acao(&"usar_pocao")
	var id := "cura"
	if jogador != null and jogador.get("efeitos_pocao") != null and String(jogador.efeitos_pocao.selecionada) != "":
		id = String(jogador.efeitos_pocao.selecionada)
	pocao["icone"].texture = Pocoes.icone(id)
	pocao["quantidade"] = Fazenda.quantidade_pocoes(id)

func _botao_da_acao(acao: StringName) -> Dictionary:
	for botao in _botoes:
		if botao["acao"] == acao:
			return botao
	return {}

# --- Telas abertas: o toque passa para os menus ---

func _ao_tela_aberta(nome: String) -> void:
	# Os sinais globais também anunciam os menus do parceiro.
	var interface := EventosJogo.interface_de(self)
	if interface != null and not interface._telas_abertas.has(nome):
		return
	_telas_abertas[nome] = true
	_definir_ativo(false)
	_redesenhar()

func _ao_tela_fechada(nome: String) -> void:
	var interface := EventosJogo.interface_de(self)
	if interface != null and interface._telas_abertas.has(nome):
		return
	_telas_abertas.erase(nome)
	_definir_ativo(_telas_abertas.is_empty() and not Introducao.acompanhando and not get_tree().paused)
	_redesenhar()

func _definir_ativo(ativo: bool) -> void:
	if _ativo == ativo:
		return
	_ativo = ativo
	if not ativo:
		_soltar_tudo()
	_atualizar_icones()
	_tela.visible = ativo
	_sobre.visible = ativo
	_redesenhar()

func _exit_tree() -> void:
	_soltar_tudo()

func _soltar_tudo() -> void:
	for botao in _botoes:
		_largar_botao(botao)
	_dedos.clear()
	_dedo_joystick = -1
	Controle.vetor_toque = Vector2.ZERO
	if _tela != null:
		_redesenhar()

# --- Entrada ---

func _input(evento: InputEvent) -> void:
	if not _ativo:
		return
	if evento is InputEventScreenTouch:
		_toque(evento.index, transform.affine_inverse() * evento.position, evento.pressed)
	elif evento is InputEventScreenDrag:
		_arrastar(evento.index, transform.affine_inverse() * evento.position)
	elif _modo_mouse:
		if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
			_toque(0, transform.affine_inverse() * evento.position, evento.pressed)
		elif evento is InputEventMouseMotion and (evento.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_arrastar(0, transform.affine_inverse() * evento.position)

func _toque(dedo: int, posicao: Vector2, apertou: bool) -> void:
	if not apertou:
		_soltar_dedo(dedo)
		return
	if _dedos.has(dedo):
		return
	var botao := _botao_em(posicao)
	if not botao.is_empty():
		_dedos[dedo] = botao
		_apertar_botao(botao)
	elif _dedo_joystick == -1 and posicao.x < _tamanho.x * 0.5 and not _sobre_hud_tocavel(posicao):
		_dedo_joystick = dedo
		_dedos[dedo] = "joystick"
		_base_joystick = posicao
		_haste_joystick = posicao
		_atualizar_joystick()

# Casas da barra de ferramentas e do cinto de poções (o toque nelas é do HUD, não do joystick)
func _sobre_hud_tocavel(posicao: Vector2) -> bool:
	for no in get_tree().get_nodes_in_group("toque_hud"):
		if no is Control and no.get_viewport() == get_viewport() and no.is_visible_in_tree() and Rect2(Vector2.ZERO,no.size).has_point(no.get_global_transform_with_canvas().affine_inverse() * posicao):
			return true
	return false

func _arrastar(dedo: int, posicao: Vector2) -> void:
	if dedo != _dedo_joystick:
		return
	_haste_joystick = posicao
	# Se o dedo passa do círculo, a base vai atrás (o polegar nunca "sai" do joystick)
	var desvio := _haste_joystick - _base_joystick
	if desvio.length() > RAIO_JOYSTICK:
		_base_joystick = _haste_joystick - desvio.normalized() * RAIO_JOYSTICK
	_atualizar_joystick()

func _soltar_dedo(dedo: int) -> void:
	var dono = _dedos.get(dedo)
	_dedos.erase(dedo)
	if dono is Dictionary:
		_largar_botao(dono)
	elif dedo == _dedo_joystick:
		_dedo_joystick = -1
		Controle.vetor_toque = Vector2.ZERO
	_redesenhar()

func _atualizar_joystick() -> void:
	var vetor := (_haste_joystick - _base_joystick) / RAIO_JOYSTICK
	Controle.vetor_toque = Vector2.ZERO if vetor.length() < ZONA_MORTA else vetor.limit_length(1.0)
	_redesenhar()

func _botao_em(posicao: Vector2) -> Dictionary:
	var melhor := {}
	var menor := INF
	for botao in _botoes:
		if not botao["visivel"]:
			continue
		var distancia: float = posicao.distance_to(botao["centro"])
		if distancia <= float(botao["raio"]) + FOLGA_TOQUE and distancia < menor:
			menor = distancia
			melhor = botao
	return melhor

func _apertar_botao(botao: Dictionary) -> void:
	if botao["apertado"]:
		return
	botao["apertado"] = true
	_atualizar_icones()
	_enviar(botao["acao"], true)
	if OS.has_feature("mobile") and Controle.vibracao_ligada:
		Input.vibrate_handheld(12)
	_redesenhar()

func _largar_botao(botao: Dictionary) -> void:
	if not botao["apertado"]:
		return
	botao["apertado"] = false
	_atualizar_icones()
	_enviar(botao["acao"], false)
	_redesenhar()

func _enviar(acao: StringName, apertada: bool) -> void:
	var evento := InputEventAction.new()
	evento.action = acao
	evento.pressed = apertada
	evento.strength = 1.0 if apertada else 0.0
	Input.parse_input_event(evento)

# --- Desenho ---

func _desenhar() -> void:
	# Joystick: a base nasce onde o dedo encosta; sem dedo, uma sombra no lugar de sempre mostra onde tocar
	if _dedo_joystick != -1:
		_circulo(_base_joystick, RAIO_JOYSTICK, COR_NEUTRA, OPACIDADE * 0.7)
		_circulo(_base_joystick + (_haste_joystick - _base_joystick).limit_length(RAIO_JOYSTICK), RAIO_HASTE, Color.WHITE, OPACIDADE_APERTADO)
	else:
		_circulo(Vector2(MARGEM + RAIO_JOYSTICK + 16.0 + Controle.margens_seguras().x * preload("res://codigo/ui/escala_interface.gd").fator(self), _tamanho.y - MARGEM - RAIO_JOYSTICK - 8.0), RAIO_JOYSTICK, COR_NEUTRA, 0.18)
	for botao in _botoes:
		if not botao["visivel"]:
			continue
		var opacidade := OPACIDADE_APERTADO if botao["apertado"] else OPACIDADE
		var raio: float = botao["raio"] * (0.92 if botao["apertado"] else 1.0)
		_circulo(botao["centro"], raio, botao["cor"], opacidade)
		if not botao.has("icone"):
			_rotulo(botao["centro"], botao["rotulo"], 8 if botao["raio"] >= RAIO_HABILIDADE else 7, float(botao["raio"]) * 1.7)

# Quantas poções restam, no cantinho do botão (sobre o ícone)
func _desenhar_sobre() -> void:
	if not _ativo:
		return
	var pocao := _botao_da_acao(&"usar_pocao")
	if not pocao.is_empty() and pocao["visivel"] and int(pocao["quantidade"]) >= 0:
		_rotulo(pocao["centro"] + Vector2(RAIO_HABILIDADE * 0.62, RAIO_HABILIDADE * 0.7), str(pocao["quantidade"]), 8, 0.0, _sobre)

func _circulo(centro: Vector2, raio: float, cor: Color, opacidade: float) -> void:
	_tela.draw_circle(centro, raio, Color(cor, opacidade * 0.55))
	_tela.draw_arc(centro, raio, 0.0, TAU, 32, Color(cor.lightened(0.35), opacidade), 1.5, true)

# Rótulo centrado; encolhe a fonte até caber dentro de `largura` (0 = sem limite)
func _rotulo(centro: Vector2, texto: String, tamanho: int, largura: float = 0.0, alvo: Control = null) -> void:
	var superficie: Control = alvo if alvo != null else _tela
	if largura > 0.0:
		while tamanho > 5 and FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > largura:
			tamanho -= 1
	var medida := FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho)
	var origem := centro + Vector2(-medida.x / 2.0, medida.y / 4.0)
	superficie.draw_string_outline(FONTE, origem, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, 3, Color(0.1, 0.07, 0.1, 0.9))
	superficie.draw_string(FONTE, origem, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, Color(1, 1, 1, 0.95))
