extends "res://codigo/cidade/tela_cidade.gd"

## Caixa de diálogo de RPG: fala, retrato e assuntos. O que cada morador diz vem de conversa_moradores.gd
## (personalidade, dicas pelo estado do jogo, histórias pela amizade, opinião sobre os vizinhos); um pedido por vez.
const Acabamento := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const Conversa := preload("res://codigo/cidade/conversa_moradores.gd")
## Letras por segundo do texto aparecendo
const VELOCIDADE_TEXTO := 70.0
const RetratoFalante := preload("res://codigo/ui/retrato_falante.gd")
var _retrato: RetratoFalante
var _opcoes: GridContainer
var _menu_assuntos: PanelContainer
var _continuar: Button
var _fechar_dialogo: Button
var _paginas: Array[String] = []
var _pagina := 0
var _texto_completo := ""
var _indicador: Label
var _linha_dialogo: HBoxContainer
var _rosto: PanelContainer
var _pedido := ""
var _resumo_servico: Label
var _atendimento := ""
const Atendimento := preload("res://codigo/cidade/atendimento_cidade.gd")
## Mostrando o cardápio da taverna (na conversa com o Caio ou na mesa)
var _cardapio := false
var _mesa_aberta := false
var _vizinhos_mesa: Array = []
## Submenu da horta: "cozinha" (o Caio cozinha com a colheita) ou "venda" (a Lia troca colheita por Brasas); "" = nenhum
var _submenu := ""
const Refeicoes := preload("res://codigo/dados/refeicoes.gd")
## Lendo a carta que o pombo-correio trouxe (Cidade.carta_aberta)
var _carta := false
const TEXTURA_CARTA_MISTERIOSA := preload("res://assets/npcs/pombo_correio/envelope_misterio.png")
const TEXTURA_CARDAPIO := preload("res://assets/cenario/cidade/interiores/pousada/props/cardapio.png")
var _id_atual := ""
## Fala em tela (só muda quando o jogador escolhe um assunto ou abre a conversa)
var _fala_atual := ""
var _digitando: Tween
var _subir_respostas: Button
var _descer_respostas: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = TEMA
	painel = PanelContainer.new()
	painel.name = "Painel"
	painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	painel.add_theme_stylebox_override("panel", _estilo_conversa())
	add_child(painel)
	_linha_dialogo = HBoxContainer.new()
	_linha_dialogo.add_theme_constant_override("separation",12)
	painel.add_child(_linha_dialogo)
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation",5)
	_linha_dialogo.add_child(coluna)
	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size",12)
	_titulo.add_theme_color_override("font_color",Color("75452d"))
	coluna.add_child(_titulo)
	_resumo_servico = Label.new()
	_resumo_servico.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resumo_servico.add_theme_font_size_override("font_size",8)
	_resumo_servico.add_theme_color_override("font_color",Color("75452d"))
	_resumo_servico.hide()
	coluna.add_child(_resumo_servico)
	_fala = Label.new()
	_fala.name = "Fala"
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fala.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fala.add_theme_font_size_override("font_size",10)
	_fala.add_theme_color_override("font_color",Color("493629"))
	coluna.add_child(_fala)
	var rodape := HBoxContainer.new()
	coluna.add_child(rodape)
	_indicador = Label.new()
	_indicador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_indicador.add_theme_font_size_override("font_size",8)
	_indicador.add_theme_color_override("font_color",Color("947353"))
	rodape.add_child(_indicador)
	_continuar = Button.new()
	_continuar.text = "CONTINUAR"
	_continuar.custom_minimum_size.y = 32 if _usa_toque() else 19
	_estilizar_opcao(_continuar)
	if _usa_toque():
		_continuar.icon = preload("res://codigo/ui/icones_toque.gd").glifo(Vector2i(15,5))
		_continuar.add_theme_constant_override("icon_max_width",14)
	_continuar.pressed.connect(_avancar_fala)
	rodape.add_child(_continuar)
	_rosto = PanelContainer.new()
	_rosto.custom_minimum_size = Vector2(66,70)
	_rosto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fundo := _estilo_conversa()
	fundo.set_content_margin_all(3)
	_rosto.add_theme_stylebox_override("panel",fundo)
	var lateral := VBoxContainer.new()
	lateral.add_theme_constant_override("separation", 4)
	_linha_dialogo.add_child(lateral)
	_fechar_dialogo = Button.new()
	_fechar_dialogo.name = "FecharDialogo"
	_fechar_dialogo.text = "X"
	_fechar_dialogo.tooltip_text = "FECHAR CONVERSA"
	_fechar_dialogo.custom_minimum_size = Vector2(32,32) if _usa_toque() else Vector2(26,26)
	_fechar_dialogo.size_flags_horizontal = Control.SIZE_SHRINK_END
	_estilizar_opcao(_fechar_dialogo)
	_fechar_dialogo.pressed.connect(_fechar)
	lateral.add_child(_fechar_dialogo)
	lateral.add_child(_rosto)
	_retrato = RetratoFalante.new()
	_retrato.rotulo = _fala
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rosto.add_child(_retrato)
	_menu_assuntos = PanelContainer.new()
	_menu_assuntos.name = "Assuntos"
	_menu_assuntos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_assuntos.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	coluna.add_child(_menu_assuntos)
	coluna.move_child(_menu_assuntos,3)
	_rolagem = ScrollContainer.new()
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem.follow_focus = true
	_rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var linha_respostas := HBoxContainer.new()
	linha_respostas.add_theme_constant_override("separation",4)
	_menu_assuntos.add_child(linha_respostas)
	_rolagem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rolagem.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	linha_respostas.add_child(_rolagem)
	_menu_assuntos.resized.connect(_encaixar_respostas.call_deferred)
	var setas := VBoxContainer.new()
	setas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	setas.add_theme_constant_override("separation",2)
	linha_respostas.add_child(setas)
	for sentido in [-1,1]:
		var seta := Button.new()
		seta.text = "▲" if sentido < 0 else "▼"
		seta.custom_minimum_size = Vector2(24,24)
		seta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_estilizar_opcao(seta)
		seta.alignment = HORIZONTAL_ALIGNMENT_CENTER
		seta.add_theme_font_size_override("font_size",9)
		seta.pressed.connect(func(): _rolagem.scroll_vertical += sentido * maxf(1.0,_rolagem.get_v_scroll_bar().step))
		setas.add_child(seta)
		if sentido < 0: _subir_respostas = seta
		else: _descer_respostas = seta
	_rolagem.get_v_scroll_bar().changed.connect(_atualizar_setas_respostas)
	_rolagem.get_v_scroll_bar().value_changed.connect(_atualizar_setas_respostas)
	_opcoes = GridContainer.new()
	_opcoes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opcoes.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_opcoes.add_theme_constant_override("h_separation",8)
	_opcoes.add_theme_constant_override("v_separation",2)
	_rolagem.add_child(_opcoes)
	_menu_assuntos.hide()
	visibility_changed.connect(_ao_visibilidade)
	Cidade.alterado.connect(_ao_estado)
	Cidade.conversa_pedida.connect(_ao_conversa)
	resized.connect(_ajustar_conversa)
	_ajustar_conversa()
	visible = false

