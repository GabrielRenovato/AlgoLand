extends "res://codigo/logica/gerenciador_de_ondas.gd"

## Protótipo de fenda. Conserva o contrato das ondas para saque, melhorias, morte e coop.
## O terreno e o gerenciador da arena original permanecem independentes desta cena.
signal progresso_andar_alterado

enum Etapa { PREPARANDO, EXPLORANDO, INVOCANDO, GUARDIAO, CONCLUIDO, PARADO }
const Catalogo := preload("res://codigo/fendas/catalogo_andares.gd")
var META_PROGRESSO := 35
const RAIO_ALERTA := 175.0
@export var economizar_patrulhas := OS.has_feature("android")
const MARGEM_PATRULHA := 128.0
const CONSULTAS_PATRULHA_POR_QUADRO := 4
var _quadro_patrulhas := -1
var _areas_patrulha: Array[Dictionary] = []
var _consultas_patrulha := 0
var etapa := Etapa.PREPARANDO
var pontos := 0
var guardiao: Node2D
var _adormecidos: Array[Node2D] = []
var _geracao := 0
var _aviso_guardiao: Node2D
var _tempo_alerta := 0.0
var posicao_guardiao := Vector2.ZERO
var guia: Node2D
var tesouro: Node2D
var encontro: Node2D

func _preparar_patrulhas() -> void:
	var quadro := Engine.get_physics_frames()
	if quadro==_quadro_patrulhas:return
	_quadro_patrulhas=quadro
	_consultas_patrulha=0
	_areas_patrulha.clear()
	for parte in get_tree().get_nodes_in_group("jogadores"):
		if not is_instance_valid(parte) or parte.estaMorto or parte.caido:continue
		var area: Rect2=parte.get_canvas_transform().affine_inverse()*parte.get_viewport_rect()
		if parte.has_meta("parceiro_coop"): area = Rect2(parte.global_position - Vector2(350, 250), Vector2(700, 500))
		_areas_patrulha.append({"mundo":parte.get_world_2d(),"area":area.grow(MARGEM_PATRULHA)})

func patrulha_proxima(inimigo: Node2D) -> bool:
	if not economizar_patrulhas:return true
	_preparar_patrulhas()
	for entrada in _areas_patrulha:
		if entrada.mundo==inimigo.get_world_2d() and entrada.area.has_point(inimigo.global_position):return true
	return false

func reservar_rota_patrulha() -> bool:
	if not economizar_patrulhas:return true
	_preparar_patrulhas()
	if _consultas_patrulha>=CONSULTAS_PATRULHA_POR_QUADRO:return false
	_consultas_patrulha+=1
	return true

func _abrir_janela_entre_ondas() -> void:
	# Nas fendas a vitória chama o guia, sem abrir um menu em cima do saque.
	var geracao := _geracao
	await get_tree().create_timer(ATRASO_JANELA).timeout
	if geracao!=_geracao or ondas_paradas or onda_em_andamento or etapa!=Etapa.CONCLUIDO or jogador.estaMorto: return
	if is_instance_valid(guia): return
	var raiz := get_parent().get_parent()
	var mapa: RID = jogador.get_world_2d().navigation_map
	var ponto: Vector2 = jogador.global_position+Vector2(48,12)
	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius=18
	consulta.shape=forma
	consulta.collision_mask=64
	for deslocamento in [Vector2(48,12),Vector2(-48,12),Vector2(0,55),Vector2(0,-55),Vector2(72,0),Vector2(-72,0)]:
		var candidato := NavigationServer2D.map_get_closest_point(mapa,jogador.global_position+deslocamento)
		consulta.transform=Transform2D(0,candidato+Vector2(0,9))
		if candidato.distance_to(jogador.global_position)<28: continue
		if jogador.get_world_2d().direct_space_state.intersect_shape(consulta,1).is_empty():
			ponto=candidato
			break
	guia=preload("res://codigo/fendas/guia_andar.gd").new()
	guia.gerente=self
	guia.position=raiz.to_local(ponto)
	raiz.add_child(guia)
	get_tree().call_group("hud","anunciar","ORION CHEGOU","FALE COM O GUIA PARA SE PREPARAR",2.5)

func _ready() -> void:
	add_to_group("gerenciador_andar")
	super()
	_aplicar_estacao_do_andar.call_deferred()

