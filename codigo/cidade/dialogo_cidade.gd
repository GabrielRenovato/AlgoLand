extends "res://codigo/cidade/tela_cidade.gd"

## Caixa de diálogo de RPG: fala, retrato e assuntos. O que cada morador diz vem de conversa_moradores.gd
## (personalidade, dicas pelo estado do jogo, histórias pela amizade, opinião sobre os vizinhos); um pedido por vez.
const Conversa := preload("res://codigo/cidade/conversa_moradores.gd")
## Letras por segundo do texto aparecendo
const VELOCIDADE_TEXTO := 70.0
var _retrato: TextureRect
var _opcoes: HFlowContainer
var _pedido := ""
## Mostrando o cardápio da taverna (na conversa com o Caio ou na mesa)
var _cardapio := false
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = TEMA
	painel = PanelContainer.new()
	painel.name = "Painel"
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	painel.anchor_left = 0.06
	painel.anchor_right = 0.94
	painel.offset_left = 0
	painel.offset_right = 0
	if get_viewport().has_meta("dono"):
		painel.anchor_left = 0.0
		painel.anchor_right = 1.0
		painel.offset_left = 8
		painel.offset_right = -8
	painel.offset_top = -150
	# Com muitos assuntos os botões quebram linha: a caixa cresce para cima, sem sair da tela
	painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	painel.offset_bottom = -8
	var moldura := StyleBoxFlat.new()
	moldura.bg_color = Color("26232b")
	moldura.border_color = Color("a89267")
	moldura.set_border_width_all(2)
	moldura.content_margin_left = 12
	moldura.content_margin_right = 12
	moldura.content_margin_top = 9
	moldura.content_margin_bottom = 9
	moldura.shadow_color = Color(0, 0, 0, 0.35)
	moldura.shadow_size = 3
	painel.add_theme_stylebox_override("panel", moldura)
	add_child(painel)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	painel.add_child(linha)
	var rosto := PanelContainer.new()
	rosto.custom_minimum_size = Vector2(64, 64)
	rosto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("35303a")
	fundo.border_color = Color("665746")
	fundo.set_border_width_all(1)
	rosto.add_theme_stylebox_override("panel", fundo)
	linha.add_child(rosto)
	_retrato = TextureRect.new()
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rosto.add_child(_retrato)
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 4)
	linha.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	coluna.add_child(cabecalho)
	_titulo = Label.new()
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.add_theme_color_override("font_color", Color("e7c884"))
	cabecalho.add_child(_titulo)
	var fechar := Button.new()
	fechar.text = "X"
	fechar.tooltip_text = "Encerrar conversa (Esc / B)"
	fechar.custom_minimum_size = Vector2(24, 20)
	fechar.pressed.connect(_fechar)
	cabecalho.add_child(fechar)
	_fala = Label.new()
	_fala.name = "Fala"
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fala.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fala.add_theme_color_override("font_color", Color("eee6d5"))
	coluna.add_child(_fala)
	_opcoes = HFlowContainer.new()
	_opcoes.add_theme_constant_override("h_separation", 6)
	_opcoes.add_theme_constant_override("v_separation", 4)
	coluna.add_child(_opcoes)
	visibility_changed.connect(_ao_visibilidade)
	Cidade.alterado.connect(_ao_estado)
	Cidade.conversa_pedida.connect(_ao_conversa)
	visible = false

func _ao_visibilidade() -> void:
	if visible:
		_pedido = ""
		_aviso = ""
		_submenu = ""
		_cardapio = Cidade.mesa_aberta
		_carta = Cidade.carta_aberta != ""
		if _carta:
			_pedido = Cidade.carta_aberta
			_atualizar()
			focar_inicio()
			return
		if Cidade.mesa_aberta:
			_atualizar()
			focar_inicio()
			return
		_abrir_conversa()
	else:
		Cidade.mesa_aberta = false
		_cardapio = false
		if _carta:
			_carta = false
			Cidade.fechar_carta()

## Abertura: na primeira conversa dá as boas-vindas; depois reage ao que o jogador fez desde a última conversa, senão cumprimenta
func _abrir_conversa() -> void:
	var id := Cidade.interlocutor
	if not Dados.MORADORES.has(id):
		return
	_id_atual = id
	var ctx := Conversa.contexto(id, get_tree())
	var primeira := Conversa.boas_vindas(id, ctx)
	var reacao := Conversa.reacao(id, ctx)
	if primeira != "":
		_falar(primeira)
	else:
		_falar(reacao if reacao != "" else Conversa.saudacao(id, ctx))

