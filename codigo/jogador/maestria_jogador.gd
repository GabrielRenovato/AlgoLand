extends Node
## Liga eventos de combate confirmados ao progresso individual e às técnicas físicas.
signal acerto_confirmado(alvo: Node, dano: int)
signal defesa_confirmada
const Catalogo := preload("res://codigo/dados/catalogo_maestria.gd")
const Modelo := preload("res://codigo/modelos/modelo_maestria.gd")
var jogador: CharacterBody2D
var modelo := Modelo.new()
var executando := false
var tecnica: Dictionary = {}
var tempo_tecnica := 0.0
var direcao := Vector2.DOWN
var tipo_golpe := ""
var golpe_id := 0
var _proximo_evento := 0
var _impactou := false
var _alvos: Dictionary = {}
var _bonus: Dictionary = {}
var _esquiva_ate := 0
var _guarda_ate := 0
var _recarga_ate := 0
var _sequencia_arco := 0
var _ultimo_disparo := 0
var _resumo: Dictionary = {}
var _silencio := 0.0
var _camada: CanvasLayer
var _botoes: Array[Button] = []

func iniciar(dono: CharacterBody2D, legado: bool) -> void:
	jogador = dono
	var inventario_arquivo: String = jogador.inventario.caminho_save
	var arquivo := "user://maestria_p2.json" if jogador.eh_p2 else "user://maestria.json"
	if inventario_arquivo not in ["user://inventario.json","user://inventario_p2.json"]:
		arquivo = inventario_arquivo.left(inventario_arquivo.rfind("/")+1) + ("maestria_p2.json" if jogador.eh_p2 else "maestria.json")
	var novo := not FileAccess.file_exists(arquivo)
	var erro := modelo.iniciar(arquivo, legado)
	if erro != OK:
		push_error("Maestria indisponível; save preservado: %s" % error_string(erro))
	if erro == OK and novo:
		erro = modelo.salvar()
		if erro != OK: push_error("Não foi possível iniciar a maestria: " + error_string(erro))
	modelo.alterado.connect(_recalcular)
	_recalcular()
	_montar_interface()

func familia_atual() -> String:
	var arma = jogador.inventario.equipados.get("arma")
	return Catalogo.familia(arma.tipo) if arma != null and arma.categoria == "arma" and not jogador.inventario.vara_na_mao else ""

func _recalcular() -> void:
	_bonus.clear()
	for id in modelo.aprendidos:
		var dado := Catalogo.no(id)
		var chave: String = dado.familia + ":" + dado.efeito
		_bonus[chave] = float(_bonus.get(chave, 0.0)) + float(dado.valor)

func bonus(efeito: String, familia := "") -> float:
	var f: String = familia_atual() if familia.is_empty() else familia
	return float(_bonus.get(f + ":" + efeito, 0.0))

func bonus_defesa(efeito: String) -> float:
	return minf(0.30, bonus(efeito) + (bonus(efeito, "escudo") if jogador.usando_escudo else 0.0))

func limite_combo(familia := "") -> int:
	var f: String = familia_atual() if familia.is_empty() else familia
	return 3 if modelo.legado or modelo.nivel(f) >= 5 else 2

func novo_evento() -> int:
	_proximo_evento+=1
	return _proximo_evento

func registrar_esquiva() -> void:
	_esquiva_ate = Time.get_ticks_msec() + 1800

func novo_golpe() -> void:
	golpe_id = novo_evento()
	var arma = jogador.inventario.equipados.get("arma")
	tipo_golpe = arma.tipo if arma != null else ""

func multiplicador(f: String, combo: int) -> float:
	var total := 1.0
	if combo >= limite_combo(f): total += bonus("fim_combo", f)
	if Time.get_ticks_msec() < _esquiva_ate: total += bonus("apos_esquiva", f)
	if Time.get_ticks_msec() < _guarda_ate: total += bonus("apos_guarda", f)
	return total

func consumir_abertura() -> void:
	_esquiva_ate = 0
	_guarda_ate = 0

func _registro(alvo: Node) -> Dictionary:
	var id := alvo.get_instance_id()
	if not _alvos.has(id):
		var vida: float = maxf(1.0, float(alvo.get("vida_maxima") if alvo.get("vida_maxima") != null else alvo.get("vida")))
		_alvos[id] = {"referencia":weakref(alvo), "vida":vida, "ataque":0.0, "defesa":0.0, "eventos":{}}
	return _alvos[id]

