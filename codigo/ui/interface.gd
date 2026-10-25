extends CanvasLayer

const IconesItens := preload("res://codigo/ui/icones_itens.gd")
const ControlesToque := preload("res://codigo/ui/controles_toque.gd")
const TelaCidade := preload("res://codigo/cidade/tela_cidade.gd")
const DialogoIntroducao := preload("res://codigo/introducao/dialogo_introducao.gd")
const DialogoCidade := preload("res://codigo/cidade/dialogo_cidade.gd")
const TelaBau := preload("res://codigo/ui/tela_bau.gd")
const DURACAO_ENTRADA := 0.15
# Como no Diablo: a loja abre na esquerda e o inventário junto na direita, para arrastar itens entre os dois
const TELAS_ACOMPANHANTES := {"mercante": ["inventario"], "bau": ["inventario"]}
# Ações de jogo que dividem botão com os menus (B fecha a tela e também rola; A confirma e também interage: soltas ao
# fechar, senão o A que fechou a conversa já abriria outra)
const ACOES_DO_JOGADOR := ["rolar", "attack", "open_menu"]
# Telas no centro da tela: em vez de deslizar de uma borda, aparecem com fade
const TELAS_CENTRAIS := ["acampamento", "fim_partida", "dormir", "pausa", "conversa_cidade", "mural_cidade", "desafio_arena", "introducao", "guia_pesca", "comercio", "forja", "carpintaria", "oficina_vara", "mapa_mundi", "ranking", "lobby", "mercado"]
# Só se fecha pelo próprio botão (B/Esc e o atalho do inventário são ignorados)
const TELAS_OBRIGATORIAS := ["fim_partida", "introducao"]

var _telas_abertas: Array[String] = []
var _troca_companheira: Button
var _companheira_mochila := false
var _par_compacto := ""

## Último controle que ganhou foco nesta metade da tela. O Godot guarda UM foco por janela: quando o outro jogador do co-op
## foca algo na metade dele, o foco desta metade é solto. Este guarda o "foco lógico" para devolvê-lo no próximo comando.
var _foco_logico: Control = null
## Item "na mão" de quem joga no controle: Y pega, Y numa casa solta (o controle não tem arrastar). Ver slot_ui.mover_com_controle
var item_carregado: DadosItem = null
var _mapa_aguardando := false
var _mapa_pedido := 0
signal carregado_alterado
const ACOES_NAVEGACAO := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel", "ui_focus_next", "ui_focus_prev",
		"ferramenta_anterior", "ferramenta_proxima", "colher"]

@onready var _telas: Dictionary = {
	"inventario": $TelaInventario,
	"mercante": $TelaMercante,
	"acampamento": $TelaAcampamento,
	"mistica": $TelaMistica,
	"fim_partida": $TelaFimPartida,
	"dormir": $TelaDormir,
	"caldeirao": $TelaCaldeirao,
	"pausa": $TelaPausa,
}
@onready var _paineis: Dictionary = {
	"inventario": $TelaInventario/Sidebar,
	"mercante": $TelaMercante/Painel,
	"acampamento": $TelaAcampamento/Painel,
	"mistica": $TelaMistica/Painel,
	"fim_partida": $TelaFimPartida/Centro/Painel,
	"dormir": $TelaDormir/Centro/Painel,
	"caldeirao": $TelaCaldeirao/Painel,
	"pausa": $TelaPausa/Centro/Painel,
}