## Troca a fala em tela, com o texto aparecendo aos poucos
func _falar(texto: String) -> void:
	_fala_atual = texto
	_aviso = ""
	_atualizar()
	if _digitando != null and _digitando.is_valid():
		_digitando.kill()
	_fala.visible_ratio = 0.0
	_digitando = create_tween()
	_digitando.tween_property(_fala, "visible_ratio", 1.0, maxf(0.15, texto.length() / VELOCIDADE_TEXTO))
	focar_inicio()

## Assuntos da conversa
func _assunto(qual: String) -> void:
	var id := Cidade.interlocutor
	var ctx := Conversa.contexto(id, get_tree())
	var texto := ""
	match qual:
		"papo": texto = Conversa.papo(id, ctx)
		"dica": texto = Conversa.dica(id, ctx)
		"historia": texto = Conversa.historia(id, ctx)
		"vizinhos": texto = Conversa.vizinho(id, ctx)
	_pedido = ""
	_falar(texto if texto != "" else Conversa.saudacao(id, ctx))

func _limpar() -> void:
	_botoes.clear()
	for filho in _opcoes.get_children():
		_opcoes.remove_child(filho)
		filho.queue_free()

func _botao(texto: String, acao: Callable, desativado := false) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size.y = 24
	botao.disabled = desativado
	botao.pressed.connect(acao)
	_opcoes.add_child(botao)
	_botoes.append(botao)
	return botao

func _atualizar() -> void:
	_limpar()
	if _carta:
		_mostrar_carta()
		Sons.ligar_botoes(self)
		return
	if Cidade.mesa_aberta:
		_mostrar_mesa()
		Sons.ligar_botoes(self)
		return
	var id := Cidade.interlocutor
	if not Dados.MORADORES.has(id):
		return
	if id != _id_atual:
		_pedido = ""
		_id_atual = id
		_abrir_conversa()
		return
	var morador: Dictionary = Dados.MORADORES[id]
	_titulo.text = morador["nome"]
	_titulo.tooltip_text = morador["oficio"]
	var folha: Texture2D = load(Dados.caminho_sprite(id))
	var retrato := AtlasTexture.new()
	retrato.atlas = folha
	retrato.region = Rect2(64, 0, 64, 64)
	_retrato.texture = retrato
	_retrato.modulate = morador["cor"]
	if _cardapio:
		_mostrar_cardapio()
	elif _submenu == "cozinha":
		_mostrar_cozinha()
	elif _submenu == "venda":
		_mostrar_venda_colheita()
	elif _pedido != "":
		_mostrar_pedido()
	else:
		_fala.text = _fala_atual
		var ctx := Conversa.contexto(id, get_tree())
		_botao("CONVERSAR", _assunto.bind("papo"))
		_botao("DICA", _assunto.bind("dica"))
		_botao("HISTORIA*" if Conversa.tem_historia_nova(id, ctx) else "HISTORIA", _assunto.bind("historia"))
		_botao("VIZINHOS", _assunto.bind("vizinhos"))
		_servico_dialogo(id, morador)
		var pedidos: Array = Dados.MISSOES.keys().filter(func(chave): return Dados.MISSOES[chave]["dono"] == id)
		if not pedidos.is_empty():
			var pronto := pedidos.any(func(chave): return Cidade.missoes.get(chave, {}).get("estado", "") == "aceita" and Cidade.progresso_missao(chave).x >= Cidade.progresso_missao(chave).y)
			_botao("PEDIDOS!" if pronto else "PEDIDOS", _abrir_pedido.bind(pedidos[0]))
		if id == "bardo" and _rotina() != null and _rotina().atendendo():
			_botao("CARDAPIO", _ver_cardapio.bind(true))
		# O Caio cozinha com a colheita a qualquer hora: o prato vale a próxima partida na arena
		if id == "bardo":
			_botao("COZINHAR*" if Progresso.refeicao == "" and _algum_prato_possivel() else "COZINHAR", _abrir_submenu.bind("cozinha"))
		if Cooperativo.cena_de(self).get("local") == "pousada":
			_botao("DORMIR", _abrir_servico.bind("dormir"))
	if _aviso != "":
		_fala.text = _aviso
	Sons.ligar_botoes(self)