func _atualizar_setas_respostas(_valor := 0.0) -> void:
	var barra := _rolagem.get_v_scroll_bar()
	_subir_respostas.get_parent().visible = not _menu_principal() and barra.max_value-barra.min_value>barra.page+0.5
	_subir_respostas.disabled = barra.value <= barra.min_value
	_descer_respostas.disabled = barra.value >= barra.max_value - barra.page

func _encaixar_respostas() -> void:
	if not is_inside_tree() or not _menu_assuntos.visible: return
	var altura_linha := 30.0 if _usa_toque() else 24.0
	var estreito := size.x < 360
	var largura_painel := size.x-16.0 if estreito else minf(440.0,size.x-24.0)
	var largura_lista := largura_painel-20.0-(46.0 if estreito else 66.0)-(6.0 if estreito else 12.0)-(28.0 if _subir_respostas.get_parent().visible else 0.0)
	var largura_botao := (largura_lista-8.0*(_opcoes.columns-1))/_opcoes.columns
	for botao in _botoes:
		var moldura_botao := botao.get_theme_stylebox("normal").get_minimum_size()
		var fonte := botao.get_theme_font("font")
		var altura_texto := fonte.get_multiline_string_size(botao.text,HORIZONTAL_ALIGNMENT_CENTER,maxf(40.0,largura_botao-moldura_botao.x),botao.get_theme_font_size("font_size")).y
		# Medir pela largura final: o mínimo do Button antes do layout pode
		# conter uma quebra por letra e perpetuar uma altura enorme.
		var altura_fonte := fonte.get_height(botao.get_theme_font_size("font_size"))
		altura_linha = maxf(altura_linha,ceilf(maxf(altura_fonte,altura_texto)+moldura_botao.y))
	for botao in _botoes: botao.custom_minimum_size.y = altura_linha
	var passo := altura_linha+2.0
	var altura_painel := float((164 if estreito else 148) if _usa_toque() else (144 if estreito else 132))-8.0
	var moldura := painel.get_theme_stylebox("panel").get_minimum_size().y
	var disponivel := altura_painel-moldura-_titulo.get_combined_minimum_size().y-(_resumo_servico.get_combined_minimum_size().y+5 if _resumo_servico.visible else 0.0)-(_continuar.get_combined_minimum_size().y if _continuar.visible else 0.0)-15.0
	var linhas := clampi(floori((disponivel+2.0)/passo),1,maxi(1,ceili(float(_botoes.size())/_opcoes.columns)))
	if _menu_principal(): linhas = maxi(1,ceili(float(_botoes.size())/_opcoes.columns))
	# A janela de respostas termina entre linhas, sem cortar o texto do último botão.
	_rolagem.custom_minimum_size.y = linhas*passo-2.0
	_rolagem.get_v_scroll_bar().step = passo
	_ajustar_conversa.call_deferred()

func _estilo_conversa() -> StyleBoxTexture:
	return preload("res://codigo/ui/estilo_interface.gd").painel(true)

func _estilizar_opcao(botao: Button) -> void:
	Acabamento.botao(botao,false,16)
	botao.alignment = HORIZONTAL_ALIGNMENT_CENTER
	botao.add_theme_font_size_override("font_size",9)
	botao.add_theme_color_override("font_color",Color("62422c"))
	botao.add_theme_color_override("font_hover_color",Color("372418"))
	botao.add_theme_color_override("font_focus_color",Color("372418"))
	botao.add_theme_color_override("font_disabled_color",Color("a49172"))