func _ready() -> void:
	Introducao.preparar_cena(get_parent())
	var ranking := preload("res://codigo/ui/tela_ranking.gd").new()
	ranking.name = "TelaRanking"
	add_child(ranking)
	_telas["ranking"] = ranking
	_paineis["ranking"] = ranking.painel
	ranking.hide()
	var mercado := preload("res://codigo/mercado/tela_mercado.gd").new()
	mercado.name = "TelaMercado"
	add_child(mercado)
	_telas["mercado"] = mercado
	_paineis["mercado"] = mercado.painel
	mercado.hide()
	var lobby := preload("res://codigo/ui/tela_lobby.gd").new()
	lobby.name = "TelaLobby"
	add_child(lobby)
	_telas["lobby"] = lobby
	_paineis["lobby"] = lobby.painel
	lobby.hide()
	var mapa := preload("res://codigo/ui/tela_mapa_mundi.gd").new()
	mapa.name = "MapaMundi"
	add_child(mapa)
	_telas["mapa_mundi"] = mapa
	_paineis["mapa_mundi"] = mapa.painel
	var forja := preload("res://codigo/ui/tela_forja.gd").new()
	forja.name = "TelaForja"
	add_child(forja)
	_telas["forja"] = forja
	_paineis["forja"] = forja.painel
	var carpintaria := preload("res://codigo/ui/tela_carpintaria.gd").new()
	carpintaria.name = "TelaCarpintaria"
	add_child(carpintaria)
	_telas["carpintaria"] = carpintaria
	_paineis["carpintaria"] = carpintaria.painel
	var introducao := DialogoIntroducao.new()
	introducao.name = "DialogoIntroducao"
	add_child(introducao)
	_telas["introducao"] = introducao
	_paineis["introducao"] = introducao.painel
	var bau := TelaBau.new()
	bau.name = "TelaBau"
	add_child(bau)
	_telas["bau"] = bau
	_paineis["bau"] = bau.painel
	var comercio := preload("res://codigo/comercio/tela_comercio.gd").new()
	comercio.name = "TelaComercio"
	add_child(comercio)
	_telas["comercio"] = comercio
	_paineis["comercio"] = comercio.painel
	var oficina := preload("res://codigo/pesca/oficina_vara.gd").new()
	oficina.name = "OficinaVara"
	add_child(oficina)
	_telas["oficina_vara"] = oficina
	_paineis["oficina_vara"] = oficina.painel
	var guia_pesca := preload("res://codigo/pesca/guia_pesca.gd").new()
	guia_pesca.name = "GuiaPesca"
	add_child(guia_pesca)
	_telas["guia_pesca"] = guia_pesca
	_paineis["guia_pesca"] = guia_pesca.painel
	for nome in ["conversa_cidade", "mural_cidade", "desafio_arena"]:
		var tela: Control = DialogoCidade.new() if nome == "conversa_cidade" else TelaCidade.new()
		tela.name = nome.to_pascal_case()
		tela.modo_mural = nome == "mural_cidade"
		tela.modo_desafio = nome == "desafio_arena"
		add_child(tela)
		_telas[nome] = tela
		_paineis[nome] = tela.painel
	# A pausa para o jogo (get_tree().paused): a Interface precisa continuar recebendo Esc/B para fechá-la
	process_mode = Node.PROCESS_MODE_ALWAYS
	for tela in _telas.values():
		tela.visible = false
	add_to_group("interface")
	# A interface do jogador 2 (metade dele no cooperativo) só abre o que for pedido a ela (EventosJogo.abrir_tela_de/para);
	# os pedidos globais são do jogador 1
	if not EventosJogo.eh_do_p2(self):
		EventosJogo.abrir_tela.connect(_abrir_tela)
		EventosJogo.fechar_tela.connect(_fechar_tela)
	Controle.modo_alterado.connect(_ao_modo_controle)
	get_viewport().gui_focus_changed.connect(_ao_foco_mudou)
	Transicao.troca_concluida.connect(_ao_chegar_no_andar)
	# Celular: joystick e botões na tela (somem enquanto uma tela está aberta)
	if Controle.usando_toque:
		# No coop o toque pertence ao P1; o parceiro usa o próprio controle.
		if not EventosJogo.eh_do_p2(self):
			add_child(ControlesToque.new())
	_troca_companheira = Button.new()
	_troca_companheira.name = "TrocarLojaMochila"
	_troca_companheira.theme = preload("res://recursos/ui/tema_sidebar.tres")
	_troca_companheira.autowrap_mode = TextServer.AUTOWRAP_OFF
	_troca_companheira.add_theme_font_size_override("font_size",8)
	_troca_companheira.pressed.connect(func():
		_companheira_mochila = not _companheira_mochila
		_organizar_companheiras()
		_focar_tela("inventario" if _companheira_mochila else _par_compacto))
	add_child(_troca_companheira)
	_troca_companheira.hide()
	preload("res://codigo/ui/escala_interface.gd").ligar(self)

func _process(_delta: float) -> void:
	_organizar_companheiras()

