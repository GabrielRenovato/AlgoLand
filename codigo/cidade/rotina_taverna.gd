extends Node

## Pedidos pelo cardápio das mesas (Dados.CARDAPIO): o morador escolhe da mesa e chama o Caio; o jogador pede sentado
## à mesa ou conversando com o Caio (pedir_jogador). O Caio prepara no balcão e leva até a mesa (ou até o jogador, se
## ele estiver de pé), com a refeição, os comentários e o convívio depois de comer. O Caio não senta: atende o tempo todo.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const Bandeja := preload("res://codigo/cidade/bandeja_taverna.gd")
const PASSEIOS := [Vector2(352, 250), Vector2(464, 200), Vector2(430, 152), Vector2(330, 200), Vector2(344, 296)]
## Centros das mesas da taverna (layout_interiores.py, pousada)
const MESAS := [Vector2(184, 226), Vector2(264, 226), Vector2(400, 226), Vector2(184, 298), Vector2(264, 298), Vector2(400, 298)]
const META_MESA := 30.0
## Quanto tempo o prato do jogador fica na mesa enquanto ele come
const TEMPO_REFEICAO_JOGADOR := 12.0
## Na festa de sábado as pausas do Caio (anotar, preparar, voltar) passam esse tanto mais rápido
const RITMO_PAUSAS_FESTA := 2.5
var vila: Node2D
var pedidos: Dictionary = {}
var entregas := 0
var avaliacoes: Array[Dictionary] = []
var visitas_mesas: Array[Vector2] = []
var passeios_concluidos := 0
var conversas_iniciadas := 0
## Pedidos dos jogadores ainda não entregues: [{"jogador", "prato"}], na ordem em que chegaram
var fila_jogadores: Array[Dictionary] = []
var _estado := "aguardando"
var _cliente := ""
## Jogador sendo atendido agora (no lugar de _cliente)
var _pedido_jogador: Dictionary = {}
var _espera := 5.0
var _bandeja: Node2D
var _pratos: Dictionary = {}
var _pratos_jogadores: Dictionary = {}
var _pedir_depois: Dictionary = {}
var _ultima_mesa := Vector2.INF
var _papo_dupla_em := 12.0
var _retomar_papo_em := 0.0

func _ready() -> void:
	vila = get_parent()
	name = "RotinaTaverna"

func _fala_livre() -> bool:
	return vila._participantes.is_empty() and vila.moradores.values().all(func(npc): return not npc._balao.visible)

func _janela_fala() -> bool:
	return vila.moradores.values().all(func(npc): return not npc._balao.visible)

func _falar_servico(npc: Node2D, texto: String, duracao: float) -> void:
	vila.fala_servico = true
	_retomar_papo_em = duracao + 0.5
	npc.dizer(texto, duracao)

## A taverna está servindo agora (Caio no balcão, no horário)
func atendendo() -> bool:
	if not is_instance_valid(vila) or not vila.moradores.has("bardo"):
		return false
	if not Dados.taverna_aberta(vila.hora_atual(), Calendario.dia_da_semana()):
		return false
	var caio: Node2D = vila.moradores["bardo"]
	return caio.visible and not caio.dormindo and not caio._saindo and not caio.agenda.get("dormindo", false)

## O jogador pediu um prato do cardápio (já validado e pago por quem chama). "" = aceito, senão o motivo
func pedir_jogador(jogador: Node2D, prato: String) -> String:
	if not Dados.CARDAPIO.has(prato):
		return "ESSE PRATO NAO EXISTE"
	if not atendendo():
		return "A TAVERNA ESTA FECHADA AGORA"
	for pedido in fila_jogadores:
		if pedido["jogador"] == jogador:
			return "SEU PEDIDO JA ESTA SAINDO"
	if not _pedido_jogador.is_empty() and _pedido_jogador["jogador"] == jogador:
		return "SEU PEDIDO JA ESTA SAINDO"
	fila_jogadores.append({"jogador": jogador, "prato": prato})
	var caio: Node2D = vila.moradores["bardo"]
	if _janela_fala():
		_falar_servico(caio, "Um %s saindo! Ja levo ate voce." % String(Dados.CARDAPIO[prato]["nome"]).to_lower(), 3.0)
	return ""

