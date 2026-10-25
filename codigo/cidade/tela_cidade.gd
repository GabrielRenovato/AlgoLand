extends Control

const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const TEMA := preload("res://recursos/ui/tema_sidebar.tres")
var modo_mural := false
var modo_desafio := false
var painel: PanelContainer
var _entrada_portal: Button
var _lista: VBoxContainer
var _titulo: Label
var _fala: Label
var _botoes: Array[Button] = []
var _aviso := ""
var _aba_mural := 0
var _abas_mural: Array[Button] = []
## Lista rolável (mural, portal). No controle: o foco puxa a rolagem, o analógico direito rola e, no primeiro ou no
## último botão, o direcional continua rolando o texto que não tem botão
var _rolagem: ScrollContainer
const ROLAGEM_ANALOGICO := 260.0
const PASSO_ROLAGEM := 36

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = TEMA
	painel = PanelContainer.new()
	painel.name = "Painel"
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var moldura := preload("res://codigo/ui/estilo_interface.gd").painel(false, 8.0)
	painel.add_theme_stylebox_override("panel", moldura)
	painel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	painel.offset_left = -260
	painel.offset_right = 260
	painel.offset_top = -260 if modo_mural else (-140 if modo_desafio else -206)
	painel.offset_bottom = -12
	add_child(painel)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 0 if modo_desafio else (4 if modo_mural else 8))
	painel.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 4)
	margem.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	coluna.add_child(cabecalho)
	_titulo = Label.new()
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titulo.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	cabecalho.add_child(_titulo)
	var fechar := Button.new()
	fechar.text = "X" if modo_mural else "FECHAR"
	fechar.custom_minimum_size = Vector2(32,32) if modo_mural else (Vector2(28,28) if modo_desafio else Vector2.ZERO)
	fechar.pressed.connect(_fechar)
	cabecalho.add_child(fechar)
	if modo_mural:
		var abas := HBoxContainer.new()
		abas.add_theme_constant_override("separation",4)
		coluna.add_child(abas)
		var grupo := ButtonGroup.new()
		for indice in 3:
			var aba := Button.new()
			aba.text = ["PEDIDOS", "HOJE NA VILA", "MERCADO"][indice]
			aba.theme_type_variation = &"BotaoAba"
			aba.toggle_mode = true
			aba.button_group = grupo
			aba.button_pressed = indice == _aba_mural
			aba.custom_minimum_size.y = 32 if Controle.usando_toque else 26
			aba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			aba.pressed.connect(_trocar_aba_mural.bind(indice))
			abas.add_child(aba)
			_abas_mural.append(aba)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if modo_mural else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	rolagem.follow_focus = true
	_rolagem = rolagem
	coluna.add_child(rolagem)
	preload("res://codigo/ui/indicador_rolagem.gd").ligar(rolagem)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	rolagem.add_child(_lista)
	if modo_desafio:
		_entrada_portal = Button.new()
		_entrada_portal.theme_type_variation = &"BotaoPrimario"
		_entrada_portal.custom_minimum_size.y = 28
		_entrada_portal.pressed.connect(_iniciar_desafio)
		coluna.add_child(_entrada_portal)
	visibility_changed.connect(_ao_visibilidade)
	Cidade.alterado.connect(_ao_estado)
	Cidade.conversa_pedida.connect(_ao_conversa)
	visible = false
	resized.connect(_ajustar_largura)
	_ajustar_largura()

func _process(delta: float) -> void:
	if not visible or _rolagem == null:
		return
	var eixo := Input.get_joy_axis(_dispositivo(), JOY_AXIS_RIGHT_Y)
	if absf(eixo) > 0.25:
		_rolagem.scroll_vertical += roundi(eixo * ROLAGEM_ANALOGICO * delta)

