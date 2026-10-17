extends SceneTree

## Pesca (minigame copiado do SeasonsFarm): ponto do pier -> lançar -> esperar -> beliscar -> fisgar -> peixe na bolsa
## -> venda ao Nilo em Brasas. Fotos em arte/previas/pesca. Saves isolados obrigatórios.

var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await process_frame

func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/previas/pesca"))
	root.get_texture().get_image().save_png("res://arte/previas/pesca/%s.png" % nome)

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	var peixes = load("res://codigo/pesca/peixes.gd")
	var fazenda: Node = root.get_node("Fazenda")
	var progresso: Node = root.get_node("Progresso")
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	fazenda.peixes = {}
	root.get_node("InventarioJogador").salvar()
	root.get_node("InventarioJogador").limpar()
	root.get_node("InventarioJogador").carregar()
	fazenda.peixes_pescados = {}
	progresso.brasas = 0

	# --- Dados ---
	for id in peixes.DADOS:
		verificar("%s: existe no catalogo com icone" % id, peixes.existe(id) and peixes.icone(id) != null)
	for estacao in 4:
		verificar("mar na estacao %d sorteia peixe" % estacao, peixes.sortear("mar", estacao) != "")
		verificar("rio na estacao %d sorteia peixe" % estacao, peixes.sortear("rio", estacao) != "")
	verificar("peixe do mar nao e de rio", peixes.catalogo()[peixes.sortear("mar", 0)]["ambiente"] == "mar")

	# --- Bolsa e venda ---
	fazenda.pescar("sardinha")
	fazenda.pescar("sardinha")
	fazenda.pescar("salmao")
	verificar("bolsa conta os peixes", fazenda.total_de_peixes() == 3 and fazenda.quantidade_peixes("sardinha") == 2)
	verificar("valor = 3+3+14", fazenda.valor_dos_peixes() == 20)
	fazenda.salvar()
	fazenda.peixes = {}
	root.get_node("InventarioJogador").salvar()
	root.get_node("InventarioJogador").limpar()
	root.get_node("InventarioJogador").carregar()
	fazenda.peixes_pescados = {}
	fazenda.carregar()
	verificar("peixes sobrevivem ao save", fazenda.total_de_peixes() == 3 and int(fazenda.peixes_pescados.get("sardinha", 0)) == 2)
	verificar("vender um tipo paga so ele", fazenda.vender_peixes("sardinha") == 6 and progresso.brasas == 6 and fazenda.quantidade_peixes("salmao") == 1)
	verificar("vender tudo", fazenda.vender_peixes() == 14 and progresso.brasas == 20 and fazenda.total_de_peixes() == 0)
	verificar("vender sem peixe nao paga", fazenda.vender_peixes() == 0)
	verificar("historico fica depois de vender", int(fazenda.peixes_pescados.get("salmao", 0)) == 1)

	# --- Sessão no pier da praia ---
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	var jogador: CharacterBody2D = current_scene.get_node("Jogador")
	var ponto: Area2D = current_scene.get_node("PescaPierLeste")
	jogador.global_position = ponto.global_position
	await quadros(8)
	verificar("perto do ponto", ponto.jogador_perto and ponto.pode_interagir())
	ponto.abrir_tela()
	await quadros(3)
	var sessao: Node = jogador.get_node_or_null("SessaoPesca")
	verificar("sessao criada e jogador parado", sessao != null and not jogador.movimento_habilitado)
	verificar("nao abre duas sessoes", not ponto.pode_interagir())
	await quadros(20)
	foto("lancando")
	sessao._tempo = 99.0
	await quadros(4)
	verificar("esperando a mordida", sessao.estado == sessao.Estado.ESPERANDO)
	sessao._espera = 0.0
	await quadros(6)
	verificar("peixe beliscou", sessao.estado == sessao.Estado.BELISCANDO and sessao.peixe != "")
	foto("belisco")
	sessao._puxar()
	await quadros(60)
	var minijogo: Control = sessao._minijogo
	verificar("minijogo aberto", minijogo != null and minijogo.ativo)
	var quadros_peixe := {}
	minijogo.set_process(false)
	for i in 8:
		quadros_peixe[sessao._sombra.frame] = true
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-peixe-pulando-%d.png" % i)
		await create_timer(0.10).timeout
	verificar("peixe continua pulando durante a fisgada",quadros_peixe.size() == 4)
	minijogo.set_process(true)
	foto("minijogo")
	var guarda := 0
	while sessao.estado == sessao.Estado.PUXANDO and guarda < 40:
		if minijogo.check_ativo:
			minijogo._resolver("otimo", minijogo.ganho_otimo, Color.WHITE)
		await quadros(30)
		guarda += 1
	verificar("captura perfeita creditada", fazenda.pesca_perfeitas > 0)
	verificar("fisgou o peixe", sessao.estado == sessao.Estado.PEGOU and fazenda.total_de_peixes() == 1)
	await quadros(20)
	foto("pegou")
	await quadros(180)
	verificar("sessao acabou e jogador solto", not is_instance_valid(sessao) and jogador.movimento_habilitado)

	# --- Peixe escapa ---
	ponto.abrir_tela()
	await quadros(3)
	sessao = jogador.get_node("SessaoPesca")
	sessao._tempo = 99.0
	await quadros(2)
	sessao._espera = 0.0
	await quadros(4)
	sessao._puxar()
	await quadros(60)
	minijogo = sessao._minijogo
	guarda = 0
	while is_instance_valid(sessao) and guarda < 40:
		if is_instance_valid(minijogo) and minijogo.check_ativo:
			minijogo._resolver("erro", -minijogo.perda_erro, Color.WHITE)
		await quadros(30)
		guarda += 1
	verificar("errar tudo: peixe escapa", fazenda.total_de_peixes() == 1 and jogador.movimento_habilitado)

	# --- Perder a mordida ---
	ponto.abrir_tela()
	await quadros(3)
	sessao = jogador.get_node("SessaoPesca")
	sessao._tempo = 99.0
	await quadros(2)
	sessao._espera = 0.0
	await quadros(4)
	sessao._espera = 0.0
	await quadros(4)
	verificar("sem apertar a tempo a linha recolhe", not is_instance_valid(sessao) or sessao.is_queued_for_deletion())
	await quadros(4)
	verificar("jogador solto depois de perder", jogador.movimento_habilitado)
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
