extends SceneTree

## Fumaça rápida do cooperativo local: os dois jogadores passam por todas as cenas (vila, interiores, casa, fazenda,
## arena), andam, abrem e fecham a mochila e jogam uma onda inteira. Serve para pegar crash e erro de script; conferir
## também "SCRIPT ERROR" no log. Saves isolados obrigatórios.

const CENAS := ["res://cenas/cidade.tscn", "res://cenas/cidade/venda.tscn", "res://cenas/cidade/sede.tscn",
	"res://cenas/cidade/enfermaria.tscn", "res://cenas/cidade/pousada.tscn", "res://cenas/cidade/mistica.tscn",
	"res://cenas/cidade/casa_bento.tscn", "res://cenas/casa.tscn", "res://cenas/fazenda.tscn"]
const P1 := 41
const P2 := 40

var falhas := 0
var coop: Node

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await physics_frame
		await process_frame

func botao(dispositivo: int, indice: int) -> void:
	for pressionado in [true, false]:
		var evento := InputEventJoypadButton.new()
		evento.device = dispositivo
		evento.button_index = indice
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await quadros(2)

func eixo(dispositivo: int, valor_x: float, valor_y: float) -> void:
	for dados in [[JOY_AXIS_LEFT_X, valor_x], [JOY_AXIS_LEFT_Y, valor_y]]:
		var evento := InputEventJoypadMotion.new()
		evento.device = dispositivo
		evento.axis = dados[0]
		evento.axis_value = dados[1]
		Input.parse_input_event(evento)

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	for nome in ["InventarioJogador", "InventarioJogador2"]:
		root.get_node(nome).limpar()
		root.get_node(nome).criar_itens_iniciais()
	coop = root.get_node("Cooperativo")
	coop.entrar(P2)
	coop.dispositivo_p1 = P1
	coop.dispositivo_p2 = P2
	coop._reconfigurar_entrada()

	for caminho in CENAS:
		await _visitar(caminho)
	await _arena()
	coop.sair()
	await quadros()
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)

func _visitar(caminho: String) -> void:
	var nome := caminho.get_file().get_basename()
	change_scene_to_file(caminho)
	await quadros(30)
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	verificar(nome + ": cena carregou", current_scene != null and current_scene.scene_file_path == caminho)
	verificar(nome + ": os dois jogadores existem", p1 != null and p2 != null)
	if p1 == null or p2 == null:
		return
	verificar(nome + ": mesmo mundo", p1.get_world_2d() == p2.get_world_2d())
	verificar(nome + ": tela dividida montada", coop.interface_p2() != null)
	# Os dois andam um pouco em direções opostas
	var inicio2 := p2.global_position
	eixo(P2, 1.0, 0.3)
	eixo(P1, -1.0, -0.3)
	await quadros(25)
	eixo(P2, 0.0, 0.0)
	eixo(P1, 0.0, 0.0)
	await quadros(4)
	verificar(nome + ": P2 anda pelo proprio controle", p2.global_position.distance_to(inicio2) > 2.0)
	# Mochila dos dois: abre e fecha (View no controle)
	await botao(P2, JOY_BUTTON_BACK)
	await botao(P1, JOY_BUTTON_BACK)
	await quadros(6)
	await botao(P2, JOY_BUTTON_BACK)
	await botao(P1, JOY_BUTTON_BACK)
	await quadros(6)
	verificar(nome + ": jogadores livres depois da mochila", p1.movimento_habilitado and p2.movimento_habilitado)

func _arena() -> void:
	await _visitar("res://cenas/cenario.tscn")
	var gerenciador: Node = get_first_node_in_group("gerenciador_ondas")
	verificar("arena: gerenciador de ondas", gerenciador != null)
	if gerenciador == null:
		return
	if not gerenciador.onda_em_andamento:
		gerenciador.iniciar_onda()
	await quadros(90)
	verificar("arena: onda 1 em andamento", gerenciador.onda_em_andamento)
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	# Os dois atacam um pouco (X no controle) e os inimigos que sobrarem caem por dano direto
	for i in 3:
		await botao(P1, JOY_BUTTON_X)
		await botao(P2, JOY_BUTTON_X)
	for vez in 40:
		for inimigo in get_nodes_in_group("enemy"):
			if is_instance_valid(inimigo) and inimigo.has_method("receber_dano"):
				inimigo.receber_dano(99999)
		await quadros(6)
		if not gerenciador.onda_em_andamento:
			break
	verificar("arena: onda 1 termina com os dois vivos", not gerenciador.onda_em_andamento and not p1.estaMorto and not p2.estaMorto)
	await quadros(60)
	verificar("arena: P1 e P2 continuam na cena depois da onda", is_instance_valid(p1) and is_instance_valid(p2))
	# P2 apanha bastante (sem morrer) e o jogo segue
	if is_instance_valid(p2) and p2.has_method("receber_dano"):
		p2.receber_dano(int(p2.get("vida_maxima") if p2.get("vida_maxima") != null else 50) / 2)
		await quadros(20)
		verificar("arena: P2 leva dano sem quebrar nada", is_instance_valid(p2))