## Em janelas estreitas alterna entre loja e mochila, preservando os itens e o arrastar no PC.
func _organizar_companheiras() -> void:
	if _troca_companheira == null: return
	var medida := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(self)
	var par := ""
	for nome in TELAS_ACOMPANHANTES:
		if nome in _telas_abertas and "inventario" in _telas_abertas: par = nome
	var compacto := par != "" and medida.x < 440
	_troca_companheira.visible = compacto
	if not compacto:
		if _par_compacto != "":
			for nome in [_par_compacto,"inventario"]:
				if nome in _telas_abertas: _telas[nome].show()
		_par_compacto = ""
		return
	_par_compacto = par
	_telas[par].visible = not _companheira_mochila
	_telas["inventario"].visible = _companheira_mochila
	_telas["inventario"].ajustar_largura(minf(216,medida.x-80))
	_troca_companheira.text = ("BAU" if par == "bau" else "LOJA") if _companheira_mochila else "MOCHILA"
	var painel: Control = _paineis["inventario" if _companheira_mochila else par]
	var largura := minf(68,medida.x-painel.size.x-24)
	var fonte := _troca_companheira.get_theme_font("font")
	var espaco_texto := largura - _troca_companheira.get_theme_stylebox("normal").get_minimum_size().x - 4
	var tamanho_fonte := 8
	while tamanho_fonte > 4 and fonte.get_string_size(_troca_companheira.text,HORIZONTAL_ALIGNMENT_LEFT,-1,tamanho_fonte).x > espaco_texto:
		tamanho_fonte -= 1
	_troca_companheira.add_theme_font_size_override("font_size",tamanho_fonte)
	_troca_companheira.size = Vector2(largura,44)
	_troca_companheira.position = Vector2(8 if _companheira_mochila else medida.x-largura-8, (medida.y-44)/2)


func definir_carregado(item: DadosItem) -> void:
	if item_carregado == item:
		return
	item_carregado = item
	carregado_alterado.emit()

## Entrar no andar precisa deixar o mesmo estado de ações de fechar a mochila.
## Não libera menus, cenas guiadas, forja ou o parceiro que está em outro mapa.
func _ao_chegar_no_andar(caminho: String) -> void:
	if not caminho.begins_with("res://cenas/fendas/andar_") or not _telas_abertas.is_empty() or Introducao.ativa() or Introducao.cinematica or Introducao.acompanhando:
		return
	var jogador := EventosJogo.dono(self)
	if jogador == null or jogador.estaMorto or jogador.esta_forjando:
		return
	var cena := Cooperativo.cena_de(jogador)
	if cena == null or cena.scene_file_path != caminho: return
	get_viewport().gui_release_focus()
	_foco_logico = null
	jogador.desabilitar_todas_acoes(false)
	for filho in get_children():
		if filho.get_script() == ControlesToque: filho._soltar_tudo()

func _ao_foco_mudou(no: Control) -> void:
	_foco_logico = no

## O controle que esta metade considera em foco, mesmo quando o foco do Godot foi solto pelo outro jogador
func foco_atual() -> Control:
	var real := get_viewport().gui_get_focus_owner()
	if real != null:
		return real
	if is_instance_valid(_foco_logico) and _foco_logico.is_visible_in_tree() and not _telas_abertas.is_empty():
		return _foco_logico
	return null

## No co-op o foco do Godot é único por janela: se o parceiro focou algo, devolve o foco desta metade antes de o comando navegar
func _input(evento: InputEvent) -> void:
	if get_tree().get_first_node_in_group("remapeando_controles") != null: return
	# Escrevendo no chat do canto: M, I e as outras teclas são letras, não atalhos
	if Controle.digitando and evento is InputEventKey: return
	var jogador := EventosJogo.dono(self)
	var acao_mapa: String = jogador.acao("open_map") if jogador != null else "open_map"
	# Dentro de um andar da fenda "MAPA" alterna o automapa do andar, não a carta do mundo
	var minimapa := _minimapa_do_andar()
	if minimapa != null and not Introducao.ativa() and not Comercio.em_viagem and _telas_abertas.is_empty():
		if evento is InputEventJoypadButton and evento.is_action(acao_mapa):
			if evento.pressed:
				_mapa_aguardando = true
				_mapa_pedido += 1
				_alternar_minimapa_se_segurou(_mapa_pedido, minimapa)
			elif _mapa_aguardando:
				_mapa_aguardando = false
				# R3 curto continua trocando a arma; segurar reserva o mesmo botao para o mapa
				for hud in get_tree().get_nodes_in_group("hud_p2" if EventosJogo.eh_do_p2(self) else "hud_p1"):
					if hud.barra_armas != null and not hud.barra_armas.modo_fazenda: hud.barra_armas.trocar(1)
			get_viewport().set_input_as_handled()
			return
		if evento.is_action_pressed(acao_mapa) and not evento.is_echo():
			minimapa.alternar()
			get_viewport().set_input_as_handled()
			return
	if evento.is_action(acao_mapa) and evento is InputEventJoypadButton:
		if evento.pressed and not Introducao.ativa() and not Comercio.em_viagem:
			if "mapa_mundi" in _telas_abertas:
				_fechar_tela("mapa_mundi")
			elif _telas_abertas.is_empty():
				_mapa_aguardando = true
				_mapa_pedido += 1
				_abrir_mapa_se_segurou(_mapa_pedido)
		elif not evento.pressed and _mapa_aguardando:
			_mapa_aguardando = false
			# R3 curto continua trocando a arma; segurar reserva o mesmo botao para o mapa.
			if _telas_abertas.is_empty():
				for hud in get_tree().get_nodes_in_group("hud_p2" if EventosJogo.eh_do_p2(self) else "hud_p1"):
					if hud.barra_armas != null and not hud.barra_armas.modo_fazenda: hud.barra_armas.trocar(1)
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed(acao_mapa) and not evento.is_echo() and not Introducao.ativa() and not Comercio.em_viagem:
		if "mapa_mundi" in _telas_abertas: _fechar_tela("mapa_mundi")
		elif _telas_abertas.is_empty(): _abrir_tela("mapa_mundi")
		get_viewport().set_input_as_handled()
		return
	if _telas_abertas.is_empty() or get_viewport().gui_get_focus_owner() != null or not is_instance_valid(_foco_logico):
		return
	if not (evento is InputEventJoypadButton or evento is InputEventJoypadMotion or evento is InputEventKey):
		return
	for acao in ACOES_NAVEGACAO:
		if evento.is_action_pressed(acao) and _foco_logico.is_visible_in_tree() and _foco_logico.focus_mode != Control.FOCUS_NONE:
			_foco_logico.grab_focus()
			return

