extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_mira.gd
# Direção dos golpes e dos disparos do jogador, e os arcos:
#  - o golpe de espada/lança sai para onde o jogador aponta NESTE instante (em cardinal; na diagonal não mistura dois lados), inclusive o
#    golpe enfileirado do combo (antes saía para onde ele apontava no começo do golpe anterior);
#  - o arco só puxa a flecha para inimigos do lado que ele aponta (o das costas não rouba a mira);
#  - o arco longo atira 3 flechas em leque, mais devagar; os arcos mais caros rendem mais dano por segundo.
# ATENCAO: carrega a cena de jogo e equipa itens (grava user://inventario.json); faça backup do user:// antes.

var _falhas: int = 0
var _cena: Node
var _jogador: Node2D
var _inventario: Node

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _fisica(n: int) -> void:
	for i in n:
		await physics_frame

func _ms(ms: int) -> void:
	await create_timer(ms / 1000.0).timeout

func _soltar() -> void:
	for acao in ["move_up", "move_down", "move_left", "move_right", "attack", "aparar", "rolar"]:
		Input.action_release(acao)

func _atacar() -> void:
	var ev := InputEventAction.new()
	ev.action = &"attack"
	ev.pressed = true
	Input.parse_input_event(ev)
	var solta := InputEventAction.new()
	solta.action = &"attack"
	solta.pressed = false
	Input.parse_input_event(solta)

func _flechas() -> Array:
	var lista: Array = []
	for no in _cena.get_children():
		if no.get_script() != null and String(no.get_script().resource_path).ends_with("flecha.gd"):
			lista.append(no)
	return lista

func _limpar() -> void:
	for no in _flechas():
		no.queue_free()
	for inimigo in get_nodes_in_group("enemy"):
		inimigo.queue_free()
	await _quadros(2)

