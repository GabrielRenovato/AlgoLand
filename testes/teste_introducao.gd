extends SceneTree

## Percorre o prólogo real com saves isolados e física do jogador ativa.
var falhas := 0
var intro: Node
var ultima_etapa := -1
var visitas: Dictionary = {}
var ondas_abatidas := false
var andou_cidade := false
var andou_fazenda := false
var equipou := false
var roteiro_automatico := true
var praticar_liberado := false
var praticas_vistas := {}
var reacoes_vistas := {}
var direcoes_vistas := {}
var arvore_alternativa := {}
var pedra_alternativa := {}
var solo_alternativo := Vector2i(-1, -1)
var erros_dialogo := {}
var dialogos_vistos := 0
var passos_seguidos := 0
var fora_da_rua := false

func _initialize() -> void:
	rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 6) -> void:
	for i in n:
		await process_frame

func esperar(condicao: Callable, limite := 3000) -> bool:
	for i in limite:
		if condicao.call():
			return true
		await process_frame
	return false

func rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco" or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		quit(1)
		return
	await process_frame
	intro = root.get_node("Introducao")
	intro.caminho_save = "user://teste_introducao.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(intro.caminho_save))
	intro.carregar()
	verificar("save anterior sem prólogo continua livre na cidade", not intro.ativa() and intro.cena_continuar().ends_with("cidade.tscn"))
	root.get_node("Progresso").apagar()
	root.get_node("Calendario").apagar()
	root.get_node("Fazenda").apagar()
	root.get_node("Transicao").limpar()
	intro.iniciar()
	verificar("novo jogo começa na queda da arena", intro.etapa == intro.Etapa.QUEDA and intro.cena_continuar().ends_with("cenario.tscn"))
	var inv: Node = root.get_node("InventarioJogador")
	inv.criar_itens_iniciais(true)
	inv.salvar()
	verificar("kit inicial ainda não dá armas nem ferramentas", inv.equipados.arma == null and inv.equipados.escudo == null and inv.itens_de_fazenda().is_empty())
	# Entradas reais do diálogo, inclusive Enter sem foco prévio no botão.
	var dialogo: Control = load("res://codigo/introducao/dialogo_introducao.gd").new()
	root.add_child(dialogo)
	var paginas: Array[String] = ["Primeira pagina", "Segunda pagina", "Terceira pagina", "Quarta pagina"]
	dialogo.iniciar(paginas)
	dialogo.show()
	await quadros()
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_ENTER
	tecla.keycode = KEY_ENTER
	tecla.pressed = true
	dialogo._espera = 0
	# A entrada avança depois que a animação de digitação terminou.
	if dialogo._digitando != null: dialogo._digitando.kill()
	dialogo._texto.visible_ratio = 1.0
	Input.parse_input_event(tecla)
	await quadros()
	verificar("Enter avança o diálogo sem foco de teclado", dialogo._indice == 1)
	tecla.pressed = false
	Input.parse_input_event(tecla)
	var botao := InputEventJoypadButton.new()
	botao.button_index = JOY_BUTTON_A
	botao.pressed = true
	dialogo._espera = 0
	# A entrada avança depois que a animação de digitação terminou.
	if dialogo._digitando != null: dialogo._digitando.kill()
	dialogo._texto.visible_ratio = 1.0
	Input.parse_input_event(botao)
	await quadros()
	verificar("confirmação do controle avança só uma página", dialogo._indice == 2)
	botao.pressed = false
	Input.parse_input_event(botao)
	dialogo._espera = 0
	# A entrada avança depois que a animação de digitação terminou.
	if dialogo._digitando != null: dialogo._digitando.kill()
	dialogo._texto.visible_ratio = 1.0
	dialogo._avancar.pressed.emit()
	verificar("botão de toque avança o diálogo", dialogo._indice == 3)
	verificar("fala preserva o texto da página e título em maiúsculas", not dialogo._texto.text.is_empty() and dialogo._texto.text == dialogo._paginas[dialogo._indice] and dialogo._titulo.text == dialogo._titulo.text.to_upper())
	verificar("fonte do diálogo ampliada", dialogo._texto.get_theme_font_size("font_size") >= 10)
	var encerramento := [false]
	dialogo.concluido.connect(func(): encerramento[0] = true)
	dialogo._fechar_dialogo.pressed.emit()
	verificar("X conclui a fala sem exigir as páginas restantes",encerramento[0] and dialogo._indice == dialogo._paginas.size())
	dialogo.queue_free()
	await quadros()
	process_frame.connect(conduzir)
	Engine.time_scale = 10
	change_scene_to_file(intro.cena_continuar())
	var entrou_na_vila := await esperar(func(): return intro.etapa == intro.Etapa.CAMINHO and is_instance_valid(current_scene.get_node_or_null("SequenciaIntroducao")), 8000)
	verificar("chegou à caminhada na vila", entrou_na_vila)
	if entrou_na_vila:
		await quadros(4)
		var jogador: Node = current_scene.get_node("Jogador")
		verificar("jogador acompanha Bento automaticamente na cidade", jogador.seguindo_introducao and intro.acompanhando)
	praticar_liberado = true
	var terminou := await esperar(func(): return intro.etapa == intro.Etapa.CONCLUIDA, 20000)
	verificar("sequência inteira termina ao descansar na cama", terminou)
	verificar("prólogo deixa a entrada no andar 1",int(root.get_node("Transicao").estado.get("onda_atual",1)) == 1)
	verificar("treino não conclui andar nem bloqueia checkpoint",root.get_node("Progresso").ondas_concluidas == 0 and not root.get_node("Progresso").onda_comecou)
	verificar("equipou espada e escudo antes da luta", equipou)
	verificar("vitória nos slimes acionou o resgate", visitas.has(intro.Etapa.RESGATE))
	verificar("visitou arena, cidade, fazenda e descanso", visitas.has(intro.Etapa.PORTAL) and visitas.has(intro.Etapa.VILA) and visitas.has(intro.Etapa.PASSEIO) and visitas.has(intro.Etapa.DESCANSO))
	verificar("guia acompanhou o jogador até a fazenda",andou_cidade)
	verificar("prólogo entrega ferramentas sem receita",["machadinha","picareta","enxada","regador"].all(func(tipo): return inv.buscar_por_tipo(tipo)!=null))
	verificar("entregou sementes de primavera", inv.quantidade_sementes("cenoura") >= 5 and inv.quantidade_sementes("morango") >= 4)
	verificar("ferramentas gratuitas permitem as seis lições",["cortar","quebrar","arar","plantar","regar","colher"].all(func(id): return intro.tarefas.has(id)))
	verificar("queda tem suspensão, impacto e recuperação", ["CAINDO", "IMPACTO", "RECUPERANDO", "PRONTO"].all(func(id): return reacoes_vistas.has(id)))
	verificar("caminhada atualiza direções do movimento", direcoes_vistas.size() >= 2)
	verificar("conversas param a física e a animação olhando para Bento", dialogos_vistos >= 5 and erros_dialogo.is_empty())
	verificar("jogador recebe o rastro real de Bento", passos_seguidos > 10)
	verificar("trajeto da cidade acompanha ruas de pedra", andou_cidade and not fora_da_rua)
	verificar("primeiro descanso avançou para o dia 2", root.get_node("Calendario").dia == 2)
	# Confere os quadros realmente desenhados nas quatro direções, com a espada equipada.
	roteiro_automatico = false
	var personagem: Node = current_scene.get_node("Jogador")
	var alvo := Marker2D.new()
	alvo.position = Vector2(1000, 1000)
	current_scene.add_child(alvo)
	personagem.alvo_introducao = alvo
	personagem.seguindo_introducao = true
	for direcao in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		personagem.position = Vector2(152, 166)
		personagem.caminho_introducao = PackedVector2Array([personagem.position + direcao * 80])
		personagem._mover_na_introducao(0.016)
		personagem._arvore_animacao.advance(0.25)
		var linha: int = 4 + [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT].find(direcao)
		var quadro: int = personagem.sprite_corpo.frame
		verificar("passos calmos na direção %s" % direcao, quadro / 8 == linha and quadro % 8 < 6)
		verificar("camadas alinhadas na caminhada %s" % direcao, personagem.sprite_cabelo.frame == quadro and personagem.sprite_roupa.frame == quadro)
	personagem.seguindo_introducao = false
	alvo.queue_free()
	# Checkpoint restaura ferramentas e sementes sem repetir presentes ao reabrir o jogo.
	roteiro_automatico = false
	intro.etapa = intro.Etapa.PASSEIO
	intro.parada = 4
	intro.salvar()
	var antes: int = inv.quantidade_sementes("cenoura")
	inv.limpar()
	verificar("checkpoint carrega", intro.carregar())
	verificar("checkpoint mantém parada e inventário", intro.parada == 4 and inv.quantidade_sementes("cenoura") == antes and inv.buscar_por_tipo("regador") != null)
	intro.entregar("semente:cenoura", 6)
	verificar("retomada não duplica sementes recebidas", inv.quantidade_sementes("cenoura") == antes)
	intro.etapa = intro.Etapa.COMBATE
	intro.reiniciar_apos_morte()
	verificar("derrota inicial volta à queda sem bloquear a partida", intro.etapa == intro.Etapa.QUEDA)
	intro.etapa = intro.Etapa.CONCLUIDA
	intro.cinematica = false
	Engine.time_scale = 1
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	current_scene = null
	await quadros()
	print("FALHAS: ", falhas)
	quit(falhas)

