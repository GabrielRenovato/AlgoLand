extends CanvasLayer

## Troca de cena com fade (arena <-> fazenda <-> casa) e o que precisa atravessar a troca.
## O Jogador é instanciado de novo em cada cena, então o que mora nele (vida, estamina, totens comprados) e o que
## mora no gerenciador de ondas (a onda em que a partida está) é guardado aqui na saída e devolvido na chegada.
## Ouro, inventário, Progresso (a partida atual e o checkpoint) e Calendario são autoloads e não precisam de nada:
## a troca de cena não é morte e não reinicia a partida (o Gerenciador-de-ondas consulta `retornando`).
##
## Chegada: a cena nova tem Marker2D no grupo "chegada" chamados "Chegada_<ponto>"; o jogador aparece no marcador
## do ponto pedido (sem marcador, fica onde a cena o colocou).

signal troca_concluida(caminho: String)
## Terminou de dormir (já com o dia seguinte aplicado e o jogador acordado)
signal dormiu

## Para restaurar o modo anterior basta usar ARENA_ORIGINAL como DESTINO_COMBATE.
const ARENA_ORIGINAL := "res://cenas/cenario.tscn"
const DESTINO_COMBATE := "res://cenas/andar_fenda.tscn"
const DURACAO_SAIDA := 0.35
const DURACAO_ENTRADA := 0.45
const DURACAO_DORMIR := 0.7
## Quanto a cama fica ocupada (respirando, com os Z) antes de a tela escurecer
const TEMPO_NA_CAMA := 1.3
const HORA_ACORDAR := 6.0
const CAMADA := 100
const QUADROS_ESPERA_CHEGADA := 3
## Trocas rapidas usam apenas o fade; o painel aparece se o recurso ainda estiver pendente.
const ESPERA_PAINEL_CARREGAMENTO_MS := 400

## true da saída de uma cena até a nova terminar de carregar: o Gerenciador-de-ondas não reinicia a partida
var retornando := false
## Foto do jogador e da arena na saída (ver _guardar_estado). Vazio = nada a restaurar (partida nova)
var estado: Dictionary = {}
## Hora do ciclo dia/noite, para o dia não "voltar para as 6h" a cada porta; -1 = sem valor
var hora_salva := -1.0
## Ao sair da arena (os andares da fenda) para qualquer lugar fora dela, o jogador chega à vila às 23:00 e
## tem três horas para dormir antes de desmaiar às 02:00. Dentro dos andares o cansaço não o interrompe (iluminacao.gd)
const HORA_SAIDA_ARENA := 23.0
var _destino_atual := ""
var ocupada := false

var _painel: ColorRect
var _tween: Tween
var _carregador: Control
var _carregando := false
# Evita a espera infinita do carregador em segundo plano em aparelhos Android.
var carregar_na_thread_principal := OS.has_feature("android")
signal progresso_carregamento(caminho: String, progresso: float)

func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_painel = ColorRect.new()
	_painel.color = Color(0.03, 0.04, 0.08, 0.0)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_painel)
	_carregador = preload("res://codigo/ui/tela_carregamento.gd").new()
	add_child(_carregador)

## A arena só se alcança pelo portal da cidade: a onda começa sozinha logo depois da chegada (lido e zerado pelo
## GerenciadorOndas ao carregar). Sair para a cidade guarda a partida: a onda atual volta na próxima entrada.
var iniciar_onda_ao_chegar := false

func entrar_na_arena() -> void:
	if ocupada:
		return
	iniciar_onda_ao_chegar = true
	var onda: int = int(estado.get("onda_atual",1))
	if not Progresso.onda_comecou: onda = maxi(onda,Progresso.onda_inicial)
	var destino: String = preload("res://codigo/fendas/catalogo_andares.gd").cena(onda) if DESTINO_COMBATE != ARENA_ORIGINAL else ARENA_ORIGINAL
	ir_para(destino, "portal")

## `encerrar`: a partida acabou (o jogador escolheu voltar no meio dela): a onda e os totens não voltam
func sair_da_arena(encerrar := false) -> void:
	if encerrar:
		_esquecer_onda = true
		_esquecer_totens = true
	ir_para("res://cenas/cidade.tscn", "portal")

