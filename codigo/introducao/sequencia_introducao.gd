extends Node

## Encenação por cena; apenas o estado e os presentes atravessam o portal pelo autoload Introducao.
const Estado := preload("res://codigo/introducao/estado_introducao.gd")
const Roteiro := preload("res://codigo/introducao/roteiro_introducao.gd")
const Guia := preload("res://codigo/introducao/guia_introducao.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")
const Item := preload("res://codigo/modelos/dados_item.gd")
const Portal := preload("res://codigo/cidade/portal_arena.gd")
const Tarefa := preload("res://codigo/introducao/tarefa_pratica.gd")
const Glifos := preload("res://codigo/introducao/icones_introducao.gd")
const IconesFazenda := preload("res://codigo/ui/icones_fazenda.gd")
const Passagem := preload("res://codigo/logica/passagem.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var cena: Node2D
var jogador: Node2D
var guia: CharacterBody2D
var dialogo: Control
var gerenciador: Node
var portal: Node2D
var objetivo: Label
var tarefa: Node
var _icone_objetivo: TextureRect
var _equipar: Button
var _marcador: Sprite2D
var _alvo: Node2D
var _executando := false
var reacao_queda := ""
## Espaço entre o jogador e o Bento durante as falas (centro a centro, mesma linha dos pés)
const DISTANCIA_CONVERSA := 24.0
const ALCANCE_ENCAIXE := 72.0

func _ready() -> void:
	add_to_group("sequencia_introducao")
	cena = get_parent()
	iniciar.call_deferred()

func iniciar() -> void:
	for i in 4:
		await get_tree().process_frame
	if Transicao.ocupada:
		await Transicao.troca_concluida
	jogador = cena.get_node("Jogador")
	dialogo = EventosJogo.interface_p1()._telas["introducao"]
	_montar_objetivo()
	Introducao.alterada.connect(_atualizar_objetivo)
	Controle.dicas_alteradas.connect(_atualizar_objetivo)
	var luz := cena.get_node_or_null("Iluminacao")
	if luz != null:
		luz.definir_hora(9)
	match cena.scene_file_path:
		Estado.ARENA:
			gerenciador = get_tree().get_first_node_in_group("gerenciador_ondas")
			gerenciador.onda_completada.connect(_ao_vencer)
			_montar_portal()
			if Introducao.etapa <= Estado.Etapa.EQUIPAR:
				_queda_e_equipamento()
			elif Introducao.etapa == Estado.Etapa.COMBATE:
				_comecar_combate()
			elif Introducao.etapa == Estado.Etapa.RESGATE:
				_resgate()
			elif Introducao.etapa == Estado.Etapa.PORTAL:
				_alvo = portal
		Estado.CIDADE:
			if Introducao.etapa in [Estado.Etapa.PORTAL, Estado.Etapa.VILA, Estado.Etapa.CAMINHO]:
				_visita_vila()
		Estado.FAZENDA:
			if Introducao.etapa in [Estado.Etapa.CAMINHO, Estado.Etapa.PASSEIO]:
				_visita_fazenda()
	_atualizar_objetivo()

func _bloquear(valor: bool) -> void:
	Introducao.cinematica = valor
	jogador.desabilitar_todas_acoes(valor)
	if valor:
		jogador.velocity = Vector2.ZERO
		jogador.animar()
	_atualizar_objetivo()

func _conversar(falas: Array, narrador := "BENTO") -> void:
	_parar_acompanhamento()
	_bloquear(true)
	if narrador == "BENTO" and is_instance_valid(guia):
		guia.parar_para_conversa()
		await _encaixar_na_conversa()
		guia.parar_para_conversa()
		jogador.parar_para_conversa(guia.global_position)
	var paginas: Array[String] = []
	for fala in falas:
		paginas.append(str(fala))
	dialogo.iniciar(paginas, narrador)
	EventosJogo.abrir_tela.emit("introducao")
	await dialogo.concluido
	_bloquear(false)

## Leva o jogador a um passo ao lado do Bento, com os pés na mesma linha, para os dois ficarem frente a frente.
## Prefere o lado em que já está; se houver parede, tenta o outro; longe demais ou sem espaço, fica onde está.
func _encaixar_na_conversa() -> void:
	var lado := signf(jogador.global_position.x - guia.global_position.x)
	if lado == 0.0:
		lado = -1.0
	var altura := 9.0 - Profundidade.PES_JOGADOR
	for sentido in [lado, -lado]:
		var alvo: Vector2 = guia.global_position + Vector2(sentido * DISTANCIA_CONVERSA, altura)
		var deslocamento: Vector2 = alvo - jogador.global_position
		if deslocamento.length() < 1.0:
			return
		if deslocamento.length() > ALCANCE_ENCAIXE or jogador.test_move(jogador.global_transform, deslocamento):
			continue
		# Usa a caminhada guiada do próprio jogador (passos calmos e colisão); a entrada continua ignorada.
		jogador.seguindo_introducao = true
		jogador.alvo_introducao = null
		jogador.caminho_introducao = PackedVector2Array([alvo])
		jogador.seguimento_bloqueado = false
		jogador.movimento_habilitado = true
		var limite := 1.5
		while limite > 0 and not jogador.caminho_introducao.is_empty() and not jogador.seguimento_bloqueado:
			limite -= get_physics_process_delta_time()
			await get_tree().physics_frame
		jogador.movimento_habilitado = false
		jogador.seguindo_introducao = false
		jogador.caminho_introducao.clear()
		jogador.velocity = Vector2.ZERO
		return

func _montar_objetivo() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 5
	add_child(camada)
	objetivo = Label.new()
	objetivo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	objetivo.offset_left = 44
	objetivo.offset_right = -18
	objetivo.offset_top = 46
	objetivo.offset_bottom = 82
	objetivo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objetivo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objetivo.add_theme_font_override("font", preload("res://assets/ui/Planes_ValMore.ttf"))
	objetivo.add_theme_font_size_override("font_size", 10)
	objetivo.add_theme_color_override("font_color", Color("ffe2a0"))
	objetivo.add_theme_color_override("font_outline_color", Color("211c2b"))
	objetivo.add_theme_constant_override("outline_size", 3)
	camada.add_child(objetivo)
	_icone_objetivo = TextureRect.new()
	_icone_objetivo.position = Vector2(12, 48)
	_icone_objetivo.size = Vector2(24, 24)
	_icone_objetivo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icone_objetivo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icone_objetivo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_icone_objetivo)
	_equipar = Button.new()
	_equipar.text = "EQUIPAR"
	_equipar.position = Vector2(12, 86)
	_equipar.custom_minimum_size = Vector2(180, 28)
	_equipar.focus_mode = Control.FOCUS_NONE
	_equipar.add_theme_font_override("font", preload("res://assets/ui/Planes_ValMore.ttf"))
	_equipar.theme = preload("res://recursos/ui/tema_sidebar.tres")
	_equipar.add_theme_font_size_override("font_size", 10)
	_equipar.add_to_group("toque_hud")
	_equipar.pressed.connect(func():
		if is_instance_valid(tarefa) and tarefa.ativa:
			tarefa.equipar()
	)
	camada.add_child(_equipar)
	_marcador = Sprite2D.new()
	_marcador.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_marcador.texture = Glifos.SETA
	_marcador.rotation = PI
	_marcador.modulate = Color("ffe2a0")
	_marcador.z_as_relative = false
	_marcador.z_index = 900
	cena.add_child(_marcador)

