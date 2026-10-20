extends SceneTree

## Exercita a compra real, a persistência das armas e o atendimento físico da taverna, com saves isolados.
var falhas := 0
var Loja: GDScript
var Dados: GDScript
var festa_coop := false
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
func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	festa_coop = "--festa-coop" in OS.get_cmdline_user_args()
	if festa_coop:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1152, 648)
	Loja = load("res://codigo/dados/loja_sementes.gd")
	Dados = load("res://codigo/cidade/dados_cidade.gd")
	root.get_node("Saves").trocar("coop")
	var prog: Node = root.get_node("Progresso")
	prog.apagar()
	var cal: Node = root.get_node("Calendario")
	cal.dia = 1
	root.get_node("Introducao").pular_prologo()
	var inv: Node = root.get_node("InventarioJogador")
	var inv2: Node = root.get_node("InventarioJogador2")
	for mochila in [inv, inv2]:
		mochila.limpar()
		mochila.criar_itens_iniciais()
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(20)
	var coop: Node = root.get_node("Cooperativo")
	var eventos: Node = root.get_node("EventosJogo")
	var ui: Node = coop.interface_p2()
	prog.brasas = 30
	var ouro: int = root.get_node("DadosJogo").moedas
	ui._abrir_tela("mercante")
	await quadros(15)
	var loja: Node = ui._telas["mercante"]
	verificar("placa de pao abre venda de sementes", loja.get_node("Painel/Linhas/Cabecalho/Titulo").text == "VENDA DO TOMAS" and loja._painel_loja.visible)
	verificar("cidade nao oferece compra de armas ou bigorna", not loja._botoes_loja.has("armas") and not loja.has_method("_comprar_arma") and not loja._aba_bigorna.visible and not loja._aba_encantar.visible)
	verificar("venda lista so sementes da estacao", loja._botoes_loja["sementes"].size() == 4)
	var antes: int = inv2.quantidade_sementes("cenoura")
	loja._selecionar_item("semente:cenoura")
	loja._comprar_item_selecionado()
	verificar("compra com Brasas no inventario do jogador 2", inv2.quantidade_sementes("cenoura") == antes + 1 and prog.brasas == 28)
	verificar("compra nao gasta ouro nem entrega ao jogador 1", root.get_node("DadosJogo").moedas == ouro and inv.quantidade_sementes("cenoura") == 0)
	verificar("compra rejeita semente de outra estacao", Loja.comprar("girassol", inv2, prog, 0) != "" and prog.brasas == 28)
	prog.brasas = 0
	verificar("saldo insuficiente nao entrega nem cobra", Loja.comprar("cenoura", inv2, prog, 0) != "" and inv2.quantidade_sementes("cenoura") == antes + 1)
	prog.brasas = 30
	var modelo: Node = load("res://codigo/modelos/modelo_inventario.gd").new()
	root.add_child(modelo)
	for i in modelo.capacidade():
		modelo.adicionar_arma_nova("espada_gemea")
	modelo.caminho_save = "user://mochila_teste_cheia.json"
	verificar("mochila cheia nao perde Brasas", Loja.comprar("cenoura", modelo, prog, 0) == "MOCHILA CHEIA" and prog.brasas == 30)
	modelo.queue_free()
	cal.dia = 31
	cal.estacao_mudou.emit(1)
	await quadros()
	verificar("estoque muda ao virar a estacao", loja._botoes_loja["sementes"].size() == 4 and loja._botoes_loja["sementes"][0].tooltip_text.contains("GIRASSOL"))
	cal.dia = 91
	cal.estacao_mudou.emit(3)
	await quadros()
	verificar("inverno sem venda fora da estacao", loja._botoes_loja["sementes"].is_empty() and loja._nome_item.text == "INVERNO" and loja._botao_comprar.disabled)
	ui._fechar_tela("mercante")
	cal.dia = 1
	prog.iniciar_partida()
	prog.registrar_onda_concluida(3, false, false)
	verificar("onda 3 nao aprende receita nem entrega a arma", not prog.receita_liberada("arco_curto") and not prog.arma_liberada("arco_curto") and inv.buscar_por_tipo("arco_curto") == null and inv2.buscar_por_tipo("arco_curto") == null)
	var receitas = load("res://codigo/dados/forja_armas.gd")
	inv.adicionar_coletavel("receita", "arco_curto")
	prog.aprender_receita("arco_curto", inv)
	prog.adicionar_materiais_forja(receitas.RECEITAS["arco_curto"])
	verificar("primeira fabricacao libera modelo e entrega aos dois", prog.fabricar_arma("arco_curto") == "" and inv.buscar_por_tipo("arco_curto") != null and inv2.buscar_por_tipo("arco_curto") != null)
	prog.registrar_onda_concluida(20, true, false)
	verificar("ondas nao aprendem receitas sozinhas", prog.armas_liberadas.size() == 1)
	for tipo in receitas.RECEITAS:
		if not prog.receita_liberada(tipo):
			inv.adicionar_coletavel("receita", tipo)
			prog.aprender_receita(tipo, inv)
	prog.salvar()
	prog.carregar()
	verificar("desbloqueios sobrevivem ao carregamento", prog.armas_liberadas.size() == receitas.RECEITAS.size())
	inv.definir_linhas_extras(7)
	inv2.definir_linhas_extras(7)
	for tipo in receitas.RECEITAS:
		if not prog.arma_liberada(tipo):
			prog.adicionar_materiais_forja(receitas.RECEITAS[tipo])
			prog.fabricar_arma(tipo)
	var arma = inv.buscar_por_tipo("arco_longo")
	arma.nivel = 5
	arma.raridade = "lendario"
	arma.encantamento = "fogo"
	coop._jogador1().reiniciar_para_nova_partida()
	await quadros()
	var nova = inv.buscar_por_tipo("arco_longo")
	verificar("reset entrega arma liberada comum no nivel 1", nova != null and nova.nivel == 1 and nova.raridade == "comum" and nova.encantamento == "")
	verificar("coop tambem recebe kit nivel 1 ao resetar", inv2.buscar_por_tipo("arco_longo") != null and inv2.buscar_por_tipo("arco_longo").nivel == 1)
	var indice: int = inv.indice_de(nova)
	inv.mochila[indice] = null
	inv.entregar_armas_liberadas()
	verificar("nao retira copias infinitas da mesma arma", inv.buscar_por_tipo("arco_longo") == null)
	ui._abrir_tela("inventario")
	var inventario: Node = ui._telas["inventario"]
	inventario.selecionar_pagina(2)
	await quadros(12)
	verificar("inventario tem quatro abas com icones e sem texto", inventario._botoes_abas.size() == 4 and inventario._botoes_abas.all(func(botao): return botao.text == "" and botao.get_child_count() > 0 and botao.tooltip_text != ""))
	verificar("aba de desafios mostra armas e progresso", inventario._desafios.is_visible_in_tree() and inventario._desafios._grade_catalogo.get_child_count() == receitas.RECEITAS.size())
	if "--capturar" in OS.get_cmdline_user_args():
		await root.get_node("Transicao").clarear(0.0)
		await quadros()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-desafios-armas.png")
	ui._fechar_tela("inventario")
	# Sábado tem prioridade sobre folga e sono, incluindo a madrugada até as 06h.
	for hora in [18.0, 23.0, 0.0]:
		var todos := true
		for id in Dados.CAMAS:
			var agenda: Dictionary = Dados.agenda(id, hora, 0, 0, 5)
			todos = todos and agenda["local"] == "pousada" and agenda.get("festa", false) and not agenda.get("dormindo", false)
		verificar("todos festejam sabado as " + str(hora), todos and Dados.taverna_aberta(hora, 5))
	var todos_dormindo := true
	for id in Dados.CAMAS:
		var agenda: Dictionary = Dados.agenda(id, 1.4, 0, 0, 5)
		todos_dormindo = todos_dormindo and agenda.get("dormindo", false) and agenda["local"] == Dados.cama(id)["local"]
	verificar("todos saem para dormir antes das 2h", todos_dormindo)
	verificar("festa encerra as 2h", not Dados.festa_sabado(2.0, 5))
	verificar("dias comuns preservam fechamento as 2h", not Dados.taverna_aberta(2.0, 4))
	# Carrega a taverna real, com as mesas e colisões; só o relógio é congelado.
	if not festa_coop:
		coop.sair()
		root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	cal.dia = 6
	root.get_node("Transicao").hora_salva = 20.0
	change_scene_to_file("res://cenas/cidade/pousada.tscn")
	await quadros(20)
	var taverna: Node = current_scene
	taverna.get_node("Iluminacao").definir_hora(20.0)
	taverna.get_node("Iluminacao").set_process(false)
	taverna._proximo_papo = INF
	taverna.get_node("Jogador").position = Vector2(560, 280)
	for npc in taverna.moradores.values():
		npc.atualizar_rotina()
		npc._espera_balao = 999
	var atendimento: Node = taverna.get_node("RotinaTaverna")
	if festa_coop:
		await verificar_taverna_coop(coop, taverna)
	Engine.time_scale = 12.0
	var convidados: Array = taverna.moradores.values().filter(func(npc): return npc.agenda.get("local","") == "pousada")
	# Quem estava andando na rua só aparece no interior depois de alcançar a porta.
	for i in 300:
		if convidados.all(func(npc): return npc.visible and not npc.dormindo):
			break
		await process_frame
	for npc in taverna.moradores.values():
		if not npc.visible or npc.dormindo:
			print("DIAGNOSTICO chegada ", npc.id, " hora=", taverna.hora_atual(), " dia=", cal.dia, " agenda=", npc.agenda, " trajeto=", root.get_node("Cidade").trajetos_moradores.get(npc.id))
	verificar("festa reune os moradores convidados no interior",convidados.size() >= 6 and convidados.all(func(npc): return npc.visible and not npc.dormindo))
	var levou := false
	var correu := false
	var vistos_sentados := {}
	# Inclui o percurso até o balcão, os pedidos presenciais e as conversas longas das duplas.
	for i in 4200:
		await process_frame
		for id in Dados.LUGARES_FESTA:
			if taverna.moradores[id].assento.estado == "sentado":
				vistos_sentados[id] = true
		if is_instance_valid(atendimento._bandeja):
			levou = true
		if taverna.moradores["bardo"].ritmo() > 1.0:
			correu = true
		if atendimento.entregas >= 5 and atendimento.pedidos.size() == 5 and atendimento.avaliacoes.size() >= 2 and atendimento.conversas_iniciadas >= 1 and atendimento.passeios_concluidos >= 1:
			break
	Engine.time_scale = 1.0
	if atendimento.entregas < 5 or atendimento.pedidos.size() != 5:
		print("DIAGNOSTICO atendimento: ", atendimento._estado, " cliente=", atendimento._cliente, " entregas=", atendimento.entregas, " pedidos=", atendimento.pedidos)
		for id in Dados.LUGARES_FESTA:
			var npc: Node2D = taverna.moradores[id]
			print("DIAGNOSTICO ", id, " pos=", npc.position, " alvo=", npc._alvo, " caminho=", npc.caminho, " assento=", npc.assento.estado, " passeio=", npc.passeando_taverna)
	verificar("taverneiro caminha levando bandeja", levou)
	verificar("na festa o taverneiro serve mais rapido", correu and taverna.moradores["bardo"].RITMO_FESTA > 1.0)
	verificar("taverneiro entrega pedidos dos cinco vizinhos", atendimento.entregas >= 5 and atendimento.pedidos.size() == 5)
	verificar("refeicoes geram comentarios dos clientes", atendimento.avaliacoes.size() >= 2)
	verificar("duplas conversam e clientes passeiam depois de comer", atendimento.conversas_iniciadas >= 1 and atendimento.passeios_concluidos >= 1)
	verificar("convidados usam poses proprias sentadas", vistos_sentados.size() >= 5)
	verificar("pose de costas usa a arte de costas", taverna.moradores["curandeira"].assento._folha.resource_path.ends_with("_costas.png"))
	var alternou: bool = atendimento.visitas_mesas.size() >= 3
	for i in range(1, mini(atendimento.visitas_mesas.size(), 3)):
		alternou = alternou and atendimento.visitas_mesas[i] != atendimento.visitas_mesas[i - 1]
	verificar("fila alterna as mesas antes de voltar a mesma", alternou)
	verificar("interior da taverna permanece iluminado a noite", taverna.get_node("Iluminacao/CanvasModulate").color.get_luminance() > 0.7)
	if "--capturar" in OS.get_cmdline_user_args():
		var camera: Camera2D = taverna.get_node("Jogador").camera
		camera.position_smoothing_enabled = false
		camera.set_as_top_level(true)
		camera.global_position = Vector2(320, 215)
		await quadros()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-festa-taverna-coop.png" if festa_coop else "/tmp/algoland-festa-taverna.png")
	taverna.get_node("Iluminacao").definir_hora(1.4)
	for npc in taverna.moradores.values():
		npc.atualizar_rotina()
	atendimento._process(0.1)
	await create_timer(2.0).timeout
	var levantados := true
	for id in Dados.LUGARES_FESTA:
		levantados = levantados and taverna.moradores[id].assento.estado == "pe" and taverna.moradores[id].sprite.hframes == 7
	verificar("amanhecer anima levantar e restaura a caminhada", levantados)
	await quadros()
	taverna.get_node("Iluminacao").definir_hora(2.0)
	atendimento._process(0.1)
	verificar("fechamento encerra atendimento e limpa mesas", atendimento.pedidos.is_empty() and atendimento._pratos.is_empty())
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)

