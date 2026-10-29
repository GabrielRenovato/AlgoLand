extends Node
## O anfitrião simula o andar; o convidado mantém apenas jogador local e réplicas visuais.
const Remoto := preload("res://codigo/coop_online/parceiro_coop.gd")
const Replica := preload("res://codigo/coop_online/inimigo_replica.gd")
const DadosItemScript := preload("res://codigo/modelos/dados_item.gd")
const Drop := preload("res://codigo/logica/equipamento_drop.gd")
var sessao: Node
var cena: Node2D
const Grupo := preload("res://codigo/coop_online/grupo_coop.gd")
var jogador: Node2D
## Os outros jogadores da sala, por id de conexão (o anfitrião também entra aqui para os convidados).
var parceiros: Dictionary = {}
var gerente: Node
var andar := 1
var _tempo := 0.0
var _seq := 0
var _ultima_seq := -1
var _proximo_id := 1
var _ids := {}
var _inimigos := {}
var _descricoes := {}
var _enviados := {}
var _sprites := {}
var _vmax := {}
var _prontos: Array[String] = []
var _progresso_reviver := 0.0
var _grupo: CanvasLayer
var _saques := {}
var _saques_enviados := {}
var _saques_recebidos := {}
var _golpes := {}
var _pronto := false
var _tempo_reviver := 0.0
var _dano_ate := {}
var _andar_concluido := false
var _avisos: Array[Polygon2D] = []
var _projeteis: Array[Sprite2D] = []

func configurar(conexao: Node, raiz: Node2D) -> void:
	sessao = conexao
	cena = raiz
	andar = sessao.andar
	jogador = cena.get_node("Jogador")
	gerente = cena.find_child("GerenciadorOndas", true, false)
	if gerente == null:
		for no in get_tree().get_nodes_in_group("gerenciador_andar"):
			if cena.is_ancestor_of(no): gerente = no; break
	if gerente != null:
		gerente.onda_inicial = andar
		gerente.onda_atual = andar
		gerente.META_PROGRESSO = load("res://codigo/fendas/catalogo_andares.gd").meta(andar)
	var base := jogador.global_position
	for id in sessao.outros():
		var parceiro := Remoto.new()
		parceiro.name = "ParceiroOnline_" + id.substr(0, 8)
		parceiro.controlador = self
		parceiro.id_jogador = id
		cena.add_child(parceiro)
		parceiro.configurar(sessao.perfil_de(id))
		parceiro.definir_vaga(sessao.vaga_de(id))
		parceiro.posicionar(base + Vector2(16 * sessao.vaga_de(id), 0))
		parceiros[id] = parceiro
	jogador.global_position = base + Vector2(16 * sessao.vaga_de(sessao.eu), 0)
	sessao.jogador_saiu.connect(_ao_saiu)
	_grupo = Grupo.new()
	add_child(_grupo)
	if not sessao.sou_host():
		if gerente != null:
			gerente.set_physics_process(false)
			gerente.onda_em_andamento = true
		sessao.enviar({"t": "pronto_andar", "andar": andar})

func _ao_saiu(id: String) -> void:
	var parceiro = parceiros.get(id)
	if parceiro != null and is_instance_valid(parceiro): parceiro.queue_free()
	parceiros.erase(id)
	_prontos.erase(id)
	if is_instance_valid(jogador):
		get_tree().call_group("hud_p1", "avisar", "%s SAIU DA SALA" % (str(parceiro.apelido) if parceiro != null else "UM JOGADOR"))

func _process(delta: float) -> void:
	if sessao == null or not sessao.ativo or not is_instance_valid(jogador): return
	for m in sessao.retirar_pacotes(andar): _receber(m)
	_tempo -= delta
	if _tempo <= 0.0:
		_tempo = 1.0 / 15.0
		sessao.enviar({"t": "jogador", "andar": andar, "e": _estado_jogador()}, true)
		if sessao.sou_host(): _enviar_mundo()
	if sessao.sou_host(): _verificar_derrota()
	_cuidar_do_aliado_caido(delta)
	_atualizar_grupo()