func _ajustar_conversa() -> void:
	if painel == null:
		return
	var estreito := size.x < 360
	_continuar.custom_minimum_size.y = 32 if _usa_toque() else 19
	_fechar_dialogo.custom_minimum_size = Vector2(32,32) if _usa_toque() else Vector2(26,26)
	var margem := 8.0 if estreito else maxf(12.0,(size.x-440.0)/2.0)
	painel.offset_left = margem
	painel.offset_right = -margem
	painel.offset_top = -(164 if estreito else 148) if _usa_toque() else (-144 if estreito else -132)
	painel.offset_bottom = -8
	_rosto.custom_minimum_size = Vector2(46,58) if estreito else Vector2(66,70)
	_linha_dialogo.add_theme_constant_override("separation",6 if estreito else 12)
	_opcoes.columns = 1 if estreito and not _menu_principal() else 2

func _menu_principal() -> bool:
	return _submenu=="" and _pedido=="" and not _cardapio and not _mesa_aberta and not _carta

## O clique/toque completa a página; a confirmação seguinte avança ou mostra as respostas.
func _avancar_fala() -> void:
	if _menu_assuntos.visible:
		_menu_assuntos.hide()
		_sincronizar_conteudo()
		_atualizar_indicador()
		_continuar.grab_focus()
		return
	if _fala.visible_ratio < 1.0:
		if _digitando != null and _digitando.is_valid():
			_digitando.kill()
		_fala.visible_ratio = 1.0
		_atualizar_indicador()
		return
	if _pagina+1 < _paginas.size():
		_pagina += 1
		_fala.text = _paginas[_pagina]
		_digitar_pagina()
		_atualizar_indicador()
	elif _botoes.is_empty():
		_fechar()
	else:
		_menu_assuntos.visible = not _menu_assuntos.visible
		_sincronizar_conteudo()
		_topo_respostas.call_deferred()
		_atualizar_indicador()
		focar_inicio()

func _preparar_leitura() -> void:
	var texto := _fala.text
	if texto != _texto_completo:
		if _digitando != null and _digitando.is_valid():
			_digitando.kill()
		_texto_completo = texto
		_paginas.clear()
		_pagina = 0
		var estreito := size.x < 360
		var margem := 8.0 if estreito else maxf(12.0,(size.x-440.0)/2.0)
		var largura_texto := maxf(70,size.x-margem*2-20-(46 if estreito else 66)-(6 if estreito else 12))
		var fonte := _fala.get_theme_font("font")
		var pagina := ""
		for palavra in texto.replace("\n"," \n ").split(" ",false):
			var candidato: String = palavra if pagina.is_empty() else pagina+" "+palavra
			var altura := fonte.get_multiline_string_size(candidato,HORIZONTAL_ALIGNMENT_LEFT,largura_texto,10).y
			if altura > 44 and not pagina.is_empty():
				_paginas.append(pagina.strip_edges())
				pagina = palavra
			else:
				pagina = candidato
		_paginas.append(pagina.strip_edges())
	_fala.text = _paginas[_pagina] if not _paginas.is_empty() else ""
	_fala.visible_ratio = 1.0
	_menu_assuntos.visible = (_mesa_aberta or _submenu != "" or _cardapio) and _aviso == ""
	_ajustar_conversa()
	_atualizar_setas_respostas()
	_sincronizar_conteudo()
	_encaixar_respostas.call_deferred()
	_atualizar_indicador()
	_ajustar_conversa.call_deferred()

func _sincronizar_conteudo() -> void:
	_resumo_servico.visible = _atendimento != "" and _menu_assuntos.visible
	_resumo_servico.text = {
		"cozinha":"Escolha um prato para a proxima exploracao.",
		"carpintaria":"Construcoes e aves para sua fazenda.",
		"peixes":"Venda os peixes da sua mochila.",
		"venda":"Troque sua colheita por Brasas.",
		"servicos":"Escolha o atendimento.",
	}.get(_submenu,"Escolha seu pedido.")
	# Fala e respostas compartilham a mesma área, sem outro balão fora da tela.
	_fala.visible = not _menu_assuntos.visible
	_continuar.visible = not _menu_assuntos.visible
	_indicador.visible = not _menu_assuntos.visible
	_rolagem.scroll_vertical = 0

func _topo_respostas() -> void:
	await get_tree().process_frame
	if is_instance_valid(_rolagem) and _menu_assuntos.visible:
		_rolagem.scroll_vertical = 0

func _atualizar_indicador() -> void:
	_indicador.text = "%d / %d" % [_pagina+1,maxi(1,_paginas.size())] if _paginas.size() > 1 else ("" if size.x < 360 or _usa_toque() else (Controle.rotulo_botao(JOY_BUTTON_B,self)+": VOLTAR" if Controle.usando_controle_de(self) else "ESC: DESPEDIR-SE"))
	_continuar.text = "VOLTAR A FALA" if _menu_assuntos.visible else ("CONTINUAR" if _pagina+1 < _paginas.size() else ("VOLTAR" if _atendimento != "" and not _botoes.is_empty() else ("RESPONDER" if _pedido != "" else "DESPEDIR-SE")))

func _digitar_pagina() -> void:
	if _digitando != null and _digitando.is_valid():
		_digitando.kill()
	_fala.visible_ratio = 0.0
	_digitando = create_tween()
	_continuar.text = "CONTINUAR"
	_digitando.tween_property(_fala,"visible_ratio",1.0,maxf(0.15,_fala.text.length()/VELOCIDADE_TEXTO))
	_digitando.tween_callback(_atualizar_indicador)

func focar_inicio() -> void:
	if not _menu_assuntos.visible:
		_continuar.grab_focus()
		return
	for botao in _botoes:
		if not botao.disabled:
			botao.grab_focus()
			return
	_continuar.grab_focus()