func _rodar() -> void:
	await process_frame
	root.get_node("Progresso").caminho_save = "user://teste_mira_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://teste_mira_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	_inventario = root.get_node("InventarioJogador")
	_inventario.limpar()
	_inventario.criar_itens_iniciais()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	await _ms(200)
	_jogador = _cena.get_node("Jogador")
	_cena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	await _limpar()

	# --- espada: o golpe sai para onde ele aponta agora
	_inventario.equipar(_inventario.buscar_por_tipo("espada_basica"))
	await _ms(500)
	Input.action_press("move_left")
	await _fisica(3)
	_atacar()
	await _fisica(3)
	_verificar("golpe de espada apontando para a esquerda sai para a esquerda", _jogador._esta_atacando and _jogador._direcao_ataque == Vector2.LEFT, str(_jogador._direcao_ataque))
	# combo enfileirado: troca de lado no meio do golpe e aperta atacar de novo
	_soltar()
	Input.action_press("move_up")
	await _fisica(2)
	_atacar()
	await _fisica(2)
	_verificar("a mira acompanha o direcional mesmo durante o golpe (o golpe que já começou não muda)", _jogador._direcao_ataque.y < -0.9 and _jogador._fase_combo == 1, "dir=%s fase=%d" % [_jogador._direcao_ataque, _jogador._fase_combo])
	await _ms(450)
	_verificar("o segundo golpe do combo saiu para CIMA, onde ele apontava ao apertar (antes saía para a esquerda)", _jogador._fase_combo == 2 and _jogador._direcao_ataque == Vector2.UP, "fase=%d dir=%s" % [_jogador._fase_combo, _jogador._direcao_ataque])
	_soltar()
	await _ms(900)
	# diagonal: vira cardinal (sem misturar dois lados)
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _fisica(3)
	_atacar()
	await _fisica(3)
	var d: Vector2 = _jogador._cardinal_anterior
	_verificar("na diagonal o golpe vai para um lado só (cardinal; o blend da animação recebe esse vetor)", (absf(d.x) == 1.0 and d.y == 0.0) or (d.x == 0.0 and absf(d.y) == 1.0), str(d))
	_soltar()
	await _ms(900)
	# parado: o golpe sai para onde ele olhava
	var antes: Vector2 = _jogador._direcao_ataque
	_atacar()
	await _fisica(3)
	_verificar("sem apertar direção, o golpe sai para onde ele olhava", _jogador._direcao_ataque == antes or _jogador._cardinal_de(antes) == _jogador._direcao_ataque, "%s -> %s" % [antes, _jogador._direcao_ataque])
	await _ms(900)

	# --- lança
	_inventario.equipar(_inventario.buscar_por_tipo("lanca_basica"))
	await _ms(500)
	Input.action_press("move_right")
	await _fisica(3)
	_atacar()
	await _fisica(3)
	_verificar("golpe de lança apontando para a direita sai para a direita", _jogador._esta_atacando and _jogador._direcao_ataque == Vector2.RIGHT, str(_jogador._direcao_ataque))
	_soltar()
	await _ms(1200)

	# --- arco: mira assistida só do lado apontado
	_inventario.equipar(_inventario.buscar_por_tipo("arco_curvo") if _inventario.buscar_por_tipo("arco_curvo") != null else _inventario.buscar_por_tipo("lanca_basica"))
	_jogador.usando_arco = true
	var inimigo: Node2D = load("res://cenas/inimigos/slime.tscn").instantiate()
	_cena.add_child(inimigo)
	inimigo.set_physics_process(false)
	inimigo.global_position = _jogador.global_position + Vector2(-60, 0)
	await _fisica(2)
	Input.action_press("move_right")
	await _fisica(2)
	var mira: Vector2 = _jogador._mira_do_disparo()
	_verificar("arco: apontando para a direita, o inimigo à esquerda (costas) não rouba a flecha", mira.x > 0.9, str(mira))
	_soltar()
	await _fisica(2)
	mira = _jogador._mira_do_disparo()
	_verificar("arco: parado, mira no inimigo mais próximo (como sempre)", mira.x < -0.9, str(mira))
	Input.action_press("move_left")
	await _fisica(2)
	mira = _jogador._mira_do_disparo()
	_verificar("arco: apontando para o lado do inimigo, mira nele", mira.x < -0.9, str(mira))
	_soltar()
	inimigo.global_position = _jogador.global_position + Vector2(50, 40)
	Input.action_press("move_right")
	await _fisica(2)
	mira = _jogador._mira_do_disparo()
	_verificar("arco: inimigo dentro do cone (um pouco abaixo da direita) atrai a flecha", mira.x > 0.7 and mira.y > 0.2, str(mira))
	_soltar()
	inimigo.queue_free()
	await _limpar()

	# --- os arcos
	var Equip := preload("res://codigo/dados/equipamentos.gd")
	var curto: Dictionary = Equip.ARMAS_ADICIONAIS["arco_curto"]
	var curvo: Dictionary = Equip.ARMAS_ADICIONAIS["arco_curvo"]
	var longo: Dictionary = Equip.ARMAS_ADICIONAIS["arco_longo"]
	var forca := 5.0
	var dps_curto: float = (float(curto["dano"][0]) + forca) / float(curto["tempo_disparo"])
	var dps_curvo: float = (float(curvo["dano"][0]) + forca) / float(curvo["tempo_disparo"])
	var dps_longo: float = (float(longo["dano"][0]) + forca) * int(longo.get("flechas", 1)) / float(longo["tempo_disparo"])
	_verificar("quanto mais caro o arco, mais dano por segundo (nível 1: %.0f < %.0f < %.0f)" % [dps_curto, dps_curvo, dps_longo], dps_curto < dps_curvo and dps_curvo < dps_longo, "")
	var sempre_melhor := true
	for i in 5:
		sempre_melhor = sempre_melhor and curto["dano"][i] < curvo["dano"][i] and curvo["dano"][i] <= longo["dano"][i] + 3
	_verificar("em todos os níveis o dano por flecha cresce com o preço do arco", sempre_melhor, "")
	_verificar("o arco longo atira 3 flechas e é o mais lento", int(longo["flechas"]) == 3 and float(longo["tempo_disparo"]) > float(curvo["tempo_disparo"]) and float(longo["tempo_disparo"]) > float(curto["tempo_disparo"])
			and not curto.has("flechas") and not curvo.has("flechas"), "")
	_jogador.id_arco_atual = "arco_longo"
	_jogador._ao_disparo_liberado(Vector2.RIGHT)
	await _fisica(1)
	var tres := _flechas()
	var angulos: Array = []
	for f in tres:
		angulos.append(snappedf(rad_to_deg(f._direcao.angle()), 0.1))
	angulos.sort()
	_verificar("o arco longo solta 3 flechas em leque (-11, 0 e +11 graus)", tres.size() == 3 and angulos == [-11.0, 0.0, 11.0], str(angulos))
	await _limpar()
	_jogador.id_arco_atual = "arco_curto"
	_jogador._ao_disparo_liberado(Vector2.RIGHT)
	await _fisica(1)
	_verificar("o arco curto solta 1 flecha", _flechas().size() == 1, str(_flechas().size()))
	await _limpar()
	_jogador.id_arco_atual = "arco_longo"

	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	print("--- teste_mira: ", "TUDO OK" if _falhas == 0 else "%d FALHAS" % _falhas)
	print("FALHAS: ", _falhas)
	quit(1 if _falhas > 0 else 0)