func _process(_delta: float) -> void:
	if not is_instance_valid(objetivo):
		return
	var interface: Node = EventosJogo.interface_p1()
	objetivo.visible = Introducao.ativa() and not Introducao.cinematica and interface._telas_abertas.is_empty()
	_marcador.visible = objetivo.visible and is_instance_valid(_alvo)
	if _marcador.visible:
		_marcador.global_position = Vector2(_alvo.global_position.x, _topo_do_desenho(_alvo) - 4)
		if is_instance_valid(tarefa) and tarefa.ativa:
			# O ícone aponta na borda da tela se o recurso ainda estiver fora da câmera.
			var canvas := cena.get_canvas_transform()
			var tela := get_viewport().get_visible_rect().size
			var ponto_tela := canvas * _marcador.global_position
			ponto_tela = ponto_tela.clamp(Vector2(20, 126), tela - Vector2(20, 82))
			_marcador.global_position = canvas.affine_inverse() * ponto_tela
	_icone_objetivo.visible = objetivo.visible
	_equipar.visible = objetivo.visible and is_instance_valid(tarefa) and tarefa.ativa and tarefa.ferramenta() != ""

## Topo visível do alvo (Bento, portal, porta...): a seta fica acima da cabeça, não no meio do desenho
func _topo_do_desenho(alvo: Node2D) -> float:
	var topo := alvo.global_position.y - 28.0
	var achou := false
	for filho in alvo.get_children():
		var retangulo := Rect2()
		if filho is Sprite2D and filho.visible and filho.texture != null:
			retangulo = filho.get_rect()
		elif filho is AnimatedSprite2D and filho.visible and filho.sprite_frames != null:
			var quadro: Texture2D = filho.sprite_frames.get_frame_texture(filho.animation, filho.frame)
			if quadro == null:
				continue
			var tamanho := quadro.get_size()
			retangulo = Rect2(filho.offset - (tamanho * 0.5 if filho.centered else Vector2.ZERO), tamanho)
		else:
			continue
		var y: float = (filho.global_transform * retangulo.position).y
		topo = y if not achou else minf(topo, y)
		achou = true
	return topo

