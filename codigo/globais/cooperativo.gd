extends Node

## Cooperativo local (autoload Cooperativo, pedido de 2026-10-15): um segundo jogador no mesmo PC, com outro controle,
## no jogo inteiro (cidade, fazenda, casas e arena).
##
## É um mundo à parte (Saves.COOP, criado pelo menu CO-OP LOCAL, com save próprio, como o Stardew): o modo liga sozinho
## nesse mundo e desliga no solo. Controles: com dois, um para cada jogador; com um só, o 1 joga no teclado e o 2 nele.
##
## Entrada: as ações do jogador 1 ficam presas ao controle dele (device do evento); o jogador 2 ganha cópias "p2_<ação>"
## presas ao controle dele (Jogador.acao() escolhe o prefixo). Cada jogador navega seus próprios menus e telas.
## Cada metade tem seu viewport e HUD. Na mesma área, compartilham o World2D; ao atravessar portas,
## cada um usa o mundo do próprio ambiente. A área anterior permanece viva para o parceiro.
##
## O jogador 2 é outra instância de cenas/jogador.tscn (eh_p2), criada ao lado do jogador 1 em toda cena que tem um
## "Jogador" (fora do prólogo). Ele tem mochila, equipamento e vida próprios,
## barra sobre a cabeça e outra aparência. As portas levam apenas quem as atravessou; a arena segue conjunta.
## Quem cai fica caído: o parceiro levanta ficando perto por TEMPO_REVIVER, ou ele levanta no fim da onda. Os dois
## caídos = fim da partida (fluxo normal do jogador 1).

signal mudou(ativo: bool)

const CENA_JOGADOR := preload("res://cenas/jogador.tscn")
const DISTANCIA_REVIVER := 26.0
const TEMPO_REVIVER := 2.0
## Sem controle no teclado: as ações do jogador 1 vão para um device que não existe
const SEM_CONTROLE := 99
const ACOES_P2 := ["move_left", "move_right", "move_up", "move_down", "attack", "rolar", "aparar", "usar_pocao", "colher",
	"ferramenta_anterior", "ferramenta_proxima", "arma_proxima", "open_menu"]
## Aparência do jogador 2 (índices de Aparencia e cor do cabelo)
const APARENCIA_P2 := {"cabelo_atual": 3, "roupa_atual": 1, "apelido": "JOGADOR 2", "cor_cabelo": {"r": 0.55, "g": 0.85, "b": 1.0, "a": 1.0}}

## Balanço com dois jogadores na arena (aplicado pelo gerenciador de ondas no começo de cada onda):
## mais inimigos e um pouco mais de vida (dois jogadores batendo), chefe bem mais resistente e com escolta, e menos ouro
## por abate (com mais abates o ouro da onda fica só uns 10% acima do solo). O dano dos inimigos não muda: cada um tem
## a própria vida. Totens comprados valem para os dois (o ouro é um só)
const MULT_QTDE_COOP := 1.5
const MULT_VIDA_COOP := 1.25
const MULT_VIDA_CHEFE_COOP := 1.3
const ESCOLTA_CHEFE_COOP := 2
const MULT_OURO_ABATE_COOP := 0.75

var ativo := false
var dispositivo_p2 := -1
var dispositivo_p1 := -1
var vida_p2 := -1
var totens_p2: Array = []
var _reviver := {}
const LARGURA_TELA := 576.0
const ALTURA_TELA := 324.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Saves.mundo_trocado.connect(_ao_mundo_trocado)
	Input.joy_connection_changed.connect(func(_id: int, _ligado: bool) -> void:
		if ativo:
			_atribuir_controles())

## O cooperativo é um mundo próprio (Saves.COOP): liga sozinho nele e desliga no solo
func _ao_mundo_trocado(mundo: String) -> void:
	if mundo == Saves.COOP:
		if not ativo:
			ativo = true
			_atribuir_controles()
			mudou.emit(true)
	else:
		sair()

## Com dois controles, um para cada; com um só, o jogador 1 joga no teclado e o 2 no controle
func _atribuir_controles() -> void:
	var controles := Input.get_connected_joypads()
	if controles.size() >= 2:
		dispositivo_p1 = controles[0]
		dispositivo_p2 = controles[1]
	elif controles.size() == 1:
		dispositivo_p1 = SEM_CONTROLE
		dispositivo_p2 = controles[0]
	else:
		dispositivo_p1 = -1
		dispositivo_p2 = SEM_CONTROLE
	_reconfigurar_entrada()