func registrar_acerto(alvo: Node, dano: int, vida_antes: int, tipo: String, evento: int) -> void:
	var f := Catalogo.familia(tipo)
	if not modelo.pronto or f.is_empty() or dano <= 0 or vida_antes <= 0 or not is_instance_valid(alvo) or not alvo.is_in_group("enemy") or alvo.get_meta("sem_maestria",false): return
	if alvo.get_script() == preload("res://codigo/coop_online/inimigo_replica.gd"): return
	var registro := _registro(alvo)
	# A vida original inclui o golpe que acabou de entrar; a queda no último golpe não reduz o orçamento.
	registro.vida = maxf(float(registro.vida), float(vida_antes))
	var chave := "%s:%d" % [f, evento]
	if registro.eventos.has(chave): return
	registro.eventos[chave] = true
	var aceito := minf(float(mini(dano, vida_antes)), float(registro.vida) - float(registro.ataque))
	if aceito <= 0: return
	registro.ataque += aceito
	acerto_confirmado.emit(alvo,mini(dano,vida_antes))
	var xp := maxf(20, sqrt(float(registro.vida)) * 6.0) * aceito / float(registro.vida)
	xp *= clampf(1.0 / (1.0 + modelo.nivel(f) / 30.0), 0.20, 1.0)
	_creditar(f, maxi(1, roundi(xp)))

func registrar_defesa(dano: int, perfeito: bool, forca: Vector2) -> void:
	if dano <= 0 or not modelo.pronto: return
	defesa_confirmada.emit()
	_guarda_ate = Time.get_ticks_msec() + 2200
	# Identifica uma ameaça real e próxima. Não dá XP por chamar resolver() no vazio.
	var atacante: Node2D
	var distancia := 90.0
	for no in get_tree().get_nodes_in_group("enemy"):
		if not no is Node2D or no.get("esta_morto") or no.get_meta("sem_maestria",false) or no.get_world_2d() != jogador.get_world_2d(): continue
		var para: Vector2 = no.global_position - jogador.global_position
		if forca != Vector2.ZERO and para.normalized().dot(-forca.normalized()) < 0.2: continue
		if para.length() < distancia: atacante = no; distancia = para.length()
	if atacante == null: return
	var registro := _registro(atacante)
	var agora := Time.get_ticks_msec()
	if agora < int(registro.get("defesa_ate", 0)): return
	registro.defesa_ate = agora + 350
	var teto := maxf(8.0, sqrt(float(registro.vida)) * 2.4)
	var xp := minf(4.0 if perfeito else 2.0, teto - float(registro.defesa))
	if xp <= 0: return
	registro.defesa += xp
	var f := "escudo" if jogador.usando_escudo else familia_atual()
	if not f.is_empty(): _creditar(f, maxi(1, roundi(xp)))

func _creditar(f: String, xp: int, ticket := "") -> void:
	var anterior := modelo.nivel(f)
	if modelo.adicionar_xp(f, xp, ticket) != OK: return
	_resumo[f] = int(_resumo.get(f,0)) + xp
	_silencio = 0
	if modelo.nivel(f) > anterior:
		get_tree().call_group(jogador.grupo_hud(), "maestria_subiu", Catalogo.pontos(modelo.nivel(f)) > Catalogo.pontos(anterior))

func receber_credito(ticket: String, f: String, xp: int) -> void:
	if ticket.is_empty() or ticket in modelo.recebidos or not f in Catalogo.FAMILIAS or xp < 1 or xp > 180: return
	var reduzido:=maxi(1,roundi(xp*clampf(1.0/(1.0+modelo.nivel(f)/30.0),0.20,1.0)))
	_creditar(f,reduzido,ticket)

func pode_redistribuir() -> bool:
	var raiz := Cooperativo.cena_de(jogador)
	return raiz != null and ((raiz.get("regiao") == "vila") or raiz.scene_file_path.begins_with("res://cenas/cidade")) and not executando

func _selecionada(slot: int, f: String) -> String:
	var lista: Array = modelo.equipados.get(f, {}).get("tecnicas", [])
	return str(lista[slot]) if slot >= 0 and slot < lista.size() else ""