func _atualizar_objetivo() -> void:
	if not is_instance_valid(objetivo):
		return
	if is_instance_valid(tarefa) and tarefa.ativa:
		objetivo.text = "%s  0/1\n%s USAR  |  %s TROCAR" % [tarefa.DADOS[tarefa.id].texto, Controle.rotulo_acao("attack"), Controle.rotulo_acao("ferramenta_proxima")]
		if tarefa.id == "colher":
			objetivo.text = "COLHA UMA CENOURA MADURA  0/1\n%s COLHER" % Controle.rotulo_acao("colher")
		_icone_objetivo.texture = tarefa.icone()
		_marcador.texture = tarefa.icone()
		_marcador.rotation = 0
		_marcador.modulate = Color.WHITE
		_equipar.text = "EQUIPAR " + nome_ferramenta(tarefa.ferramenta())
		return
	_icone_objetivo.texture = Glifos.INFORMACAO
	_marcador.texture = Glifos.SETA
	_marcador.rotation = PI
	_marcador.modulate = Color("ffe2a0")
	match Introducao.etapa:
		Estado.Etapa.QUEDA, Estado.Etapa.EQUIPAR:
			objetivo.text = "UMA QUEDA NO LIMIAR"
		Estado.Etapa.COMBATE:
			objetivo.text = "DERROTE TODOS OS SLIMES"
		Estado.Etapa.PORTAL:
			objetivo.text = "SIGA BENTO PELO PORTAL  |  %s ENTRAR" % Controle.rotulo_acao("open_menu")
		Estado.Etapa.VILA, Estado.Etapa.CAMINHO:
			objetivo.text = "ACOMPANHANDO BENTO ATE A FAZENDA"
		Estado.Etapa.PASSEIO:
			objetivo.text = "ACOMPANHANDO BENTO: " + str(Roteiro.PARADAS[mini(Introducao.parada, Roteiro.PARADAS.size() - 1)].nome)
		Estado.Etapa.DESCANSO:
			objetivo.text = "ENTRE EM CASA E DESCANSE NA CAMA  |  %s AGIR" % Controle.rotulo_acao("open_menu")
		_:
			objetivo.text = ""