## O jogador tem um pedido esperando (para a conversa avisar)
func pedido_de(jogador: Node2D) -> String:
	for pedido in fila_jogadores:
		if pedido["jogador"] == jogador:
			return pedido["prato"]
	if not _pedido_jogador.is_empty() and _pedido_jogador["jogador"] == jogador:
		return _pedido_jogador["prato"]
	return ""

func _process(delta: float) -> void:
	_retomar_papo_em -= delta
	if _retomar_papo_em <= 0:
		vila.fala_servico = false
	_atualizar_clientes(delta)
	_atualizar_pratos_jogadores(delta)
	_conversar_duplas(delta)
	if not Dados.taverna_aberta(vila.hora_atual(), Calendario.dia_da_semana()):
		_cancelar()
		return
	var caio: Node2D = vila.moradores["bardo"]
	if not caio.visible or caio.dormindo or caio._saindo or caio.agenda.get("dormindo", false) or caio.interacao._tela_aberta:
		return
	for id in _pedir_depois.keys():
		_pedir_depois[id] = float(_pedir_depois[id]) - delta
	_espera -= delta * (RITMO_PAUSAS_FESTA if caio.agenda.get("festa", false) else 1.0)
	if _estado == "aguardando":
		if _espera > 0 or not _janela_fala():
			return
		if is_instance_valid(caio.parceiro_papo):
			vila._encerrar_papo()
		# Jogadores primeiro: pediram e pagaram
		while not fila_jogadores.is_empty():
			var pedido: Dictionary = fila_jogadores.pop_front()
			if _jogador_presente(pedido["jogador"]):
				_pedido_jogador = pedido
				_cliente = ""
				caio.atendendo_mesas = true
				caio._ir_ate(Dados.InteriorCasa.ponto("pousada", "balcao"))
				_estado = "balcao"
				return
			_devolver(pedido)
		var ordem: Array = Dados.PEDIDOS_MORADORES.keys().filter(func(id):
			var npc: Node2D = vila.moradores[id]
			return npc.visible and not npc.dormindo and not npc._saindo and not npc.agenda.get("dormindo", false) \
				and npc.assento.estado == "sentado" and not npc.interacao._tela_aberta and not npc.passeando_taverna \
				and float(_pedir_depois.get(id, 0)) <= 0 and pedidos.get(id, {}).get("estado", "descansando") == "descansando"
		)
		ordem.sort_custom(func(a, b):
			var mesa_a := _mesa_do_cliente(vila.moradores[a])
			var mesa_b := _mesa_do_cliente(vila.moradores[b])
			if (mesa_a == _ultima_mesa) != (mesa_b == _ultima_mesa):
				return mesa_a != _ultima_mesa
			return int(pedidos.get(a, {}).get("rodada", 0)) < int(pedidos.get(b, {}).get("rodada", 0))
		)
		if ordem.is_empty():
			_espera = 2.0
			return
		_cliente = ordem[0]
		_pedido_jogador = {}
		caio.atendendo_mesas = true
		var rodada := int(pedidos.get(_cliente, {}).get("rodada", 0))
		var cardapio: Array = Dados.PEDIDOS_MORADORES[_cliente]
		var prato: String = cardapio[rodada % cardapio.size()]
		pedidos[_cliente] = {"prato": prato, "comida": Dados.CARDAPIO[prato]["pedido"], "estado": "anotado", "rodada": rodada + 1}
		# Escolhe pelo cardápio da mesa e chama o Caio de lá mesmo
		var cliente_npc: Node2D = vila.moradores[_cliente]
		_falar_servico(cliente_npc, "Caio! Do cardapio, " + str(pedidos[_cliente]["comida"]) + ", por favor!", 4.0)
		_ultima_mesa = _mesa_do_cliente(cliente_npc)
		visitas_mesas.append(_ultima_mesa)
		_estado = "anotando"
		_espera = 4.0
		return
	if not _pedido_jogador.is_empty():
		_atender_jogador(caio)
		return
	var cliente: Node2D = vila.moradores.get(_cliente)
	if cliente == null or not cliente.visible or cliente.dormindo or cliente._saindo or cliente.agenda.get("dormindo", false):
		_cancelar_pedido()
		return
	match _estado:
		"anotando":
			if _espera <= 0 and _janela_fala():
				caio.olhar_para(cliente.position)
				_falar_servico(caio, "Saindo! Ja levo para a sua mesa.", 3.0)
				caio._ir_ate(Dados.InteriorCasa.ponto("pousada", "balcao"))
				_estado = "balcao"
		"balcao":
			if caio.caminho.is_empty():
				pedidos[_cliente]["estado"] = "preparando"
				_espera = 4.0
				_estado = "preparando"
		"preparando":
			if _espera <= 0:
				_pegar_bandeja(caio)
				caio._ir_ate(_mesa_do_cliente(cliente) + Vector2(40, -14))
				pedidos[_cliente]["estado"] = "levando"
				_estado = "mesa"
		"mesa":
			if caio.caminho.is_empty():
				_entregar(cliente)
				caio.olhar_para(cliente.position)
				if _janela_fala():
					_falar_servico(caio, "Aqui esta seu pedido. Bom apetite!", 3.5)
				_espera = 4.0
				_estado = "retornando"
		"retornando":
			if _espera <= 0:
				_voltar_ao_balcao(caio)

