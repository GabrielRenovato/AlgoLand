extends SceneTree
## Dois processos reais, WebRTC nativo, servidor de sinalização local e saves distintos.
var Conexao: Script
var falhas := 0
var host := false
var pasta := "/tmp/algoland-coop-online/execucao"
var sessao: Node
func _initialize(): rodar.call_deferred()
func conferir(ok: bool, nome: String):
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func esperar(condicao: Callable, segundos := 35.0) -> bool:
	var fim := Time.get_ticks_msec() + int(segundos * 1000)
	while Time.get_ticks_msec() < fim:
		if condicao.call(): return true
		await process_frame
	return false
func marcar(nome: String, texto := "ok"):
	FileAccess.open(pasta + "/" + nome, FileAccess.WRITE).store_string(texto)
func tem(nome: String) -> bool: return FileAccess.file_exists(pasta + "/" + nome)
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	for arg in OS.get_cmdline_user_args():
		if arg == "--host": host = true
		if arg.begins_with("--coop-teste-pasta="): pasta = arg.trim_prefix("--coop-teste-pasta=")
	assert(pasta.begins_with("/tmp/"))
	DirAccess.make_dir_recursive_absolute(pasta)
	create_timer(130).timeout.connect(func(): push_error("Tempo limite do coop"); quit(1))
	await process_frame
	Conexao = load("res://codigo/coop_online/conexao_coop.gd")
	root.get_node("Introducao").pular_prologo()
	var inv: Node = root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(func(): return current_scene != null and current_scene.has_node("Jogador"))
	for i in 10: await process_frame
	sessao = Conexao.obter(self)
	sessao.erro.connect(func(msg): print("COOP AVISO ", msg))
	if host:
		sessao.criar(current_scene.get_node("Jogador"))
		if not await esperar(func(): return not sessao.codigo.is_empty()):
			conferir(false, "sala criada"); quit(1); return
		marcar("sala", sessao.codigo)
	else:
		if not await esperar(func(): return tem("sala")):
			conferir(false, "codigo recebido"); quit(1); return
		var salas_recebidas: Array = []
		sessao.salas_recebidas.connect(func(salas: Array): salas_recebidas.assign(salas))
		sessao.listar(current_scene.get_node("Jogador"))
		var codigo := FileAccess.get_file_as_string(pasta + "/sala")
		var listou := await esperar(func(): return salas_recebidas.any(func(sala): return sala.codigo == codigo))
		conferir(listou, "sala do anfitriao aparece na lista publica")
		sessao.entrar(current_scene.get_node("Jogador"), codigo)
	if not await esperar(func(): return sessao.conectado):
		conferir(false, "WebRTC direto conectado"); quit(1); return
	conferir(true, "WebRTC direto conectado sem relay de gameplay")
	if host: sessao.iniciar()
	if not await esperar(func(): return current_scene != null and current_scene.has_node("AndarCoop")):
		conferir(false, "entrada no andar"); quit(1); return
	var controle: Node = current_scene.get_node("AndarCoop")
	controle.jogador.invulneravel = true
	controle.jogador.temporizador_invul = 1000
	conferir(controle.parceiro.inventario == null, "parceiro sem acesso ao inventario local")
	if host:
		if not await esperar(func(): return controle._inimigos.size() > 0 and controle._pronto):
			conferir(false, "populacao do anfitriao"); quit(1); return
		for mob in controle._inimigos.values(): mob.set_physics_process(false)
		marcar("host_pronto")
		await esperar(func(): return tem("convidado_replicas"))
		var id: int = controle._inimigos.keys()[0]
		var inimigo: Node = controle._inimigos[id]
		inimigo.set_physics_process(false)
		inimigo.global_position = controle.jogador.global_position + Vector2(70, 0)
		var vida_antes: int = inimigo.vida
		marcar("alvo", JSON.stringify({"id": id, "x": inimigo.global_position.x, "y": inimigo.global_position.y}))
		conferir(await esperar(func(): return inimigo.vida < vida_antes), "golpe do convidado aplicado somente no anfitriao")
		marcar("golpe_validado")
		await esperar(func(): return tem("saque_pedir"))
		load("res://codigo/logica/drops_forja.gd").soltar_material("ferro", 2, controle.jogador.global_position + Vector2(100, 0), current_scene)
		conferir(await esperar(func(): return tem("saque_validado")), "saque entregue na mochila do convidado")
		controle.jogador._cair()
		marcar("host_caido")
		conferir(await esperar(func(): return not controle.jogador.caido), "parceiro levanta anfitriao")
		controle.jogador.invulneravel = true
		controle.jogador.temporizador_invul = 1000
		controle.gerente.pontos = controle.gerente.META_PROGRESSO
		await controle.gerente._invocar_guardiao(controle.gerente._geracao)
		conferir(await esperar(func(): return tem("guardiao_visto")), "guardiao compartilhado")
		controle.gerente.guardiao.receber_dano(controle.gerente.guardiao.vida + 1)
		conferir(await esperar(func(): return controle.gerente.etapa == controle.gerente.Etapa.CONCLUIDO), "vitoria real do andar")
		conferir(await esperar(func(): return tem("vitoria_vista")), "vitoria recebida pelo convidado")
		root.get_node("Transicao").ir_para(load("res://codigo/fendas/catalogo_andares.gd").cena(2), "portal")
		conferir(await esperar(func(): return current_scene != null and current_scene.has_node("AndarCoop") and current_scene.get_node("AndarCoop").andar == 2), "anfitriao avancou ao andar 2")
		conferir(await esperar(func(): return tem("andar2_visto")), "convidado acompanha o proximo andar")
		marcar("fim_teste")
		await create_timer(1.0).timeout
	else:
		conferir(await esperar(func(): return controle._inimigos.size() > 0), "mesmos inimigos recebidos do anfitriao")
		conferir(get_nodes_in_group("enemy").all(func(n): return n is CharacterBody2D and n.get_script() == load("res://codigo/coop_online/inimigo_replica.gd")), "convidado nao gera IA independente")
		marcar("convidado_replicas")
		await esperar(func(): return tem("alvo"))
		var dados_alvo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pasta + "/alvo"))
		var id := int(dados_alvo.id)
		await esperar(func(): return controle._inimigos.has(id))
		var alvo: Node2D = controle._inimigos[id]
		controle.jogador.global_position = Vector2(dados_alvo.x, dados_alvo.y) + Vector2(12, 0)
		await create_timer(0.3).timeout
		alvo.receber_dano(2, Vector2.ZERO)
		conferir(await esperar(func(): return tem("golpe_validado")), "acao local chegou ao host")
		marcar("saque_pedir")
		conferir(await esperar(func(): return not get_nodes_in_group("equipamento_drop").is_empty()), "drop recebido")
		var drop: Node = get_nodes_in_group("equipamento_drop")[0]
		var antes: int = inv.quantidade_tipo("material:ferro")
		drop._dono = controle.jogador
		drop._tentar_pegar()
		conferir(inv.quantidade_tipo("material:ferro") == antes + 2, "coleta salva na mochila propria")
		marcar("saque_validado")
		await esperar(func(): return tem("host_caido"))
		controle.jogador.global_position = controle.parceiro.global_position
		conferir(await esperar(func(): return not controle.parceiro.caido), "reviver em rede")
		conferir(await esperar(func(): return controle._inimigos.values().any(func(m): return is_instance_valid(m) and m.eh_chefe)), "replica do guardiao")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta + "/convidado_andar.png")
		marcar("guardiao_visto")
		conferir(await esperar(func(): return controle._andar_concluido), "progresso e conclusao sincronizados")
		marcar("vitoria_vista")
		conferir(await esperar(func(): return current_scene != null and current_scene.has_node("AndarCoop") and current_scene.get_node("AndarCoop").andar == 2), "convidado no andar 2")
		marcar("andar2_visto")
		await esperar(func(): return tem("fim_teste"))
		conferir(await esperar(func(): return not sessao.ativo), "saida do anfitriao encerra a sessao")
	print("COOP ONLINE ", "HOST" if host else "CONVIDADO", ": ", falhas, " falhas")
	sessao.sair()
	await process_frame
	quit(1 if falhas else 0)