func _montar_portal() -> void:
	portal = Portal.new()
	portal.name = "PortalDoResgate"
	var chegada: Node2D = cena.get_node("Terrains/Chegada_portal")
	portal.position = cena.to_local(chegada.global_position) - Vector2(0, 24)
	cena.add_child(portal)
	portal.get_node("InteracaoPortal").queue_free()
	var passagem := Passagem.new()
	passagem.name = "RetornoVila"
	passagem.cena_destino = Estado.CIDADE
	passagem.ponto_chegada = "portal"
	passagem.so_entre_ondas = true
	passagem.position = Vector2(0, 12)
	passagem.deslocamento_aviso = Vector2(0, -65)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 30
	forma.shape = circulo
	passagem.add_child(forma)
	portal.add_child(passagem)

func _objeto_no_chao(tipo: String, deslocamento: Vector2) -> Sprite2D:
	var item := Item.new()
	item.tipo = tipo
	item.categoria = "escudo" if tipo == "escudo_basico" else "arma"
	var objeto := Sprite2D.new()
	objeto.name = "Inicial_" + tipo
	objeto.texture = Icones.obter(item, get_tree())
	objeto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	objeto.position = jogador.position + deslocamento
	objeto.z_index = 10
	cena.add_child(objeto)
	return objeto