func executar(slot: int, f := "") -> String:
	if f.is_empty(): f = familia_atual()
	var id := _selecionada(slot, f)
	if id.is_empty(): return "EQUIPE UMA TECNICA NA ARVORE"
	var no := Catalogo.no(id)
	if id not in modelo.aprendidos: return "TECNICA NAO APRENDIDA"
	if f == "escudo" and not jogador.usando_escudo: return "EQUIPE UM ESCUDO"
	if f != "escudo" and f != familia_atual(): return "ARMA INCOMPATIVEL"
	if executando or Time.get_ticks_msec() < _recarga_ate or jogador._esta_atacando or jogador.estaMorto or jogador.caido or jogador.esta_em_dash or jogador.modo_fazenda or jogador.esta_em_acao_fazenda or not jogador.movimento_habilitado or jogador.ataques_bloqueados or not EventosJogo.interface_de(jogador)._telas_abertas.is_empty(): return "AGUARDE UMA ABERTURA"
	if no.ramo == 2 and Time.get_ticks_msec() >= _guarda_ate: return "BLOQUEIE OU APARE ANTES DE RESPONDER"
	tecnica = Catalogo.perfil(f, no.ramo).duplicate()
	tecnica.id = id
	var custo: float = tecnica.folego * (1.0 - bonus("custo_tecnica", f))
	if jogador.stamina < custo: tecnica = {}; return "FOLEGO INSUFICIENTE"
	jogador.defesa.cancelar()
	jogador._cancelar_golpe()
	jogador._gastar_stamina(custo)
	direcao = jogador.direcao_da_acao(jogador.direcao_apontada()).normalized()
	jogador._direcao_ataque = direcao
	jogador._direcao_golpe_3d = direcao
	jogador.virar_para(direcao)
	jogador.velocity = Vector2.ZERO
	executando = true; tempo_tecnica = 0; _impactou = false
	novo_golpe()
	jogador.set_meta("tecnica_maestria", tecnica)
	return ""

func atualizar_tecnica(delta: float) -> void:
	if not executando: return
	tempo_tecnica += delta
	tecnica.tempo = tempo_tecnica
	var preparo: float = tecnica.preparo
	var duracao: float = tecnica.duracao
	if tempo_tecnica >= preparo and not _impactou:
		_impactou = true
		jogador._fase_combo = 1 if tecnica.ramo != 1 else 3
		jogador._temporizador.start(duracao)
		jogador._esta_atacando = true
		var animacao := ("AtaqueLancaSlash_%d" % ([2,3,1][int(tecnica.ramo)])) if tecnica.familia == "lanca" else ("AtaqueEspadaSlash_%d" % (int(tecnica.ramo)+1))
		jogador._arvore_animacao.set("parameters/%s/blend_position" % animacao,direcao)
		jogador._maquina_estados.travel(animacao)
		# A área comum fica desligada: o contato da técnica é feito uma única vez no tempo do movimento.
		jogador.get_node("AreaAtaque").set_deferred("monitoring", false)
		jogador.acao_visual.emit("ataque", duracao, jogador._fase_combo)
	if _impactou and tempo_tecnica < preparo + duracao:
		var p := (tempo_tecnica - preparo) / duracao
		if p < 0.45:
			jogador.move_and_collide(direcao * float(tecnica.avanco) * delta / (duracao * 0.45))
		if p >= 0.45 and not tecnica.get("contato",false):
			tecnica.contato = true
			_impacto_tecnica()
	if tempo_tecnica >= preparo + duracao + float(tecnica.recuperacao): cancelar()

func iniciar_finalizador(f: String) -> bool:
	var perfil := finalizador(f)
	if perfil.is_empty() or executando: return false
	var custo: float = 10.0 * (1.0 - bonus("custo_tecnica",f))
	if jogador.stamina < custo: return false
	jogador.defesa.cancelar()
	jogador._cancelar_golpe()
	jogador._gastar_stamina(custo)
	tecnica = perfil.duplicate()
	tecnica.finalizador = true
	tecnica.preparo = 0.12 if perfil.ramo != 1 else 0.28
	tecnica.recuperacao = 0.12 if perfil.ramo == 2 else 0.25
	tecnica.avanco = 12.0 if perfil.ramo == 0 else 0.0
	direcao = jogador.direcao_da_acao(jogador.direcao_apontada()).normalized()
	jogador._direcao_ataque = direcao
	jogador._direcao_golpe_3d = direcao
	executando = true; tempo_tecnica = 0; _impactou = false
	novo_golpe()
	jogador.set_meta("tecnica_maestria",tecnica)
	return true

func _impacto_tecnica() -> void:
	if tecnica.familia == "arco":
		var flecha := preload("res://codigo/jogador/flecha.gd").new()
		Cooperativo.cena_de(jogador).add_child(flecha)
		flecha.global_position = jogador.global_position + Vector2(0, 2) + direcao * 12
		flecha.iniciar(jogador, direcao)
		flecha._disparo["tecnica"] = tecnica.duplicate()
		return
	for alvo in get_tree().get_nodes_in_group("enemy"):
		if not alvo is Node2D or alvo.get_world_2d() != jogador.get_world_2d() or alvo.get("esta_morto"): continue
		var para: Vector2 = alvo.global_position - jogador.global_position
		if alvo.has_method("ponto_de_acerto_proximo"): para = alvo.ponto_de_acerto_proximo(jogador.global_position) - jogador.global_position
		if para.length() > float(tecnica.alcance) or (para.length() > 1 and para.normalized().dot(direcao) < float(tecnica.cone)): continue
		var consulta := PhysicsRayQueryParameters2D.create(jogador.global_position + Vector2(0, 8), alvo.global_position, 64)
		if not jogador.get_world_2d().direct_space_state.intersect_ray(consulta).is_empty(): continue
		jogador.aplicar_golpe(alvo, direcao, float(tecnica.dano) * (1.0 + bonus("dominio_%d" % tecnica.ramo, tecnica.familia)), float(tecnica.empurrao), {"tipo":"escudo_basico" if tecnica.familia == "escudo" else tipo_golpe,"evento_maestria":golpe_id,"especial":true,"finalizador":tecnica.get("finalizador",false)})