# --- Entrar e sair -----------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if ativo:
		_acompanhar_cena(delta)

func entrar(dispositivo: int) -> void:
	if ativo:
		return
	ativo = true
	dispositivo_p2 = dispositivo
	dispositivo_p1 = Controle.dispositivo if Controle.usando_controle and Controle.dispositivo != dispositivo else SEM_CONTROLE
	_reconfigurar_entrada()
	mudou.emit(true)

func sair() -> void:
	if not ativo:
		return
	var p1_atual := _jogador1()
	var raiz_atual := get_tree().current_scene
	if p1_atual != null and raiz_atual != null and p1_atual.get_parent() != raiz_atual:
		p1_atual.reparent(raiz_atual)
		p1_atual.name = "Jogador"
	ativo = false
	var cena := get_tree().current_scene
	var p2 := cena.get_node_or_null("Jogador2") if cena != null else null
	if p2 != null:
		p2.queue_free()
	var p1 := _jogador1()
	if p1 != null and p1.camera != null:
		p1.camera.offset = Vector2.ZERO
	var tela := cena.get_node_or_null("TelaDividida") if cena != null else null
	if tela != null:
		tela.queue_free()
	_vistas.clear()
	_cameras.clear()
	_jogadores.clear()
	_locais.clear()
	_ambientes.clear()
	_cameras_locais.clear()
	_viajando.clear()
	for acao in ACOES_P2:
		if InputMap.has_action("p2_" + acao):
			InputMap.erase_action("p2_" + acao)
	_definir_device_p1(-1)
	dispositivo_p2 = -1
	vida_p2 = -1
	mudou.emit(false)

## O jogador 1 só ouve o controle dele; o jogador 2 ganha cópias das ações de jogo no controle dele
func _reconfigurar_entrada() -> void:
	_definir_device_p1(dispositivo_p1)
	for acao in ACOES_P2:
		var nome: String = "p2_" + acao
		if InputMap.has_action(nome):
			InputMap.erase_action(nome)
		InputMap.add_action(nome, InputMap.action_get_deadzone(acao))
		for evento in InputMap.action_get_events(acao):
			if evento is InputEventJoypadButton or evento is InputEventJoypadMotion:
				var copia: InputEvent = evento.duplicate()
				copia.device = dispositivo_p2
				InputMap.action_add_event(nome, copia)

func _definir_device_p1(dispositivo: int) -> void:
	for acao in InputMap.get_actions():
		if String(acao).begins_with("p2_"):
			continue
		for evento in InputMap.action_get_events(acao):
			if evento is InputEventJoypadButton or evento is InputEventJoypadMotion:
				var copia: InputEvent = evento.duplicate()
				copia.device = dispositivo
				InputMap.action_erase_event(acao, evento)
				InputMap.action_add_event(acao, copia)

## Há um jogador 2 de verdade na cena (o balanço só vale com ele presente)
func com_dois() -> bool:
	return ativo and jogador2() != null and not Introducao.ativa()

## Movimento do jogador 2 (analógico ou direcional dele)
func vetor_p2() -> Vector2:
	if not ativo:
		return Vector2.ZERO
	return Vector2(Input.get_axis("p2_move_left", "p2_move_right"), Input.get_axis("p2_move_up", "p2_move_down"))

# --- Tela dividida -------------------------------------------------------------------------------------------
# Cada metade é uma SubViewport no mesmo World2D da cena, com a câmera do seu jogador e a interface dele (HUD e telas):
# o HUD e a Interface da cena vão para a metade do jogador 1; o jogador 2 ganha um HUD e uma Interface próprios.
# Cada vista renderiza nos pixels físicos da metade da janela. A resolução lógica só organiza a interface;
# o stretch interno do viewport rasteriza fontes e sprites na resolução final, como o canvas_items do solo.

const VistaJogador := preload("res://codigo/ui/vista_jogador.gd")
const CENA_HUD := preload("res://cenas/ui.tscn")
const CENA_INTERFACE := preload("res://cenas/ui/interface.tscn")
var _vistas := {}
var _cameras := {}
var _interface_p2: Node
var _jogadores := {}
var _locais := {}
var _ambientes := {}
var _cameras_locais := {}
var _viajando := {}