func _usa_toque() -> bool:
	return Controle.usando_toque and not EventosJogo.eh_do_p2(self)

func _interlocutor_local() -> String:
	var jogador := EventosJogo.dono(self)
	return String(jogador.get_meta("interlocutor_dialogo",Cidade.interlocutor)) if jogador != null else Cidade.interlocutor

func _ao_visibilidade() -> void:
	if visible:
		_pedido = ""
		_aviso = ""
		_submenu = ""
		var quem := EventosJogo.dono(self)
		_atendimento = String(quem.get_meta("atendimento_dialogo","")) if quem != null else ""
		_mesa_aberta = bool(quem.get_meta("mesa_dialogo",Cidade.mesa_aberta)) if quem != null else Cidade.mesa_aberta
		_vizinhos_mesa = Cidade.mesa_vizinhos.duplicate()
		_cardapio = _mesa_aberta
		var dono_dialogo := EventosJogo.dono(self)
		var carta_local := String(dono_dialogo.get_meta("carta_dialogo",Cidade.carta_aberta)) if dono_dialogo != null else Cidade.carta_aberta
		_carta = carta_local != ""
		if _carta or _mesa_aberta: _atendimento = ""
		if _carta:
			_pedido = carta_local
			_atualizar()
			focar_inicio()
			return
		if _mesa_aberta:
			_atualizar()
			focar_inicio()
			return
		if _atendimento != "":
			_id_atual = _interlocutor_local()
			_submenu = _atendimento
			_atualizar()
			focar_inicio()
		else:
			_abrir_conversa()
	else:
		if _digitando != null and _digitando.is_valid():
			_digitando.kill()
		_fala.visible_ratio = 1.0
		_menu_assuntos.hide()
		_mesa_aberta = false
		_cardapio = false
		if _carta:
			_carta = false
			Cidade.fechar_carta(_pedido)
			var dono_dialogo := EventosJogo.dono(self)
			if dono_dialogo != null: dono_dialogo.set_meta("carta_dialogo","")

## Abertura: na primeira conversa dá as boas-vindas; depois reage ao que o jogador fez desde a última conversa, senão cumprimenta
func _abrir_conversa() -> void:
	var cena := Cooperativo.cena_de(self)
	if cena.has_method("_encerrar_papo"):
		cena._encerrar_papo()
		for npc in cena.moradores.values(): npc.calar()
	var id := _interlocutor_local()
	if not Dados.MORADORES.has(id):
		return
	_id_atual = id
	var ctx := Conversa.contexto(id, get_tree())
	var primeira := Conversa.boas_vindas(id, ctx)
	var reacao := Conversa.reacao(id, ctx)
	# Pedido pronto para entregar: a conversa já abre nele, sem passar pelo botão PEDIDOS
	_pedido = _pedido_pronto(id)
	if _pedido == "" and primeira == "":
		var jornada := preload("res://codigo/cidade/jornada_limiar.gd").rastreio(Cidade,EventosJogo.dono(self))
		if jornada.get("dono","") == id and jornada.get("fase","") == "aceitar" and Cidade.memoria.get("pedido_adiado:"+jornada.id,-1) != Calendario.dia:
			_pedido = jornada.id
		else:
			for chave in Dados.MISSOES:
				if Dados.MISSOES[chave].dono == id and not Cidade.missoes.has(chave) and Cidade.memoria.get("pedido_adiado:"+chave,-1) != Calendario.dia and Dados.missao_na_estacao(chave,Calendario.estacao()):
					_pedido = chave
					break
	if id == "osvaldo" and int(Fazenda.galinheiro.obra) > 0 and bool(cena.get("comparar_visual_fazenda")):
		_falar((primeira+" " if primeira != "" else "")+"Estou cuidando da sua obra. Trabalho das 8h as 17h e termino no dia %d. Depois vou para casa descansar com a familia." % Fazenda.galinheiro.pronto_dia)
	elif primeira != "":
		_falar(primeira)
	else:
		_falar(reacao if reacao != "" else Conversa.conversa_natural(id, ctx))

## Primeiro pedido aceito de `id` com a meta cumprida pelo jogador desta tela ("" se não houver)
func _adiar_pedido() -> void:
	Cidade.memoria["pedido_adiado:"+_pedido] = Calendario.dia
	Cidade.lembrar()
	_fechar()

func _pedido_pronto(id: String) -> String:
	for chave in Dados.MISSOES:
		if Dados.MISSOES[chave]["dono"] != id or Cidade.missoes.get(chave, {}).get("estado", "") != "aceita":
			continue
		var progresso = Cidade.progresso_missao(chave, EventosJogo.dono(self))
		if progresso.x >= progresso.y:
			return chave
	return ""

## Troca a fala em tela, com o texto aparecendo aos poucos
func _falar(texto: String) -> void:
	_texto_completo = ""
	_pagina = 0
	_fala_atual = texto
	_aviso = ""
	_atualizar()
	_menu_assuntos.hide()
	_sincronizar_conteudo()
	_digitar_pagina()
	focar_inicio()

## Assuntos da conversa
func _assunto(qual: String) -> void:
	var id := _interlocutor_local()
	var ctx := Conversa.contexto(id, get_tree())
	var texto := ""
	match qual:
		"papo": texto = Conversa.papo(id, ctx)
		"dica": texto = Conversa.dica(id, ctx)
		"historia": texto = Conversa.historia(id, ctx)
		"vizinhos": texto = Conversa.vizinho(id, ctx)
	_pedido = ""
	_submenu = ""
	_falar(texto if texto != "" else Conversa.saudacao(id, ctx))