## Cada andar tem a sua estação (campo "estacao" da planta); o Calendario, a vila e a fazenda não são tocados. O clima do
## andar acompanha essa estação (o Estacoes avisa o Clima) e é sorteado por onda, sem passar para o clima do mundo
func _aplicar_estacao_do_andar() -> void:
	var raiz := get_parent().get_parent()
	var estacoes := raiz.get_node_or_null("Terrains/Estacoes")
	var planta: Dictionary = Catalogo.PLANTAS[clampi(int(raiz.get_meta("planta_andar", Catalogo.indice(onda_atual))) - 1, 0, Catalogo.PLANTAS.size() - 1)].data
	if estacoes != null and planta.has("estacao"):
		estacoes.fixar_estacao(int(planta["estacao"]))

## A estação que vale neste andar (a da planta, ou a do calendário se a planta não define)
func estacao_do_andar() -> int:
	var estacoes := get_parent().get_parent().get_node_or_null("Terrains/Estacoes")
	return int(estacoes.estacao_atual) if estacoes != null and estacoes.estacao_atual >= 0 else Calendario.estacao()

func iniciar_onda(ignorar_checkpoint: bool = false) -> void:
	var coop := get_tree().root.get_node_or_null("CoopOnline")
	if coop != null and coop.ativo and not coop.sou_host(): return
	if is_instance_valid(tesouro) and tesouro.ativo:
		return
	if Introducao.ativa() or onda_em_andamento or jogador.estaMorto:
		return
	if not ignorar_checkpoint and not Progresso.onda_comecou:
		onda_atual = maxi(onda_atual, Progresso.onda_inicial)
	var raiz := get_parent().get_parent()
	if raiz.get_meta("planta_andar",0) != Catalogo.indice(onda_atual):
		if Transicao.ocupada: return
		onda_em_andamento = true
		Transicao.iniciar_onda_ao_chegar = true
		Transicao.ir_para(Catalogo.cena(onda_atual),"portal")
		return
	META_PROGRESSO = Catalogo.meta(onda_atual)
	# Modificadores compatíveis com a população fixa dos mapas; horda/elite ficam na arena antiga.
	var chave_evento := str(onda_atual)
	var anterior: String = Progresso.eventos_andares.get(str(onda_atual-1), "")
	var candidatos: Array = EVENTOS.filter(func(e): return not e.id in ["horda", "elite", anterior] and not (estacao_do_andar() == 3 and e.get("nao_no_inverno",false)))
	if not Progresso.eventos_andares.has(chave_evento):
		Progresso.eventos_andares[chave_evento] = candidatos[_rng.randi_range(0,candidatos.size()-1)].id if onda_atual >= 4 and _rng.randf() < chance_evento else ""
	var id_evento: String = Progresso.eventos_andares[chave_evento]
	var encontrados: Array = EVENTOS.filter(func(e): return e.id == id_evento)
	_definir_evento(encontrados[0] if not encontrados.is_empty() else {})
	_geracao += 1
	var geracao := _geracao
	ondas_paradas = false
	onda_bonus = false
	pontos = 0
	etapa = Etapa.PREPARANDO
	onda_em_andamento = true
	_adormecidos.clear()
	guardiao = null
	# A transição já posicionou os jogadores na chegada. O respiro permite andar;
	# iniciar o combate deve preservar esse deslocamento e a velocidade atual.
	multiplicador_vida_inimigo = mult_vida_onda(onda_atual) * (Cooperativo.MULT_VIDA_COOP if Cooperativo.com_dois() else 1.0)
	multiplicador_dano_inimigo = mult_dano_onda(onda_atual)
	if coop != null and coop.ativo:
		var n: int = coop.jogadores_na_partida()
		multiplicador_vida_inimigo = mult_vida_onda(onda_atual) * coop.mult_vida(n)
		multiplicador_dano_inimigo *= coop.mult_dano(n)
	# A preparação precisa da malha e das colisões já sincronizadas.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if geracao != _geracao or jogador.estaMorto: return
	NavigationServer2D.map_force_update(get_viewport().world_2d.navigation_map)
	gerador.limpar_populacao()
	inimigos_vivos = gerador.montar_populacao(geracao)
	total_inimigos_onda = inimigos_vivos
	if coop != null and coop.ativo:
		# Mais inimigos exigem uma meta proporcional, sem passar do que a população realmente entrega.
		var meta_online := roundi(META_PROGRESSO * coop.mult_quantidade(coop.jogadores_na_partida()))
		META_PROGRESSO = maxi(1, mini(meta_online, roundi(gerador.pontos_possiveis * 0.75)))
	if inimigos_vivos == 0:
		etapa = Etapa.PARADO
		onda_em_andamento = false
		push_error("Andar sem pontos caminhaveis para os encontros")
		return
	etapa = Etapa.EXPLORANDO
	Progresso.registrar_onda_iniciada(onda_atual)
	onda_iniciada.emit(onda_atual)
	atualizar_ui()
	progresso_andar_alterado.emit()
	if not is_instance_valid(tesouro):
		tesouro = preload("res://codigo/fendas/tesouro_mimicos.gd").new()
		tesouro.name = "TesouroMimicos"
		tesouro.gerente = self
		get_parent().get_parent().add_child(tesouro)
		tesouro.preparar()
	if is_instance_valid(encontro): encontro.queue_free()
	if onda_atual >= 2:
		encontro = preload("res://codigo/fendas/encontro_andar.gd").new()
		encontro.gerente = self
		var entrada: Vector2 = raiz.get_node("Terrains/Chegada_portal").global_position
		encontro.position = raiz.to_local(_ponto_encontro(entrada))
		raiz.add_child(encontro)