## As metades da tela que mostram este mundo agora (vazio fora do cooperativo)
func vistas_do_mundo(mundo: World2D) -> Array[Viewport]:
	var lista: Array[Viewport] = []
	if not ativo:
		return lista
	for vista in _vistas.values():
		if is_instance_valid(vista) and vista.world_2d == mundo:
			lista.append(vista)
	return lista

func interface_p2() -> Node:
	return _interface_p2 if is_instance_valid(_interface_p2) else null

func _atualizar_tela_dividida(p1: Node2D, p2: Node2D) -> void:
	var cena := get_tree().current_scene
	if cena.get_node_or_null("TelaDividida") == null:
		_montar_tela_dividida(cena, p1, p2)
	_ajustar_metades(cena.get_node("TelaDividida"))
	var base: Camera2D = p1.camera
	for par in [[1, p1], [2, p2]]:
		var camera: Camera2D = _cameras.get(par[0])
		if not is_instance_valid(camera):
			continue
		# Cada câmera de jogador já traz o ZOOM das opções dele
		var origem: Camera2D = par[1].camera
		camera.zoom = origem.zoom if origem != null else (base.zoom if base != null else Vector2.ONE)
		if origem != null:
			_copiar_camera(origem, camera)
		camera.global_position = origem.global_position if origem != null and origem.is_set_as_top_level() else par[1].global_position
	_sincronizar_ambientes()

func _montar_tela_dividida(cena: Node, p1: Node2D, p2: Node2D) -> void:
	_jogadores = {1: p1, 2: p2}
	_locais = {1: cena, 2: cena}
	_ambientes.clear()
	_cameras_locais.clear()
	_viajando.clear()
	_copiar_camera(p1.camera, p2.camera)
	var camada := CanvasLayer.new()
	camada.name = "TelaDividida"
	# Por cima do mundo; a vinheta e o fade da Transicao ficam por cima das duas metades
	camada.layer = 1
	cena.add_child(camada)
	cena.move_child(camada, 0)
	for lado in [1, 2]:
		var moldura := VistaJogador.new()
		moldura.name = "Vista%d" % lado
		moldura.repassar_entrada = lado == 1
		# A metade precisa repassar a entrada também com o jogo pausado: senão o START do jogador 1 abria a pausa e não
		# chegava mais nela para fechar (o jogo ficava parado). A Interface já é ALWAYS; o HUD continua pausável (abaixo)
		moldura.process_mode = Node.PROCESS_MODE_ALWAYS
		moldura.stretch = true
		moldura.size = Vector2(LARGURA_TELA / 2.0, ALTURA_TELA)
		moldura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		camada.add_child(moldura)
		var vista := SubViewport.new()
		vista.world_2d = get_viewport().world_2d
		vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		vista.size_2d_override_stretch = true
		vista.set_meta("dono", p1 if lado == 1 else p2)
		vista.process_mode = Node.PROCESS_MODE_ALWAYS
		moldura.add_child(vista)
		var camera := Camera2D.new()
		camera.name = "Camera"
		camera.process_mode = Node.PROCESS_MODE_PAUSABLE
		vista.add_child(camera)
		camera.make_current()
		_vistas[lado] = vista
		_cameras[lado] = camera
	# Cada jogador ganha HUD e Interface novos na metade dele (a meta "dono" da vista diz de quem são). Os da cena
	# saem: movê-los para a vista (reparent) derrubava o Godot na troca de cena seguinte
	for no in cena.get_children():
		if no is CanvasLayer and (no.is_in_group("hud") or no.is_in_group("interface")):
			no.remove_from_group("hud")
			no.remove_from_group("hud_p1")
			no.remove_from_group("interface")
			no.queue_free()
	for lado in [1, 2]:
		var hud: Node = CENA_HUD.instantiate()
		hud.process_mode = Node.PROCESS_MODE_PAUSABLE
		_vistas[lado].add_child(hud)
		var interface: Node = CENA_INTERFACE.instantiate()
		interface.name = "Interface" if lado == 1 else "InterfaceP2"
		_vistas[lado].add_child(interface)
		if lado == 2:
			_interface_p2 = interface
	var faixa := ColorRect.new()
	faixa.name = "Divisoria"
	faixa.color = Color("211c2b")
	faixa.position = Vector2(LARGURA_TELA / 2.0 - 1, 0)
	faixa.size = Vector2(2, ALTURA_TELA)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(faixa)
	_ajustar_metades(camada)