func _limpar() -> void:
	_botoes.clear()
	for filho in _opcoes.get_children():
		_opcoes.remove_child(filho)
		filho.queue_free()

func _botao(texto: String, acao: Callable, desativado := false) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size.y = 32 if _usa_toque() else 19
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estilizar_opcao(botao)
	botao.disabled = desativado
	botao.pressed.connect(acao)
	_opcoes.add_child(botao)
	_botoes.append(botao)
	return botao

func _atualizar() -> void:
	_limpar()
	if _carta:
		_mostrar_carta()
		_preparar_leitura()
		Sons.ligar_botoes(self)
		return
	if _mesa_aberta:
		_mostrar_mesa()
		_preparar_leitura()
		Sons.ligar_botoes(self)
		return
	var id := _interlocutor_local()
	if not Dados.MORADORES.has(id):
		return
	if id != _id_atual:
		_pedido = ""
		_id_atual = id
		_abrir_conversa()
		return
	var morador: Dictionary = Dados.MORADORES[id]
	_titulo.text = morador["nome"]
	if _atendimento != "": _titulo.text = {"mercador":"VENDA DO TOMAS","curandeira":"ENFERMARIA","lia":"SEDE DA VILA","bardo":"COZINHA" if _atendimento == "cozinha" else "POUSADA","mistica":"MESA DA ESTELA","osvaldo":"OFICINA DO OSVALDO","nilo":"OFICINA DO NILO"}.get(id,morador["nome"])
	_titulo.tooltip_text = morador["oficio"]
	_retrato.definir_personagem(morador["folha"])
	if _cardapio:
		_mostrar_cardapio()
	elif _atendimento != "" and Atendimento.impedimento(Cooperativo.cena_de(self),id,_atendimento) != "":
		_fala.text = Atendimento.impedimento(Cooperativo.cena_de(self),id,_atendimento)
		_submenu = ""
	elif _submenu == "servicos":
		_fala.text = "Como posso ajudar?"
		_montar_servicos(id,morador)
	elif _submenu == "carpintaria":
		_mostrar_carpintaria()
	elif _submenu == "cozinha":
		_mostrar_cozinha()
	elif _submenu == "peixes":
		_mostrar_venda_peixes()
	elif _submenu == "venda":
		_mostrar_venda_colheita()
	elif _pedido != "":
		_mostrar_pedido()
	else:
		_fala.text = _fala_atual
	if _aviso != "":
		_fala.text = _aviso
	_preparar_leitura()
	Sons.ligar_botoes(self)

func _montar_servicos(id: String, morador: Dictionary) -> void:
	_servico_dialogo(id,morador)
	if id == "bardo":
		if _rotina() != null and _rotina().atendendo():
			_botao("CARDAPIO", _ver_cardapio.bind(true))
		if Cooperativo.cena_de(self).get("local") == "pousada":
			_botao("DORMIR", _abrir_servico.bind("dormir"))

func _servico_dialogo(id: String, morador: Dictionary) -> void:
	if id == "osvaldo":
		_botao("CONSTRUCOES E AVES",_abrir_submenu.bind("carpintaria"))
		return
	if id == "nilo":
		var cena := Cooperativo.cena_de(self)
		var hora: float = cena.hora_atual()
		if cena.local == "palafita" and hora >= 8 and hora < 17:
			_botao("MELHORAR VARA",_ver_vara)
		else:
			_botao("OFICINA: 8H AS 17H",func(): _falar("Leve sua vara ate minha loja no cais, das 8h as 17h. Eu so preciso das pedras de refinamento que voce pescar."))
		return
	# Fora do horário comercial ou no dia de folga o serviço fica fechado (ver Dados.servico_fechado)
	var luz := Cooperativo.cena_de(self).get_node_or_null("Iluminacao")
	var hora: float = luz.hora if luz != null else 12.0
	var fechado := Dados.servico_fechado(id, hora, Calendario.dia_da_semana())
	# De folga ele nem fala de trabalho: a opção de comércio some do diálogo
	if fechado == "FOLGA HOJE":
		return
	if fechado != "" and String(morador["servico"]) != "":
		var botao := _botao(fechado, func() -> void: pass, true)
		var horario: Array = Dados.HORARIOS[id]
		botao.tooltip_text = "Atende das %dh as %dh. Folga: %s." % [int(horario[0]), int(horario[1]), Calendario.DIAS_SEMANA[int(Dados.FOLGAS[id])]]
		return
	var contratado := not id in Progresso.MORADORES or Progresso.tem_morador(id)
	match morador["servico"]:
		"forja":
			_botao("SOBRE A FORJA", func(): _falar("Aprenda as receitas da arena e traga os materiais na mochila ate a bigorna. Voce entrega os materiais ao encomendar; cada arma leva de um a tres dias do nosso calendario. A bigorna mostra a data para voltar e retirar. Atendo das 8h as 18h, exceto quarta."))
		"mercante":
			_botao("SEMENTES", _abrir_servico.bind("mercante"))
			_botao("VENDER PEIXES",_abrir_submenu.bind("peixes"))
		"acampamento":
			_botao("MELHORIAS", _abrir_servico.bind("acampamento"))
			_botao("VENDER COLHEITA", _abrir_submenu.bind("venda"))
		"mistica": _botao("CHECKPOINT", _abrir_servico.bind("mistica"), not contratado)
		"cura":
			_botao("RECUPERAR", _curar, not contratado)
			# As poções (a colheita vira poção) são feitas com ela, contratada ou não
			_botao("POCOES", _abrir_servico.bind("caldeirao"))
	if not contratado and not _botoes.is_empty():
		_botoes[0].tooltip_text = "Use a mesa da sede para contratar este apoio."

