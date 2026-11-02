extends "res://codigo/coop_online/andar_coop.gd"

var _tempo_resumo := 0.0

## Réplicas e combate direto reutilizam o contrato visual do coop, sem saque da arena.
func _receber(m: Dictionary) -> void:
	var tipo := str(m.get("t",""))
	if tipo=="resumo_campanha":
		if not sessao.sou_host() and str(m.get("de",""))==sessao.dono and m.get("resumo") is Dictionary:
			cena.registro_run.receber_resumo(m.resumo)
		return
	if tipo=="saque_inicial":
		if not sessao.sou_host() and str(m.get("de",""))==sessao.dono:
			cena.saque_inicial.receber(str(m.get("evento","")),str(m.get("regiao","")),Vector2(float(m.get("x",0)),float(m.get("y",0))),str(m.get("garantia","")))
		return
	if tipo=="cerne_fala":
		if not sessao.sou_host():cena.fala_do_cerne(str(m.get("texto","")).left(100),str(m.get("complemento","")).left(100),false)
		return
	if tipo=="vigilia_pedido":
		if sessao.sou_host() and parceiros.has(str(m.de)) and parceiros[str(m.de)].position.distance_to(cena.alvos.raizes_despertas.no.position)<50:
			cena.encontro.iniciar()
		return
	if tipo=="vigilia_estado":
		if not sessao.sou_host():
			cena.vigilia_remota=1 if bool(m.get("ativa",false)) else 0
			if cena.vigilia_remota==1:
				for no in cena.get_children():
					if no.has_method("pular") and no.get("ativa"): no.pular()
		return
	if tipo=="invocacao":
		_invocacao_remota(str(m.de))
		return
	if tipo=="perfil":
		if parceiros.has(str(m.de)) and m.get("perfil") is Dictionary:
			parceiros[str(m.de)].configurar(m.perfil)
		return
	if tipo=="pronto_andar" and sessao.sou_host():
		sessao.enviar({"t":"perfil","andar":andar,"perfil":sessao.Duelo.perfil_do(jogador)})
		sessao.enviar({"t":"vigilia_estado","andar":1,"ativa":is_instance_valid(cena.encontro) and cena.encontro.ativa})
	if tipo in ["jogador","pronto_andar","nascer","mundo","remover","golpe","dano","texturas","efeitos_visuais","espelhos","maestria_credito"]:
		super._receber(m)

## O avatar do outro jogador pode ainda não existir quando a mensagem chega: espera até 4 s.
func _invocacao_remota(id: String) -> void:
	for i in 40:
		if parceiros.has(id): break
		await get_tree().create_timer(0.1).timeout
	if parceiros.has(id) and is_instance_valid(parceiros[id]):
		load("res://codigo/campanha/abertura_chegada.gd").efeito_remoto(parceiros[id])

func _process(delta: float) -> void:
	if sessao==null or not sessao.ativo: return
	for m in sessao.retirar_pacotes(andar): _receber(m)
	for evento in sessao.eventos:
		cena.controlador.interagir("vencer",str(evento.get("alvo","")))
	sessao.eventos.clear()
	_tempo -= delta
	if _tempo<=0:
		_tempo=0.05
		sessao.enviar({"t":"jogador","andar":andar,"e":_estado_jogador()},true)
		if sessao.sou_host():
			_enviar_mundo()
			_enviar_visuais()
	_tempo_resumo+=delta
	if sessao.sou_host() and _tempo_resumo>=0.5:
		_tempo_resumo=0
		sessao.enviar({"t":"resumo_campanha","andar":andar,"resumo":cena.registro_run.resumo_rede()})
	_atualizar_grupo()

func configurar(conexao: Node, raiz: Node2D) -> void:
	super.configurar(conexao,raiz)
	sessao.enviar({"t":"perfil","andar":andar,"perfil":sessao.Duelo.perfil_do(jogador)})

func _abate(_id: int) -> void: pass
func _aplicar_efeito(_m: Dictionary) -> void: pass

func _criar_espelho(d: Dictionary) -> Node:
	if d.get("k")=="erupcao_raizes":
		var efeito := preload("res://codigo/inimigos/erupcao_raizes.gd").new()
		efeito.somente_visual=true
		efeito.position=Vector2(float(d.get("x",0)),float(d.get("y",0)))
		cena.add_child(efeito)
		return efeito
	return super(d)

func _atualizar_espelho(id: int,no: Node,d: Dictionary) -> void:
	if d.get("k")=="erupcao_raizes":
		no.atualizar(clampf(float(d.get("t",0)),0,.55))
		return
	super(id,no,d)

func _enviar_mundo() -> void:
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
				var hashes: Array = []
				for s in _sprites.get(id, []):
					if is_instance_valid(s):
						poses.append([s.hframes, s.vframes, s.frame, s.flip_h, s.is_visible_in_tree(), snappedf(s.rotation, 0.01), [s.modulate.r, s.modulate.g, s.modulate.b, s.modulate.a], [s.position.x,s.position.y]])
						hashes.append(_hash_textura(s.texture))
				_vmax[id] = maxi(int(_vmax.get(id, 1)), int(no.vida))
				cache[id] = [id, snappedf(no.global_position.x, 0.1), snappedf(no.global_position.y, 0.1), no.vida, poses, _vmax[id], hashes, no.esta_congelado()]
			# Inimigo parado e adormecido não muda: só vai de novo no refresco, o que poupa banda com muita gente.
			if not completo and memoria.get(id) == cache[id]: continue
			memoria[id] = cache[id]
			estados.append(cache[id])
		_enviar_texturas_novas(pedido[0], estados)
		# Lotes pequenos respeitam o tamanho máximo do SCTP, inclusive em celular/Web.
		for inicio in range(0, maxi(1, estados.size()), 8):
			_seq += 1
			sessao.enviar_para(pedido[0], {"t": "mundo", "andar": andar, "seq": _seq, "inimigos": estados.slice(inicio, inicio + 8)}, true)

func _aplicar_golpe(m: Dictionary) -> void:
	var no: Node=_inimigos.get(int(m.get("id",0)))
	var antes: int=maxi(0,int(no.vida)) if is_instance_valid(no) else 0
	super._aplicar_golpe(m)
	var depois: int=maxi(0,int(no.vida)) if is_instance_valid(no) else 0
	if is_instance_valid(no) and antes>depois:cena.registro_run.acerto(str(m.get("de","")),no,antes-depois)