func _servico_dialogo(id: String, morador: Dictionary) -> void:
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
		"mercante": _botao("SEMENTES", _abrir_servico.bind("mercante"))
		"acampamento":
			_botao("MELHORIAS", _abrir_servico.bind("acampamento"))
			_botao("VENDER COLHEITA", _abrir_submenu.bind("venda"))
		"mistica": _botao("CHECKPOINT", _abrir_servico.bind("mistica"), not contratado)
		"cura":
			_botao("RECUPERAR", _curar, not contratado)
			# As poções (a colheita vira poção) são feitas com ela, contratada ou não
			_botao("POCOES", _abrir_servico.bind("caldeirao"))
	if not contratado and not _botoes.is_empty():
		_botoes[0].tooltip_text = "Converse com Lia para contratar este apoio."

func _mostrar_pedido() -> void:
	var dados: Dictionary = Dados.MISSOES[_pedido]
	var estado: String = Cidade.missoes.get(_pedido, {}).get("estado", "disponivel")
	_fala.text = "%s\n%s\nRecompensa: %d Brasas e +2 amizade." % [dados["nome"], dados["texto"], dados["brasas"]]
	if estado == "disponivel":
		_botao("ACEITAR", _aceitar.bind(_pedido))
	elif estado == "aceita":
		var progresso := Cidade.progresso_missao(_pedido)
		_fala.text += " (%d/%d)" % [progresso.x, progresso.y]
		_botao("ENTREGAR", _entregar.bind(_pedido), progresso.x < progresso.y)
	else:
		_fala.text = dados["nome"] + "\nPedido concluido. Obrigado pela ajuda!"
	var pedidos: Array = Dados.MISSOES.keys().filter(func(chave): return Dados.MISSOES[chave]["dono"] == Cidade.interlocutor)
	if pedidos.size() > 1:
		_botao("OUTRO PEDIDO", _abrir_pedido.bind(pedidos[(pedidos.find(_pedido) + 1) % pedidos.size()]))
	_botao("VOLTAR", _abrir_pedido.bind(""))

## A carta do pombo-correio: quem pede, o pedido e a recompensa. Aceitar daqui vale o mesmo que pelo morador ou pelo mural
func _mostrar_carta() -> void:
	if not Dados.MISSOES.has(_pedido):
		_mostrar_carta_misteriosa()
		return
	var dados: Dictionary = Dados.MISSOES[_pedido]
	var dono: String = dados["dono"]
	var morador: Dictionary = Dados.MORADORES[dono]
	_titulo.text = "CARTA DE " + String(morador["nome"])
	_titulo.tooltip_text = "Trazida pelo pombo-correio"
	var retrato := AtlasTexture.new()
	retrato.atlas = load(Dados.caminho_sprite(dono))
	retrato.region = Rect2(64, 0, 64, 64)
	_retrato.texture = retrato
	_retrato.modulate = morador["cor"]
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
	_retrato.texture = TEXTURA_CARTA_MISTERIOSA
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
	_submenu = qual
	_aviso = ""
	_atualizar()
	focar_inicio()

func _algum_prato_possivel() -> bool:
	return Refeicoes.ORDEM.any(func(id): return Fazenda.motivo_para_nao_cozinhar(id) == "")

## Os pratos com a receita; os que faltam ingrediente ficam apagados. Um prato por partida
func _mostrar_cozinha() -> void:
	if Progresso.refeicao != "":
		var atual := Refeicoes.dados(Progresso.refeicao)
		_fala.text = "Voce ja comeu %s (%s). Vale ate o fim da proxima partida na arena; depois eu cozinho outro." % [String(atual["nome"]).to_lower(), Refeicoes.texto_bonus(Progresso.refeicao)]
	else:
		_fala.text = "Traga a colheita que eu cozinho. O prato vale a proxima partida inteira na arena (um por vez)."
		for id in Refeicoes.ORDEM:
			var dados := Refeicoes.dados(id)
			var botao := _botao("%s: %s" % [dados["nome"], Refeicoes.texto_bonus(id)], _cozinhar.bind(id), Fazenda.motivo_para_nao_cozinhar(id) != "")
			botao.tooltip_text = "%s\nReceita: %s" % [dados["texto"], Refeicoes.texto_receita(id, Fazenda.PLANTAS)]
	_botao("VOLTAR", _abrir_submenu.bind(""))

func _cozinhar(id: String) -> void:
	var motivo := Fazenda.cozinhar(id)
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
	if not Cidade.mesa_aberta:
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
	_retrato.texture = TEXTURA_CARDAPIO
	_retrato.modulate = Color.WHITE
	var rotina := _rotina()
	if rotina != null:
		_mostrar_cardapio()
	else:
		_fala.text = "Uma mesa tranquila."
	for id in Cidade.mesa_vizinhos:
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