const ENFERMARIA := "res://cenas/cidade/enfermaria.tscn"
## Caiu na arena: acorda ao lado de um leito da enfermaria e a Rosa conversa com ele (cidade.gd lê e zera)
var acordou_ferido := false
var _esquecer_onda := false
var _esquecer_totens := false

## Depois da morte: a partida acabou, então a onda guardada é descartada (a próxima entrada começa na onda 1)
func acordar_na_enfermaria() -> void:
	if ocupada:
		return
	acordou_ferido = true
	_esquecer_onda = true
	ir_para(ENFERMARIA, "leito")

const CASA := "res://cenas/casa.tscn"

## 02:00 (Iluminacao): em casa ele só dorme; na rua desmaia de cansaço, é levado para a casa da fazenda e acorda
## na cama de manhã, como no Stardew. A tela fica escura da rua até a cama
func desmaiar() -> void:
	if ocupada:
		return
	_cancelar_esperas()
	var cena := get_tree().current_scene
	if cena != null and cena.scene_file_path == CASA:
		dormir("cama", null, true)
		return
	get_tree().call_group("hud", "anunciar", "VOCE DESMAIOU", "DE TANTO CANSACO...", 1.5)
	await get_tree().create_timer(1.0).timeout
	await ir_para(CASA, "cama", false)
	await dormir("cama", null, true)
	get_tree().call_group("hud", "anunciar", "ALGUEM TE TROUXE PARA CASA", "DURMA ANTES DAS 2H", 3.0)

## Vai para outra cena: fade para preto, troca, reposiciona o jogador em `ponto` e clareia (com `clarear_no_fim`
## false a tela fica escura, para quem emenda outra transição). Ignora pedidos enquanto outra troca está em andamento
func ir_para(caminho: String, ponto := "", clarear_no_fim := true) -> void:
	if ocupada:
		return
	ocupada = true
	var jogador := _obter_jogador()
	if jogador != null:
		jogador.desabilitar_todas_acoes(true)
	await escurecer()
	_destino_atual = caminho
	_guardar_estado()
	retornando = true
	var erro := await carregar_cena(caminho)
	if erro != OK:
		push_error("Transicao: nao foi possivel abrir %s (erro %d)" % [caminho, erro])
		retornando = false
		if jogador != null and is_instance_valid(jogador):
			jogador.desabilitar_todas_acoes(false)
		await clarear()
		ocupada = false
		return
	for i in QUADROS_ESPERA_CHEGADA:
		await get_tree().process_frame
	_restaurar_estado(ponto)
	retornando = false
	if clarear_no_fim:
		await clarear()
	ocupada = false
	troca_concluida.emit(caminho)

## Carregamento compartilhado pelo titulo, criacao, pausa e viagens. O percentual vem do ResourceLoader.
func carregar_cena(caminho: String) -> Error:
	if _carregando: return ERR_BUSY
	if not ResourceLoader.exists(caminho,"PackedScene"): return ERR_FILE_NOT_FOUND
	_carregando = true
	var origem := ""
	if get_tree().current_scene != null:
		origem = preload("res://codigo/ui/tela_carregamento.gd").nome_do_destino(get_tree().current_scene.scene_file_path)
	var inicio := Time.get_ticks_msec()
	progresso_carregamento.emit(caminho,0.0)
	var cena: PackedScene
	var erro := OK
	if carregar_na_thread_principal:
		# Desenha o painel antes da leitura/instanciação. Em alguns Androids, a
		# requisição em thread fica IN_PROGRESS indefinidamente (Godot #121124).
		_carregador.iniciar(caminho,origem)
		await get_tree().process_frame
		await get_tree().process_frame
		cena = ResourceLoader.load(caminho,"PackedScene") as PackedScene
	else:
		erro = ResourceLoader.load_threaded_request(caminho,"PackedScene")
		if erro != OK:
			_carregador.hide()
			_carregando = false
			return erro
		var progresso: Array = []
		var status := ResourceLoader.load_threaded_get_status(caminho,progresso)
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var valor := float(progresso[0]) if not progresso.is_empty() else 0.0
			if not _carregador.visible and Time.get_ticks_msec()-inicio >= ESPERA_PAINEL_CARREGAMENTO_MS:
				_carregador.iniciar(caminho,origem)
			if _carregador.visible: _carregador.atualizar(valor)
			progresso_carregamento.emit(caminho,valor)
			await get_tree().process_frame
			status = ResourceLoader.load_threaded_get_status(caminho,progresso)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			cena = ResourceLoader.load_threaded_get(caminho) as PackedScene
	if cena == null:
		_carregador.hide()
		_carregando = false
		return ERR_CANT_OPEN
	if _carregador.visible:
		_carregador.atualizar(1.0,true)
		await get_tree().process_frame
	progresso_carregamento.emit(caminho,1.0)
	erro = get_tree().change_scene_to_packed(cena)
	if erro == OK:
		for i in QUADROS_ESPERA_CHEGADA: await get_tree().process_frame
	if erro == OK:
		await Saves.restaurar_local()
	_carregador.hide()
	_carregando = false
	return erro

