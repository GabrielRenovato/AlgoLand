extends SceneTree

var falhas := 0
var Catalogo: GDScript
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	Catalogo = load("res://codigo/fendas/catalogo_andares.gd")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena = false
	root.get_node("Progresso").iniciar_partida()
	root.get_node("Fazenda").definir_clima_hoje(0)
	var ultima_meta := 0
	var ultima_largura := 0
	for andar in range(1,12):
		var dados: Dictionary = Catalogo.dados(andar)
		verificar("tamanho e meta crescem %d" % andar, int(dados.limites[2]) > ultima_largura and int(dados.combate.meta) > ultima_meta)
		ultima_meta = int(dados.combate.meta)
		ultima_largura = int(dados.limites[2])
		var transicao: Node = root.get_node("Transicao")
		transicao.retornando = true
		transicao.estado = {"onda_atual":andar}
		transicao.iniciar_onda_ao_chegar = false
		change_scene_to_file(Catalogo.cena(andar))
		await quadros(12)
		transicao.retornando = false
		var gerente: Node = current_scene.get_node("enemySpawner/GerenciadorOndas")
		var gerador: Node = current_scene.get_node("enemySpawner")
		var terreno: Node2D = current_scene.get_node("Terrains")
		var jogador: Node2D = current_scene.get_node("Jogador")
		jogador.set_physics_process(false)
		jogador.invulneravel = true
		gerente.iniciar_onda(true)
		await quadros(4)
		gerente.set_physics_process(false)
		for i in gerador._populacao:
			i.set_physics_process(false)
			if i.has_node("PatrulhaAndar"): i.get_node("PatrulhaAndar").set_physics_process(false)
		var comuns := 0
		var elites := 0
		for i in gerador._populacao:
			if i.has_meta("elite_andar"): elites += 1
			else: comuns += 1
		var esperados := 0
		for s in dados.setores: esperados += int(s.grupos)*int(dados.combate.comuns_por_grupo)
		verificar("populacao completa e dois tipos de recompensa %d" % andar, comuns == esperados and elites == int(dados.combate.elites))
		var disponivel: int = comuns*int(dados.combate.pontos_comum)+elites*int(dados.combate.pontos_elite)
		verificar("100 por cento alcancavel com sobra %d" % andar, gerente.META_PROGRESSO == Catalogo.meta(andar) and disponivel > gerente.META_PROGRESSO)
		var mapa := terreno.get_world_2d().navigation_map
		var entrada: Vector2 = terreno.get_node("Chegada_portal").global_position
		var conectadas := true
		for s in terreno.get_node("Setores").get_children():
			for camada in [1,2,4]:
				var rota := NavigationServer2D.map_get_path(mapa,entrada,s.global_position,true,camada)
				if rota.is_empty() or rota[-1].distance_to(s.global_position)>4:
					print("ROTA FALHOU ",andar," ",s.name," camada ",camada)
					conectadas = false
		verificar("todas as camaras conectadas nas tres classes %d" % andar,conectadas)
		var mobs_conectados := true
		for i in gerador._populacao:
			var rota := NavigationServer2D.map_get_path(mapa,entrada,i.global_position,true,1)
			if rota.is_empty() or rota[-1].distance_to(i.global_position)>4: mobs_conectados = false
		verificar("nenhum mob fora do percurso %d" % andar,mobs_conectados)
		var boss: Vector2 = gerador.ponto_guardiao()
		var rota := NavigationServer2D.map_get_path(mapa,entrada,boss,true,1)
		var passagem := true
		var mascara_original: int = jogador.collision_mask
		jogador.collision_mask = 64 # Obstaculos fixos; mobs parados no caminho sao encontros, nao paredes.
		for i in range(1,rota.size()):
			var a := rota[i-1]
			var b := rota[i]
			var passos := maxi(ceili(a.distance_to(b)/8),1)
			for j in passos:
				var inicio := a.lerp(b,float(j)/passos)
				var fim := a.lerp(b,float(j+1)/passos)
				if jogador.test_move(Transform2D(0,inicio),fim-inicio):
					if passagem: print("BLOQUEIO FISICO ",andar," ",inicio," -> ",fim)
					passagem = false
		jogador.collision_mask = mascara_original
		verificar("colisao real do jogador cabe na rota %d" % andar,passagem)
		var estacoes: Node = terreno.get_node("Estacoes")
		var caminhos := {}
		var folhas_decoracao := {}
		var faces_sazonais := {}
		var tons_caverna := {}
		var arvores_gentle := {}
		var marcos: Array[Sprite2D] = []
		var marcos_fora := true
		for objeto in terreno.get_node("Objetos3D").get_children():
			if objeto is Sprite2D and objeto.has_meta("decoracao_fenda"):
				marcos.append(objeto)
				var proximo := NavigationServer2D.map_get_closest_point(mapa,objeto.global_position)
				if not objeto.get_meta("passavel",false) and proximo.distance_to(objeto.global_position)<3: marcos_fora = false
				if objeto.z_as_relative or objeto.offset != Vector2(-32,-60) or objeto.z_index != int(floor(objeto.global_position.y/8))*8: marcos_fora = false
		verificar("marcos com apoio fora das rotas e profundidade correta %d" % andar,not marcos.is_empty() and marcos_fora)
		for indice in 4:
			estacoes.definir_estacao(indice,true)
			var tex: Texture2D = terreno.get_node("Chao").tile_set.get_source(0).texture
			caminhos[tex.resource_path] = true
			if not marcos.is_empty():
				folhas_decoracao[str((marcos[0].texture as AtlasTexture).atlas.resource_path,marcos[0].modulate)] = true
			if terreno.has_node("Pedreira"):
				faces_sazonais[str((terreno.get_node("Pedreira").material as ShaderMaterial).get_shader_parameter("tom"))] = true
			if terreno.has_node("FacesMinerais"):
				faces_sazonais[terreno.get_node("FacesMinerais").texture.resource_path] = true
			if terreno.has_node("GentleForest"):
				var controle_gentle: Node = terreno.get_node("GentleForest")
				if not controle_gentle._atlas.is_empty(): arvores_gentle[controle_gentle._atlas[0].atlas.resource_path] = true
				verificar("brilho Gentle usa tres quadros nativos %d / %d" % [andar,indice],controle_gentle._brilho.get_tile_animation_frames_count(Vector2i.ZERO)==3 and controle_gentle._brilho.texture.resource_path.ends_with("brilho.png"))
			if terreno.has_node("Caverna"):
				tons_caverna[str((terreno.get_node("Caverna").material as ShaderMaterial).get_shader_parameter("tom"))] = true
			if dados.bioma.begins_with("caverna"):
				verificar("caverna sem precipitacao %d / %d" % [andar,indice], estacoes.ambiente_interno and estacoes.meteorologia.clima_atual == 0 and not estacoes._petalas.emitting and not estacoes._folhas.emitting)
		verificar("quatro folhas distintas integradas %d" % andar,caminhos.size() == 4)
		verificar("decoracao troca as quatro variantes %d" % andar,folhas_decoracao.size()==4)
		if terreno.has_node("GentleForest"):
			var paleta: String = "03" if andar==8 else "01" if andar==1 else "02"
			verificar("Gentle paleta correta e arvores nas quatro estacoes %d" % andar,terreno.get_node("GentleForest").get_meta("paleta")==paleta and arvores_gentle.size()==4)

		if dados.bioma == "pedreira":
			verificar("paredes sazonais integradas %d" % andar,faces_sazonais.size()==4)
		if dados.bioma=="ruinas":
			verificar("terreno natural sem piso e muros artificiais %d" % andar,not terreno.has_node("Calcamento") and not terreno.has_node("FacesMinerais") and terreno.get_node("Penhasco").get_used_cells().is_empty())
		if dados.bioma.begins_with("caverna"):
			verificar("caverna em grade nativa e reflexo das quatro estacoes %d" % andar,tons_caverna.size()==4 and terreno.get_node("Caverna").tile_set.tile_size==Vector2i(16,16))
		# Guardiao real, inclusive habilidades, depois da preparacao do terreno.
		var inimigo: Node = gerador.criar_guardiao(boss,gerente._geracao)
		verificar("guardiao corresponde a planta %d" % andar,inimigo.scene_file_path == Catalogo.chefe(andar).cena.resource_path and inimigo.eh_chefe)
		inimigo.queue_free()
		gerente.parar_ondas()
		await quadros(3)
	# Troca real pelo botao de continuar: preserva vida/ouro e carrega outro terreno.
	var transicao: Node = root.get_node("Transicao")
	transicao.estado = {"onda_atual":1}
	transicao.retornando = true
	change_scene_to_file(Catalogo.cena(1))
	await quadros(12)
	transicao.retornando = false
	var gerente: Node = current_scene.get_node("enemySpawner/GerenciadorOndas")
	var jogador: Node = current_scene.get_node("Jogador")
	jogador.hp_atual = 77
	root.get_node("DadosJogo").moedas = 123
	gerente.onda_atual = 2
	gerente.iniciar_onda()
	await transicao.troca_concluida
	await create_timer(1.5).timeout
	verificar("avancar carrega o segundo terreno de verdade",current_scene.scene_file_path == Catalogo.cena(2) and current_scene.get_meta("planta_andar") == 2)
	verificar("viagem preserva vida ouro e contador",current_scene.get_node("Jogador").hp_atual == 77 and root.get_node("DadosJogo").moedas == 123 and current_scene.get_node("enemySpawner/GerenciadorOndas").onda_atual == 2)
	var progresso: Node = root.get_node("Progresso")
	var abates_antes: int = progresso.abates
	var vitorias_antes: int = progresso.ondas_concluidas
	var painel: Node = root.get_node("PainelDebug")
	verificar("F3 oferece proximo andar", painel._opcoes.has("ANDARES") and painel._opcoes["ANDARES"][0][0]=="PROXIMO ANDAR")
	painel._ao_proximo_andar()
	painel._ao_proximo_andar()
	await transicao.troca_concluida
	await create_timer(1.5).timeout
	verificar("F3 carrega a mina e ignora clique duplicado",current_scene.scene_file_path==Catalogo.cena(3) and current_scene.get_node("Terrains").has_node("Caverna") and current_scene.get_node("enemySpawner/GerenciadorOndas").onda_atual==3)
	verificar("pular andar preserva vida ouro e nao premia",current_scene.get_node("Jogador").hp_atual==77 and root.get_node("DadosJogo").moedas==123 and progresso.abates==abates_antes and progresso.ondas_concluidas==vitorias_antes)
	current_scene.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	verificar("circuito depois do onze usa os dez mapas avancados",Catalogo.indice(12)==2 and Catalogo.indice(21)==11 and Catalogo.indice(22)==2)
	current_scene.queue_free()
	await quadros()
	print("Jornada fendas: %d falhas" % falhas)
	quit(1 if falhas else 0)
