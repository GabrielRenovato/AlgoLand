extends SceneTree

## Exercita os mapas reais, rotinas, diálogo, serviços, pedidos e persistência com saves isolados.
var falhas := 0
var dados: GDScript
var cidade: Node
var progresso: Node
var calendario: Node
var fazenda: Node
var inventario: Node
var transicao: Node

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await process_frame

func verificar_terreno(vila: Node) -> void:
	for camada: TileMapLayer in vila.get_node("Terrains").find_children("*", "TileMapLayer", true, false):
		var nome: String = camada.name
		var validos := not camada.get_used_cells().is_empty()
		for celula in camada.get_used_cells():
			var fonte := camada.tile_set.get_source(camada.get_cell_source_id(celula)) as TileSetAtlasSource
			validos = validos and fonte != null and fonte.has_tile(camada.get_cell_atlas_coords(celula))
		verificar("tiles existentes no atlas: " + nome, validos)
	var chao: TileMapLayer = vila.get_node("Terrains/Terreno")
	verificar("chao cobre toda a vila e as margens", chao.get_used_rect() == Rect2i(-2, -2, 48, 40))
	var fonte := chao.tile_set.get_source(0) as TileSetAtlasSource
	for estacao in range(4):
		vila.get_node("Terrains/Estacoes").definir_estacao(estacao, true)
		var imagem := fonte.texture.get_image()
		var opacos := true
		for y in range(16, 96):
			for x in range(16):
				opacos = opacos and imagem.get_pixel(x, y).a > 0.99
		verificar("grama visivel na estacao " + str(estacao), opacos)
	vila.get_node("Terrains/Estacoes").definir_estacao(calendario.estacao(), true)

func carregar_cena(caminho: String, hora := 12.0) -> Node:
	if current_scene != null:
		current_scene.queue_free()
		await quadros()
	transicao.hora_salva = hora
	var cena: Node = load(caminho).instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros(8)
	cena.get_node("Iluminacao").set_process(false)
	return cena