func _mostrar_pedido() -> void:
	var dados: Dictionary = Dados.MISSOES[_pedido]
	var estado: String = Cidade.missoes.get(_pedido, {}).get("estado", "disponivel")
	_fala.text = "%s\n%s\nRecompensa: %d Brasas e +2 amizade." % [dados["nome"], dados["texto"], dados["brasas"]]
	if estado == "disponivel":
		_botao("ACEITAR", _aceitar.bind(_pedido))
	elif estado == "aceita":
		var progresso := Cidade.progresso_missao(_pedido,EventosJogo.dono(self))
		_fala.text += " (%d/%d)" % [progresso.x, progresso.y]
		_botao("ENTREGAR", _entregar.bind(_pedido), progresso.x < progresso.y)
	else:
		_fala.text = dados["nome"] + "\nPedido concluido. Obrigado pela ajuda!"
	_botao("AGORA NAO" if estado == "disponivel" else "DEPOIS",_adiar_pedido)

## A carta do pombo-correio: quem pede, o pedido e a recompensa. Aceitar daqui vale o mesmo que pelo morador ou pelo mural
func _mostrar_carta() -> void:
	if not Dados.MISSOES.has(_pedido):
		if not Cidade.carta_misteriosa(_pedido).is_empty():
			_mostrar_carta_misteriosa()
		else:
			_titulo.text = "CARTA INDISPONIVEL"
			_fala.text = "Este pedido nao esta mais disponivel."
			_fala.visible_ratio = 1.0
			_botao("FECHAR",_fechar)
		return
	var dados: Dictionary = Dados.MISSOES[_pedido]
	var dono: String = dados["dono"]
	var morador: Dictionary = Dados.MORADORES[dono]
	_titulo.text = "CARTA DE " + String(morador["nome"])
	_titulo.tooltip_text = "Trazida pelo pombo-correio"
	_retrato.definir_personagem(morador["folha"])
	_fala.text = "%s\n%s\nRecompensa: %d Brasas e +2 amizade." % [dados["nome"], dados["texto"], dados["brasas"]]
	_fala.visible_ratio = 1.0
	if Cidade.missoes.get(_pedido, {}).get("estado", "disponivel") == "disponivel":
		_botao("ACEITAR", _aceitar.bind(_pedido))
		_botao("DEPOIS", _fechar)
	else:
		_botao("FECHAR", _fechar)
	if _aviso != "":
		_fala.text = _aviso + " Para entregar, fale com " + String(morador["nome"]).capitalize() + "."

## Carta sem remetente: só o bilhete, assinado "?", e o presentinho que veio junto (entregue ao fechar)
func _mostrar_carta_misteriosa() -> void:
	var carta: Dictionary = Cidade.carta_misteriosa(_pedido)
	_titulo.text = "CARTA SEM REMETENTE"
	_titulo.tooltip_text = "Trazida pelo pombo-correio. De quem sera?"
	_retrato.definir_imagem(TEXTURA_CARTA_MISTERIOSA)
	_retrato.modulate = Color.WHITE
	_fala.text = "\"%s\"\n- ?" % carta.get("texto", "")
	if int(carta.get("brasas", 0)) > 0:
		_fala.text += "\nDentro do envelope havia %d Brasas." % int(carta["brasas"])
	_fala.visible_ratio = 1.0
	_botao("GUARDAR", _fechar)

# --- Taverna: cardápio e mesa ------------------------------------------------------------------------------------

func _rotina() -> Node:
	return Cooperativo.cena_de(self).get_node_or_null("RotinaTaverna")

# --- Horta: cozinha do Caio e venda de colheita para a Lia ----------------------------------------------------

func _abrir_submenu(qual: String) -> void:
	if _atendimento == "": return
	_submenu = qual if qual != "" else _atendimento
	_aviso = ""
	_atualizar()
	focar_inicio()

func _algum_prato_possivel() -> bool:
	return Refeicoes.ORDEM.any(func(id): return Fazenda.motivo_para_nao_cozinhar(id,EventosJogo.dono(self)) == "")

## Os pratos com a receita; os que faltam ingrediente ficam apagados. Um prato por partida
func _mostrar_cozinha() -> void:
	if Progresso.refeicao != "":
		var atual := Refeicoes.dados(Progresso.refeicao)
		_fala.text = "Voce ja comeu %s (%s). Vale ate o fim da proxima partida na arena; depois eu cozinho outro." % [String(atual["nome"]).to_lower(), Refeicoes.texto_bonus(Progresso.refeicao)]
	else:
		_fala.text = "Traga a colheita e os peixes que eu cozinho. O prato vale a proxima partida inteira na arena (um por vez)."
		for id in Refeicoes.ORDEM:
			var dados := Refeicoes.dados(id)
			var botao := _botao("%s: %s" % [dados["nome"], Refeicoes.texto_bonus(id)], _cozinhar.bind(id), Fazenda.motivo_para_nao_cozinhar(id,EventosJogo.dono(self)) != "")
			botao.tooltip_text = "%s\nReceita: %s" % [dados["texto"], Refeicoes.texto_receita(id, Fazenda.PLANTAS)]