func cancelar() -> void:
	if not executando: return
	executando = false
	_recarga_ate = Time.get_ticks_msec() + 350
	jogador.remove_meta("tecnica_maestria")
	jogador._cancelar_golpe()
	jogador.velocity = Vector2.ZERO
	tecnica = {}

func finalizador(f: String) -> Dictionary:
	var id: String = modelo.equipados.get(f, {}).get("finalizador", "")
	if id.is_empty(): return {}
	var dado := Catalogo.no(id)
	return Catalogo.perfil(f, dado.ramo)

func _montar_interface() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 6
	add_child(_camada)
	for slot in 2:
		var botao := Button.new()
		botao.focus_mode = Control.FOCUS_NONE
		botao.custom_minimum_size = Vector2(32, 32)
		botao.add_theme_font_size_override("font_size", 10)
		botao.pressed.connect(_pedir.bind(slot))
		_camada.add_child(botao)
		_botoes.append(botao)

func _pedir(slot: int) -> void:
	var f := familia_atual()
	if jogador.usando_escudo and (jogador.defesa.estado != 0 or _selecionada(slot, f).is_empty()): f = "escudo"
	var motivo := executar(slot, f)
	if not motivo.is_empty(): get_tree().call_group(jogador.grupo_hud(), "avisar", motivo)

func _unhandled_input(evento: InputEvent) -> void:
	if not jogador.movimento_habilitado or jogador.ataques_bloqueados or jogador.modo_fazenda: return
	for slot in 2:
		if evento.is_action_pressed(jogador.acao("tecnica_%d" % (slot + 1))):
			get_viewport().set_input_as_handled()
			_pedir(slot)

func _process(delta: float) -> void:
	if not is_instance_valid(jogador): return
	_silencio += delta
	if _silencio > 6 and not _resumo.is_empty():
		for f in _resumo: get_tree().call_group(jogador.grupo_hud(), "avisar", "%s: +%d DOMINIO" % [Catalogo.NOMES[f], _resumo[f]])
		_resumo.clear()
		for id in _alvos.keys():
			if _alvos[id].referencia.get_ref() == null: _alvos.erase(id)
	var interface: Node = EventosJogo.interface_de(jogador)
	if interface != null and _camada.get_parent() != interface: _camada.reparent(interface)
	var tamanho:Vector2=interface.get_viewport().get_visible_rect().size if interface != null else jogador.get_viewport_rect().size
	var disponivel: bool = interface != null and interface._telas_abertas.is_empty() and jogador.movimento_habilitado and not jogador.modo_fazenda and not jogador.estaMorto
	var altura := tamanho.y - 46.0 - Controle.margens_seguras().w
	var hud := get_tree().get_first_node_in_group(jogador.grupo_hud())
	if hud != null and hud.get("barra_armas") != null:
		var barra: Control = hud.barra_armas._coluna
		if barra.is_visible_in_tree():
			var area: Rect2 = barra.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, barra.size)
			if area.get_center().y > tamanho.y * 0.5: altura = minf(altura, area.position.y - 38.0)
	for slot in 2:
		var f := familia_atual()
		if jogador.usando_escudo and (jogador.defesa.estado != 0 or _selecionada(slot, f).is_empty()): f = "escudo"
		var id := _selecionada(slot, f)
		var botao := _botoes[slot]
		botao.visible = disponivel and not id.is_empty()
		botao.position = Vector2(tamanho.x * 0.5 + (slot - 1) * 36 + 2, altura)
		botao.text = str(slot + 1) if Controle.usando_toque else Controle.rotulo_acao(jogador.acao("tecnica_%d" % (slot+1)))
		botao.tooltip_text = str(Catalogo.no(id).get("nome", "")) + (" (DEFENDA + TECNICA PARA USAR O ESCUDO)" if jogador.usando_escudo else "")
		botao.disabled = executando or Time.get_ticks_msec() < _recarga_ate

func tentar_finalizador_arco() -> bool:
	var agora:=Time.get_ticks_msec()
	_sequencia_arco=1 if agora-_ultimo_disparo>2500 else _sequencia_arco+1
	_ultimo_disparo=agora
	if _sequencia_arco<3:return false
	_sequencia_arco=0
	return iniciar_finalizador("arco")