func _atualizar_grupo() -> void:
	var membros: Array = []
	for j in sessao.jogadores:
		var id := str(j.get("id", ""))
		if id == sessao.eu:
			membros.append({"nome": str(sessao.perfil_de(id).get("apelido", jogador.apelido)), "hp": jogador.hp_atual, "hpm": jogador.estatisticas.hp_maximo, "caido": jogador.caido, "vaga": sessao.vaga_de(id), "eu": true, "pronto": _andar_concluido and not sessao.sou_host() and bool(sessao.prontos_avanco.get(id, false))})
		elif parceiros.has(id) and is_instance_valid(parceiros[id]):
			var p: Node2D = parceiros[id]
			membros.append({"nome": p.apelido, "hp": p.hp_atual, "hpm": p.hp_maximo, "caido": p.caido, "vaga": sessao.vaga_de(id), "eu": false, "pronto": _andar_concluido and id != sessao.dono and bool(sessao.prontos_avanco.get(id, false))})
	_grupo.atualizar(membros, "COOP • %s • %d MS" % ["ANFITRIAO" if sessao.sou_host() else "CONVIDADO", maxi(0, sessao.ping_ms)])

func _estado_jogador() -> Dictionary:
	# Mesmo contrato de movimento/poses já usado no duelo, sem instanciar aquela arena.
	var timer: Timer = jogador._temporizador
	var d: Node = jogador.defesa
	var par := func(v: Vector2) -> Array: return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]
	return {"x": snappedf(jogador.global_position.x, 0.1), "y": snappedf(jogador.global_position.y, 0.1),
		"vx": snappedf(jogador.velocity.x, 0.1), "vy": snappedf(jogador.velocity.y, 0.1),
		"a": jogador._esta_atacando, "c": jogador._fase_combo, "tl": timer.time_left if timer != null else 0.0,
		"da": par.call(jogador._direcao_ataque), "d3": par.call(jogador._direcao_golpe_3d), "dp": par.call(jogador.direcao_apontada()),
		"dash": jogador.esta_em_dash, "def": int(d.estado), "dg": par.call(d.direcao_guarda),
		"gt": d._tempo, "gi": d._indice, "gp": d._pausa,
		"gh": (Time.get_ticks_msec() - d._inicio_guarda_ms) / 1000.0,
		"ar": jogador.no_arco.esta_disparando(), "ad": par.call(jogador.no_arco._direcao_disparo),
		"rf": jogador.no_reacao.visible and jogador.no_reacao.pose_atual == "ferido",
		"cai": jogador.caido, "morto": jogador.estaMorto, "hp": jogador.hp_atual, "hpm": jogador.estatisticas.hp_maximo,
		"arma": jogador.id_arma_atual, "es": jogador.usando_espada, "ec": jogador.usando_escudo, "la": jogador.usando_lanca, "arc": jogador.usando_arco}