func _cozinhar(id: String) -> void:
	if not _validar_atendimento(): return
	var motivo := Fazenda.cozinhar(id,EventosJogo.dono(self))
	if motivo != "":
		_aviso = motivo
		Sons.tocar("erro", 0.0)
		_atualizar()
		return
	Sons.tocar("caldeirao", 0.0)
	var nome := String(Refeicoes.dados(id)["nome"])
	get_tree().call_group("hud", "anunciar", nome, Refeicoes.texto_bonus(id) + " NA PROXIMA PARTIDA", 3.0)
	_aviso = "Bom apetite! %s vale a proxima partida inteira: %s." % [nome.to_lower(), Refeicoes.texto_bonus(id)]
	_atualizar()
	focar_inicio()

## A Lia troca a colheita por Brasas (melhorias permanentes): um botão por planta, vendendo tudo dela
func _mostrar_venda_colheita() -> void:
	var tem_algo := false
	for planta in Fazenda.ORDEM_PLANTAS:
		var quantidade := Fazenda.quantidade_colhida(planta)
		if quantidade <= 0:
			continue
		tem_algo = true
		var preco := Fazenda.brasas_por_colheita(planta)
		var botao := _botao("%s x%d = %d BRASAS" % [Fazenda.PLANTAS[planta]["nome"], quantidade, quantidade * preco], _vender_colheita.bind(planta))
		botao.tooltip_text = "%d Brasas cada." % preco
	_fala.text = "Colheita vira Brasa para as melhorias da vila. Quanto mais rara a planta, mais vale." if tem_algo \
		else "Voce nao tem colheita guardada. Plante na fazenda e volte aqui."
	_botao("VOLTAR", _abrir_submenu.bind(""))

func _vender_colheita(planta: String) -> void:
	if not _validar_atendimento(): return
	var ganho := Fazenda.vender_colheita(planta)
	if ganho > 0:
		Sons.tocar("moeda", 0.05)
		_aviso = "+%d Brasas. Obrigada! A vila agradece." % ganho
	_atualizar()
	focar_inicio()

func _ver_cardapio(ver: bool) -> void:
	_cardapio = ver
	_aviso = ""
	_atualizar()
	focar_inicio()

## Lista do cardápio com o preço em Brasas; escolher paga e o Caio leva até o jogador
func _mostrar_cardapio() -> void:
	var rotina := _rotina()
	var jogador := EventosJogo.dono(self)
	var esperando: String = rotina.pedido_de(jogador) if rotina != null and jogador != null else ""
	if rotina == null or not rotina.atendendo():
		_fala.text = "A cozinha esta fechada agora. A taverna serve das %dh as %dh." % [Dados.HORARIO_TAVERNA[0], Dados.HORARIO_TAVERNA[1]]
	elif esperando != "":
		_fala.text = "Seu %s ja esta a caminho. O Caio leva ate voce." % String(Dados.CARDAPIO[esperando]["nome"]).to_lower()
	else:
		_fala.text = "CARDAPIO DA TAVERNA (voce tem %d Brasas). O Caio leva o pedido ate a sua mesa." % Progresso.brasas
		for prato in Dados.CARDAPIO:
			var dados: Dictionary = Dados.CARDAPIO[prato]
			var botao := _botao("%s - %d" % [dados["nome"], dados["preco"]], _pedir_prato.bind(prato), Progresso.brasas < int(dados["preco"]))
			botao.tooltip_text = "Recupera %d%% da vida." % roundi(float(dados["cura"]) * 100.0)
	if not _mesa_aberta:
		_botao("VOLTAR", _ver_cardapio.bind(false))

func _pedir_prato(prato: String) -> void:
	var rotina := _rotina()
	var jogador := EventosJogo.dono(self)
	var preco := int(Dados.CARDAPIO[prato]["preco"])
	if rotina == null or jogador == null:
		return
	if Progresso.brasas < preco:
		_aviso = "Brasas insuficientes."
		_atualizar()
		return
	Progresso.brasas -= preco
	var motivo: String = rotina.pedir_jogador(jogador, prato)
	if motivo != "":
		Progresso.brasas += preco
		_aviso = motivo
		_atualizar()
		return
	Progresso.brasas_alteradas.emit(Progresso.brasas)
	Progresso.salvar()
	Sons.tocar("moeda", 0.05)
	_fechar()

## Sentado à mesa da taverna: o cardápio e os vizinhos de mesa (para conversar sem levantar)
func _mostrar_mesa() -> void:
	_titulo.text = "MESA DA TAVERNA"
	_titulo.tooltip_text = ""
	_retrato.definir_imagem(TEXTURA_CARDAPIO)
	_retrato.modulate = Color.WHITE
	var rotina := _rotina()
	if rotina != null:
		_mostrar_cardapio()
	else:
		_fala.text = "Uma mesa tranquila."
	for id in _vizinhos_mesa:
		if Dados.MORADORES.has(id):
			_botao("FALAR COM " + String(Dados.MORADORES[id]["nome"]), _falar_com_vizinho.bind(id))
	_botao("LEVANTAR", _levantar_da_mesa)
	if _aviso != "":
		_fala.text = _aviso

func _falar_com_vizinho(id: String) -> void:
	var jogador := EventosJogo.dono(self)
	_fechar()
	# Reabre como conversa normal (o morador precisa ver a tela abrir para ficar na conversa)
	Cidade.call_deferred("conversar", id, jogador)

