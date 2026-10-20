extends SceneTree

## Falas, turnos e passeios reais. Executar em projeto com saves isolados.
var Papos: GDScript
var Dados: GDScript
var falhas := 0

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

func contexto(clima := 0, vencida := 0, chefe := 0) -> Dictionary:
	return {"clima": clima, "estacao": 0, "vencida": vencida, "chefe": chefe, "nome_chefe": Papos.Conversa.chefe_da_onda(chefe)}

func visiveis(vila: Node) -> int:
	var total := 0
	for npc in vila.moradores.values():
		total += int(npc._balao.is_visible_in_tree())
	return total

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	Papos = load("res://codigo/cidade/papos_vizinhos.gd")
	Dados = load("res://codigo/cidade/dados_cidade.gd")
	root.get_node("Saves").trocar("solo")
	var validos := true
	var pares := 0
	# O Nilo tem rotina própria e não participa dos encontros espontâneos da vila.
	for a in Dados.CAMAS:
		for b in Dados.CAMAS:
			if a >= b:
				continue
			pares += 1
			for clima in 7:
				for progresso in [[0, 0], [3, 0], [9, 0], [20, 20]]:
					var falas: Array[Dictionary] = Papos.montar(a, b, contexto(clima, progresso[0], progresso[1]))
					validos = validos and falas.size() >= 8 and falas.size() <= 12
					for i in falas.size():
						validos = validos and falas[i]["dono"] in [a, b] and not falas[i]["texto"].contains("{")
						validos = validos and Papos.duracao(falas[i]["texto"]) >= 3.5
						if i > 0:
							validos = validos and falas[i]["dono"] != falas[i - 1]["dono"]
	verificar("todas as duplas, sete climas e quatro niveis de progresso geram conversas completas", validos and pares == Dados.CAMAS.size() * (Dados.CAMAS.size() - 1) / 2)
	var chuva := str(Papos.montar("mercador", "bardo", contexto(4)))
	verificar("temporal usa falas de abrigo, sem inventar calor", chuva.contains("trovoes") and not chuva.contains("ceu aberto"))
	var arena := str(Papos.montar("bento", "lia", contexto(0, 20, 20)))
	verificar("arena cita andar concluido e chefe reais", arena.contains("andar concluido ja e o 20") and arena.contains("MEDUSA"))
	verificar("iniciante nao recebe vitoria inventada", str(Papos.montar("bento", "lia", contexto())).to_lower().contains("ainda nao tivemos noticia") )
	verificar("reencontros variam o assunto", Papos.montar("lia", "bento", contexto(), 0) != Papos.montar("lia", "bento", contexto(), 1))
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(20)
	var vila := current_scene
	vila.set_process(false)
	var calendario: Node = root.get_node("Calendario")
	calendario.dia = 2
	var luz: Node = vila.get_node("Iluminacao")
	luz.definir_hora(19.0)
	luz.set_process(false)
	var clima: Node = vila.get_node("Terrains/Estacoes/Meteorologia")
	clima.definir_clima(0, true)
	for npc in vila.moradores.values():
		npc.atualizar_rotina(true)
		npc._espera_balao = 999
	verificar("Bento nao oferece servico de sementes", Dados.MORADORES["bento"]["servico"] == "")
	for id in vila.moradores:
		if id not in ["mercador", "curandeira"]:
			vila.moradores[id].visible = false
	var a: Node = vila.moradores["mercador"]
	var b: Node = vila.moradores["curandeira"]
	a.position = Vector2(344, 304)
	b.position = Vector2(368, 304)
	a.caminho.clear()
	b.caminho.clear()
	vila.get_node("Jogador").position = Vector2(300, 350)
	a.dizer("Primeira fala antiga")
	b.dizer("Segunda fala antiga")
	verificar("falas soltas lado a lado nao se sobrepoem", visiveis(vila) == 1 and b._balao.visible)
	a.calar()
	b.calar()
	a.caminho = PackedVector2Array([Vector2(384, 304)])
	b.caminho = PackedVector2Array([Vector2(408, 304)])
	verificar("vizinhos podem se encontrar durante a caminhada", a.livre_para_papo() and b.livre_para_papo())
	vila._proximo_papo = 0
	seed(17)
	for tentativa in 30:
		vila._tentar_papo_entre_vizinhos()
		if not vila._participantes.is_empty():
			break
	verificar("proximidade inicia encontro sem chamada direta", vila._participantes.size() == 2)
	var passos: int = vila._falas_papo.size()
	var posicao_a: Vector2 = a.position
	var posicao_b: Vector2 = b.position
	await quadros()
	verificar("encontro mantem os dois parados", a.position == posicao_a and b.position == posicao_b)
	var turnos_ok := passos >= 8
	for i in passos:
		turnos_ok = turnos_ok and visiveis(vila) == 1
		vila._tempo_fala = 0
		vila._atualizar_papo(0)
		await quadros(1)
	verificar("uma unica fala visivel em todos os turnos", turnos_ok)
	verificar("trajeto continua depois do encontro", not a.caminho.is_empty() and not b.caminho.is_empty())
	verificar("despedida libera ambos e apaga baloes", vila._participantes.is_empty() and a.parceiro_papo == null and b.parceiro_papo == null and visiveis(vila) == 0)
	vila._papo(a, b)
	clima.definir_clima(1, true)
	vila._atualizar_papo(0)
	verificar("mudanca do clima interrompe assunto desatualizado", vila._participantes.is_empty())
	vila._papo(a, b)
	b.interacao._tela_aberta = true
	vila._atualizar_papo(0)
	verificar("interagir com NPC interrompe encontro", vila._participantes.is_empty())
	b.interacao._tela_aberta = false
	vila._papo(a, b)
	luz.definir_hora(22.0)
	a.atualizar_rotina()
	verificar("mudanca de compromisso interrompe conversa", vila._participantes.is_empty())
	luz.definir_hora(19.0)
	a.atualizar_rotina()
	a._saindo = false
	a.caminho.clear()
	# O passeio usa rotas navegaveis, memoria de destinos e o rng proprio do morador.
	a.passeio.rng.seed = 12345
	var destinos: Array[String] = []
	var pausas_ok := true
	var velocidades: Array[float] = []
	for i in 10:
		a.caminho.clear()
		a.passeio.espera = 0
		a.passeio.atualizar(a, 0.1)
		if not a.caminho.is_empty():
			destinos.append(a.passeio.atual)
			velocidades.append(a.passeio.velocidade)
			a.position = a.caminho[-1]
			a.caminho.clear()
			a.passeio.atualizar(a, 0.1)
			pausas_ok = pausas_ok and a.passeio.espera > 10.0
	var variados := destinos.size() == 10
	for i in destinos.size():
		for j in range(maxi(0, i - 3), i):
			variados = variados and destinos[i] != destinos[j]
	verificar("dez passeios sem repetir os tres ultimos destinos", variados)
	verificar("paradas para afazeres em vez de andar sem pausa", pausas_ok)
	verificar("ritmo de caminhada varia entre trajetos", velocidades.size() > 1 and velocidades.min() < velocidades.max())
	var alvo_anterior: Vector2 = a._alvo
	a.atualizar_rotina()
	verificar("atualizacao da agenda nao apaga o afazer escolhido", a._alvo == alvo_anterior)
	luz.definir_hora(10.0)
	a.atualizar_rotina()
	verificar("horario comercial encerra passeio", not a.agenda.get("livre", false) and a.agenda["local"] == "venda")
	luz.definir_hora(23.0)
	a.atualizar_rotina()
	verificar("hora de dormir preservada", a.agenda.get("dormindo", false))
	# Captura o encontro em vez de todos os baloes da vila ao mesmo tempo.
	luz.definir_hora(19.0)
	for npc in [a, b]:
		npc.atualizar_rotina(true)
		npc.caminho.clear()
		npc._saindo = false
	a.position = Vector2(344, 304)
	b.position = Vector2(368, 304)
	vila._papo(a, b)
	await quadros(20)
	var baloes_legiveis := visiveis(vila) == 1
	for npc in [a, b]:
		if npc._balao.visible:
			baloes_legiveis = baloes_legiveis and npc._balao.size.x > 0 and npc._balao.size.x <= 144.0 and npc._balao.size.y < 100.0
	verificar("encontro real mantem uma fala legivel apos varios quadros", baloes_legiveis)
	if "--capturar" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-papo-vizinhos.png")
	vila._encerrar_papo()
	change_scene_to_file("res://cenas/casa.tscn")
	await quadros(20)
	var jogador: Node = current_scene.get_node("Jogador")
	var cama: Node = get_first_node_in_group("cama")
	cama.deitar(jogador)
	await quadros()
	var cabeca: Sprite2D = cama.get_node("Cabeca/sprite_corpo")
	var celula: Vector2 = jogador.sprite_corpo.texture.get_size() / Vector2(jogador.sprite_corpo.hframes, jogador.sprite_corpo.vframes)
	verificar("recorte da cabeca acompanha resolucao refinada", cabeca.region_rect.size.is_equal_approx(cama.RECORTE_CABECA.size * celula / 64.0))
	verificar("cabeca mantem tamanho fisico ao dormir", (cabeca.region_rect.size * cabeca.scale).is_equal_approx(cama.RECORTE_CABECA.size))
	var imagem := cabeca.texture.get_image().get_region(cabeca.region_rect)
	var opacos := 0
	for y in imagem.get_height():
		for x in imagem.get_width():
			opacos += int(imagem.get_pixel(x, y).a > 0.5)
	verificar("recorte contem pixels do rosto", opacos > 50)
	if "--capturar" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-sono-corrigido.png")
	cama.levantar()
	await quadros()
	verificar("acordar restaura personagem e remove cabeca", jogador.visible and cama.get_node_or_null("Cabeca") == null)
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