func _receber(m: Dictionary) -> void:
	var de := str(m.get("de", ""))
	match str(m.get("t", "")):
		"jogador":
			var e = m.get("e", {})
			if not e is Dictionary or not parceiros.has(de): return
			var ponto := Vector2(float(e.get("x", 0)), float(e.get("y", 0)))
			if not ponto.is_finite() or absf(ponto.x) > 12000 or absf(ponto.y) > 12000: return
			parceiros[de].aplicar_estado(e)
		"pronto_andar":
			if sessao.sou_host() and parceiros.has(de) and not de in _prontos:
				_prontos.append(de)
				# Quem chega recebe o retrato completo do que já existe no andar.
				for id in _descricoes: sessao.enviar_para(de, _descricoes[id])
				for id in _saques: sessao.enviar_para(de, _saques[id])
		"nascer":
			if sessao.sou_host(): return
			var id := int(m.get("id", 0))
			if _inimigos.has(id) or _inimigos.size() >= 400: return
			var replica := Replica.new()
			replica.controlador = self
			cena.add_child(replica)
			if not replica.configurar(m):
				replica.queue_free()
				return
			_inimigos[id] = replica
		"mundo":
			if sessao.sou_host() or int(m.get("seq", -1)) <= _ultima_seq: return
			_ultima_seq = int(m.seq)
			for e in m.get("inimigos", []):
				if e is Array and e.size() >= 5 and _inimigos.has(int(e[0])): _inimigos[int(e[0])].aplicar(e)
			if gerente != null:
				gerente.META_PROGRESSO = clampi(int(m.get("meta", gerente.META_PROGRESSO)), 1, 100000)
				gerente.pontos = clampi(int(m.get("pontos", 0)), 0, gerente.META_PROGRESSO)
				gerente.etapa = int(m.get("etapa", 0))
				gerente.inimigos_vivos = int(m.get("vivos", 0))
				gerente.total_inimigos_onda = int(m.get("total", 0))
				gerente.atualizar_ui()
				gerente.progresso_andar_alterado.emit()
		"remover":
			if not sessao.sou_host():
				var id := int(m.get("id", 0))
				if _inimigos.has(id):
					_inimigos[id].remover()
					_inimigos.erase(id)
		"golpe":
			if sessao.sou_host(): _aplicar_golpe(m)
		"efeito":
			if sessao.sou_host(): _aplicar_efeito(m)
		"dano":
			if not sessao.sou_host(): jogador.receber_dano(clampi(int(m.get("dano", 0)), 0, 100000), Vector2(float(m.get("kx", 0)), float(m.get("ky", 0))))
		"reviver":
			if not sessao.sou_host(): jogador.levantar_caido(clampf(float(m.get("fr", 0.5)), 0.05, 1.0))
		"reviver_pedido":
			if sessao.sou_host(): _executar_reviver(de, str(m.get("alvo", "")))
		"petrificar":
			if not sessao.sou_host(): jogador.aplicar_petrificacao(clampf(float(m.get("duracao", 1)), 0.1, 10))
		"execucao":
			if not sessao.sou_host(): jogador.receber_hitkill_chefe()
		"efeitos_visuais":
			if not sessao.sou_host(): _aplicar_visuais(m)
		"recompensa":
			if not sessao.sou_host() and not _saques_recebidos.has("abate_" + str(m.get("id", 0))):
				_saques_recebidos["abate_" + str(m.get("id", 0))] = true
				DadosJogo.adicionar_moedas(clampi(int(m.get("ouro", 0)), 0, 10000))
				Progresso.registrar_abate()
		"concluido":
			if not sessao.sou_host() and not _andar_concluido:
				_andar_concluido = true
				gerente.onda_em_andamento = false
				gerente.etapa = gerente.Etapa.CONCLUIDO
				jogador.levantar_caido()
				# O anfitrião já chama o Orion ao vencer; o convidado também precisa dele para comprar e se preparar.
				gerente._abrir_janela_entre_ondas()
				DadosJogo.adicionar_moedas(gerente.ouro_fim_onda(andar))
				Progresso.registrar_onda_concluida(andar, false, false)
				get_tree().call_group("hud_p1", "anunciar", "ANDAR CONCLUIDO", "FALE COM O ORION E MARQUE PRONTO", 5.0)
		"saque":
			if not sessao.sou_host(): _criar_saque(m)

func _vida_maxima_de(no: Node) -> int:
	var maxima := int(no.get("vida_maxima"))
	if maxima <= 0 and no.has_node("HPBar"): maxima = int(no.get_node("HPBar").vida_maxima)
	return maxi(maxi(maxima, int(no.vida)), 1)