func trocar(caminho: String, ponto: String) -> void:
	transicao.ir_para(caminho, ponto)
	var limite := Time.get_ticks_msec() + 8000
	while transicao.ocupada and Time.get_ticks_msec() < limite:
		await process_frame
	verificar("transicao concluiu: " + caminho, not transicao.ocupada and current_scene.scene_file_path == caminho)
	current_scene.get_node("Iluminacao").set_process(false)

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute em copia de testes com saves isolados.")
		quit(1)
		return
	await process_frame
	dados = load("res://codigo/cidade/dados_cidade.gd")
	cidade = root.get_node("Cidade")
	progresso = root.get_node("Progresso")
	calendario = root.get_node("Calendario")
	fazenda = root.get_node("Fazenda")
	inventario = root.get_node("InventarioJogador")
	transicao = root.get_node("Transicao")
	for no in [cidade, progresso, calendario, fazenda]:
		no.caminho_save = "user://teste_cidade_%s.json" % no.name
		no.apagar()
	inventario.limpar()
	inventario.criar_itens_iniciais()
	transicao.limpar()
	verificar("agenda muda por horario", dados.agenda("mercador", 9, 0)["local"] == "venda" and dados.agenda("mercador", 18, 0)["local"] == "cidade")
	verificar("inverno leva encontros para a pousada", dados.agenda("bardo", 12, 3)["local"] == "pousada")
	verificar("madrugada leva moradores para casa", dados.agenda("bento", 1, 0)["local"] == "casa_bento")
	var vila := await carregar_cena("res://cenas/cidade.tscn")
	verificar("vila tem seis moradores", vila.moradores.size() == 6)
	for id in vila.moradores:
		var morador: Node = vila.moradores[id]
		var geometria: Dictionary = dados.geometria_sprite(id)
		var folha: Image = morador.sprite.texture.get_image()
		var altura := folha.get_region(Rect2i(0, 0, 64, 64)).get_used_rect().size.y
		verificar("altura do NPC acompanha o jogador: " + id, altura == int(geometria["altura_parado"]) and is_equal_approx(morador.sprite.scale.y, float(geometria["escala_mapa"])))
		var pes: float = morador.sprite.position.y + (float(geometria["pes_y"]) - 32) * morador.sprite.scale.y
		verificar("escala mantem pes na colisao: " + id, absf(pes - morador.get_node("CollisionShape2D").position.y) < 0.01)
	verificar("nenhuma onda na cidade", get_nodes_in_group("gerenciador_ondas").is_empty())
	verificar("camera respeita os limites da vila", vila.get_node("Jogador").camera.limit_right == 704)
	verificar_terreno(vila)
	var jogador_fisica: CharacterBody2D = vila.get_node("Jogador")
	jogador_fisica.collision_mask = 64
	for forma: CollisionShape2D in vila.get_node("Decoracao/Obstaculos").get_children():
		if forma.disabled:
			continue
		verificar("decoração bloqueia o corpo na base: " + forma.name, jogador_fisica.test_move(Transform2D(0, forma.global_position + Vector2(0, 30)), Vector2(0, -40)))
	var ponte: Vector2 = dados.ponto("ponte")
	verificar("ponte permite atravessar rio", not jogador_fisica.test_move(Transform2D(0, ponte - Vector2(24, 0)), Vector2(32, 0)))
	verificar("rio bloqueia fora da ponte", jogador_fisica.test_move(Transform2D(0, Vector2(636, 400)), Vector2(48, 0)))
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = jogador_fisica.get_node("CollisionShape2D").shape
	consulta.collision_mask = 64
	for predio in dados.PREDIOS:
		consulta.transform = Transform2D(0, vila.get_node("Chegada_" + predio).global_position + Vector2(0, 9))
		verificar("chegada livre de objetos e paredes: " + predio, vila.get_world_2d().direct_space_state.intersect_shape(consulta).is_empty())
	jogador_fisica.collision_mask = 96
	verificar("servicos conquistados continuam bloqueados inicialmente", not progresso.tem_morador("mistica"))
	verificar("moradores ja vivem na vila sem contratar o bonus", vila.moradores["bardo"].visible)
	var npc: Node = vila.moradores["bento"]
	var antes: Vector2 = npc.position
	npc._ir_ate(antes + Vector2(0, 40))
	vila.get_node("Jogador").position = Vector2(64, 360)
	await create_timer(0.5).timeout
	verificar("morador percorre a rota e anima", npc.position.distance_to(antes) > 4 and npc.sprite.frame < 16)
	var rota: PackedVector2Array = vila.caminho_entre(dados.ponto("mercador_abertura"), dados.ponto("estela_flores"))
	verificar("rota entre bairros contorna obstaculos", rota.size() > 8)
	var base_venda: Vector2 = dados.PREDIOS["venda"]["base"]
	var rota_parede: PackedVector2Array = vila.caminho_entre(dados.ponto("mercador_abertura"), base_venda - Vector2(0, 16))
	verificar("destino bloqueado termina fora da parede", not rota_parede.is_empty() and not vila.navegacao.is_point_solid(Vector2i(rota_parede[-1] / vila.navegacao.cell_size)))
	var interface: Node = vila.get_node("Interface")
	cidade.conversar("bento")
	await quadros()
	verificar("conversa abre e trava as acoes", interface._telas_abertas.has("conversa_cidade") and not vila.get_node("Jogador").movimento_habilitado)
	verificar("porta nao troca mapa durante conversa", not vila.get_node("Porta_venda").pode_interagir())
	verificar("so interlocutor registra a conversa aberta", vila.moradores["bento"].interacao._tela_aberta and not vila.moradores["lia"].interacao._tela_aberta)
	vila.moradores["lia"].interacao._ao_corpo_saiu(vila.get_node("Jogador"))
	verificar("outro morador sair da zona nao fecha conversa", interface._telas_abertas.has("conversa_cidade"))
	interface._fechar_tela("conversa_cidade")
	cidade.conversar("bento")
	interface._fechar_tela("conversa_cidade")
	verificar("amizade de conversa so cresce uma vez por dia", cidade.amizade["bento"] == 1)
	verificar("fechar conversa libera o jogador", vila.get_node("Jogador").movimento_habilitado)
	interface._abrir_tela("mural_cidade")
	await quadros()
	var pedidos: Array = dados.MISSOES.keys().filter(func(id): return dados.missao_na_estacao(id, calendario.estacao()))
	verificar("mural mostra pedidos da estação e agenda", interface._telas["mural_cidade"]._botoes.size() == pedidos.size())
	interface._fechar_tela("mural_cidade")
	# A bigorna conserva os requisitos da arena mesmo estando em outro mapa.
	transicao.estado = {"onda_atual": 8}
	interface._abrir_tela("mercante")
	var loja: Node = interface._telas["mercante"]
	var amostra: Node = load("res://cenas/ui/componentes/item_ui.tscn").instantiate()
	root.add_child(amostra)
	amostra.exibir(inventario.equipados["arma"])
	loja._slot_bigorna.colocar_item(amostra)
	var melhoria: Dictionary = loja._dados_upgrade()
	verificar("bigorna na cidade usa a onda guardada", melhoria.get("onda_atual") == 8 and melhoria.get("onda_ok", false))
	verificar("loja na cidade oferece viagem para arena", loja._botao_iniciar_onda.text == "IR PARA A ARENA")
	interface._fechar_tela("mercante")
	amostra.queue_free()
	transicao.estado = {}
	cidade.aceitar("boas_vindas")
	verificar("nao aceita duas vezes", not cidade.aceitar("boas_vindas"))
	verificar("pedido incompleto nao entrega", not cidade.concluir("boas_vindas", "lia"))
	for id in dados.MORADORES:
		cidade.conversar(id)
		interface._fechar_tela("conversa_cidade")
	var brasas: int = progresso.brasas
	verificar("pedido concluido paga recompensa", cidade.concluir("boas_vindas", "lia") and progresso.brasas == brasas + 10)
	verificar("recompensa nao duplica", not cidade.concluir("boas_vindas", "lia"))
	verificar("amizade cresce ao ajudar", cidade.amizade["lia"] == 3)
	cidade.aceitar("horta")
	fazenda.colheita = {"cenoura": 3, "tomate": 4}
	calendario.dia = 31
	verificar("pedido guarda estacao em que foi aceito", cidade.progresso_missao("horta").x == 3)
	verificar("so entrega ao morador certo", not cidade.concluir("horta", "lia"))
	verificar("entrega desconta colheita correta", cidade.concluir("horta", "bento") and fazenda.quantidade_colhida("cenoura") == 0 and fazenda.quantidade_colhida("tomate") == 4)
	verificar("Bento nao oferece sementes", dados.MORADORES["bento"]["servico"] == "")
	cidade.aceitar("cancao")
	for i in 3:
		cidade.registrar_onda(i + 1)
	verificar("missoes contam ondas depois do aceite", cidade.progresso_missao("cancao") == Vector2i(3, 3))
	verificar("pedido da arena entrega", cidade.concluir("cancao", "bardo"))
	cidade.salvar()
	cidade.missoes = {}
	verificar("save restaura pedidos e amizade", cidade.carregar() and cidade.missoes["cancao"]["estado"] == "concluida" and cidade.amizade["bardo"] == 3)
	# Interiores e portas reais, sem teletransportar por fora da Transicao.
	calendario.dia = 1
	cidade.aceitar("passeio")
	vila.get_node("Iluminacao").definir_hora(12)
	vila.get_node("Jogador").hp_atual = 70
	for id in dados.PREDIOS:
		verificar("porta exterior aponta para o interior: " + id, vila.get_node("Porta_" + id).cena_destino == "res://cenas/cidade/%s.tscn" % id)
		vila.get_node("Iluminacao").definir_hora(12)
		await trocar("res://cenas/cidade/%s.tscn" % id, "entrada")
		var interior: Node = current_scene.get_node("Interior")
		var sala: Node = interior.get_node("Sala")
		verificar("interior tem piso nativo e cômodos: " + id, sala.casa == id and not sala.geometria["areas"].is_empty() and sala.FOLHA is Texture2D)
		verificar("interior tem mobiliário próprio: " + id, interior.get_child_count() >= 9)
		var tamanho := Vector2i(sala.geometria["recorte"][2], sala.geometria["recorte"][3])
		verificar("navegação cobre o interior em grade de 8 pixels: " + id, current_scene.navegacao.cell_size == Vector2(8, 8) and current_scene.navegacao.region.size == tamanho / 8)
		consulta.transform = Transform2D(0, current_scene.get_node("Jogador").global_position + Vector2(0, 9))
		verificar("entrada interior sem colisao: " + id, current_scene.get_world_2d().direct_space_state.intersect_shape(consulta).is_empty())
		verificar("morador alcancavel desde a porta: " + id, not current_scene.caminho_entre(current_scene.get_node("Chegada_entrada").position, Vector2(64, 60)).is_empty())
		var jogador_interior: CharacterBody2D = current_scene.get_node("Jogador")
		jogador_interior.collision_mask = 64
		for forma: CollisionShape2D in current_scene.get_node("Obstaculos").get_children():
			if not forma.name.begins_with("Movel"):
				continue
			var centro := forma.global_position
			var metade := (forma.shape as RectangleShape2D).size * 0.5
			for direcao in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var distancia: float = metade.y if direcao.y != 0 else metade.x
				var de: Vector2 = centro + direcao * (distancia + 10) - Vector2(0, 9)
				verificar("movel bloqueia aproximação " + id + "/" + forma.name + "/" + str(direcao), jogador_interior.test_move(Transform2D(0, de), -direcao * 16))
		jogador_interior.collision_mask = 96
		verificar("interior preserva vida e hora: " + id, current_scene.get_node("Jogador").hp_atual == 70 and absf(current_scene.hora_atual() - 12) < 0.1)
		verificar("saida retorna ao predio correto: " + id, current_scene.get_node("Saida").ponto_chegada == id)
		current_scene.get_node("Saida").abrir_tela()
		while transicao.ocupada:
			await process_frame
		vila = current_scene
		vila.get_node("Iluminacao").set_process(false)
		verificar("retorno coloca jogador na porta: " + id, vila.get_node("Jogador").position.distance_to(vila.get_node("Chegada_" + id).position) < 2)
	verificar("pedido de visitas conclui", cidade.concluir("passeio", "lia"))
	calendario.dia = 91
	vila.get_node("Iluminacao").definir_hora(12)
	var pousada := await carregar_cena("res://cenas/cidade/pousada.tscn")
	verificar("inverno moradores se encontram dentro da pousada", pousada.moradores.values().filter(func(n): return n.visible).size() == 4)
	transicao.dormir("cama")
	while transicao.ocupada:
		await process_frame
	verificar("pousada permite dormir e avancar o dia", calendario.dia == 23 and absf(pousada.hora_atual() - 6) < 0.1)
	verificar("acorda dentro da pousada com vida cheia", pousada.get_node("Jogador").hp_atual == pousada.get_node("Jogador").estatisticas.hp_maximo)
	verificar("acorda ao lado da cama", pousada.get_node("Jogador").position.distance_to(pousada.get_node("Chegada_cama").position) < 2)
	var arena := await carregar_cena("res://cenas/cenario.tscn")
	verificar("NPCs sairam da arena", arena.get_node_or_null("Merchant") == null and arena.get_node_or_null("Mistica") == null and get_nodes_in_group("moradores_cidade").is_empty())
	verificar("arena aponta para cidade", arena.get_node("Terrains/PassagemCaverna").cena_destino == "res://cenas/cidade.tscn")
	var gerenciador: Node = arena.get_node("enemySpawner/GerenciadorOndas")
	verificar("mural de desafio substitui inicio pelo mercador", arena.get_node("InicioOndas").nome_tela == "desafio_arena")
	arena.get_node("Interface")._abrir_tela("desafio_arena")
	verificar("desafio oferece inicio de combate", arena.get_node("Interface")._telas["desafio_arena"]._botoes.size() == 1)
	arena.get_node("Interface")._fechar_tela("desafio_arena")
	gerenciador.onda_atual = 3
	progresso.abates = 4
	await trocar("res://cenas/cidade.tscn", "arena")
	verificar("cidade preserva partida e onda", progresso.abates == 4 and transicao.estado["onda_atual"] == 3)
	await trocar("res://cenas/cenario.tscn", "caverna")
	verificar("volta a arena conserva onda e abates", current_scene.get_node("enemySpawner/GerenciadorOndas").onda_atual == 3 and progresso.abates == 4)
	current_scene.get_node("Interface")._abrir_tela("desafio_arena")
	current_scene.get_node("Interface")._telas["desafio_arena"]._iniciar_desafio()
	await quadros()
	verificar("botao do mural inicia a onda e fecha a passagem", current_scene.get_node("enemySpawner/GerenciadorOndas").onda_em_andamento and not current_scene.get_node("Terrains/PassagemCaverna").pode_interagir())
	current_scene.queue_free()
	await quadros()
	for no in [cidade, progresso, calendario, fazenda]:
		no.apagar()
	print("FALHAS: ", falhas)
	quit(falhas)