func conduzir() -> void:
	if not roteiro_automatico or not is_instance_valid(current_scene):
		return
	if intro.etapa != ultima_etapa:
		ultima_etapa = intro.etapa
		visitas[ultima_etapa] = true
		print("ETAPA ", ultima_etapa, " / ", current_scene.scene_file_path)
	var cena := current_scene
	var jogador := cena.get_node_or_null("Jogador")
	var sequencia := cena.get_node_or_null("SequenciaIntroducao")
	var interface := cena.get_node_or_null("Interface")
	if jogador == null or interface == null or sequencia == null or not is_instance_valid(sequencia.objetivo):
		return
	if sequencia.reacao_queda != "":
		reacoes_vistas[sequencia.reacao_queda] = true
	if intro.acompanhando and jogador.velocity.length() > 2:
		var direcao: Vector2 = jogador._direcao_ataque
		var esperado := 48 if direcao.x > 0 else (56 if direcao.x < 0 else (40 if direcao.y < 0 else 32))
		# A árvore de animação avalia no fim do quadro; amostra só quando o blend já corresponde.
		if jogador._arvore_animacao.get("parameters/run/blend_position") == direcao:
			direcoes_vistas[direcao] = true
	jogador.set_physics_process(true)
	if intro.acompanhando and is_instance_valid(sequencia.guia):
		if not jogador.caminho_introducao.is_empty() and jogador.caminho_introducao[-1].is_equal_approx(sequencia.guia.position):
			passos_seguidos += 1
		if intro.etapa == intro.Etapa.CAMINHO:
			for ponto in [jogador.position, sequencia.guia.position]:
				var pes: Vector2 = ponto + Vector2(0, 9)
				var terreno: TileMapLayer = cena.get_node("Terrains/Terreno")
				var fonte := terreno.get_cell_source_id(terreno.local_to_map(pes))
				if fonte not in [1, 2]:
					fora_da_rua = true
	if intro.cinematica:
		var dialogo: Control = interface._telas.introducao
		if dialogo.visible:
			if is_instance_valid(sequencia.guia):
				dialogos_vistos += 1
				var esperado: Vector2 = jogador._cardinal_de(sequencia.guia.global_position - jogador.global_position)
				var quadro_parado: int = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT].find(esperado) * 8
				if jogador.velocity != Vector2.ZERO or jogador._maquina_estados.get_current_node() != "idle" or jogador._arvore_animacao.get("parameters/idle/blend_position") != esperado or jogador.sprite_corpo.frame != quadro_parado:
					erros_dialogo[intro.etapa] = true
			dialogo.avancar()
		return
	match intro.etapa:
		intro.Etapa.COMBATE:
			var inv: Node = root.get_node("InventarioJogador")
			equipou = inv.equipados.arma != null and inv.equipados.escudo != null and inv.itens_de_fazenda().is_empty()
			var inimigos := get_nodes_in_group("enemy")
			if inimigos.size() >= 3 and not ondas_abatidas:
				ondas_abatidas = true
				verificar("ataque inicial tem exatamente três slimes", inimigos.size() == 3 and inimigos.all(func(no): return no.scene_file_path.ends_with("slime.tscn")))
				var tutorial: Control = get_first_node_in_group("hud").get_node_or_null("MiniTutorial")
				verificar("tutorial de controles original ativo na arena", root.get_node("Controle").usando_toque or (tutorial != null and tutorial.visible))
				verificar("portal bloqueado antes da vitória", not sequencia.portal.get_node("RetornoVila").pode_interagir())
				for inimigo in inimigos:
					inimigo.receber_dano(9999)
		intro.Etapa.PORTAL:
			if not root.get_node("Transicao").ocupada:
				sequencia.portal.get_node("RetornoVila").abrir_tela()
		intro.Etapa.CAMINHO, intro.Etapa.PASSEIO:
			if is_instance_valid(sequencia.guia) and not sequencia.guia.caminho.is_empty():
				if intro.etapa == intro.Etapa.CAMINHO:
					andou_cidade = true
				else:
					andou_fazenda = true
			if praticar_liberado and is_instance_valid(sequencia.tarefa) and sequencia.tarefa.ativa and not jogador.esta_em_acao_fazenda:
				var tarefa: Node = sequencia.tarefa
				praticas_vistas[tarefa.id] = true
				tarefa.equipar()
				jogador._direcao_ataque = Vector2.UP
				var ponto: Vector2 = tarefa.ponto
				if tarefa.id == "cortar":
					if arvore_alternativa.is_empty():
						for candidato in cena.get_node("Terrains/Extracao").recursos:
							if candidato.tipo == "arvore" and candidato.chave != tarefa.recurso.chave and not root.get_node("Fazenda").recurso_removido(candidato.chave):
								arvore_alternativa = candidato
								break
					ponto = cena.get_node("Terrains/Extracao").to_global(arvore_alternativa.pos)
				elif tarefa.id == "quebrar":
					if pedra_alternativa.is_empty():
						for candidato in cena.get_node("Terrains/Extracao").recursos:
							if candidato.tipo == "pedra" and candidato.chave != tarefa.recurso.chave and not root.get_node("Fazenda").recurso_removido(candidato.chave):
								pedra_alternativa = candidato
								break
					ponto = cena.get_node("Terrains/Extracao").to_global(pedra_alternativa.pos)
				elif tarefa.id == "arar":
					if solo_alternativo == Vector2i(-1, -1):
						var plantio: Node = cena.get_node("Terrains/Plantio")
						var fazenda: Node = root.get_node("Fazenda")
						for y in range(22, 35):
							for x in range(7, 37):
								var celula := Vector2i(x, y)
								if celula != tarefa.celula and not fazenda.entulho.has(celula) and not fazenda.esta_arado(celula) and plantio.avaliar_terreno("enxada", celula) == "":
									solo_alternativo = celula
									break
							if solo_alternativo != Vector2i(-1, -1):
								break
					ponto = cena.get_node("Terrains/Plantio").to_global(Vector2(solo_alternativo) * 16 + Vector2(8, 8))
				jogador.global_position += ponto - jogador.ponto_acao_fazenda()
				jogador.acao_fazenda(tarefa.DADOS[tarefa.id].acao)
		intro.Etapa.DESCANSO:
			if root.get_node("Transicao").ocupada:
				return
			if cena.scene_file_path.ends_with("fazenda.tscn"):
				cena.get_node("Terrains/PortaCasa").abrir_tela()
			elif cena.scene_file_path.ends_with("casa.tscn"):
				root.get_node("Transicao").dormir("cama")