func _unhandled_input(evento: InputEvent) -> void:
	if get_tree().get_first_node_in_group("remapeando_controles") != null: return
	if Controle.digitando and evento is InputEventKey:
		get_viewport().set_input_as_handled()
		return
	if Comercio.em_viagem and not Comercio.em_combate:
		get_viewport().set_input_as_handled()
		return
	if _telas_abertas.has("introducao"):
		get_viewport().set_input_as_handled()
		return
	# Na tela de fim de partida só o botão dela segue em frente
	if _telas_abertas.has("fim_partida"):
		if evento.is_action_pressed("open_inventory") or evento.is_action_pressed("close_menu"):
			get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("open_inventory"):
		if _telas_abertas.has("inventario"):
			_fechar_tela("inventario")
		else:
			_abrir_tela("inventario")
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("close_menu") and not _telas_abertas.is_empty():
		# Dentro de OPCOES ou da confirmação da pausa, Esc/B só volta ao menu da pausa
		if _telas_abertas.has("pausa") and _telas["pausa"].voltar_subtela():
			get_viewport().set_input_as_handled()
			return
		for nome in _telas_abertas.duplicate():
			_fechar_tela(nome)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("pausar"):
		# Esc sem nenhuma tela aberta abre a pausa (o jogador sentado só se levanta: o mesmo Esc o levanta)
		var jogador := EventosJogo.dono(self)
		if _telas_abertas.is_empty() and not (jogador != null and bool(jogador.get("esta_sentado"))):
			_abrir_tela("pausa")
			get_viewport().set_input_as_handled()
		elif _telas_abertas == ["pausa"]:
			_fechar_tela("pausa")
			get_viewport().set_input_as_handled()

func _abrir_tela(nome: String, acompanhante := false) -> void:
	if Comercio.em_viagem and not Comercio.em_combate and nome != "comercio":
		return
	if not Introducao.permite_tela(nome):
		return
	if not _telas.has(nome):
		return
	if nome == "inventario" and acompanhante:
		_telas[nome].selecionar_aba(false)
		_ajustar_mochila(nome)
	if _telas_abertas.has(nome):
		return
	# Com a tela de fim de partida aberta nenhuma outra abre por cima
	if _telas_abertas.has("fim_partida") and not nome in TELAS_OBRIGATORIAS:
		return
	# A morte vale mais que qualquer outra tela aberta
	if nome in TELAS_OBRIGATORIAS:
		for outra in _telas_abertas.duplicate():
			_fechar_tela(outra)
	_ajustar_mochila(nome)
	_telas[nome].visible = true
	# Botões que as telas montam por código (loja, acampamento, Mística) só existem depois de visíveis
	Sons.ligar_botoes(_telas[nome])
	_telas_abertas.append(nome)
	_animar_entrada(_paineis[nome])
	_definir_acoes_do_jogador_desabilitadas(true)
	EventosJogo.tela_aberta.emit(nome)
	for outra in TELAS_ACOMPANHANTES.get(nome, []):
		_abrir_tela(outra, true)
	# No controle o foco vai para a tela pedida (não para a que abriu junto)
	if not acompanhante:
		_companheira_mochila = false
		_organizar_companheiras()
		_focar_tela(nome)