# --- Pedido do jogador --------------------------------------------------------------------------------------------

func _atender_jogador(caio: Node2D) -> void:
	var jogador: Node2D = _pedido_jogador["jogador"]
	if _estado != "retornando" and not _jogador_presente(jogador):
		_devolver(_pedido_jogador)
		_cancelar_pedido()
		return
	match _estado:
		"balcao":
			if caio.caminho.is_empty():
				_espera = 4.0
				_estado = "preparando"
		"preparando":
			if _espera <= 0:
				_pegar_bandeja(caio)
				caio._ir_ate(_ponto_entrega(jogador))
				_espera = 1.0
				_estado = "mesa"
		"mesa":
			# Ele pode ter mudado de lugar: refaz a rota de tempos em tempos
			if not caio.caminho.is_empty() and _espera <= 0:
				caio._ir_ate(_ponto_entrega(jogador))
				_espera = 1.0
			if caio.caminho.is_empty():
				if caio.position.distance_to(_ponto_entrega(jogador)) > 24.0:
					caio._ir_ate(_ponto_entrega(jogador))
					return
				caio.olhar_para(jogador.position)
				_servir_jogador(jogador, String(_pedido_jogador["prato"]))
				if _janela_fala():
					_falar_servico(caio, "Aqui esta: %s. Bom apetite!" % String(Dados.CARDAPIO[_pedido_jogador["prato"]]["nome"]).to_lower(), 3.5)
				_espera = 3.0
				_estado = "retornando"
		"retornando":
			if _espera <= 0:
				_pedido_jogador = {}
				_voltar_ao_balcao(caio)

func _jogador_presente(jogador: Variant) -> bool:
	return is_instance_valid(jogador) and jogador.is_inside_tree() and jogador.get_world_2d() == vila.get_world_2d() \
			and not bool(jogador.get("estaMorto"))

## A mesa em que o jogador está sentado (Vector2.INF = não está numa mesa)
func mesa_do_jogador(jogador: Node2D) -> Vector2:
	if not bool(jogador.get("esta_sentado")):
		return Vector2.INF
	for mesa in MESAS:
		var local: Vector2 = vila.to_local(jogador.global_position)
		if absf(local.x - mesa.x) <= META_MESA and absf(local.y - mesa.y) <= META_MESA:
			return mesa
	return Vector2.INF

func _ponto_entrega(jogador: Node2D) -> Vector2:
	var mesa := mesa_do_jogador(jogador)
	if mesa != Vector2.INF:
		return mesa + Vector2(40, -14)
	return vila.to_local(jogador.global_position) + Vector2(18, 0)

## Entrega ao jogador: a comida faz efeito na hora (vida); sentado à mesa, o prato fica na frente dele enquanto come
func _servir_jogador(jogador: Node2D, prato: String) -> void:
	if is_instance_valid(_bandeja):
		_bandeja.queue_free()
	_bandeja = null
	var dados: Dictionary = Dados.CARDAPIO[prato]
	if jogador.has_method("curar") and float(dados["cura"]) > 0.0:
		jogador.curar(maxi(1, roundi(jogador.estatisticas.hp_maximo * float(dados["cura"]))))
	Sons.tocar("beber", 0.05)
	get_tree().call_group(jogador.grupo_hud(), "anunciar", String(dados["nome"]), "VIDA RECUPERADA", 2.0)
	entregas += 1
	var mesa := mesa_do_jogador(jogador)
	if mesa == Vector2.INF:
		return
	_limpar_prato_jogador(jogador)
	var local: Vector2 = vila.to_local(jogador.global_position)
	var prato_no := Bandeja.new()
	prato_no.position = Vector2(clampf(local.x, mesa.x - 14, mesa.x + 14), mesa.y + (-12 if local.y > mesa.y else -23))
	prato_no.z_as_relative = false
	prato_no.z_index = Profundidade.z_de(mesa.y) + 1
	vila.add_child(prato_no)
	_pratos_jogadores[jogador] = {"no": prato_no, "tempo": TEMPO_REFEICAO_JOGADOR}