func _input(evento: InputEvent) -> void:
	if not visible or _rolagem == null or not (evento is InputEventJoypadButton or evento is InputEventJoypadMotion or evento is InputEventKey):
		return
	var abaixo := evento.is_action_pressed("ui_down", true)
	var acima := evento.is_action_pressed("ui_up", true)
	if not abaixo and not acima:
		return
	var ativos := _botoes.filter(func(botao: Button) -> bool: return not botao.disabled and botao.is_visible_in_tree())
	var foco := get_viewport().gui_get_focus_owner()
	var barra := _rolagem.get_v_scroll_bar()
	# Sem botão para onde ir: o direcional rola a lista
	if abaixo and (ativos.is_empty() or foco == ativos.back() or not ativos.has(foco)) and _rolagem.scroll_vertical < barra.max_value - barra.page:
		_rolagem.scroll_vertical += PASSO_ROLAGEM
		get_viewport().set_input_as_handled()
	elif acima and (ativos.is_empty() or foco == ativos.front() or not ativos.has(foco)) and _rolagem.scroll_vertical > 0:
		_rolagem.scroll_vertical -= PASSO_ROLAGEM
		get_viewport().set_input_as_handled()

## O controle de quem usa esta tela (o do jogador 2 na metade dele)
func _dispositivo() -> int:
	if EventosJogo.eh_do_p2(self) and Cooperativo.ativo:
		return Cooperativo.dispositivo_p2
	return Cooperativo.dispositivo_p1 if Cooperativo.ativo and Cooperativo.dispositivo_p1 >= 0 else Controle.dispositivo

func _ajustar_largura() -> void:
	if painel == null:
		return
	var largura := minf(520.0, maxf(size.x - 16.0, 0.0))
	painel.offset_left = -largura / 2.0
	painel.offset_right = largura / 2.0
	if modo_mural or modo_desafio:
		var altura := minf(340.0 if modo_desafio else 300.0,maxf(size.y-16.0,0.0))
		painel.offset_top = -8.0-altura
		painel.offset_bottom = -8.0

func _ao_visibilidade() -> void:
	if visible:
		_aviso = ""
		_atualizar()

func _ao_estado() -> void:
	if visible:
		_atualizar()

func _ao_conversa(_id: String) -> void:
	if visible and not modo_mural:
		_atualizar()

func _limpar() -> void:
	_botoes.clear()
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()

func _texto(texto: String, cor := Color(0.86, 0.84, 0.78)) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.custom_minimum_size.x = 0
	rotulo.add_theme_color_override("font_color", cor)
	_lista.add_child(rotulo)
	return rotulo

func _botao(texto: String, acao: Callable, desativado := false) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	botao.custom_minimum_size.y = 24
	botao.disabled = desativado
	botao.pressed.connect(acao)
	_lista.add_child(botao)
	_botoes.append(botao)
	return botao

func _atualizar() -> void:
	_limpar()
	if modo_desafio:
		_titulo.text = "FENDA DO BOSQUE"
		var papel := PanelContainer.new()
		papel.add_theme_stylebox_override("panel",preload("res://codigo/ui/estilo_interface.gd").painel(true,8.0))
		_lista.add_child(papel)
		var mapa := preload("res://codigo/ui/mapa_jornada_arena.gd").new()
		mapa.modo_andares = true
		mapa.preparar(maxi(Progresso.recorde_onda,Progresso.onda_maxima),_onda_do_portal())
		papel.add_child(mapa)
		var jogador := EventosJogo.dono(self)
		_texto("Explore o bosque. Derrote grupos para completar a barra e invocar o guardiao. Elites valem mais progresso.")
		_entrada_portal.text = "ENTRAR / ANDAR %d" % _onda_do_portal()
		_entrada_portal.disabled = jogador == null
		_botoes.append(_entrada_portal)
		Sons.ligar_botoes(self)
		return
	if modo_mural:
		_montar_mural()
		Sons.ligar_botoes(self)
		return
	else:
		var id := Cidade.interlocutor
		if not Dados.MORADORES.has(id):
			return
		var morador: Dictionary = Dados.MORADORES[id]
		_titulo.text = "%s - %s" % [morador["nome"], morador["oficio"].to_upper()]
		var cena := Cooperativo.cena_de(self)
		var hora: float = cena.hora_atual() if cena != null and cena.has_method("hora_atual") else 12.0
		var agenda := Dados.agenda(id, hora, Calendario.estacao(), -1, Calendario.dia_da_semana())
		_texto("%s  |  AMIZADE %d/10" % [agenda["atividade"], int(Cidade.amizade.get(id, 0))], Color(1, 0.85, 0.5))
		var saudacao := "Boa noite! " if hora >= 18 or hora < 6 else "Bom dia! " if hora < 12 else "Boa tarde! "
		var intimidade := " Que bom rever um amigo. " if int(Cidade.amizade.get(id, 0)) >= 4 else " "
		_texto(saudacao + morador["fala"] + intimidade + Dados.FALAS_ESTACAO[Calendario.estacao()])
		_montar_servico(id, morador)
		if Cooperativo.cena_de(self).get("local") == "pousada":
			_botao("PASSAR A NOITE NA POUSADA", _abrir_servico.bind("dormir"))
	for missao in Dados.MISSOES:
		if not Cidade.missoes.has(missao) and not Dados.missao_na_estacao(missao,Calendario.estacao()):
			continue
		if not modo_mural and Dados.MISSOES[missao]["dono"] != Cidade.interlocutor:
			continue
		_montar_missao(missao)
	if _aviso != "":
		_texto(_aviso, Color(0.65, 1, 0.65))
	Sons.ligar_botoes(self)

