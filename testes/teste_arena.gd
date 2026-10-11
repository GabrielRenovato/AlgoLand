extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_arena.gd
# Confere a arena sazonal (cenas/terreno.tscn): malha de navegação, spawns fora de obstáculos, ciclo de estações,
# troca de texturas e a tela de título fixa no inverno.
# ATENCAO: carrega a cena de jogo de verdade (pode regravar user://inventario.json); faça backup do user:// antes.

const Profundidade := preload("res://Codigos/Globais/profundidade.gd")

# Carregado em _rodar: estacoes.gd usa autoloads (Sons), que só existem depois do primeiro quadro
var Estacoes: GDScript
var _falhas: int = 0
var _cena: Node
var _terreno: Node2D
var _estacoes: Node
var _gerenciador: Node
var _nomes: Array = []

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

func _rodar() -> void:
	await process_frame
	Estacoes = load("res://Codigos/Design/estacoes.gd")
	_testar_mapa_de_ondas_para_estacoes()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	await create_timer(0.3).timeout
	_terreno = _cena.get_node("Terrains")
	_estacoes = _terreno.get_node("Estacoes")
	_gerenciador = _cena.get_node("enemySpawner/GerenciadorOndas")
	_testar_estrutura()
	await _testar_navegacao()
	await _testar_profundidade_do_carvalho()
	_testar_troca_de_estacao()
	await _testar_ciclo_por_ondas()
	_cena.queue_free()
	await _quadros(3)
	await _testar_tela_de_titulo()
	print("FALHAS: ", _falhas)
	quit(_falhas)

func _testar_mapa_de_ondas_para_estacoes() -> void:
	var esperado := {1: 0, 5: 0, 6: 1, 10: 1, 11: 2, 15: 2, 16: 3, 20: 3, 21: 0, 26: 1, 40: 3, 41: 0}
	for onda in esperado:
		_verificar("onda %d -> estacao %d" % [onda, esperado[onda]], Estacoes.estacao_da_onda(onda) == esperado[onda],
				"obteve %d" % Estacoes.estacao_da_onda(onda))

func _testar_estrutura() -> void:
	for caminho in ["BarracaAberta", "BarracaAberta/Colisao/Forma", "BarraFechada", "BarraFechada/1", "Fogueira",
			"Fogueira/Interacao", "LimiteArena/Contorno", "Obstaculos", "Navegacao", "Objetos3D", "Estacoes",
			"Chao", "Terra", "Agua", "Brilho", "Penhasco", "Detalhes"]:
		_verificar("no %s existe" % caminho, _terreno.get_node_or_null(caminho) != null, "")
	var barra := _terreno.get_node("BarraFechada/1") as TileMapLayer
	_verificar("BarraFechada/1 tem colisao de tiles", barra.tile_set.get_physics_layers_count() > 0, "")
	var contorno := _terreno.get_node("LimiteArena/Contorno") as CollisionPolygon2D
	_verificar("poligono da arena preservado (%d pontos)" % contorno.polygon.size(), contorno.polygon.size() == 37
			and contorno.polygon[0] == Vector2(-112, 112), "")
	var chao := _terreno.get_node("Chao") as TileMapLayer
	_verificar("chao com tiles", chao.get_used_cells().size() > 5000, "%d" % chao.get_used_cells().size())
	_verificar("um unico TileSetAtlasSource no chao", chao.tile_set.get_source_count() == 1, "")
	# profundidade: todo filho de Objetos3D ganhou z pela base (origem nos pes)
	var sem_z := 0
	for no in _terreno.get_node("Objetos3D").get_children():
		if no is Sprite2D and no.z_index != Profundidade.z_de(no.global_position.y):
			sem_z += 1
	_verificar("sprites de Objetos3D com z por profundidade", sem_z == 0, "%d sem z" % sem_z)

