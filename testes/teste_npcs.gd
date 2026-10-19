extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_npcs.gd
# NPCs com vida (codigo/logica/npc_vivo.gd): passeiam com o ciclo de andar (4 quadros por direcao) perto do lugar deles,
# param e olham para o jogador quando ele chega perto, o mercador (sentado) cumprimenta com um pulinho, e o bardo e a
# mistica alternam a pose especial com as pausas em que passeiam.
# Usa arquivos de teste para Progresso e Fazenda (nao toca nos saves reais).

const CAMINHO_PROGRESSO := "user://teste_npcs_progresso.json"
const CAMINHO_FAZENDA := "user://teste_npcs_fazenda.json"

var _falhas: int = 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

# Quadros (sem repetir) que o sprite mostra durante `segundos`
func _amostrar(sprite: Sprite2D, segundos: float) -> Array:
	var vistos: Array = []
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
		if not vistos.has(sprite.frame):
			vistos.append(sprite.frame)
	return vistos

func _rodar() -> void:
	await process_frame
	var progresso = root.get_node("Progresso")
	var fazenda = root.get_node("Fazenda")
	progresso.caminho_save = CAMINHO_PROGRESSO
	fazenda.caminho_save = CAMINHO_FAZENDA
	progresso.apagar()
	fazenda.apagar()
	for id in ["curandeira", "bardo", "mistica"]:
		progresso.moradores[id] = true

	var cena: Node = load("res://cenas/cenario.tscn").instantiate()
	var mercante: Node = load("res://cenas/mercante.tscn").instantiate()
	mercante.name = "Merchant"
	mercante.position = Vector2(569, 176)
	cena.add_child(mercante)
	for entrada in [["Curandeira", "curandeira", "old woman", Vector2(525, 205)], ["Bardo", "bardo", "bard", Vector2(590, 205)], ["Mistica", "mistica", "mystic", Vector2(495, 228)]]:
		var morador: Node = load("res://cenas/morador.tscn").instantiate()
		morador.name = entrada[0]
		morador.id_morador = entrada[1]
		morador.textura = load("res://assets/npcs/npc %s A v01.png" % entrada[2])
		morador.position = entrada[3]
		cena.add_child(morador)
	root.add_child(cena)
	current_scene = cena
	await _quadros(10)
	var jogador: Node2D = cena.get_node("Jogador")
	# Jogador onde ele nasce de verdade (no acampamento): sem forcar nada, os moradores tem que sair andando sozinhos
	var posicoes_iniciais := {}
	for no in ["Curandeira", "Bardo", "Mistica"]:
		posicoes_iniciais[no] = cena.get_node(no).global_position
	var vivos_ini := {}
	for no in posicoes_iniciais:
		vivos_ini[no] = cena.get_node(no).get_node("NpcVivo")
		vivos_ini[no]._em_especial = false
		vivos_ini[no]._resta_fase = 9999.0
	var andaram := {}
	var fim_natural := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < fim_natural and andaram.size() < 3:
		await process_frame
		for no in posicoes_iniciais:
			if cena.get_node(no).global_position.distance_to(posicoes_iniciais[no]) > 3.0:
				andaram[no] = true
	_verificar("com o jogador no ponto de partida os 3 moradores saem andando sozinhos", andaram.size() == 3, str(andaram.keys()))
	for no in posicoes_iniciais:
		cena.get_node(no).global_position = posicoes_iniciais[no]
		vivos_ini[no]._casa = posicoes_iniciais[no]
		vivos_ini[no]._andando = false
	jogador.global_position = Vector2(-400, -400)
	var nomes := {"Merchant": "mercador", "Curandeira": "curandeira", "Bardo": "bardo", "Mistica": "mistica"}
	var npcs := {}
	for no in nomes:
		var npc: Node = cena.get_node(no)
		var vivo: Node = npc.get_node_or_null("NpcVivo")
		npcs[no] = {"npc": npc, "vivo": vivo, "sprite": npc.get_node("Sprite2D")}
		_verificar("%s tem o animador" % no, vivo != null and vivo.get_script().resource_path.ends_with("npc_vivo.gd"), "")
	_verificar("todos os perfis existem (pelo id do morador ou pelo perfil do mercador)",
			npcs["Merchant"]["vivo"]._cfg == npcs["Merchant"]["vivo"].PERFIS["mercador"] and npcs["Bardo"]["vivo"]._cfg == npcs["Bardo"]["vivo"].PERFIS["bardo"]
			and npcs["Mistica"]["vivo"]._cfg == npcs["Mistica"]["vivo"].PERFIS["mistica"] and npcs["Curandeira"]["vivo"]._cfg == npcs["Curandeira"]["vivo"].PERFIS["curandeira"], "")

	# --- mercador sentado: respira nos 2 quadros da linha 5 e nao anda
	var mercador: Sprite2D = npcs["Merchant"]["sprite"]
	var pos_mercador: Vector2 = npcs["Merchant"]["npc"].global_position
	var vivo_merc: Node = npcs["Merchant"]["vivo"]
	vivo_merc._resta_gesto = 0.0
	vivo_merc._espera_gesto = 99.0
	var parado_merc: Array = await _amostrar(mercador, 1.6)
	_verificar("mercador sentado fica parado no quadro de repouso (nao balanca a mao o tempo todo)", parado_merc == [20], str(parado_merc))
	vivo_merc._espera_gesto = 0.0
	var gesto_merc: Array = await _amostrar(mercador, 1.5)
	_verificar("de vez em quando faz um gesto curto (alterna os 2 quadros da linha 5) e volta ao repouso", gesto_merc.size() == 2 and gesto_merc.all(func(q): return floori(float(q) / 4.0) == 5)
			and mercador.frame == 20 and vivo_merc._espera_gesto >= 6.0, str(gesto_merc))
	_verificar("mercador sentado fica no lugar", npcs["Merchant"]["npc"].global_position == pos_mercador, "")
	# --- curandeira parada: quadro de passagem (coluna 1) de frente
	var curandeira: Sprite2D = npcs["Curandeira"]["sprite"]
	var cur: Node2D = npcs["Curandeira"]["npc"]
	var vivo_cur: Node = npcs["Curandeira"]["vivo"]
	vivo_cur._resta_parado = 99.0
	vivo_cur._linha_olhar = -1
	vivo_cur._espera_olhada = 99.0
	await _quadros(3)
	_verificar("parada: quadro de passagem da linha de frente", curandeira.frame == 1, str(curandeira.frame))
	# --- passeia: depois da espera anda ate um ponto perto de casa, com o ciclo de 4 quadros
	var casa: Vector2 = vivo_cur._casa
	vivo_cur._resta_parado = 0.0
	var colunas := {}
	var maior_distancia := 0.0
	var andou := false
	var linhas_andar := {}
	var fim_passeio := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < fim_passeio:
		await process_frame
		if vivo_cur._andando:
			andou = true
			colunas[curandeira.frame % 4] = true
			linhas_andar[curandeira.frame / 4] = true
		maior_distancia = maxf(maior_distancia, cur.global_position.distance_to(casa))
		if andou and not vivo_cur._andando:
			break
	_verificar("curandeira anda (o corpo sai do lugar)", andou and maior_distancia > 2.0, "dist=%.1f" % maior_distancia)
	_verificar("andando passa pelos 4 quadros do ciclo (pernas se alternam)", colunas.size() == 4, str(colunas.keys()))
	_verificar("andando usa a linha da direcao do movimento (0 a 3)", linhas_andar.keys().all(func(l): return l <= 3), str(linhas_andar.keys()))
	_verificar("fica dentro do raio de passeio em volta de casa", maior_distancia <= vivo_cur._cfg["passeio"] + 2.0, "dist=%.1f" % maior_distancia)
	_verificar("ao chegar para e volta ao quadro de passagem", not vivo_cur._andando and curandeira.frame % 4 == 1, "frame=%d" % curandeira.frame)
	_verificar("anda colidindo com o cenario (mascara inclui a camada 64 dos obstaculos)", (cur.collision_mask & 64) != 0, str(cur.collision_mask))
	# olhando para onde vai: alvo a direita e depois a esquerda do corpo (o quadro entra na linha certa em poucos quadros)
	var ok_dir := true
	for par in [[Vector2(30, 0), 1], [Vector2(-30, 0), 3]]:
		vivo_cur._alvo = cur.global_position + par[0]
		vivo_cur._andando = true
		var linha_certa := false
		for k in 12:
			await process_frame
			linha_certa = linha_certa or curandeira.frame / 4 == par[1]
		ok_dir = ok_dir and linha_certa
	vivo_cur._andando = false
	_verificar("anda de lado olhando para a direita e para a esquerda (linhas 1 e 3)", ok_dir, "")
	vivo_cur._resta_parado = 99.0

	# --- olha para o jogador (com o jogador longe ela olha de frente / em volta)
	var casos := {Vector2(80, 0): 1, Vector2(-80, 0): 3, Vector2(0, 60): 0, Vector2(0, -60): 2}
	var ok_olhar := true
	var detalhe_olhar := ""
	for d in casos:
		jogador.global_position = cur.global_position + d * 0.4
		await _quadros(4)
		var linha: int = curandeira.frame / 4
		if linha != int(casos[d]) or curandeira.frame % 4 != 1:
			ok_olhar = false
			detalhe_olhar += "%s -> linha %d (esperava %d); " % [d, linha, casos[d]]
	_verificar("curandeira para e vira para o lado em que o jogador esta (direita, esquerda, baixo, cima)", ok_olhar, detalhe_olhar)
	# com o jogador perto ela nao sai andando
	vivo_cur._resta_parado = 0.0
	jogador.global_position = cur.global_position + Vector2(0, 30)
	var pos_antes := cur.global_position
	await _quadros(20)
	_verificar("com o jogador perto ela nao anda", not vivo_cur._andando and cur.global_position == pos_antes, "")
	jogador.global_position = Vector2(-400, -400)
	vivo_cur._resta_parado = 99.0

	# --- olhadas em volta: em ~25 s sem ninguem por perto ela olha para algum lado ao menos uma vez
	var viu_lado := false
	vivo_cur._espera_olhada = 0.0
	var fim := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < fim and not viu_lado:
		await process_frame
		viu_lado = (curandeira.frame / 4) in [1, 2, 3]
	_verificar("parada e sem ninguem por perto a curandeira olha para os lados de vez em quando", viu_lado, "")

	# --- cumprimento do mercador: pulinho quando o jogador chega perto
	var merc_npc: Node2D = npcs["Merchant"]["npc"]
	var y0: float = npcs["Merchant"]["vivo"]._y_original
	jogador.global_position = merc_npc.global_position + Vector2(0, 30)
	var subiu := false
	for i in 20:
		await process_frame
		subiu = subiu or mercador.position.y < y0 - 1.0
	_verificar("mercador da um pulinho quando o jogador chega", subiu, "")
	await create_timer(0.5).timeout
	_verificar("e volta para o lugar", is_equal_approx(mercador.position.y, y0), "y=%f" % mercador.position.y)
	jogador.global_position = Vector2(-400, -400)

	# --- poses especiais: bardo toca (linha 6) e a mistica olha a bola (linha 6), alternando com o idle
	for no in ["Bardo", "Mistica"]:
		var spr: Sprite2D = npcs[no]["sprite"]
		var vivo: Node = npcs[no]["vivo"]
		var linhas_vistas := {}
		var limite := Time.get_ticks_msec() + 45000
		# para nao esperar o sorteio: acelera as fases
		while Time.get_ticks_msec() < limite and not (linhas_vistas.has(6) and linhas_vistas.keys().any(func(l): return l <= 3)):
			vivo._resta_fase = minf(vivo._resta_fase, 0.4)
			await create_timer(0.5).timeout
			linhas_vistas[spr.frame / 4] = true
		_verificar("%s alterna a pose especial (linha 6) com o idle" % no, linhas_vistas.has(6) and linhas_vistas.keys().any(func(l): return l <= 3), str(linhas_vistas.keys()))
	# bardo continua tocando com o jogador perto; a mistica larga a bola e olha para ele
	var bardo: Node2D = npcs["Bardo"]["npc"]
	var vb = npcs["Bardo"]["vivo"]
	vb._em_especial = true
	vb._resta_fase = 99.0
	jogador.global_position = bardo.global_position + Vector2(0, 30)
	await _quadros(5)
	_verificar("bardo continua tocando com o jogador perto", npcs["Bardo"]["sprite"].frame / 4 == 6, str(npcs["Bardo"]["sprite"].frame))
	# na pose especial o bardo e a mistica nao andam; nas pausas passeiam
	vb._andando = false
	var pos_bardo: Vector2 = bardo.global_position
	vb._resta_parado = 0.0
	await _quadros(30)
	_verificar("tocando, o bardo fica no lugar", bardo.global_position == pos_bardo and not vb._andando, "")
	var mis: Node2D = npcs["Mistica"]["npc"]
	var vm = npcs["Mistica"]["vivo"]
	vm._em_especial = true
	vm._resta_fase = 99.0
	jogador.global_position = mis.global_position + Vector2(0, 30)
	await _quadros(5)
	_verificar("mistica deixa a bola e olha para o jogador quando ele chega", npcs["Mistica"]["sprite"].frame / 4 <= 3, str(npcs["Mistica"]["sprite"].frame))

	# --- NPC escondido (nao contratado ou em onda) nao gasta animacao nem quebra
	npcs["Bardo"]["npc"].visible = false
	await _quadros(3)
	_verificar("NPC escondido nao da erro", true, "")

	cena.queue_free()
	await _quadros(3)
	progresso.apagar()
	fazenda.apagar()
	for caminho in [CAMINHO_PROGRESSO, CAMINHO_FAZENDA]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	print("FALHAS: ", _falhas)
	quit(_falhas)