func _atualizar_pratos_jogadores(delta: float) -> void:
	for jogador in _pratos_jogadores.keys():
		var dados: Dictionary = _pratos_jogadores[jogador]
		dados["tempo"] = float(dados["tempo"]) - delta
		var sentado: bool = is_instance_valid(jogador) and bool(jogador.get("esta_sentado"))
		if not sentado or float(dados["tempo"]) <= 0.0 or not is_instance_valid(dados["no"]):
			_limpar_prato_jogador(jogador)
			continue
		dados["no"].porcao = clampf(ceilf(3.0 * float(dados["tempo"]) / TEMPO_REFEICAO_JOGADOR) / 3.0, 0, 1)
		dados["no"].queue_redraw()

func _limpar_prato_jogador(jogador: Variant) -> void:
	var dados: Dictionary = _pratos_jogadores.get(jogador, {})
	if is_instance_valid(dados.get("no")):
		dados["no"].queue_free()
	_pratos_jogadores.erase(jogador)

## Pedido que não deu para entregar (o jogador saiu, a taverna fechou): as Brasas voltam
func _devolver(pedido: Dictionary) -> void:
	Progresso.brasas += int(Dados.CARDAPIO[pedido["prato"]]["preco"])
	Progresso.brasas_alteradas.emit(Progresso.brasas)
	Progresso.salvar()

# --- Comum -------------------------------------------------------------------------------------------------------

func _pegar_bandeja(caio: Node2D) -> void:
	if is_instance_valid(_bandeja):
		_bandeja.queue_free()
	_bandeja = Bandeja.new()
	_bandeja.position = Vector2(6, -5)
	caio.add_child(_bandeja)

func _voltar_ao_balcao(caio: Node2D) -> void:
	caio._ir_ate(Dados.InteriorCasa.ponto("pousada", "balcao"))
	caio.atendendo_mesas = false
	_estado = "aguardando"
	_espera = 4.0

func _mesa_do_cliente(cliente: Node2D) -> Vector2:
	if Dados.LUGARES_FESTA.has(cliente.id):
		return Vector2(Dados.LUGARES_FESTA[cliente.id].x, 226)
	return Vector2(264, 226)

func _entregar(cliente: Node2D) -> void:
	if is_instance_valid(_bandeja):
		_bandeja.queue_free()
	_bandeja = null
	_limpar_prato(_cliente)
	var prato := Bandeja.new()
	var mesa := _mesa_do_cliente(cliente)
	prato.position = mesa + Vector2(0, -12 if cliente.id in Dados.COSTAS_FESTA else -23)
	prato.z_as_relative = false
	prato.z_index = Profundidade.z_de(mesa.y) + 1
	vila.add_child(prato)
	_pratos[_cliente] = prato
	pedidos[_cliente]["estado"] = "comendo"
	pedidos[_cliente]["tempo"] = randf_range(14.0, 23.0)
	pedidos[_cliente]["duracao"] = pedidos[_cliente]["tempo"]
	_pedir_depois[_cliente] = randf_range(100.0, 160.0)
	entregas += 1