func verificar_taverna_coop(coop: Node, taverna: Node) -> void:
	var p1: Node2D = coop._jogador1()
	var p2: Node2D = coop.jogador2()
	verificar("coop tem duas vistas e compartilha a mesma taverna", coop.ativo and coop._vistas.size() == 2 and p1.get_world_2d() == p2.get_world_2d() and coop.cena_de(p2) == taverna)
	var bancos: Array = get_nodes_in_group("assentos").filter(func(banco): return banco.get_world_2d() == p1.get_world_2d() and banco.global_position.y > 300 and banco.frente == -1)
	verificar("coop encontra bancos livres de costas para os dois jogadores", bancos.size() >= 2)
	if bancos.size() >= 2:
		bancos[0]._sentar(p1)
		bancos[1]._sentar(p2)
		await quadros()
		verificar("jogadores sentam de costas em bancos independentes", p1.esta_sentado and p2.esta_sentado and p1._frente_sentado == -1 and p2._frente_sentado == -1)
		p1.pediu_levantar.emit()
		await quadros()
		verificar("levantar o jogador 1 preserva o jogador 2 sentado", not p1.esta_sentado and p2.esta_sentado and bancos[1].ocupada)
		p2.pediu_levantar.emit()
		await quadros()
		verificar("jogador 2 levanta e libera seu proprio banco", not p2.esta_sentado and not bancos[1].ocupada)
	p2.position = Vector2(600, 280)
	await coop.viajar_local(p1, "res://cenas/cidade.tscn", "pousada")
	await quadros()
	verificar("sair da taverna nao teleporta o parceiro", coop.cena_de(p2) == taverna and p1.get_world_2d() != p2.get_world_2d())
	verificar("taverna continua iluminada com parceiro na rua", taverna.get_node("Iluminacao/CanvasModulate").color.get_luminance() > 0.7)
	await coop.viajar_local(p1, "res://cenas/cidade/pousada.tscn", "entrada")
	await quadros()
	verificar("reencontro reutiliza a mesma taverna e seus moradores", p1.get_world_2d() == p2.get_world_2d() and coop.cena_de(p1) == taverna and get_nodes_in_group("moradores_cidade").filter(func(npc): return npc.vila == taverna).size() == Dados.MORADORES.size() - 1)
	p1.position = Vector2(560, 280)
	p2.position = Vector2(600, 280)