func _equipar_do_chao(tipo: String, objeto: Sprite2D) -> void:
	var movimento := create_tween()
	movimento.tween_property(objeto, "position", jogador.position + Vector2(0, 3), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await movimento.finished
	var item: DadosItem = InventarioJogador.buscar_por_tipo(tipo)
	if item == null:
		item = InventarioJogador._criar_item({"tipo": tipo, "categoria": "escudo" if tipo == "escudo_basico" else "arma", "duas_maos": false})
		InventarioJogador.adicionar(item)
	InventarioJogador.equipar(item)
	objeto.queue_free()
	Sons.tocar("menu_confirmar", 0)
	await get_tree().create_timer(0.3).timeout

func _queda_e_equipamento() -> void:
	if _executando:
		return
	_executando = true
	_bloquear(true)
	gerenciador.parar_ondas()
	var espada := _objeto_no_chao("espada_basica", Vector2(-24, 13))
	var escudo := _objeto_no_chao("escudo_basico", Vector2(22, 15))
	var corpo: Node2D = jogador.get_node("CompositeSprites")
	var base := corpo.position
	jogador.pausar_animacoes(true)
	_quadro_da_queda(6)
	reacao_queda = "CAINDO"
	corpo.position.y -= 160
	corpo.modulate.a = 0
	var queda := create_tween().set_parallel()
	queda.tween_property(corpo, "position", base, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	queda.tween_property(corpo, "modulate:a", 1, 0.3)
	await queda.finished
	await _aterrissar()
	jogador.pausar_animacoes(false)
	Introducao.definir_etapa(Estado.Etapa.EQUIPAR)
	await _conversar(["O chao treme. Uma espada e um escudo antigos brilham ao seu lado.", "Voce pega os dois. Algo se move entre as arvores..."], "O LIMIAR")
	_bloquear(true)
	await _equipar_do_chao("espada_basica", espada)
	await _equipar_do_chao("escudo_basico", escudo)
	Introducao.definir_etapa(Estado.Etapa.COMBATE)
	_executando = false
	_comecar_combate()

func _comecar_combate() -> void:
	_bloquear(false)
	gerenciador.iniciar_onda_introducao()
	get_tree().call_group("hud", "anunciar", "O LIMIAR DESPERTOU", "DERROTE OS SLIMES PARA SOBREVIVER.", 3)

func _ao_vencer(_onda: int) -> void:
	if Introducao.etapa != Estado.Etapa.COMBATE:
		return
	Introducao.definir_etapa(Estado.Etapa.RESGATE)
	_resgate.call_deferred()

func _criar_guia(ponto: Vector2) -> void:
	if is_instance_valid(guia):
		return
	# A versão da agenda reaparece normalmente nas próximas visitas à cidade.
	if cena.get("moradores") != null and cena.moradores.has("bento"):
		var habitual: Node = cena.moradores.bento
		habitual.process_mode = Node.PROCESS_MODE_DISABLED
		habitual.hide()
		habitual.interacao.process_mode = Node.PROCESS_MODE_DISABLED
		habitual.collision_layer = 0
	guia = Guia.new()
	guia.cena = cena
	guia.jogador = jogador
	guia.position = ponto
	cena.add_child(guia)
	guia.passo_dado.connect(_registrar_passo)
	_alvo = guia

func _andar(destino: Vector2, esperar := true) -> bool:
	if not guia.ir_ate(destino, esperar):
		push_error("INTRODUCAO: CAMINHO DE BENTO BLOQUEADO ATE %s" % destino)
		return false
	if esperar:
		Introducao.acompanhando = true
		jogador.seguindo_introducao = true
		jogador.alvo_introducao = guia
		# Primeiro alcança o ponto de partida do guia; depois percorre seus passos reais.
		jogador.caminho_introducao = guia.caminho_para(jogador.position, guia.position)
		jogador.caminho_introducao.append(guia.position)
	while not guia.chegou or (esperar and jogador.distancia_caminho_introducao() > 38):
		if esperar and jogador.seguimento_bloqueado:
			# Um morador pode atravessar o rastro: aguarda a passagem sem cortar caminho.
			guia.esperando_companhia = true
		await get_tree().physics_frame
		if not is_inside_tree():
			return false
	_parar_acompanhamento()
	return true

func _registrar_passo(ponto: Vector2) -> void:
	if jogador.seguindo_introducao:
		jogador.caminho_introducao.append(ponto)

func _parar_acompanhamento() -> void:
	Introducao.acompanhando = false
	if is_instance_valid(jogador):
		jogador.seguindo_introducao = false
		jogador.caminho_introducao.clear()
		jogador.velocity = Vector2.ZERO
		jogador.animar()

func _exit_tree() -> void:
	_parar_acompanhamento()

static func nome_ferramenta(tipo: String) -> String:
	return {"machadinha": "MACHADINHA", "picareta": "PICARETA", "enxada": "ENXADA", "regador": "REGADOR", "semente:cenoura": "SEMENTE DE CENOURA"}.get(tipo, "")

func _resgate() -> void:
	if _executando:
		return
	_executando = true
	_bloquear(true)
	_criar_guia(portal.position + Vector2(0, 18))
	if not await _andar(jogador.position + Vector2(32, 0), false):
		return
	await _conversar(Roteiro.RESGATE)
	_bloquear(true)
	if not await _andar(portal.position + Vector2(0, 15), false):
		return
	var sumir := create_tween()
	sumir.tween_property(guia, "modulate:a", 0, 0.45)
	await sumir.finished
	guia.queue_free()
	_alvo = portal
	Introducao.definir_etapa(Estado.Etapa.PORTAL)
	_bloquear(false)
	_executando = false

func _visita_vila() -> void:
	_executando = true
	_criar_guia(jogador.position + Vector2(0, 32))
	if Introducao.etapa != Estado.Etapa.CAMINHO:
		Introducao.definir_etapa(Estado.Etapa.VILA)
		await _conversar(Roteiro.VILA)
	Introducao.definir_etapa(Estado.Etapa.CAMINHO)
	_bloquear(false)
	# Desce pela rua do portal e vira para oeste na rua principal de pedra.
	if not await _andar(Vector2(488, 260)):
		return
	if not await _andar(Vector2(44, 260)):
		return
	await _conversar(["A fazenda fica logo depois desta trilha. Vem comigo!"])
	if not await _andar(Vector2(12, 260)):
		return
	guia.hide()
	Introducao.saida_liberada = true
	_executando = false
	Transicao.ir_para(Estado.FAZENDA, "cidade")

func _visita_fazenda() -> void:
	_executando = true
	Introducao.definir_etapa(Estado.Etapa.PASSEIO)
	_criar_guia(jogador.position + Vector2(-28, 0))
	tarefa = Tarefa.new()
	tarefa.cena = cena
	add_child(tarefa)
	_bloquear(false)
	while Introducao.parada < Roteiro.PARADAS.size():
		var dados: Dictionary = Roteiro.PARADAS[Introducao.parada]
		_atualizar_objetivo()
		if not await _andar(dados.ponto):
			return
		# Entrega antes da fala para a ferramenta já estar disponível ao explicar seu uso.
		for tipo in dados.get("ferramentas", []):
			await _entregar(str(tipo), 1)
		if dados.get("sementes", false):
			await _entregar("semente:cenoura", 6)
			await _entregar("semente:morango", 4)
		await _conversar(dados.falas)
		for id in dados.get("tarefas", []):
			await _praticar(str(id))
		Introducao.parada += 1
		Introducao.salvar()
	Introducao.definir_etapa(Estado.Etapa.DESCANSO)
	_alvo = cena.get_node("Terrains/PortaCasa")
	# Vai embora de verdade pela trilha, sem prender o jogador durante a despedida.
	if not await _andar(Vector2(1080, 287), false):
		return
	guia.queue_free()
	_executando = false

func _entregar(tipo: String, quantidade: int) -> void:
	while not Introducao.entregar(tipo, quantidade):
		await _conversar(["Sua mochila esta cheia. Libere uma casa para eu te entregar isto."])
		# Devolve o controle e o inventário; não cria um ciclo de diálogos sem saída.
		while InventarioJogador._primeira_livre() < 0:
			await get_tree().process_frame
	if tipo in Item.FERRAMENTAS:
		Fazenda.definir_ferramenta(tipo)

func reiniciar_arena() -> void:
	if cena.scene_file_path == Estado.ARENA and not _executando:
		_alvo = null
		_queda_e_equipamento()

func _praticar(id: String) -> void:
	if not tarefa.iniciar(id):
		return
	_alvo = null
	_atualizar_objetivo()
	_bloquear(false)
	await tarefa.concluida
	while jogador.esta_em_acao_fazenda:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	Sons.tocar("menu_confirmar", 0)
	_alvo = guia
	_atualizar_objetivo()
	await _conversar([{
		"cortar": "Isso! Arvore no chao. Agora a picareta.",
		"quebrar": "Muito bem! Agora vamos preparar um canteiro.",
		"arar": "Certo! Esse quadrado agora e um canteiro.",
		"plantar": "Plantada! Agora pegue o regador e molhe o canteiro.",
		"regar": "Pronto! A cenoura cresce quando o dia passar.",
		"colher": "Boa colheita! A sua cenoura cresce nos proximos dias."
	}[id]])

## A página original já traz suspensão, agachamento e recuperação; todas as camadas usam a mesma pose.
func _quadro_da_queda(quadro: int) -> void:
	for camada in [jogador.sprite_corpo, jogador.sprite_cabelo, jogador.sprite_roupa]:
		camada.frame = quadro

func _aterrissar() -> void:
	reacao_queda = "IMPACTO"
	_quadro_da_queda(2)
	Sons.tocar("acerto", 0, -10)
	Controle.vibrar(0.12, 0.25, 0.16)
	var poeira := CPUParticles2D.new()
	poeira.position = jogador.position + Vector2(0, 9)
	poeira.z_index = jogador.z_index + 1
	poeira.one_shot = true
	poeira.amount = 12
	poeira.lifetime = 0.4
	poeira.explosiveness = 1
	poeira.direction = Vector2.UP
	poeira.spread = 80
	poeira.gravity = Vector2(0, 60)
	poeira.initial_velocity_min = 12
	poeira.initial_velocity_max = 30
	poeira.color = Color("c49a70")
	cena.add_child(poeira)
	poeira.emitting = true
	poeira.finished.connect(poeira.queue_free)
	var camera: Camera2D = jogador.camera
	var origem := camera.offset
	var tremor := create_tween()
	tremor.tween_property(camera, "offset", origem + Vector2(0, 2), 0.05)
	tremor.tween_property(camera, "offset", origem - Vector2(0, 1), 0.07)
	tremor.tween_property(camera, "offset", origem, 0.1)
	await get_tree().create_timer(0.2).timeout
	reacao_queda = "RECUPERANDO"
	_quadro_da_queda(1)
	await get_tree().create_timer(0.22).timeout
	_quadro_da_queda(0)
	await get_tree().create_timer(0.24).timeout
	reacao_queda = "PRONTO"
