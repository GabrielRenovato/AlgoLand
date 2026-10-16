extends SceneTree

## Regressões do controle (pedido de 2026-10-16): trocar de ferramenta com LB/RB na fazenda (sozinho e no cooperativo) e
## o START pausar e despausar no cooperativo, pelos dois controles, sem o jogo ficar parado. Saves isolados obrigatórios.

const P1 := 41
const P2 := 40

var falhas := 0
var coop: Node
var fazenda: Node

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await process_frame

func botao(dispositivo: int, indice: int) -> void:
	for pressionado in [true, false]:
		var evento := InputEventJoypadButton.new()
		evento.device = dispositivo
		evento.button_index = indice
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await quadros(3)

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	coop = root.get_node("Cooperativo")
	fazenda = root.get_node("Fazenda")
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	root.get_node("InventarioJogador").limpar()
	root.get_node("InventarioJogador").criar_itens_iniciais()
	# Sozinho, com o controle 0
	var controle: Node = root.get_node("Controle")
	if controle.has_method("_definir"):
		controle._definir(true)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(30)
	await _trocar_ferramenta("sozinho", 0)

	# Cooperativo
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	for nome in ["InventarioJogador", "InventarioJogador2"]:
		root.get_node(nome).limpar()
		root.get_node(nome).criar_itens_iniciais()
	coop.entrar(P2)
	coop.dispositivo_p1 = P1
	coop.dispositivo_p2 = P2
	coop._reconfigurar_entrada()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(40)
	verificar("coop: jogador 2 na fazenda", coop.jogador2() != null)
	await _trocar_ferramenta("coop P1", P1)
	await _trocar_ferramenta("coop P2", P2)
	await _viagem_individual()
	await _pausa("coop P1", P1)
	await _pausa("coop P2", P2)
	verificar("coop: continua com dois jogadores depois das pausas", coop.ativo and coop.jogador2() != null)
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)

func _trocar_ferramenta(quem: String, dispositivo: int) -> void:
	var lado := 2 if dispositivo == P2 else 1
	var parceiro := 1 if lado == 2 else 2
	var antes_parceiro: String = fazenda.ferramenta_de(parceiro)
	var antes: String = fazenda.ferramenta_de(lado)
	await botao(dispositivo, JOY_BUTTON_RIGHT_SHOULDER)
	var depois_rb: String = fazenda.ferramenta_de(lado)
	verificar("%s: RB troca a ferramenta (%s -> %s)" % [quem, antes, depois_rb], depois_rb != antes and depois_rb != "")
	await botao(dispositivo, JOY_BUTTON_LEFT_SHOULDER)
	verificar("%s: LB volta a ferramenta (%s -> %s)" % [quem, depois_rb, fazenda.ferramenta_de(lado)], fazenda.ferramenta_de(lado) == antes)
	verificar(quem + ": troca não altera ferramenta do parceiro", fazenda.ferramenta_de(parceiro) == antes_parceiro)

## O caso do jogo: os dois saem da vila e vão cada um sozinho para a fazenda (Cooperativo.viajar_local), que fica num
## SubViewport à parte, sem entrada própria
func _viagem_individual() -> void:
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(40)
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	verificar("viagem: dois jogadores na vila", p1 != null and p2 != null)
	if p1 == null or p2 == null:
		return
	await coop.viajar_local(p1, "res://cenas/fazenda.tscn", "cidade")
	await quadros(10)
	await coop.viajar_local(p2, "res://cenas/fazenda.tscn", "cidade")
	await quadros(20)
	verificar("viagem: os dois estao na fazenda (fora da cena principal)", p1.modo_fazenda and p2.modo_fazenda and p1.get_world_2d() == p2.get_world_2d() and p1.get_world_2d() != current_scene.get_world_2d())
	await _trocar_ferramenta("viagem P1", P1)
	await _trocar_ferramenta("viagem P2", P2)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(40)

func _pausa(quem: String, dispositivo: int) -> void:
	await botao(dispositivo, JOY_BUTTON_START)
	await quadros(4)
	verificar("%s: START pausa o jogo" % quem, paused)
	await botao(dispositivo, JOY_BUTTON_START)
	await quadros(4)
	verificar("%s: START de novo despausa" % quem, not paused)
	if paused:
		paused = false
		await quadros(4)
	await botao(dispositivo, JOY_BUTTON_START)
	await quadros(4)
	await botao(dispositivo, JOY_BUTTON_B)
	await quadros(4)
	verificar("%s: B fecha a pausa" % quem, not paused)
	paused = false
	await quadros(4)