func _ajustar_metades(camada: CanvasLayer) -> void:
	var janela := get_viewport()
	var tamanho := janela.get_visible_rect().size
	var escala_janela := janela.get_final_transform().get_scale()
	var pixels := (tamanho * escala_janela).round()
	var divisao := floorf(pixels.x / 2.0)
	for lado in [1, 2]:
		var moldura: SubViewportContainer = camada.get_node("Vista%d" % lado)
		var inicio := divisao if lado == 2 else 0.0
		var fim := pixels.x if lado == 2 else divisao
		# A escala inversa cancela a escala da janela: um texel da vista ocupa um pixel físico.
		# A textura já nasce na resolução final, sem a ampliação de uma imagem de 288x324.
		moldura.scale = Vector2.ONE / escala_janela
		moldura.size = Vector2(fim - inicio, pixels.y)
		moldura.position = Vector2(inicio / escala_janela.x, 0)
		var vista: SubViewport = _vistas[lado]
		vista.size_2d_override = Vector2i((moldura.size / escala_janela).round())
	var faixa: ColorRect = camada.get_node("Divisoria")
	faixa.position = Vector2(divisao / escala_janela.x - 1, 0)
	faixa.size = Vector2(2, tamanho.y)

## O controle do jogador 2 vai só para a metade dele, com o device trocado para o do jogador 1: assim as telas dele
## entendem as ações de sempre (ui_accept, close_menu, open_inventory...) sem mexer nas do jogador 1
func _input(evento: InputEvent) -> void:
	if not ativo or not (evento is InputEventJoypadButton or evento is InputEventJoypadMotion) or evento.device != dispositivo_p2:
		return
	var vista: SubViewport = _vistas.get(2)
	if not is_instance_valid(vista):
		return
	var copia: InputEvent = evento.duplicate()
	copia.device = dispositivo_p1
	vista.push_input(copia)

# --- Em cada cena ------------------------------------------------------------------------------------------------

func _jogador1() -> Node2D:
	var cena := get_tree().current_scene
	var guardado = _jogadores.get(1)
	if is_instance_valid(guardado) and cena != null and cena.is_ancestor_of(guardado):
		return guardado
	return cena.get_node_or_null("Jogador") as Node2D if cena != null else null

func jogador2() -> Node2D:
	var cena := get_tree().current_scene
	var guardado = _jogadores.get(2)
	if is_instance_valid(guardado) and cena != null and cena.is_ancestor_of(guardado):
		return guardado
	return cena.get_node_or_null("Jogador2") as Node2D if cena != null else null

## O outro jogador (ou null)
func parceiro_de(jogador: Node) -> Node2D:
	if not ativo:
		return null
	return jogador2() if jogador == _jogador1() else _jogador1()

func _acompanhar_cena(delta: float) -> void:
	var p1 := _jogador1()
	if p1 == null or Transicao.ocupada or Introducao.ativa():
		return
	var p2 := jogador2()
	if p2 == null:
		p2 = _criar_p2(p1)
		return
	_atualizar_tela_dividida(p1, p2)
	_cuidar_dos_caidos(p1, p2, delta)

func _criar_p2(p1: Node2D) -> Node2D:
	var p2: Node2D = CENA_JOGADOR.instantiate()
	p2.name = "Jogador2"
	p2.eh_p2 = true
	p2.remove_from_group("character")
	p2.position = p1.position + Vector2(18, 0)
	p1.get_parent().add_child(p2)
	# O que é só da partida do jogador 2 atravessa as trocas de cena por aqui: vida e totens comprados por ele
	for dados in totens_p2:
		p2.aplicar_efeitos_item(dados)
		p2.itens_comprados.append(dados.duplicate(true))
	if vida_p2 > 0:
		p2.hp_atual = mini(vida_p2, p2.estatisticas.hp_maximo)
		p2.atualizar_barra_hp()
	p2.tree_exiting.connect(func() -> void:
		vida_p2 = p2.hp_atual if not p2.estaMorto else -1
		totens_p2 = p2.itens_comprados.duplicate(true))
	# Plantio da fazenda: o jogador 2 também usa as ferramentas
	for plantio in get_tree().get_nodes_in_group("plantio_fazenda"):
		if plantio.has_method("ligar_jogador"):
			plantio.ligar_jogador(p2)
	return p2

