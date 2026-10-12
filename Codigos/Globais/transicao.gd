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

const DURACAO_SAIDA := 0.35
const DURACAO_ENTRADA := 0.45
const DURACAO_DORMIR := 0.7
const HORA_ACORDAR := 6.0
const CAMADA := 100
const QUADROS_ESPERA_CHEGADA := 3

## true da saída de uma cena até a nova terminar de carregar: o Gerenciador-de-ondas não reinicia a partida
var retornando := false
## Foto do jogador e da arena na saída (ver _guardar_estado). Vazio = nada a restaurar (partida nova)
var estado: Dictionary = {}
## Hora do ciclo dia/noite, para o dia não "voltar para as 6h" a cada porta; -1 = sem valor
var hora_salva := -1.0
var ocupada := false

var _painel: ColorRect
var _tween: Tween

func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_painel = ColorRect.new()
	_painel.color = Color(0.03, 0.04, 0.08, 0.0)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_painel)

## Vai para outra cena: fade para preto, troca, reposiciona o jogador em `ponto` e clareia. Ignora pedidos
## enquanto outra troca está em andamento
func ir_para(caminho: String, ponto := "") -> void:
	if ocupada:
		return
	ocupada = true
	var jogador := _obter_jogador()
	if jogador != null:
		jogador.desabilitar_todas_acoes(true)
	await escurecer()
	_guardar_estado()
	retornando = true
	var erro := get_tree().change_scene_to_file(caminho)
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
	await clarear()
	ocupada = false
	troca_concluida.emit(caminho)

## Dormir na cama: fade, Calendario.dormir() (passa o dia e salva), cura total, salvamento do progresso e do
## inventário, a manhã seguinte (6h) e o jogador acorda em `ponto_acordar` (Marker2D "Chegada_<ponto>" da cena).
## O que a troca de cena guarda (onda da arena, hora) não muda: dormir não é morte e não mexe na partida
func dormir(ponto_acordar := "") -> void:
	if ocupada:
		return
	ocupada = true
	var jogador := _obter_jogador()
	if jogador != null:
		jogador.desabilitar_todas_acoes(true)
	await escurecer(DURACAO_DORMIR)
	Calendario.dormir()
	Progresso.salvar()
	InventarioJogador.salvar()
	hora_salva = HORA_ACORDAR
	var luz := get_tree().get_first_node_in_group("iluminacao")
	if luz != null and "hora" in luz:
		luz.hora = HORA_ACORDAR
		luz._aplicar()
	if jogador != null:
		jogador.descansar()
		_posicionar(jogador, ponto_acordar)
	await get_tree().create_timer(0.5).timeout
	await clarear(DURACAO_DORMIR)
	if jogador != null and is_instance_valid(jogador):
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
		hora_salva = luz.hora
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
		if marcador is Node2D and marcador.name == "Chegada_" + ponto:
			jogador.global_position = marcador.global_position
			break
	if jogador.camera != null:
		jogador.camera.reset_smoothing()
