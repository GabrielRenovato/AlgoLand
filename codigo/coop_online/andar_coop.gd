extends Node
## O anfitrião simula o andar; o convidado mantém apenas jogador local e réplicas visuais.
const Remoto := preload("res://codigo/coop_online/parceiro_coop.gd")
const Replica := preload("res://codigo/coop_online/inimigo_replica.gd")
const DadosItemScript := preload("res://codigo/modelos/dados_item.gd")
const Drop := preload("res://codigo/logica/equipamento_drop.gd")
const SementeDrop := preload("res://codigo/logica/semente_drop.gd")
const EquipamentoDrop := preload("res://codigo/logica/equipamento_drop.gd")
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
var _reanimando := false
var _grupo: CanvasLayer
var _espelhos := {}
var _ultimo_enviado := {}
var _refresco := {}
var _espelhos_enviados_vazio := true
var _espelhos_finalizados := {}
const IndicadorScript := preload("res://codigo/efeitos/indicador_ataque.gd")
const CanalScript := preload("res://codigo/efeitos/canal_medusa.gd")
const FogoScript := preload("res://codigo/efeitos/efeito_ataque_dragao.gd")
const ChuvaScript := preload("res://codigo/efeitos/chuva_fogo_dragao.gd")
var _saques := {}
var _rng_drops := RandomNumberGenerator.new()
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
	_rng_drops.randomize()
	add_to_group("coop_tremor")
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
		_tempo = 1.0 / 20.0
		sessao.enviar({"t": "jogador", "andar": andar, "e": _estado_jogador()}, true)
		if sessao.sou_host(): _enviar_mundo()
	if sessao.sou_host(): _verificar_derrota()
	_cuidar_do_aliado_caido(delta)
	_atualizar_grupo()