func _enviar_mundo() -> void:
	if gerente == null: return
	for no in get_tree().get_nodes_in_group("enemy"):
		if not no is CharacterBody2D or not cena.is_ancestor_of(no) or no.get("vida") == null: continue
		if not no.scene_file_path.begins_with("res://cenas/inimigos/"): continue
		var instancia: int = no.get_instance_id()
		if _ids.has(instancia): continue
		var id := _proximo_id
		_proximo_id += 1
		_ids[instancia] = id
		_inimigos[id] = no
		var texturas: Array = []
		var lista: Array = no.find_children("*", "Sprite2D", true, false)
		_sprites[id] = lista
		for s in lista: texturas.append(s.texture.resource_path if s.texture != null else "")
		_vmax[id] = _vida_maxima_de(no)
		_descricoes[id] = {"t": "nascer", "andar": andar, "id": id, "cena": no.scene_file_path, "x": no.global_position.x, "y": no.global_position.y, "sx": no.scale.x, "sy": no.scale.y, "chefe": bool(no.get("eh_chefe")), "nome": str(no.get("nome_chefe")), "vm": _vmax[id], "ab": float(no.get("altura_barra_vida")), "barra": bool(no.get("usar_barra_vida")), "texturas": texturas}
		no.inimigo_morreu.connect(_abate.bind(id), CONNECT_ONE_SHOT)
	for grupo in ["equipamento_drop", "semente_drop"]:
		for no in get_tree().get_nodes_in_group(grupo):
			if not cena.is_ancestor_of(no) or _saques.has(no.get_instance_id()): continue
			var dados := {"t": "saque", "andar": andar, "id": str(no.get_instance_id()), "x": no.global_position.x, "y": no.global_position.y}
			if grupo == "equipamento_drop": dados["item"] = no.item.para_dict()
			else: dados["semente"] = no.semente
			_saques[no.get_instance_id()] = dados
	if _prontos.is_empty(): return
	for id in _inimigos.keys():
		if not is_instance_valid(_inimigos[id]):
			for p in _prontos: sessao.enviar_para(p, {"t": "remover", "andar": andar, "id": id})
			_inimigos.erase(id)
			_descricoes.erase(id)
			_sprites.erase(id)
			_vmax.erase(id)
			continue
		if not _enviados.has(id):
			var ok := true
			for p in _prontos: ok = sessao.enviar_para(p, _descricoes[id]) and ok
			if ok: _enviados[id] = true
	for id in _saques:
		if not _saques_enviados.has(id):
			var ok := true
			for p in _prontos: ok = sessao.enviar_para(p, _saques[id]) and ok
			if ok: _saques_enviados[id] = true
	# Cada convidado só recebe o estado do que está perto dele; as poses são montadas uma vez por inimigo.
	var pedidos: Array = []
	for p in _prontos:
		var par: Node2D = parceiros.get(p)
		if par != null and is_instance_valid(par): pedidos.append([p, par.global_position])
	var cache := {}
	for pedido in pedidos:
		var estados: Array = []
		for id in _inimigos:
			var no: Node2D = _inimigos[id]
			if no.global_position.distance_squared_to(pedido[1]) > 1000000: continue
			if not cache.has(id):
				var poses: Array = []
				for s in _sprites.get(id, []):
					if is_instance_valid(s): poses.append([s.hframes, s.vframes, s.frame, s.flip_h, s.is_visible_in_tree(), snappedf(s.rotation, 0.01)])
				_vmax[id] = maxi(int(_vmax.get(id, 1)), int(no.vida))
				cache[id] = [id, snappedf(no.global_position.x, 0.1), snappedf(no.global_position.y, 0.1), no.vida, poses, _vmax[id]]
			estados.append(cache[id])
		# Lotes pequenos respeitam o tamanho máximo do SCTP, inclusive em celular/Web.
		for inicio in range(0, maxi(1, estados.size()), 8):
			_seq += 1
			sessao.enviar_para(pedido[0], {"t": "mundo", "andar": andar, "seq": _seq, "inimigos": estados.slice(inicio, inicio + 8), "meta": gerente.META_PROGRESSO, "pontos": gerente.pontos, "etapa": gerente.etapa, "vivos": gerente.inimigos_vivos, "total": gerente.total_inimigos_onda}, true)
	_enviar_visuais()
	if gerente.etapa == gerente.Etapa.CONCLUIDO and not _andar_concluido:
		_andar_concluido = true
		sessao.enviar({"t": "concluido", "andar": andar})

func _abate(id: int) -> void:
	if not sessao.ativo or not sessao.sou_host(): return
	var ouro := roundi(gerente.ouro_por_abate(andar) * gerente.mult_ouro_online())
	sessao.enviar({"t": "recompensa", "andar": andar, "id": id, "ouro": ouro})

func pedir_golpe(id: int, dano: int, empurrao: Vector2) -> void:
	sessao.enviar({"t": "golpe", "andar": andar, "id": id, "dano": dano, "kx": empurrao.x, "ky": empurrao.y})

func pedir_efeito(id: int, efeito: Dictionary) -> void:
	sessao.enviar({"t": "efeito", "andar": andar, "id": id, "efeito": efeito})