func _trocar_aba_mural(indice: int) -> void:
	# O mercado entre jogadores tem tela própria: o mural fecha e ela abre na mesma interface
	if indice == 2:
		_abas_mural[2].set_pressed_no_signal(false)
		_abas_mural[_aba_mural].set_pressed_no_signal(true)
		_fechar()
		EventosJogo.abrir_tela_de.call_deferred(self, "mercado")
		return
	_aba_mural = indice
	for i in _abas_mural.size():
		_abas_mural[i].set_pressed_no_signal(i == indice)
	_rolagem.scroll_vertical = 0
	_atualizar()

func _montar_mural() -> void:
	_titulo.text = "MURAL DE PEDIDOS"
	if _aba_mural == 1:
		_montar_agenda_mural()
		return
	var dica := _texto("Aceite aqui. Entregue o pedido ao morador.")
	dica.add_theme_font_size_override("font_size",8)
	var pedidos: Array = Dados.MISSOES.keys().filter(func(id): return Cidade.missoes.has(id) or Dados.missao_na_estacao(id,Calendario.estacao()))
	var ordem := {"aceita":0,"disponivel":1,"concluida":2}
	pedidos.sort_custom(func(a,b): return ordem[Cidade.missoes.get(a,{}).get("estado","disponivel")] < ordem[Cidade.missoes.get(b,{}).get("estado","disponivel")])
	for id in pedidos:
		_cartao_pedido(id)

func _rotulo_cartao(pai: Node, texto: String, cor := Color("493629"), tamanho := 9) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.add_theme_color_override("font_color",cor)
	rotulo.add_theme_font_size_override("font_size",tamanho)
	pai.add_child(rotulo)
	return rotulo

func _novo_cartao() -> VBoxContainer:
	var cartao := PanelContainer.new()
	cartao.mouse_filter = Control.MOUSE_FILTER_PASS
	cartao.add_theme_stylebox_override("panel",preload("res://codigo/ui/estilo_interface.gd").painel(true,9.0))
	_lista.add_child(cartao)
	var linhas := VBoxContainer.new()
	linhas.add_theme_constant_override("separation",5)
	cartao.add_child(linhas)
	return linhas

func _cartao_pedido(id: String) -> void:
	var cartao := preload("res://codigo/ui/cartao_pedido.gd").criar(id,Cidade)
	_lista.add_child(cartao)
	if Cidade.missoes.get(id,{}).get("estado","disponivel") == "disponivel":
		var aceitar := Button.new()
		aceitar.text = "ACEITAR PEDIDO"
		aceitar.theme_type_variation = &"BotaoPrimario"
		aceitar.custom_minimum_size.y = 32 if Controle.usando_toque else 26
		aceitar.pressed.connect(_aceitar.bind(id))
		cartao.get_node("Conteudo").add_child(aceitar)
		_botoes.append(aceitar)

func _montar_agenda_mural() -> void:
	_texto("Encontre os moradores da Vila das Flores.")
	var luz := Cooperativo.cena_de(self).get_node_or_null("Iluminacao")
	var hora: float = luz.hora if luz != null else 6.0
	if Calendario.dia_na_estacao() == Calendario.DIAS_POR_ESTACAO:
		_texto("FESTA DA ESTACAO NA PRACA!",Color("f6d581"))
	if Calendario.dia_da_semana() == int(Dados.EVENTOS["festa_sabado"]["dia_semana"]):
		_texto("FESTA NA TAVERNA A PARTIR DAS %dh." % int(Dados.EVENTOS["festa_sabado"]["inicio"]),Color("f6d581"))
	for id in Dados.MORADORES:
		var agenda := Dados.agenda(id,hora,Calendario.estacao(),-1,Calendario.dia_da_semana())
		var local: String = {"cidade":"PRACA","praia":"PRAIA","palafita":"PESCARIA DO NILO"}.get(agenda["local"],Dados.PREDIOS.get(agenda["local"],{}).get("nome",String(agenda["local"]).to_upper()))
		var linhas := _novo_cartao()
		_rotulo_cartao(linhas,Dados.MORADORES[id]["nome"]+" - "+local,Color("493020"),9)
		_rotulo_cartao(linhas,agenda["atividade"],Color("805532"),8)