func _atualizar_grupo() -> void:
	var membros: Array = []
	for j in sessao.jogadores:
		var id := str(j.get("id", ""))
		# Só os aliados: a vida do próprio jogador já está no HUD dele.
		if id == sessao.eu: continue
		if parceiros.has(id) and is_instance_valid(parceiros[id]):
			var p: Node2D = parceiros[id]
			membros.append({"nome": p.apelido, "hp": p.hp_atual, "hpm": p.hp_maximo, "caido": p.caido, "vaga": sessao.vaga_de(id), "eu": false, "pronto": _andar_concluido and id != sessao.dono and bool(sessao.prontos_avanco.get(id, false))})
	_grupo.atualizar(membros, "%d MS" % maxi(0, sessao.ping_ms) if not membros.is_empty() else "")

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
		"af": jogador.no_fazenda.acao_atual if jogador.esta_em_acao_fazenda else "", "cai": jogador.caido, "morto": jogador.estaMorto, "hp": jogador.hp_atual, "hpm": jogador.estatisticas.hp_maximo,
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
		"espelhos":
			if not sessao.sou_host(): _aplicar_espelhos(m.get("lista", []))
		"tremor":
			if not sessao.sou_host(): _tremer(clampf(float(m.get("i", 0)), 0, 12), clampf(float(m.get("d", 0.2)), 0.05, 1.0))
		"recompensa":
			if not sessao.sou_host() and not _saques_recebidos.has("abate_" + str(m.get("id", 0))):
				_saques_recebidos["abate_" + str(m.get("id", 0))] = true
				DadosJogo.adicionar_moedas(gerente._aplicar_saque(clampf(float(m.get("ouro", 0)), 0.0, 10000.0)))
				_soltar_drops_locais(int(m.get("id", 0)), bool(m.get("ultimo", false)))
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
			pass # versões antigas do anfitrião ainda mandavam o saque dele; agora cada um sorteia o seu

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
		_descricoes[id] = {"t": "nascer", "andar": andar, "id": id, "cena": no.scene_file_path, "x": no.global_position.x, "y": no.global_position.y, "sx": no.scale.x, "sy": no.scale.y, "chefe": bool(no.get("eh_chefe")), "mut": bool(no.get("eh_mutante")), "nome": str(no.get("nome_chefe")), "vm": _vmax[id], "ab": float(no.get("altura_barra_vida")), "barra": bool(no.get("usar_barra_vida")), "texturas": texturas}
		no.inimigo_morreu.connect(_abate.bind(id), CONNECT_ONE_SHOT)
	# Os drops do anfitrião são só dele: cada convidado sorteia os próprios quando o inimigo morre.
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
	# Cada convidado só recebe o estado do que está perto dele; as poses são montadas uma vez por inimigo.
	var pedidos: Array = []
	for p in _prontos:
		var par: Node2D = parceiros.get(p)
		if par != null and is_instance_valid(par): pedidos.append([p, par.global_position])
	var cache := {}
	for pedido in pedidos:
		var estados: Array = []
		var memoria: Dictionary = _ultimo_enviado.get(pedido[0], {})
		_ultimo_enviado[pedido[0]] = memoria
		var agora_ms := Time.get_ticks_msec()
		var completo: bool = agora_ms >= int(_refresco.get(pedido[0], 0))
		if completo: _refresco[pedido[0]] = agora_ms + 1500
		for id in _inimigos:
			var no: Node2D = _inimigos[id]
			if no.global_position.distance_squared_to(pedido[1]) > 1000000: continue
			if not cache.has(id):
				var poses: Array = []
				for s in _sprites.get(id, []):
					if is_instance_valid(s): poses.append([s.hframes, s.vframes, s.frame, s.flip_h, s.is_visible_in_tree(), snappedf(s.rotation, 0.01)])
				_vmax[id] = maxi(int(_vmax.get(id, 1)), int(no.vida))
				cache[id] = [id, snappedf(no.global_position.x, 0.1), snappedf(no.global_position.y, 0.1), no.vida, poses, _vmax[id]]
			# Inimigo parado e adormecido não muda: só vai de novo no refresco, o que poupa banda com muita gente.
			if not completo and memoria.get(id) == cache[id]: continue
			memoria[id] = cache[id]
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
	# Valor-base igual ao do anfitrião (evento e tamanho do grupo); cada um aplica o próprio bônus de saque.
	var ouro: float = float(gerente.ouro_por_abate(andar)) * gerente.mult_evento("ouro") * gerente.mult_ouro_online()
	sessao.enviar({"t": "recompensa", "andar": andar, "id": id, "ouro": snappedf(ouro, 0.001), "ultimo": gerente.inimigos_vivos <= 0})

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
		_parar_animacao_reviver()
		return
	if Input.is_action_pressed("open_menu") and get_viewport().gui_get_focus_owner() == null:
		# Ajoelha virado para o aliado (pose de colher) enquanto segura; os outros jogadores veem a mesma pose.
		if not jogador.esta_em_acao_fazenda:
			jogador._direcao_ataque = (alvo.global_position - jogador.global_position).normalized()
			_reanimando = jogador.acao_fazenda("colher") or _reanimando
		_progresso_reviver += delta
		alvo.mostrar_reviver(_progresso_reviver / sessao.TEMPO_REVIVER, "REANIMANDO...")
		if _progresso_reviver >= sessao.TEMPO_REVIVER:
			_progresso_reviver = 0.0
			_parar_animacao_reviver()
			_pedir_reviver(alvo)
	else:
		_parar_animacao_reviver()
		_progresso_reviver = maxf(0.0, _progresso_reviver - delta * 2.0)
		alvo.mostrar_reviver(_progresso_reviver / sessao.TEMPO_REVIVER, "SEGURE %s PARA REANIMAR" % Controle.rotulo_acao("open_menu"))

func _parar_animacao_reviver() -> void:
	if _reanimando:
		_reanimando = false
		jogador.cancelar_acao_fazenda()

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

## Chamado pelo grupo "coop_tremor" (inimigo_base._tremer_camera) no anfitrião.
func tremor(intensidade: float, duracao: float) -> void:
	if sessao != null and sessao.ativo and sessao.sou_host():
		sessao.enviar({"t": "tremor", "andar": andar, "i": intensidade, "d": duracao})

func _tremer(intensidade: float, duracao: float) -> void:
	var camera: Camera2D = jogador.get_node_or_null("Camera2D")
	if camera == null: return
	var tween := camera.create_tween()
	for i in 6:
		var forca := intensidade * (1.0 - float(i) / 6.0)
		tween.tween_property(camera, "offset", Vector2(randf_range(-forca, forca), randf_range(-forca, forca)), duracao / 6.0)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)