func _levantar_da_mesa() -> void:
	var jogador := EventosJogo.dono(self)
	_fechar()
	if jogador != null and bool(jogador.get("esta_sentado")):
		jogador.pediu_levantar.emit()

func _abrir_pedido(id: String) -> void:
	_pedido = id
	_aviso = ""
	_atualizar()
	focar_inicio()


func _ver_vara() -> void:
	if not _validar_atendimento(): return
	_fechar()
	EventosJogo.abrir_tela_de(self,"oficina_vara")

func _mostrar_venda_peixes() -> void:
	var peixes := preload("res://codigo/pesca/peixes.gd")
	_fala.text = "Compro os peixes que voce trouxer da praia e do lago."
	for id in preload("res://codigo/pesca/peixes.gd").DADOS:
		var quantidade := Fazenda.quantidade_peixes(id,EventosJogo.dono(self))
		if quantidade<=0: continue
		_botao("%s x%d = %d BRASAS" % [peixes.nome(id),quantidade,Fazenda.valor_dos_peixes(id,EventosJogo.dono(self))],_vender_peixe.bind(id))
	if Fazenda.total_de_peixes(EventosJogo.dono(self)) == 0:
		_botao("NENHUM PEIXE NA BOLSA",func(): pass,true)
	_botao("VOLTAR",_abrir_submenu.bind(""))

func _vender_peixe(id: String) -> void:
	if not _validar_atendimento(): return
	if _interlocutor_local() != "mercador" or Dados.servico_fechado("mercador",Cooperativo.cena_de(self).hora_atual(),Calendario.dia_da_semana()) != "":
		return
	if Fazenda.vender_peixes(id,EventosJogo.dono(self)) > 0:
		Sons.tocar("moeda",0.05)
	_atualizar()
	focar_inicio()

func _aceitar(id: String) -> void:
	if not Cidade.aceitar(id): return
	if _carta:
		# A confirmação continua sendo a mesma carta até fechar e registrar sua leitura.
		_pedido = id
		_aviso = "Pedido aceito! O pedido ficou no seu diario."
		_atualizar()
		focar_inicio()
		return
	_pedido = ""
	_falar("Combinado! O pedido ficou no seu diario. Volte para falar comigo quando terminar.")

func _entregar(id: String) -> void:
	if Cidade.concluir(id,_interlocutor_local(),EventosJogo.dono(self)):
		_pedido = ""
		_falar(preload("res://codigo/cidade/jornada_limiar.gd").ENTREGAS.get(id, "Obrigado! Voce recebeu %d Brasas e ganhou amizade." % Dados.MISSOES[id]["brasas"]))

func _validar_atendimento() -> bool:
	if _atendimento == "": return false
	var erro := Atendimento.impedimento(Cooperativo.cena_de(self),_interlocutor_local(),_atendimento)
	if erro == "": return true
	_submenu = ""
	_aviso = erro
	_atualizar()
	return false

func _abrir_servico(nome: String) -> void:
	if _validar_atendimento(): super._abrir_servico(nome)

func _curar() -> void:
	if _validar_atendimento() and Progresso.tem_morador("curandeira"): super._curar()

func _mostrar_carpintaria() -> void:
	var criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
	var estado: Dictionary = Fazenda.galinheiro
	_fala.text = "Eu construo o abrigo na sua fazenda. Madeira e pedra saem da mochila de quem encomenda. Os cuidados das aves sao feitos la, diretamente no cenario."
	if estado.obra > 0:
		_fala.text = "A obra do nivel %d fica pronta no dia %d. As aves continuam abrigadas durante a ampliacao." % [estado.obra,estado.pronto_dia]
	elif estado.nivel < 3:
		var proximo: int = estado.nivel+1
		var custo: Array[String] = []
		for material in criacao.CUSTOS[proximo]: custo.append("%d %s" % [criacao.CUSTOS[proximo][material],material.to_upper()])
		_botao(("CONSTRUIR" if estado.nivel == 0 else "AMPLIAR")+" GALINHEIRO\n"+", ".join(custo)+" / %d DIA(S)" % criacao.PRAZOS[proximo],_encomendar_carpinteiro.bind("construir"))
		_fala.text += "\nMateriais: %s. Prazo: %d dia(s). Capacidade: %d aves." % [", ".join(custo),criacao.PRAZOS[proximo],criacao.CAPACIDADES[proximo]]
	if estado.nivel > 0:
		_botao("GALINHA: 25 BRASAS",_encomendar_carpinteiro.bind("comprar"))
		_botao("GALO: 25 BRASAS",_encomendar_carpinteiro.bind("comprar_galo"))

func _encomendar_carpinteiro(acao: String) -> void:
	if not _validar_atendimento(): return
	var cena := Cooperativo.cena_de(self)
	var luz := cena.get_node_or_null("Iluminacao")
	if luz == null or luz.hora_do_mundo() < 8 or luz.hora_do_mundo() >= 17:
		_aviso = "Recebo encomendas das 8h as 17h."
		_atualizar()
		return
	var erro := preload("res://codigo/fazenda/criacao_galinhas.gd").executar(Fazenda,EventosJogo.dono(self),acao)
	_aviso = erro if erro != "" else "Combinado! Os materiais ja estao separados. Vou trabalhar na sua fazenda das 8h as 17h; termino no dia %d." % Fazenda.galinheiro.pronto_dia if acao == "construir" else "Combinado! Sua encomenda foi registrada."
	_atualizar()