func _ponto_encontro(entrada: Vector2) -> Vector2:
	var mapa: RID = jogador.get_world_2d().navigation_map
	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 16
	consulta.shape = forma
	consulta.collision_mask = 64
	for deslocamento in [Vector2(-64,24),Vector2(64,24),Vector2(-80,48),Vector2(80,48),Vector2(0,96),Vector2(-96,0),Vector2(96,0)]:
		var ponto := NavigationServer2D.map_get_closest_point(mapa,entrada+deslocamento)
		if ponto.distance_to(entrada) < 30: continue
		if is_instance_valid(tesouro) and is_instance_valid(tesouro.portal) and ponto.distance_to(tesouro.portal.global_position) < 80: continue
		consulta.transform = Transform2D(0,ponto)
		if jogador.get_world_2d().direct_space_state.intersect_shape(consulta,1).is_empty(): return ponto
	return NavigationServer2D.map_get_closest_point(mapa,entrada+Vector2(0,64))

func _physics_process(delta: float) -> void:
	if etapa == Etapa.GUARDIAO:
		if is_instance_valid(guardiao) and guardiao.get_meta("guardiao_aguardando",false):
			var despertar: bool = guardiao.vida < guardiao.vida_maxima
			for parte in get_tree().get_nodes_in_group("jogadores"):
				if parte.get_world_2d() == guardiao.get_world_2d() and not parte.estaMorto and not parte.caido and parte.global_position.distance_to(guardiao.global_position)<240:
					despertar = true
			if despertar:
				guardiao.set_meta("guardiao_aguardando",false)
				guardiao.set_physics_process(true)
		return
	if etapa != Etapa.EXPLORANDO: return
	_tempo_alerta -= delta
	if _tempo_alerta > 0.0: return
	_tempo_alerta = 0.2
	var jogadores := get_tree().get_nodes_in_group("jogadores")
	var alertados := {}
	for inimigo in _adormecidos.duplicate():
		if not is_instance_valid(inimigo) or inimigo.esta_morto:
			_adormecidos.erase(inimigo)
			continue
		var despertar: bool = inimigo.vida < int(inimigo.get_meta("vida_inicial"))
		for parte in jogadores:
			if parte.get_world_2d() != inimigo.get_world_2d() or parte.estaMorto or parte.caido: continue
			if parte.global_position.distance_squared_to(inimigo.global_position) <= RAIO_ALERTA * RAIO_ALERTA:
				var raio := PhysicsRayQueryParameters2D.create(inimigo.global_position,parte.global_position,64)
				if inimigo.get_world_2d().direct_space_state.intersect_ray(raio).is_empty(): despertar=true
		if despertar:
			alertados[str(inimigo.get_meta("grupo_andar",""))] = inimigo.global_position
	for inimigo in _adormecidos.duplicate():
		if not is_instance_valid(inimigo) or inimigo.esta_morto: continue
		var grupo: String = str(inimigo.get_meta("grupo_andar",""))
		if not alertados.has(grupo): continue
		if inimigo.global_position.distance_to(alertados[grupo])>260: continue
		if inimigo.has_node("PatrulhaAndar"):
			inimigo.get_node("PatrulhaAndar").set_physics_process(false)
			inimigo.get_node("PatrulhaAndar").queue_free()
		inimigo.set_physics_process(true)
		_adormecidos.erase(inimigo)

func registrar_inimigo_adormecido(inimigo: Node2D) -> void:
	inimigo.set_meta("vida_inicial", inimigo.vida)
	inimigo.set_physics_process(false)
	inimigo._atualizar_ordem_desenho()
	_adormecidos.append(inimigo)
	var patrulha := preload("res://codigo/fendas/patrulha_andar.gd").new()
	patrulha.name = "PatrulhaAndar"
	patrulha.gerente = self
	inimigo.add_child(patrulha)