func _montar_servico(id: String, morador: Dictionary) -> void:
	var servico: String = morador["servico"]
	if servico == "":
		if id == "bardo" and not Progresso.tem_morador(id):
			_texto("O apoio do bardo pode ser contratado com Lia na comunidade.")
		return
	var contratado := not id in Progresso.MORADORES or Progresso.tem_morador(id)
	match servico:
		"mercante":
			_botao("COMPRAR SEMENTES COM BRASAS", _abrir_servico.bind("mercante"))
		"acampamento":
			_botao("MELHORIAS E APOIO DOS MORADORES", _abrir_servico.bind("acampamento"))
		"mistica":
			_botao("ESCOLHER CHECKPOINT", _abrir_servico.bind("mistica"), not contratado)
		"cura":
			_botao("DESCANSAR NA ENFERMARIA", _curar, not contratado)
	if not contratado:
		_texto("Converse com Lia para contratar este apoio. Os beneficios ja conquistados continuam valendo.")

func _montar_missao(id: String) -> void:
	var dados: Dictionary = Dados.MISSOES[id]
	var estado: String = Cidade.missoes.get(id, {}).get("estado", "disponivel")
	_texto(dados["nome"] + (" - CONCLUIDO" if estado == "concluida" else ""), Color(1, 0.85, 0.5))
	_texto("%s Pedido de %s. Recompensa: %d Brasas e +2 amizade." % [dados["texto"], Dados.MORADORES[dados["dono"]]["nome"], dados["brasas"]])
	if estado == "disponivel":
		_botao("ACEITAR PEDIDO", _aceitar.bind(id))
	elif estado == "aceita":
		var progresso := Cidade.progresso_missao(id)
		_texto("PROGRESSO: %d / %d" % [progresso.x, progresso.y])
		if not modo_mural:
			_botao("ENTREGAR PEDIDO", _entregar.bind(id), progresso.x < progresso.y)

func _aceitar(id: String) -> void:
	Cidade.aceitar(id)
	_aviso = "Pedido aceito."
	_atualizar()
	focar_inicio()

func _entregar(id: String) -> void:
	if Cidade.concluir(id, Cidade.interlocutor):
		_aviso = "Obrigado! Voce recebeu %d Brasas e ganhou amizade." % Dados.MISSOES[id]["brasas"]
	_atualizar()
	focar_inicio()

func _abrir_servico(nome: String) -> void:
	_fechar()
	EventosJogo.abrir_tela_de(self, nome)

func _curar() -> void:
	var jogador := EventosJogo.dono(self)
	if jogador != null:
		jogador.descansar()
	_aviso = "Vida e folego recuperados. Cuide-se!"
	_atualizar()
	focar_inicio()

func _fechar() -> void:
	EventosJogo.fechar_tela_de(self, "desafio_arena" if modo_desafio else "mural_cidade" if modo_mural else "conversa_cidade")

## Onda em que a próxima entrada começa: a que ficou guardada ao sair da arena e, no começo da partida, a do checkpoint da Mística
func _onda_do_portal() -> int:
	var onda: int = int(Transicao.estado.get("onda_atual", 1))
	if not Progresso.onda_comecou and Progresso.onda_inicial > 1:
		onda = Progresso.onda_inicial
	return onda

func _iniciar_desafio() -> void:
	var jogador := EventosJogo.dono(self)
	if jogador == null:
		return
	_fechar()
	Transicao.entrar_na_arena()

func focar_inicio() -> void:
	if modo_mural and _botoes.is_empty():
		Controle.focar(_abas_mural[_aba_mural])
		return
	for botao in _botoes:
		if not botao.disabled:
			Controle.focar(botao)
			return