## Reviver: o parceiro de pé perto de quem caiu por TEMPO_REVIVER
func _cuidar_dos_caidos(p1: Node2D, p2: Node2D, delta: float) -> void:
	for par in [[p1, p2], [p2, p1]]:
		var caido: Node2D = par[0]
		var amigo: Node2D = par[1]
		if not bool(caido.get("caido")):
			_reviver.erase(caido.name)
			continue
		var perto: bool = not amigo.estaMorto and amigo.get_world_2d() == caido.get_world_2d() and amigo.global_position.distance_to(caido.global_position) <= DISTANCIA_REVIVER
		var progresso: float = float(_reviver.get(caido.name, 0.0)) + (delta if perto else -delta)
		progresso = maxf(progresso, 0.0)
		_reviver[caido.name] = progresso
		caido.mostrar_reviver(progresso / TEMPO_REVIVER)
		if progresso >= TEMPO_REVIVER:
			_reviver.erase(caido.name)
			caido.levantar_caido()

## A partida acabou (morte ou volta para a cidade): o jogador 2 perde os totens e a vida guardada
func encerrar_partida_p2() -> void:
	totens_p2.clear()
	vida_p2 = -1

## Fim da onda: quem estava caído levanta
func levantar_todos() -> void:
	for jogador in get_tree().get_nodes_in_group("jogadores"):
		if bool(jogador.get("caido")):
			jogador.levantar_caido()

func _anunciar(texto: String, subtitulo: String) -> void:
	get_tree().call_group("hud", "anunciar", texto, subtitulo, 2.0)

# --- Ambientes independentes: as portas movem somente quem as atravessou ------------------------------

func cena_de(no: Node) -> Node:
	var atual := no
	while atual != null:
		if atual.has_meta("ambiente_coop"):
			return atual
		# A metade da tela fica dentro da cena raiz, mas quem está nela pode ter atravessado uma porta
		if ativo and atual is SubViewport and atual.has_meta("dono"):
			var dono_vista: Node = atual.get_meta("dono")
			return _locais.get(2 if dono_vista.eh_p2 else 1, get_tree().current_scene)
		# Durante _ready a cena já está na raiz, mas current_scene ainda pode ser a anterior.
		if atual.get_parent() == get_tree().root and not atual.scene_file_path.is_empty():
			return atual
		atual = atual.get_parent()
	if ativo and no.get_viewport().has_meta("dono"):
		var dono: Node = no.get_viewport().get_meta("dono")
		return _locais.get(2 if dono.eh_p2 else 1, get_tree().current_scene)
	return get_tree().current_scene

func _copiar_camera(origem: Camera2D, destino: Camera2D) -> void:
	for propriedade in ["limit_left", "limit_top", "limit_right", "limit_bottom"]:
		destino.set(propriedade, origem.get(propriedade))

func _guardar_camera(camera: Camera2D) -> Dictionary:
	return {"esquerda": camera.limit_left, "cima": camera.limit_top, "direita": camera.limit_right,
		"baixo": camera.limit_bottom, "fixa": camera.is_set_as_top_level(), "posicao": camera.position}

func _aplicar_camera(camera: Camera2D, dados: Dictionary) -> void:
	camera.set_as_top_level(dados["fixa"])
	camera.position = dados["posicao"]
	camera.limit_left = dados["esquerda"]
	camera.limit_top = dados["cima"]
	camera.limit_right = dados["direita"]
	camera.limit_bottom = dados["baixo"]