func _aplicar_efeito(m: Dictionary) -> void:
	var id := int(m.get("id", 0))
	var parceiro: Node2D = parceiros.get(str(m.get("de", "")))
	if parceiro == null or not _inimigos.has(id) or not is_instance_valid(_inimigos[id]) or parceiro.estaMorto: return
	var no: Node2D = _inimigos[id]
	if no.global_position.distance_to(parceiro.global_position) > 450: return
	var e: Dictionary = m.get("efeito", {})
	var duracao := clampf(float(e.get("duracao", 0)), 0, 5)
	if e.get("tipo") == "fogo": no.aplicar_queimadura(clampi(int(e.get("dano", 0)), 0, 100), clampf(float(e.get("intervalo", 1)), 0.25, 5), duracao, Color.from_string(str(e.get("cor", "ff9900")), Color.ORANGE))
	elif e.get("tipo") == "gelo": no.aplicar_congelamento(duracao)
	elif e.get("tipo") == "lento": no.aplicar_lentidao(clampf(float(e.get("fracao", 0)), 0, 0.8), duracao)
	elif e.get("tipo") == "atordoar": no.atordoar(duracao)

func _aplicar_golpe(m: Dictionary) -> void:
	var id := int(m.get("id", 0))
	var de := str(m.get("de", ""))
	var parceiro: Node2D = parceiros.get(de)
	if parceiro == null or not _inimigos.has(id) or not is_instance_valid(_inimigos[id]) or parceiro.estaMorto: return
	var no: Node2D = _inimigos[id]
	var alcance := 450.0 if parceiro.usando_arco else 110.0
	if no.global_position.distance_to(parceiro.global_position) > alcance: return
	var agora := Time.get_ticks_msec()
	var chave := de + ":" + str(id)
	if agora < int(_golpes.get(chave, 0)): return
	_golpes[chave] = agora + 120
	var limite := clampi(int(sessao.perfil_de(de).get("dano_maximo", 30)), 1, 100000)
	var dano := clampi(int(m.get("dano", 0)), 0, limite)
	if dano > 0: no.receber_dano(dano, Vector2(float(m.get("kx", 0)), float(m.get("ky", 0))).limit_length(400))

func dano_no_parceiro(parceiro: Node2D, dano: int, empurrao: Vector2) -> void:
	if not sessao.sou_host() or Time.get_ticks_msec() < int(_dano_ate.get(parceiro.id_jogador, 0)): return
	_dano_ate[parceiro.id_jogador] = Time.get_ticks_msec() + 150
	sessao.enviar_para(parceiro.id_jogador, {"t": "dano", "andar": andar, "dano": dano, "kx": empurrao.x, "ky": empurrao.y})

## Só cai a sessão se todos caírem.
func _verificar_derrota() -> void:
	if not jogador.caido: return
	for p in parceiros.values():
		if is_instance_valid(p) and not p.caido: return
	sessao._falhar("TODOS OS JOGADORES CAIRAM")

## Perto de um aliado caído, segurar a ação de interagir o reanima; ele volta com pouca vida.
func _cuidar_do_aliado_caido(delta: float) -> void:
	var alvo: Node2D = null
	if not jogador.caido and not jogador.estaMorto:
		for p in parceiros.values():
			if is_instance_valid(p) and p.caido and p.global_position.distance_to(jogador.global_position) <= sessao.ALCANCE_REVIVER:
				alvo = p
				break
	for p in parceiros.values():
		if is_instance_valid(p) and p != alvo: p.mostrar_reviver(-1.0)
	if alvo == null:
		_progresso_reviver = 0.0
		return
	if Input.is_action_pressed("open_menu") and get_viewport().gui_get_focus_owner() == null:
		_progresso_reviver += delta
		alvo.mostrar_reviver(_progresso_reviver / sessao.TEMPO_REVIVER, "REANIMANDO...")
		if _progresso_reviver >= sessao.TEMPO_REVIVER:
			_progresso_reviver = 0.0
			_pedir_reviver(alvo)
	else:
		_progresso_reviver = maxf(0.0, _progresso_reviver - delta * 2.0)
		alvo.mostrar_reviver(_progresso_reviver / sessao.TEMPO_REVIVER, "SEGURE %s PARA REANIMAR" % Controle.rotulo_acao("open_menu"))

func _pedir_reviver(alvo: Node2D) -> void:
	if sessao.sou_host(): _executar_reviver(sessao.eu, alvo.id_jogador)
	else: sessao.enviar({"t": "reviver_pedido", "andar": andar, "alvo": alvo.id_jogador})