## Dormir na cama: fade, Calendario.dormir() (passa o dia e salva), cura total, salvamento do progresso e do
## inventário, a manhã seguinte (6h) e o jogador acorda em `ponto_acordar` (Marker2D "Chegada_<ponto>" da cena).
## O que a troca de cena guarda (onda da arena, hora) não muda: dormir não é morte e não mexe na partida
func dormir(ponto_acordar := "", quem: Node2D = null, todos := false) -> void:
	if ocupada:
		return
	var jogador: Node2D = quem if quem != null else _obter_jogador()
	# Cooperativo (como no Stardew): quem confirmou deita e espera; a noite só passa com os dois deitados.
	# `todos` (o desmaio das 2h) leva os dois de uma vez
	if Cooperativo.com_dois() and not todos:
		_deitar_esperando(jogador, ponto_acordar)
		return
	var lista: Array[Node2D] = []
	if Cooperativo.com_dois():
		for parte in [Cooperativo._jogador1(), Cooperativo.jogador2()]:
			if parte != null:
				lista.append(parte)
	elif jogador != null:
		lista.append(jogador)
	await _passar_noite(ponto_acordar, lista)

# --- Sono no cooperativo -----------------------------------------------------------------------------------

## Quem já confirmou DORMIR e espera o parceiro deitar
var _esperando_dormir: Array[Node2D] = []
## Onde cada jogador deitado está: a cama (Node2D de cama.gd) ou null (sem cama livre: só some até a manhã)
var _deitados: Dictionary = {}
var _ponto_dormir := ""
## O mesmo botão que confirmou o DORMIR não levanta na hora
var _levantar_liberado_ms := 0

func _deitar_esperando(jogador: Node2D, ponto: String) -> void:
	if jogador == null or jogador in _esperando_dormir:
		return
	_ponto_dormir = ponto
	jogador.desabilitar_todas_acoes(true)
	_deitar(jogador)
	_esperando_dormir.append(jogador)
	_levantar_liberado_ms = Time.get_ticks_msec() + 400
	var parceiro := Cooperativo.parceiro_de(jogador)
	if parceiro == null or parceiro in _esperando_dormir:
		var lista := _esperando_dormir.duplicate()
		_esperando_dormir.clear()
		await _passar_noite(_ponto_dormir, lista)
		return
	var numero := 2 if jogador.eh_p2 else 1
	_anunciar_para(jogador, "ESPERANDO O JOGADOR %d" % (1 if numero == 2 else 2), "B OU %s PARA LEVANTAR" % Controle.rotulo_acao("open_menu"))
	_anunciar_para(parceiro, "JOGADOR %d FOI DORMIR" % numero, "DEITE PARA PASSAR A NOITE")