func viajar_local(jogador: Node2D, caminho: String, ponto: String) -> void:
	if not com_dois() or jogador == null:
		return
	var lado := 2 if jogador.eh_p2 else 1
	if _viajando.get(lado, false):
		return
	_viajando[lado] = true
	# Uma pescaria em andamento acaba antes de o jogador mudar de mundo (a sessão é filha dele e não atravessa).
	var pescaria := jogador.get_node_or_null("SessaoPesca")
	if pescaria != null:
		pescaria._terminar()
	jogador.desabilitar_todas_acoes(true)
	# As áreas podem pedir a passagem durante a física: só remover/reparentear depois dela.
	await get_tree().process_frame
	var raiz := get_tree().current_scene
	var anterior: Node = _locais.get(lado, raiz)
	_cameras_locais[str(lado) + anterior.scene_file_path] = _guardar_camera(jogador.camera)
	var destino: Node
	var mundo: World2D
	if caminho == raiz.scene_file_path:
		destino = raiz
		mundo = raiz.get_world_2d()
	elif _ambientes.has(caminho):
		destino = _ambientes[caminho]["cena"]
		mundo = _ambientes[caminho]["vista"].world_2d
	else:
		var recurso := load(caminho) as PackedScene
		if recurso == null:
			jogador.desabilitar_todas_acoes(false)
			_viajando.erase(lado)
			return
		destino = recurso.instantiate()
		destino.set_meta("ambiente_coop", true)
		for no in destino.get_children():
			if no is CanvasLayer:
				destino.remove_child(no)
				no.free()
		var substituto: Node = destino.get_node_or_null("Jogador")
		if substituto != null:
			_aplicar_camera(jogador.camera, _guardar_camera(substituto.get_node("Camera2D")))
			destino.remove_child(substituto)
			substituto.free()
		var ambiente := SubViewport.new()
		ambiente.name = "Ambiente%d" % _ambientes.size()
		ambiente.world_2d = World2D.new()
		ambiente.size = _vistas[lado].size_2d_override
		ambiente.render_target_update_mode = SubViewport.UPDATE_DISABLED
		raiz.get_node("TelaDividida").add_child(ambiente)
		# As cenas configuram a câmera no _ready pelo nó Jogador. O mesmo personagem atravessa a porta.
		jogador.reparent(destino, false)
		jogador.name = "Jogador"
		ambiente.add_child(destino)
		_ambientes[caminho] = {"cena": destino, "vista": ambiente, "camera": _guardar_camera(jogador.camera)}
		mundo = ambiente.world_2d
	var chave := str(lado) + caminho
	if _cameras_locais.has(chave):
		_aplicar_camera(jogador.camera, _cameras_locais[chave])
	elif _ambientes.has(caminho):
		_aplicar_camera(jogador.camera, _ambientes[caminho]["camera"])
	_locais[lado] = destino
	_vistas[lado].world_2d = mundo
	jogador.reparent(raiz if destino == raiz else _vistas[lado], false)
	jogador.name = "Jogador2" if lado == 2 else "Jogador"
	jogador.camera.enabled = destino == raiz and lado == 1
	var chegada := destino.find_child("Chegada_" + ponto, true, false) as Node2D
	if chegada != null:
		jogador.global_position = chegada.global_position
	jogador.velocity = Vector2.ZERO
	jogador.modo_fazenda = bool(destino.get_meta("barra_ferramentas", false))
	if jogador.modo_fazenda:
		for plantio in get_tree().get_nodes_in_group("plantio_fazenda"):
			if plantio.get_world_2d() == mundo:
				plantio.ligar_jogador(jogador)
	var interface: Node = _vistas[lado].get_node("Interface" if lado == 1 else "InterfaceP2")
	for tela in interface._telas_abertas.duplicate():
		interface._fechar_tela(tela)
	for hud in get_tree().get_nodes_in_group("hud_p%d" % lado):
		# O relógio passa a seguir a iluminação do lugar novo
		hud._ligar_iluminacao()
		if jogador.modo_fazenda and hud.barra_armas == null:
			hud._criar_barra(true)
		if hud.barra_armas != null and hud.barra_armas.modo_fazenda:
			hud.barra_armas.visible = jogador.modo_fazenda
	jogador.desabilitar_todas_acoes(false)
	_atualizar_tela_dividida(_jogador1(), jogador2())
	_cameras[lado].reset_smoothing()
	_viajando.erase(lado)

func _sincronizar_ambientes() -> void:
	var luz := get_tree().current_scene.get_node_or_null("Iluminacao")
	if luz == null:
		return
	for dados in _ambientes.values():
		var local: Node = dados["cena"].get_node_or_null("Iluminacao")
		if local != null:
			local.set_process(false)
			local.definir_hora(luz.hora)
			local._aplicar()

## Interações e moradores só consultam jogadores presentes no mesmo mundo físico.
func jogador_no_ambiente(no: Node2D) -> Node2D:
	var melhor: Node2D
	var distancia := INF
	for jogador in get_tree().get_nodes_in_group("jogadores"):
		if not jogador is CharacterBody2D or jogador.get_world_2d() != no.get_world_2d():
			continue
		var atual: float = jogador.global_position.distance_squared_to(no.global_position)
		if atual < distancia:
			distancia = atual
			melhor = jogador
	return melhor