func _atualizar_clientes(delta: float) -> void:
	for id in pedidos.keys():
		var npc: Node2D = vila.moradores[id]
		var pedido: Dictionary = pedidos[id]
		if not npc.visible or npc._saindo or npc.agenda.get("dormindo", false):
			npc.passeando_taverna = false
			_limpar_prato(id)
			pedido["estado"] = "indo_dormir"
			continue
		pedido["tempo"] = float(pedido.get("tempo", 0)) - delta
		match pedido["estado"]:
			"comendo":
				if is_instance_valid(_pratos.get(id)):
					_pratos[id].porcao = clampf(ceilf(3.0 * pedido["tempo"] / pedido["duracao"]) / 3.0, 0, 1)
					_pratos[id].queue_redraw()
				if pedido["tempo"] <= 0:
					pedido["estado"] = "avaliando"
			"avaliando":
				if _janela_fala() and not npc.interacao._tela_aberta:
					var boa := randf() < 0.7
					var texto: String = (["O pedido estava otimo, Caio! Obrigado pelo capricho.", "Gostei muito. Comer com os vizinhos deixa a noite melhor."] if boa else ["Hoje ja provei melhor, Caio. Na proxima voce acerta!", "Podia ter vindo mais quente. Mas a companhia esta excelente."]).pick_random()
					_falar_servico(npc, texto, 4.5)
					avaliacoes.append({"id": id, "texto": texto, "boa": boa})
					pedido["estado"] = "comentando"
					pedido["tempo"] = 5.0
			"comentando":
				if pedido["tempo"] <= 0 and not is_instance_valid(npc.parceiro_papo):
					_limpar_prato(id)
					npc.passeando_taverna = true
					var outro := _parceiro(id)
					if outro != null and outro.visible and randf() < 0.5:
						npc._ir_ate(outro.position + Vector2(30, 0))
						pedido["estado"] = "indo_conversar"
						pedido["parceiro"] = outro.id
					else:
						npc._ir_ate(PASSEIOS.pick_random())
						pedido["estado"] = "passeando"
					pedido["tempo"] = randf_range(10, 20)
			"indo_conversar":
				if npc.caminho.is_empty() and npc.assento.estado == "pe" and _fala_livre():
					var outro: Node2D = vila.moradores[pedido["parceiro"]]
					if outro.visible and not outro._saindo and npc.position.distance_to(outro.position) <= vila.DISTANCIA_PAPO:
						vila._papo(npc, outro)
						conversas_iniciadas += 1
						pedido["estado"] = "conversando"
					else:
						pedido["estado"] = "voltando"
						npc.passeando_taverna = false
			"conversando":
				if not is_instance_valid(npc.parceiro_papo):
					npc.passeando_taverna = false
					pedido["estado"] = "voltando"
			"passeando":
				if npc.caminho.is_empty() and pedido["tempo"] <= 0:
					passeios_concluidos += 1
					npc.passeando_taverna = false
					pedido["estado"] = "voltando"
			"voltando":
				if npc.assento.estado == "sentado":
					pedido["estado"] = "descansando"

func _parceiro(id: String) -> Node2D:
	for dupla in Dados.DUPLAS_FESTA:
		if id in dupla:
			return vila.moradores[dupla[1] if dupla[0] == id else dupla[0]]
	return null

func _conversar_duplas(delta: float) -> void:
	_papo_dupla_em -= delta
	if _papo_dupla_em > 0 or not _fala_livre():
		return
	for dupla in Dados.DUPLAS_FESTA:
		var a: Node2D = vila.moradores[dupla[0]]
		var b: Node2D = vila.moradores[dupla[1]]
		if a.assento.estado != "sentado" or b.assento.estado != "sentado" or a.atendendo_mesas or b.atendendo_mesas:
			continue
		var chave: String = vila._chave_papo(a.id, b.id)
		if Time.get_ticks_msec() / 1000.0 < float(vila._reencontro.get(chave, 0)):
			continue
		vila._papo(a, b)
		conversas_iniciadas += 1
		_papo_dupla_em = 30.0
		return

func _limpar_prato(id: String) -> void:
	if is_instance_valid(_pratos.get(id)):
		_pratos[id].queue_free()
	_pratos.erase(id)

func _cancelar_pedido() -> void:
	if is_instance_valid(vila) and vila.moradores.has("bardo"):
		vila.moradores["bardo"].atendendo_mesas = false
	if is_instance_valid(_bandeja):
		_bandeja.queue_free()
	_bandeja = null
	_estado = "aguardando"
	_cliente = ""
	_pedido_jogador = {}
	_espera = 5.0

func _cancelar() -> void:
	vila.fala_servico = false
	if not _pedido_jogador.is_empty() and _estado != "retornando":
		_devolver(_pedido_jogador)
	for pedido in fila_jogadores:
		_devolver(pedido)
	fila_jogadores.clear()
	_cancelar_pedido()
	for id in _pratos.keys():
		_limpar_prato(id)
	pedidos.clear()
	_pedir_depois.clear()