func _todos_obstaculos() -> Array:
	var polis: Array = []
	for caminho in ["Obstaculos", "BarracaAberta/Colisao", "Fogueira"]:
		var raiz := _terreno.get_node(caminho)
		var pilha: Array = [raiz]
		while not pilha.is_empty():
			var no: Node = pilha.pop_back()
			if no is CollisionPolygon2D and not no.disabled:
				var pts := PackedVector2Array()
				for p in no.polygon:
					pts.append(no.to_global(p))
				polis.append(pts)
				_nomes.append(str(no.get_path()))
			elif no is CollisionShape2D and no.shape is RectangleShape2D and not no.disabled:
				var m: Vector2 = no.shape.size * 0.5
				var pts := PackedVector2Array()
				for q in [Vector2(-m.x, -m.y), Vector2(m.x, -m.y), Vector2(m.x, m.y), Vector2(-m.x, m.y)]:
					pts.append(no.to_global(q))
				polis.append(pts)
				_nomes.append(str(no.get_path()))
			pilha.append_array(no.get_children())
	return polis

func _distancia_poligono(p: Vector2, poli: PackedVector2Array) -> float:
	var melhor := INF
	for i in poli.size():
		var a := poli[i]
		var b := poli[(i + 1) % poli.size()]
		melhor = minf(melhor, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return melhor

func _testar_navegacao() -> void:
	await physics_frame
	await physics_frame
	await physics_frame
	var nav := _terreno.get_node("Navegacao") as NavigationRegion2D
	var malha := nav.navigation_polygon
	_verificar("malha de navegacao assada com poligonos", malha != null and malha.get_polygon_count() > 0,
			"poligonos=%d" % (malha.get_polygon_count() if malha else -1))
	var mapa := nav.get_navigation_map()
	var polis := _todos_obstaculos()
	_verificar("obstaculos coletados (%d)" % polis.size(), polis.size() > 100, "")
	var jogador := _cena.get_node("Jogador") as Node2D
	var spawner := _cena.get_node("enemySpawner")
	var n_spawns := 0
	for filho in spawner.get_children():
		if not (filho is Marker2D):
			continue
		n_spawns += 1
		var p: Vector2 = filho.global_position
		var dentro := false
		var folga := INF
		var perto := ""
		for k in polis.size():
			if Geometry2D.is_point_in_polygon(p, polis[k]):
				dentro = true
			var dk := _distancia_poligono(p, polis[k])
			if dk < folga:
				folga = dk
				perto = _nomes[k]
		_verificar("spawn %s fora de obstaculos (folga %.0f px)" % [filho.name, folga], not dentro and folga >= 24.0, "mais perto: %s em %s" % [perto, str(p)])
		# o spawner sorteia um deslocamento de +-20 px (slime_spawner.gd): nenhum ponto sorteado pode cair dentro de obstaculo
		var dentro_sorteio := 0
		for k in 300:
			var q := p + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			for poli in polis:
				if Geometry2D.is_point_in_polygon(q, poli):
					dentro_sorteio += 1
					break
		_verificar("spawn %s: 300 deslocamentos sorteados fora de obstaculos" % filho.name, dentro_sorteio == 0, "%d dentro" % dentro_sorteio)
		var no_mapa := NavigationServer2D.map_get_closest_point(mapa, p)
		_verificar("spawn %s sobre a malha de navegacao (%.1f px)" % [filho.name, no_mapa.distance_to(p)], no_mapa.distance_to(p) < 4.0, "")
		var caminho := NavigationServer2D.map_get_path(mapa, p, jogador.global_position, true)
		_verificar("caminho do spawn %s ate o jogador (%d pontos)" % [filho.name, caminho.size()],
				caminho.size() > 1 and caminho[caminho.size() - 1].distance_to(jogador.global_position) < 24.0, "")
	_verificar("tres spawns testados", n_spawns == 3, "%d" % n_spawns)
	# o centro da lagoa e do penhasco nao pode ser andavel
	var agua_mundo := _terreno.to_global(Vector2(40, 90))
	var topo_mesa := _terreno.to_global(Vector2(48, -10))
	for par in [["lagoa", agua_mundo], ["penhasco", topo_mesa]]:
		var perto := NavigationServer2D.map_get_closest_point(mapa, par[1])
		_verificar("%s fora da malha (%.0f px do ponto andavel mais proximo)" % [par[0], perto.distance_to(par[1])],
				perto.distance_to(par[1]) > 10.0, "")

func _testar_profundidade_do_carvalho() -> void:
	var jogador := _cena.get_node("Jogador") as Node2D
	var carvalho := _terreno.get_node("Objetos3D/Carvalho01") as Sprite2D
	var base_mundo := carvalho.global_position
	# atras do tronco (mais ao norte e dentro do retangulo do sprite): o carvalho fica semitransparente
	jogador.global_position = base_mundo + Vector2(0, -30)
	await _quadros(40)
	_verificar("jogador atras do carvalho: sprite com fade (alfa %.2f)" % carvalho.modulate.a, carvalho.modulate.a < 0.7, "")
	# na frente (mais ao sul): opaco de novo
	jogador.global_position = base_mundo + Vector2(0, 40)
	await _quadros(60)
	_verificar("jogador na frente do carvalho: sprite opaco (alfa %.2f)" % carvalho.modulate.a, carvalho.modulate.a > 0.95, "")
	_verificar("z do jogador na frente maior que o do carvalho",
			Profundidade.z_de(jogador.global_position.y + Profundidade.PES_JOGADOR) > carvalho.z_index, "")
	jogador.global_position = _terreno.to_global(Vector2(567, 218))

func _testar_troca_de_estacao() -> void:
	var fonte: TileSetAtlasSource = (_terreno.get_node("Chao") as TileMapLayer).tile_set.get_source(0)
	var nomes := ["spring", "summer", "autumn", "winter"]
	var snow := _terreno.get_node("Objetos3D/BonecoDeNeve") as CanvasItem
	var rosas := _terreno.get_node("Objetos3D/Arbusto497") as CanvasItem
	for i in 4:
		_estacoes.definir_estacao(i, true)
		_verificar("estacao %d: folha do chao" % i, fonte.texture.resource_path.ends_with("/%s.png" % nomes[i]), fonte.texture.resource_path)
		var achou_arvore := false
		var achou_amostra := false
		for no in _terreno.get_node("Objetos3D").get_children():
			if no is Sprite2D and no.texture is AtlasTexture:
				var t: AtlasTexture = no.texture
				if t.resource_name == "arvore":
					achou_arvore = true
					if not (t.atlas.resource_path.contains("(%s" % nomes[i])):
						_verificar("estacao %d: atlas da arvore" % i, false, t.atlas.resource_path)
						return
				elif t.resource_name == "amostra":
					achou_amostra = true
					if not t.atlas.resource_path.ends_with("/%s.png" % nomes[i]):
						_verificar("estacao %d: atlas do carvalho/arbusto" % i, false, t.atlas.resource_path)
						return
		_verificar("estacao %d: arvores e props trocados" % i, achou_arvore and achou_amostra, "")
		_verificar("estacao %d: so_inverno/nao_inverno" % i, snow.visible == (i == 3) and rosas.visible == (i != 3), "")
		var clima := _terreno.get_node("Estacoes/Clima")
		# petalas e folhas ficam em Clima; os vaga-lumes numa camada propria (acompanha a camera, sem o tom da noite)
		var vagalumes := _terreno.get_node("Estacoes/CamadaVagalumes").get_child(0)
		var emitindo := [clima.get_child(0).emitting, vagalumes.emitting, clima.get_child(1).emitting]
		_verificar("estacao %d: clima %s" % [i, str(emitindo)], emitindo == [i == 0, i == 1, i == 2], "")
		# A neve agora é de sprite (clima.gd): so no inverno, e as particulas antigas (grupo clima_neve) nao existem mais
		var meteoro: Node = _estacoes.meteorologia
		_verificar("estacao %d: clima padrao (%d)" % [i, meteoro.clima_atual], meteoro.clima_atual == meteoro.clima_padrao(i), "")
		_verificar("estacao %d: neve %s" % [i, "ligada" if i == 3 else "desligada"], meteoro.eh_neve(meteoro.clima_atual) == (i == 3), "")
		_verificar("estacao %d: sem particulas de neve antigas" % i, get_nodes_in_group("clima_neve").is_empty(), "")

func _testar_ciclo_por_ondas() -> void:
	_estacoes.definir_estacao(0, true)
	var luz = get_first_node_in_group("iluminacao")
	_verificar("iluminacao com tom da estacao", luz != null and luz.tom_estacao != Color.WHITE, "")
	# onda 3 completa: continua primavera
	_gerenciador.onda_bonus = false
	_gerenciador.onda_completada.emit(3)
	await create_timer(0.3).timeout
	_verificar("onda 3 completa: continua primavera", _estacoes.estacao_atual == 0, "")
	# onda 5 completa: vai para verao depois do atraso + fade
	_gerenciador.onda_completada.emit(5)
	await create_timer(Estacoes.ATRASO_TROCA + Estacoes.DURACAO_FADE_SAIDA + 0.4).timeout
	_verificar("onda 5 completa: verao", _estacoes.estacao_atual == 1, "estacao=%d" % _estacoes.estacao_atual)
	# bonus nao avanca a onda: onda 10 com bonus fica no verao
	_gerenciador.onda_bonus = true
	_gerenciador.onda_completada.emit(10)
	await create_timer(Estacoes.ATRASO_TROCA + 0.6).timeout
	_verificar("bonus na onda 10 nao muda de estacao", _estacoes.estacao_atual == 1, "estacao=%d" % _estacoes.estacao_atual)
	_gerenciador.onda_bonus = false
	# onda iniciada que ja pertence a outra estacao: alinha sem fade
	_gerenciador.onda_iniciada.emit(11)
	_verificar("onda 11 iniciada: outono sem esperar", _estacoes.estacao_atual == 2, "estacao=%d" % _estacoes.estacao_atual)
	# onda completada seguida de inicio antes do atraso cancela a troca agendada
	_gerenciador.onda_completada.emit(15)
	_gerenciador.onda_iniciada.emit(15)
	await create_timer(Estacoes.ATRASO_TROCA + 1.2).timeout
	_verificar("troca agendada cancelada se a onda recomeca", _estacoes.estacao_atual == 2, "estacao=%d" % _estacoes.estacao_atual)
	# ondas paradas (morte): volta para a estacao da onda inicial
	_gerenciador.sinal_ondas_paradas.emit()
	_verificar("ondas paradas: volta a primavera", _estacoes.estacao_atual == 0, "estacao=%d" % _estacoes.estacao_atual)
	# Mistica: comecar na onda 11 -> outono
	_gerenciador.onda_inicial_definida.emit(11)
	await create_timer(1.6).timeout
	_verificar("checkpoint da mistica na onda 11: outono", _estacoes.estacao_atual == 2, "estacao=%d" % _estacoes.estacao_atual)
	_gerenciador.sinal_ondas_paradas.emit()

func _testar_tela_de_titulo() -> void:
	var titulo: Node = load("res://cenas/inicio-do-jogo.tscn").instantiate()
	root.add_child(titulo)
	current_scene = titulo
	await _quadros(8)
	var est: Node = titulo.get_node("Cenario/Estacoes")
	_verificar("tela de titulo: inverno fixo", est.estacao_atual == 3, "estacao=%d" % est.estacao_atual)
	_verificar("tela de titulo: neve leve de sprite", est.meteorologia.clima_atual == est.meteorologia.Estado.NEVE_LEVE, "clima=%d" % est.meteorologia.clima_atual)
	_verificar("tela de titulo: sem particulas de neve antigas", titulo.get_node_or_null("Neve") == null)
	titulo.queue_free()
	await _quadros(2)