## Quem está esperando pode desistir: B (voltar) ou o botão de interagir
func _input(evento: InputEvent) -> void:
	if _esperando_dormir.is_empty() or ocupada or Time.get_ticks_msec() < _levantar_liberado_ms:
		return
	for jogador in _esperando_dormir.duplicate():
		if not is_instance_valid(jogador):
			_esperando_dormir.erase(jogador)
			continue
		if evento.is_action_pressed(jogador.acao("close_menu")) or evento.is_action_pressed(jogador.acao("open_menu")):
			_levantar_da_espera(jogador)
			get_viewport().set_input_as_handled()
			return

func _process(_delta: float) -> void:
	# O parceiro saiu do cooperativo enquanto o outro esperava: a noite passa só para quem ficou deitado
	if not _esperando_dormir.is_empty() and not ocupada and not Cooperativo.com_dois():
		var lista := _esperando_dormir.duplicate()
		_esperando_dormir.clear()
		_passar_noite(_ponto_dormir, lista)

func _levantar_da_espera(jogador: Node2D) -> void:
	_esperando_dormir.erase(jogador)
	_acordar(jogador)
	jogador.desabilitar_todas_acoes(false)
	_anunciar_para(jogador, "VOCE LEVANTOU", "", 1.0)
	var parceiro := Cooperativo.parceiro_de(jogador)
	if parceiro != null:
		_anunciar_para(parceiro, "JOGADOR %d LEVANTOU" % (2 if jogador.eh_p2 else 1), "", 1.0)

## Desmaio, troca de cena: ninguém fica preso deitado esperando
func _cancelar_esperas() -> void:
	for jogador in _esperando_dormir.duplicate():
		if is_instance_valid(jogador):
			_acordar(jogador)
			jogador.desabilitar_todas_acoes(false)
	_esperando_dormir.clear()

func _anunciar_para(jogador: Node, titulo: String, subtitulo := "", tempo := 3.0) -> void:
	get_tree().call_group("hud_p2" if bool(jogador.get("eh_p2")) else "hud_p1", "anunciar", titulo, subtitulo, tempo)

## Deita na primeira cama livre do mundo dele (a cabeça no travesseiro); sem cama livre ele só some até acordar
func _deitar(jogador: Node2D) -> void:
	if _deitados.has(jogador):
		return
	var cama: Node = null
	for candidata in get_tree().get_nodes_in_group("cama"):
		if candidata.get_world_2d() == jogador.get_world_2d() and candidata.has_method("deitar") and not candidata.deitado:
			cama = candidata
			break
	if cama != null:
		cama.deitar(jogador)
	else:
		jogador.visible = false
	_deitados[jogador] = cama

func _acordar(jogador: Node2D) -> void:
	if not _deitados.has(jogador):
		return
	var cama: Node = _deitados[jogador]
	_deitados.erase(jogador)
	if is_instance_valid(cama):
		cama.levantar()
	if is_instance_valid(jogador):
		jogador.visible = true

## A noite: fade, Calendario.dormir, salvamento, 6h em TODAS as iluminações (no cooperativo cada ambiente aberto
## tem a sua; antes só a primeira voltava para as 6h e a casa ficava na hora em que dormiram), cura e acordar
func _passar_noite(ponto_acordar: String, jogadores: Array[Node2D]) -> void:
	if ocupada:
		return
	ocupada = true
	var na_cama := false
	for jogador in jogadores:
		if not is_instance_valid(jogador):
			continue
		jogador.desabilitar_todas_acoes(true)
		_deitar(jogador)
		na_cama = na_cama or _deitados.get(jogador) != null
	# Na casa a cama respira um instante antes do fade; fora dela (apagou na arena ou na fazenda) vai direto ao escuro
	if na_cama:
		await get_tree().create_timer(TEMPO_NA_CAMA).timeout
	await escurecer(DURACAO_DORMIR)
	Calendario.dormir()
	Progresso.salvar()
	InventarioJogador.salvar()
	var inventario_p2 := get_node_or_null("/root/InventarioJogador2")
	if Cooperativo.com_dois() and inventario_p2 != null and inventario_p2.has_method("salvar"):
		inventario_p2.salvar()
	hora_salva = HORA_ACORDAR
	for luz in get_tree().get_nodes_in_group("iluminacao"):
		if luz.has_method("definir_hora"):
			luz.definir_hora(HORA_ACORDAR)
			if luz.has_method("_aplicar"):
				luz._aplicar()
	var lado := 0
	for jogador in jogadores:
		if not is_instance_valid(jogador):
			continue
		jogador.descansar()
		_posicionar(jogador, ponto_acordar)
		# Os dois acordam lado a lado, não um em cima do outro
		jogador.global_position.x += 14.0 * lado
		lado += 1
	await get_tree().create_timer(0.5).timeout
	# A cama volta ao normal e o jogador reaparece ao lado dela, ainda no escuro
	for jogador in jogadores:
		_acordar(jogador)
	await clarear(DURACAO_DORMIR)
	for jogador in jogadores:
		if is_instance_valid(jogador):
			jogador.desabilitar_todas_acoes(false)
	get_tree().call_group("hud", "anunciar", "BOM DIA", Calendario.texto_data(), 2.0)
	ocupada = false
	dormiu.emit()