func _aplicar_espelhos(lista: Array) -> void:
	var vistos := {}
	for d in lista:
		if not d is Dictionary: continue
		var id := int(d.get("id", 0))
		if _espelhos_finalizados.has(id): continue
		vistos[id] = true
		var no = _espelhos.get(id)
		if no == null or not is_instance_valid(no):
			no = _criar_espelho(d)
			if no == null: continue
			_espelhos[id] = no
		_atualizar_espelho(id, no, d)
	for id in _espelhos.keys():
		if vistos.has(id): continue
		var no = _espelhos[id]
		_espelhos.erase(id)
		if is_instance_valid(no): no.cancelar() if no.has_method("cancelar") else no.queue_free()

func _par(v, padrao := Vector2.ZERO) -> Vector2:
	return Vector2(float(v[0]), float(v[1])) if v is Array and v.size() == 2 else padrao

func _criar_espelho(d: Dictionary) -> Node:
	var no: Node
	match str(d.get("k", "")):
		"ind":
			no = IndicadorScript.new()
			cena.add_child(no)
			no.configurar(Vector2(float(d.get("x", 0)), float(d.get("y", 0))), clampf(float(d.get("r", 64)), 4, 600))
		"canal":
			no = CanalScript.new()
			cena.add_child(no)
		"fogo":
			var tipo := str(d.get("tp", "sopro"))
			if not tipo in FogoScript.ARQUIVOS: return null
			no = FogoScript.new()
			no.tipo = tipo
			no.direcao = _par(d.get("dr"), Vector2.RIGHT)
			no.alcance = clampf(float(d.get("al", 150)), 1, 1000)
			cena.add_child(no)
		"chuva":
			no = ChuvaScript.new()
			cena.add_child(no)
			# O polígono do aviso já chega pelos avisos de ataque; aqui só os meteoros.
			no._aviso.visible = false
		_:
			return null
	return no

func _atualizar_espelho(id: int, no: Node, d: Dictionary) -> void:
	match str(d.get("k", "")):
		"ind":
			if bool(d.get("i", false)):
				_espelhos_finalizados[id] = true
				no.detonar_impacto()
			else: no.atualizar_progresso(float(d.get("p", 0)))
		"canal": no.atualizar(_par(d.get("o")), _par(d.get("d")), float(d.get("t", 0)), float(d.get("f", -1)))
		"fogo":
			no.global_position = _par(d.get("gp"))
			no.global_rotation = float(d.get("rot", 0))
			no.scale = _par(d.get("sc"), Vector2.ONE)
			no.visible = bool(d.get("v", false))
			no.frame = clampi(int(d.get("fr", 0)), 0, 5)
			no.z_as_relative = false
			no.z_index = clampi(int(d.get("zi", 0)), -4096, 4096)
		"chuva":
			var pontos := PackedVector2Array()
			for p in (d.get("z", []) as Array).slice(0, 128): pontos.append(_par(p))
			var assinatura := str(pontos).hash()
			if int(no.get_meta("zh", 0)) != assinatura:
				no.set_meta("zh", assinatura)
				no.definir_zona(pontos)
				no._aviso.visible = false
			no.atualizar(float(d.get("t", 0)), bool(d.get("a", false)))

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
	var espelhos: Array = []
	for no in get_tree().get_nodes_in_group("espelhos_coop"):
		if not is_instance_valid(no) or not cena.is_ancestor_of(no): continue
		var dados: Dictionary = no.espelho()
		dados["id"] = no.get_instance_id()
		espelhos.append(dados)
	if not espelhos.is_empty() or not _espelhos_enviados_vazio:
		sessao.enviar({"t": "espelhos", "andar": andar, "lista": espelhos.slice(0, 12)}, true)
	_espelhos_enviados_vazio = espelhos.is_empty()

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

## Drops individuais: o convidado sorteia o próprio saque, com a própria sorte e as próprias receitas, no ponto da morte.
func _soltar_drops_locais(id: int, ultimo: bool) -> void:
	var alvo = _inimigos.get(id)
	if alvo == null or not is_instance_valid(alvo): return
	var chefe: bool = SementeDrop.eh_chefe(alvo)
	SementeDrop.soltar_de(alvo, cena, _rng_drops, true)
	EquipamentoDrop.soltar_de(alvo, cena, _rng_drops, andar, chefe)
	var forja := preload("res://codigo/logica/drops_forja.gd")
	if chefe: forja.soltar_material("nucleo", 1, alvo.global_position, cena)
	if ultimo: forja.soltar_material("fragmento", 1, alvo.global_position, cena)
	if EquipamentoDrop.sortear_moeda_forja(_rng_drops, chefe): forja.soltar_material("moeda_forja", 1, alvo.global_position, cena)

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