## A mochila mantém os slots nativos: ao lado da loja usa quatro colunas em vez de encolher.
func _ajustar_mochila(nome: String) -> void:
	if nome != "inventario":
		return
	var disponivel := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(self).x
	for outra in TELAS_ACOMPANHANTES:
		if outra in _telas_abertas:
			var painel: Control = _paineis[outra]
			var inicio := disponivel * painel.anchor_left + float(painel.get_meta("offset_entrada", painel.offset_left))
			disponivel -= inicio + painel.size.x
	_telas["inventario"].ajustar_largura(minf(210.0, maxf(136.0, floorf(disponivel)-16)))

func _fechar_tela(nome: String) -> void:
	if not _telas_abertas.has(nome):
		return
	_telas_abertas.erase(nome)
	_telas[nome].visible = false
	if _telas_abertas.is_empty():
		_definir_acoes_do_jogador_desabilitadas(false)
		# Com algum botão em foco o jogador não ataca; e o B/A que fechou a tela não pode rolar/atacar
		get_viewport().gui_release_focus()
		_foco_logico = null
		definir_carregado(null)
		for acao in ACOES_DO_JOGADOR:
			Input.action_release(acao)
	else:
		_focar_tela(_telas_abertas[0])
	EventosJogo.tela_fechada.emit(nome)
	for outra in TELAS_ACOMPANHANTES.get(nome, []):
		_fechar_tela(outra)

func _focar_tela(nome: String) -> void:
	var tela: Node = _telas[nome]
	if tela.has_method("focar_inicio"):
		tela.focar_inicio()

# Pegou o controle com uma tela aberta e nada em foco: foca a tela principal
func _ao_modo_controle(usando_controle: bool) -> void:
	if usando_controle and not _telas_abertas.is_empty() and get_viewport().gui_get_focus_owner() == null:
		_focar_tela(_telas_abertas[0])
		# o toque que acordou o controle só acende o foco, sem já andar uma posição
		get_viewport().set_input_as_handled()

# Desliza a sidebar a partir da borda em que ela está presa
func _animar_entrada(painel: Control) -> void:
	var anterior: Tween = painel.get_meta("animacao_entrada") if painel.has_meta("animacao_entrada") else null
	if anterior != null and anterior.is_valid():
		anterior.kill()
	if painel in _paineis_centrais():
		painel.modulate.a = 0.0
		var animacao := painel.create_tween()
		painel.set_meta("animacao_entrada", animacao)
		animacao.tween_property(painel, "modulate:a", 1.0, DURACAO_ENTRADA)
		return
	# Calculado pelas âncoras: se a tela fechar no meio da animação, position.x fica no meio do caminho
	# position também altera offset_left: guardar o destino antes da primeira animação.
	if not painel.has_meta("offset_entrada"):
		painel.set_meta("offset_entrada", painel.offset_left)
	var x_final := painel.get_parent_area_size().x * painel.anchor_left + float(painel.get_meta("offset_entrada"))
	var na_direita := painel.anchor_left >= 1.0
	painel.position.x = x_final + (painel.size.x if na_direita else -painel.size.x)
	var tween := painel.create_tween()
	painel.set_meta("animacao_entrada", tween)
	tween.tween_property(painel, "position:x", x_final, DURACAO_ENTRADA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _paineis_centrais() -> Array:
	var lista: Array = []
	for nome in TELAS_CENTRAIS:
		lista.append(_paineis[nome])
	return lista

func _definir_acoes_do_jogador_desabilitadas(desabilitar: bool) -> void:
	var jogador := EventosJogo.dono(self)
	if jogador != null:
		jogador.desabilitar_todas_acoes(desabilitar or Introducao.cinematica)

## O minimapa do andar deste jogador (existe só dentro de um andar da fenda)
func _minimapa_do_andar() -> Control:
	for no in get_tree().get_nodes_in_group("minimapa_p2" if EventosJogo.eh_do_p2(self) else "minimapa_p1"):
		if no is Control and is_instance_valid(no) and no.is_inside_tree():
			return no
	return null

func _alternar_minimapa_se_segurou(pedido: int, minimapa: Control) -> void:
	await get_tree().create_timer(0.4).timeout
	if not _mapa_aguardando or pedido != _mapa_pedido: return
	_mapa_aguardando = false
	if is_instance_valid(minimapa):
		minimapa.alternar()

func _abrir_mapa_se_segurou(pedido: int) -> void:
	await get_tree().create_timer(0.4).timeout
	if not _mapa_aguardando or pedido != _mapa_pedido: return
	_mapa_aguardando = false
	if _telas_abertas.is_empty() and not Introducao.ativa() and not Comercio.em_viagem:
		_abrir_tela("mapa_mundi")