## Fade para preto (também usado ao dormir). Termina com a tela toda escura
func escurecer(duracao := DURACAO_SAIDA) -> void:
	_mover_fade(1.0, duracao)
	if _tween != null and _tween.is_valid():
		await _tween.finished

func clarear(duracao := DURACAO_ENTRADA) -> void:
	_mover_fade(0.0, duracao)
	if _tween != null and _tween.is_valid():
		await _tween.finished

func _mover_fade(alfa: float, duracao: float) -> void:
	if _tween:
		_tween.kill()
	if duracao <= 0.0:
		_painel.color.a = alfa
		_tween = null
		return
	_tween = create_tween()
	_tween.tween_property(_painel, "color:a", alfa, duracao)

func esta_escuro() -> bool:
	return _painel.color.a > 0.99

## Zera o que atravessa cenas (novo jogo)
func limpar() -> void:
	estado = {}
	hora_salva = -1.0
	retornando = false

# --- Estado do jogador e da arena ------------------------------------------------------------------------

func _obter_jogador() -> Node:
	for no in get_tree().get_nodes_in_group("character"):
		if no is CharacterBody2D:
			return no
	return null

func _guardar_estado() -> void:
	var novo := {}
	var jogador := _obter_jogador()
	if jogador != null:
		novo["hp"] = jogador.hp_atual
		novo["stamina"] = jogador.stamina
		novo["itens_comprados"] = jogador.itens_comprados.duplicate(true)
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null:
		novo["onda_atual"] = gerenciador.onda_atual
	elif estado.has("onda_atual"):
		# Fazenda e casa não têm gerenciador: a onda da arena segue guardada para a volta
		novo["onda_atual"] = estado["onda_atual"]
	var luz := get_tree().get_first_node_in_group("iluminacao")
	if luz != null and "hora" in luz:
		hora_salva = luz.hora_do_mundo() if luz.has_method("hora_do_mundo") else luz.hora
	# Saindo da arena (de um andar para fora da fenda): chega às 23:00.
	if gerenciador != null and not _destino_atual.begins_with("res://cenas/fendas/andar_") and _destino_atual != ARENA_ORIGINAL:
		hora_salva = HORA_SAIDA_ARENA
	if _esquecer_onda:
		novo.erase("onda_atual")
		_esquecer_onda = false
	if _esquecer_totens:
		novo.erase("itens_comprados")
		_esquecer_totens = false
	estado = novo

func _restaurar_estado(ponto: String) -> void:
	var jogador := _obter_jogador()
	if jogador == null:
		return
	_posicionar(jogador, ponto)
	jogador.aplicar_estado_de_transicao(estado)

## Coloca o jogador no marcador "Chegada_<ponto>" da cena atual (sem marcador, não mexe)
func _posicionar(jogador: Node, ponto: String) -> void:
	if ponto == "":
		return
	for marcador in get_tree().get_nodes_in_group("chegada"):
		if marcador is Node2D and marcador.name == "Chegada_" + ponto and marcador.get_world_2d() == jogador.get_world_2d():
			jogador.global_position = marcador.global_position
			break
	if jogador.camera != null:
		jogador.camera.reset_smoothing()