func ao_abate(inimigo: Node2D, valor: int, chefe: bool, geracao: int) -> void:
	if geracao != _geracao or not onda_em_andamento or ondas_paradas: return
	if chefe:
		if etapa != Etapa.GUARDIAO or inimigo != guardiao: return
		etapa = Etapa.CONCLUIDO
		# O fluxo original confirma recorde, receitas, melhoria e escolha de continuar/voltar.
		super.inimigo_morreu()
		progresso_andar_alterado.emit()
		return
	if etapa != Etapa.EXPLORANDO: return
	DadosJogo.adicionar_moedas(_aplicar_saque(float(ouro_por_abate(onda_atual)) * mult_evento("ouro") * mult_ouro_online()))
	Progresso.registrar_abate()
	inimigos_vivos = maxi(inimigos_vivos - 1, 0)
	pontos = mini(pontos + valor, META_PROGRESSO)
	atualizar_ui()
	progresso_andar_alterado.emit()
	if pontos >= META_PROGRESSO:
		_invocar_guardiao(geracao)

## Fator do ouro por abate conforme o tamanho do grupo online (1.0 fora dele).
func mult_ouro_online() -> float:
	var coop := get_tree().root.get_node_or_null("CoopOnline")
	return coop.mult_ouro(coop.jogadores_na_partida()) if coop != null and coop.ativo else 1.0

func _invocar_guardiao(geracao: int) -> void:
	etapa = Etapa.INVOCANDO
	_adormecidos.clear()
	# A barra encerra os encontros restantes, sem premiar inimigos descartados.
	gerador.limpar_populacao()
	inimigos_vivos = 1
	total_inimigos_onda = 1
	posicao_guardiao = gerador.ponto_guardiao()
	_aviso_guardiao = preload("res://codigo/efeitos/aviso_ataque.gd").new()
	get_parent().get_parent().add_child(_aviso_guardiao)
	_aviso_guardiao.global_position = posicao_guardiao
	var circulo := PackedVector2Array()
	for i in 24: circulo.append(Vector2.from_angle(TAU * i / 24) * 32)
	_aviso_guardiao.definir_area(circulo)
	progresso_andar_alterado.emit()
	get_tree().call_group("hud", "anunciar", "GUARDIAO INVOCADO", "SIGA O INDICADOR", 1.8)
	await get_tree().create_timer(1.8).timeout
	if geracao != _geracao or ondas_paradas or jogador.estaMorto: return
	if is_instance_valid(_aviso_guardiao): _aviso_guardiao.queue_free()
	etapa = Etapa.GUARDIAO
	guardiao = gerador.criar_guardiao(posicao_guardiao, geracao)
	atualizar_ui()
	progresso_andar_alterado.emit()

## F3: pula os encontros sem abates/drops e leva o grupo à luta real do andar atual.
func ir_ao_guardiao_debug() -> void:
	if is_instance_valid(tesouro) and tesouro.ativo:
		return
	if not OS.is_debug_build() or Transicao.ocupada or ondas_paradas or jogador.estaMorto:
		return
	var geracao := _geracao
	if etapa == Etapa.EXPLORANDO:
		pontos = META_PROGRESSO
		await _invocar_guardiao(geracao)
	if geracao != _geracao or etapa != Etapa.GUARDIAO or not is_instance_valid(guardiao):
		return
	var mapa: RID = guardiao.get_world_2d().navigation_map
	for parte in get_tree().get_nodes_in_group("jogadores"):
		if parte.get_world_2d() != guardiao.get_world_2d() or parte.estaMorto or parte.caido:
			continue
		var destino: Vector2 = guardiao.global_position + Vector2(64 if parte.eh_p2 else -64,72)
		parte.global_position = NavigationServer2D.map_get_closest_point(mapa,destino)
		parte.velocity = Vector2.ZERO
		if parte.camera != null: parte.camera.reset_smoothing()
	guardiao.set_meta("guardiao_aguardando",false)
	guardiao.set_physics_process(true)
	atualizar_ui()
	progresso_andar_alterado.emit()

func eh_onda_chefe(_onda: int) -> bool:
	return etapa == Etapa.GUARDIAO or etapa == Etapa.CONCLUIDO

func parar_ondas() -> void:
	if is_instance_valid(tesouro) and tesouro.ativo:
		tesouro._restaurar()
	if is_instance_valid(encontro): encontro.queue_free()
	encontro = null
	if is_instance_valid(guia): guia.queue_free()
	guia=null
	if is_instance_valid(_aviso_guardiao): _aviso_guardiao.queue_free()
	_geracao += 1
	etapa = Etapa.PARADO
	_adormecidos.clear()
	super()
	progresso_andar_alterado.emit()
