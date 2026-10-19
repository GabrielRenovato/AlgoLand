extends SceneTree

var falhas := 0
var verificacoes := 0
func _initialize() -> void:
	_executar.call_deferred()

func verificar(condicao: bool, mensagem: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		push_error("FALHA: " + mensagem)

func _executar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes carroca"):
		push_error("FALHA: exige save isolado da carroca")
		quit(1)
		return
	var comercio := root.get_node("Comercio")
	comercio.liberado = true
	var fazenda := root.get_node("Fazenda")
	var calendario := root.get_node("Calendario")
	var dados := root.get_node("DadosJogo")
	var saves := root.get_node("Saves")
	var introducao := root.get_node("Introducao")
	saves.trocar("coop")
	comercio.apagar()
	saves.trocar("solo")
	introducao.pular_prologo()
	comercio.apagar()
	# Retorno sem espaço preserva a carga e permite vender, sem criar estoque virtual.
	var mochila := root.get_node("InventarioJogador")
	mochila.limpar()
	for i in mochila.capacidade():
		mochila.mochila[i] = DadosItem.de_coletavel("material", "madeira", 1)
	comercio.em_viagem = true
	comercio.eventos.assign(["roda"])
	comercio.etapa = 2
	comercio.carga.assign([{"chave":"pocao:cura", "lado":1}])
	comercio.voltar()
	verificar(comercio.em_viagem and comercio.carga.size() == 1 and fazenda.quantidade_pocoes("cura") == 0, "mochila cheia preserva produto na carga")
	verificar(comercio.etapa == comercio.eventos.size() and comercio.vender(0, 1) > 0, "retorno bloqueado permite vender o produto restante")
	mochila.limpar()
	mochila.criar_itens_iniciais()
	comercio.apagar()
	comercio.definir_pelagem(0)
	comercio.carregar()
	verificar(comercio.pelagem == 0, "pelagem preta persiste no save")
	comercio.definir_pelagem(1)
	comercio.definir_pelagem(9)
	verificar(comercio.pelagem == 1, "ignora pelagem invalida")
	calendario.dia = 1
	fazenda.colheita = {"cenoura": 30, "batata": 4}
	fazenda.pocoes = {"cura": 4}
	verificar(comercio.capacidade() == 8, "oito casas iniciais")
	verificar(comercio.pedidos().has("colheita:cenoura"), "pedido inicial de primavera")
	for i in 8:
		verificar(comercio.reservar("colheita:cenoura", 1), "reserva unidade %d" % i)
	verificar(not comercio.reservar("colheita:cenoura", 1), "limite impede volume ilimitado")
	verificar(fazenda.colheita.cenoura == 30, "preparacao nao retira da bolsa")
	verificar(not comercio.retirar(0, 2), "parceiro nao retira carga alheia")
	verificar(comercio.iniciar(42), "inicia rota")
	verificar(fazenda.colheita.cenoura == 22, "debita somente ao partir")
	verificar(comercio.eventos.size() in [2, 3], "duas a tres escolhas")
	verificar(not comercio.reservar("colheita:cenoura", 1), "nao carrega no mercado")
	comercio.etapa = comercio.eventos.size()
	var ganho := 0
	for i in 8:
		ganho += comercio.vender(0, 1)
	verificar(ganho == 4 * 4 + 4 * 3, "premio acaba ao atender quatro unidades")
	verificar(comercio.vender(0, 1) == 0, "nao vende duas vezes")
	comercio.salvar()
	comercio.carregar()
	verificar(comercio.receita[0] == ganho and comercio.carga.is_empty(), "retoma vendas sem duplicar")
	verificar(comercio.preco("colheita:cenoura") == 3, "cota persiste ao recarregar")
	comercio.em_viagem = false
	comercio.carga.clear()
	comercio.reservar("pocao:cura", 2)
	comercio.iniciar(7)
	comercio.etapa = comercio.eventos.size()
	verificar(comercio.vender(0, 1) == 0, "P1 nao vende a unidade do P2")
	verificar(comercio.vender(0, 2) == 12, "P2 vende seu produto")
	# A semana 5 cai no verão; o segundo produto é tomate.
	calendario.dia = 36
	verificar(comercio.pedidos().has("colheita:tomate"), "demanda acompanha semana e estacao")
	verificar(comercio.atendidos.is_empty(), "cotas reiniciam na nova semana")
	comercio.em_viagem = false
	dados.moedas = 1000
	verificar(comercio.melhorar(null), "melhoria paga")
	verificar(comercio.capacidade() == 10 and dados.moedas == 880, "melhoria custa 120 e abre duas casas")
	verificar(comercio.melhorar(null), "segunda melhoria paga")
	verificar(comercio.capacidade() == 12 and not comercio.melhorar(null), "maximo de doze casas")
	comercio.salvar()
	saves.trocar("coop")
	verificar(comercio.nivel == 0 and comercio.carga.is_empty(), "coop separado do solo")
	saves.trocar("solo")
	verificar(comercio.nivel == 2, "volta ao progresso solo")
	comercio.apagar()
	verificar(comercio.nivel == 0 and not comercio.em_viagem, "novo jogo limpa rota")
	# Renderização da cena real, com câmera e recursos sazonais existentes.
	change_scene_to_file("res://cenas/fazenda.tscn")
	for i in 12:
		await process_frame
	var carroca := current_scene.get_node("Carroca")
	await physics_frame
	var espaco: PhysicsDirectSpaceState2D = carroca.get_world_2d().direct_space_state
	var linha_base := PhysicsRayQueryParameters2D.create(Vector2(580, 278), Vector2(640, 278), 32)
	verificar(not espaco.intersect_ray(linha_base).is_empty(), "base fisica do cavalo impede atravessar o corpo")
	var linha_estrada := PhysicsRayQueryParameters2D.create(Vector2(580, 310), Vector2(640, 310), 32)
	verificar(espaco.intersect_ray(linha_estrada).is_empty(), "cavalo preserva passagem ao sul da carroca")
	var jogador := current_scene.get_node("Jogador")
	jogador.position = Vector2(520, 310)
	jogador.camera.position_smoothing_enabled = false
	jogador.camera.limit_left = 0
	jogador.camera.limit_top = 0
	jogador.camera.reset_smoothing()
	var luz := current_scene.get_node("Iluminacao")
	luz.definir_hora(12)
	var estacoes := current_scene.get_node("Terrains/Estacoes")
	for estacao in 4:
		calendario.dia = estacao * 30 + 1
		calendario.estacao_mudou.emit(estacao)
		call_group("hud", "atualizar_data")
		estacoes.definir_estacao(estacao, true)
		for i in 8:
			await process_frame
		for cor in 3:
			comercio.definir_pelagem(cor)
			verificar(carroca.cavalo.material.get_shader_parameter("pelagem") == cor, "pelagem %d na estacao %d" % [cor, estacao])
		verificar(carroca.cavalo.texture != null and (carroca.cavalo.texture.get_size() * carroca.cavalo.scale).is_equal_approx(Vector2(124.8, 83.2)), "cavalo sazonal ampliado no mundo %d" % estacao)
		verificar(carroca.sprite.texture != null, "textura sazonal %d" % estacao)
		verificar((carroca.sprite.texture.get_size() * carroca.sprite.scale).is_equal_approx(Vector2(96, 64)), "canvas preservado no mundo %d" % estacao)
		if "--capturar" in OS.get_cmdline_user_args():
			await create_timer(1).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://arte/previas/comercio/fazenda_%d.png" % estacao)
	calendario.dia = 1
	calendario.estacao_mudou.emit(0)
	call_group("hud", "atualizar_data")
	fazenda.colheita = {"cenoura": 10}
	comercio.reservar("colheita:cenoura", 1)
	comercio.iniciar(1)
	var interface := current_scene.get_node("Interface")
	interface._abrir_tela("comercio")
	for i in 5:
		await process_frame
	if "--capturar" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://arte/previas/comercio/viagem.png")
	comercio.etapa = 0
	comercio.eventos.assign(["monstros", "roda"])
	comercio.iniciar_combate()
	await process_frame
	verificar(comercio.em_combate and not jogador.modo_fazenda, "luta usa jogador em modo combate")
	verificar(comercio._inimigos.size() == 2, "encontro usa monstros existentes")
	jogador.morrer()
	await process_frame
	verificar(not comercio.em_combate and comercio.carga.is_empty(), "derrota encerra luta e perde uma unidade")
	verificar(jogador.hp_atual == 1 and not jogador.estaMorto, "derrota de estrada preserva partida")
	comercio.etapa = comercio.eventos.size() + 1
	var antes: int = calendario.dia
	comercio.voltar()
	await create_timer(3).timeout
	verificar(calendario.dia == antes + 1, "ida e volta consomem um dia exato")
	verificar(not comercio.em_viagem, "retorno libera o mundo")
	print("COMERCIO: %d verificacoes, %d falhas" % [verificacoes, falhas])
	quit(1 if falhas else 0)