## O anfitrião confere quem reanima quem (de pé, perto) antes de levantar o aliado.
func _executar_reviver(quem_id: String, alvo_id: String) -> void:
	var quem: Node2D = jogador if quem_id == sessao.eu else parceiros.get(quem_id)
	var alvo: Node2D = jogador if alvo_id == sessao.eu else parceiros.get(alvo_id)
	if quem == null or alvo == null or quem == alvo or not is_instance_valid(quem) or not is_instance_valid(alvo): return
	if quem.caido or not alvo.caido: return
	if quem.global_position.distance_to(alvo.global_position) > sessao.ALCANCE_REVIVER * 2.0: return
	alvo.levantar_caido(sessao.FRACAO_REVIVER)

func _enviar_visuais() -> void:
	var avisos: Array = []
	for no in get_tree().get_nodes_in_group("avisos_ataque_coop"):
		if not cena.is_ancestor_of(no) or not no.is_visible_in_tree() or no._superficie.polygon.size() < 3: continue
		var pontos: Array = []
		for p in no._superficie.polygon:
			var global: Vector2 = no._superficie.to_global(p)
			pontos.append([snappedf(global.x, 0.1), snappedf(global.y, 0.1)])
		avisos.append(pontos)
	var projeteis: Array = []
	for no in get_tree().get_nodes_in_group("projeteis_hostis_coop"):
		if cena.is_ancestor_of(no): projeteis.append([no.global_position.x, no.global_position.y, no._sprite.rotation, no.tipo, no._sprite.frame])
	sessao.enviar({"t": "efeitos_visuais", "andar": andar, "avisos": avisos.slice(0, 16), "projeteis": projeteis.slice(0, 48)}, true)

func _aplicar_visuais(m: Dictionary) -> void:
	var dados: Array = m.get("avisos", [])
	for i in mini(16, dados.size()):
		if i >= _avisos.size():
			var aviso := Polygon2D.new()
			aviso.texture = load("res://assets/efeitos/avisos/perigo.png")
			aviso.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			aviso.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			aviso.modulate.a = 0.75
			aviso.z_index = 2
			cena.add_child(aviso)
			_avisos.append(aviso)
		var pontos := PackedVector2Array()
		for p in (dados[i] as Array).slice(0, 128): pontos.append(Vector2(float(p[0]), float(p[1])))
		_avisos[i].polygon = pontos
		_avisos[i].uv = pontos
	for i in _avisos.size(): _avisos[i].visible = i < dados.size()
	var tiros: Array = m.get("projeteis", [])
	for i in mini(48, tiros.size()):
		if i >= _projeteis.size():
			var sprite := Sprite2D.new()
			cena.add_child(sprite)
			_projeteis.append(sprite)
		var p: Array = tiros[i]
		if p.size() < 5: continue
		var sprite := _projeteis[i]
		sprite.position = Vector2(float(p[0]), float(p[1]))
		sprite.rotation = float(p[2])
		if str(p[3]) == "flecha":
			sprite.texture = load("res://assets/personagens/Arco/flecha.png")
			sprite.hframes = 1
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://assets/efeitos/esqueletos/base_mana_seed.png")
			atlas.region = Rect2(0, 0, 96, 32)
			sprite.texture = atlas
			sprite.hframes = 3
			sprite.frame = clampi(int(p[4]), 0, 2)
		sprite.z_index = load("res://codigo/globais/profundidade.gd").z_de(sprite.position.y + 12)
	for i in _projeteis.size(): _projeteis[i].visible = i < tiros.size()

func _criar_saque(m: Dictionary) -> void:
	var id := str(m.get("id", ""))
	if _saques_recebidos.has(id): return
	_saques_recebidos[id] = true
	var posicao := Vector2(float(m.get("x", 0)), float(m.get("y", 0)))
	if m.has("item") and m.item is Dictionary:
		var dados: Dictionary = m.item.duplicate(true)
		dados["quantidade"] = clampi(int(dados.get("quantidade", 1)), 1, 999)
		Drop.soltar_item(DadosItemScript.de_dict(dados), posicao, cena, RandomNumberGenerator.new())
	elif m.has("semente") and Fazenda.PLANTAS.has(str(m.semente)):
		var drop = load("res://codigo/logica/semente_drop.gd").new()
		drop.semente = str(m.semente)
		drop.preparar_pulo(posicao, posicao)
		cena.add_child(drop)
