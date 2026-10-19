extends Control

const Plantas := preload("res://codigo/dados/plantas.gd")
const Pocoes := preload("res://codigo/dados/pocoes.gd")
var painel: PanelContainer
var _lista: VBoxContainer
var _botoes: Array[Button] = []
var _rolagem: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://recursos/ui/tema_sidebar.tres")
	painel = PanelContainer.new()
	painel.name = "Painel"
	painel.set_anchors_preset(Control.PRESET_CENTER)
	var moldura := preload("res://codigo/ui/estilo_interface.gd").painel(false, 10.0)
	painel.add_theme_stylebox_override("panel", moldura)
	painel.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(painel)
	_rolagem = ScrollContainer.new()
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem.follow_focus = true
	painel.add_child(_rolagem)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	_rolagem.add_child(_lista)
	Comercio.alterado.connect(_atualizar)
	visibility_changed.connect(_ao_visibilidade)
	resized.connect(_ajustar)
	visible = false
	_ajustar()

func _ajustar() -> void:
	var largura := minf(450, maxf(140, size.x - 16))
	var altura := minf(300, maxf(120, size.y - 16))
	painel.offset_left = -largura / 2
	painel.offset_right = largura / 2
	painel.offset_top = -altura / 2
	painel.offset_bottom = altura / 2

func _lado() -> int:
	return 2 if EventosJogo.eh_do_p2(self) else 1

func _ao_visibilidade() -> void:
	if visible:
		_atualizar()
	elif not Comercio.em_viagem:
		Comercio.cancelar_preparo(_lado())

func _texto(texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", 9)
	_lista.add_child(rotulo)

func _botao(texto: String, acao: Callable, bloqueado := false) -> void:
	var botao := Button.new()
	botao.text = texto
	botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	botao.custom_minimum_size.y = 23
	botao.add_theme_font_size_override("font_size", 9)
	botao.disabled = bloqueado
	botao.pressed.connect(acao)
	_lista.add_child(botao)
	_botoes.append(botao)

func _atualizar() -> void:
	if not visible or _lista == null:
		return
	var foco := get_viewport().gui_get_focus_owner()
	var indice_foco := _botoes.find(foco)
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	_botoes.clear()
	var lado := _lado()
	_texto("CARROCA • VILA DAS COLINAS")
	_texto("VIAJANTE %d • %d MOEDAS • CARGA %d/%d" % [lado, EventosJogo.moedas_de(self), Comercio.carga.size(), Comercio.capacidade()])
	if Comercio.aviso != "":
		_texto(Comercio.aviso)
	if Comercio.em_combate:
		_texto("O COMBATE ACONTECE JUNTO DA CARROCA.")
		_botao("VOLTAR A LUTA", _fechar)
		_botao("RECUAR (PERDE 1 CARGA)", func(): Comercio.terminar_combate(false))
	elif not Comercio.em_viagem:
		_preparar(lado)
	elif Comercio.etapa < Comercio.eventos.size():
		var evento: Array = Comercio.EVENTOS[Comercio.eventos[Comercio.etapa]]
		_vinheta(true)
		_texto("ESTRADA • PARADA %d/%d • ATRASO %dH" % [Comercio.etapa + 1, Comercio.eventos.size(), Comercio.atraso])
		_texto(evento[0] + "\n" + evento[1])
		for i in evento[2].size():
			_botao(evento[2][i], Comercio.escolher.bind(i, lado), Comercio.votos.has(lado))
	elif Comercio.etapa == Comercio.eventos.size():
		_vinheta(false)
		_texto("MERCADO • PEDIDOS DA SEMANA")
		_pedidos()
		_texto("VENDA SUA CARGA; O OURO CHEGA NA VOLTA.")
		_carga(lado, true)
		_botao("TERMINEI • VOLTAR", Comercio.pedir_retorno.bind(lado), Comercio.votos.has(lado))
	else:
		_vinheta(false)
		_texto("VOLTA PARA CASA\nVENDAS: P1 %d • P2 %d MOEDAS\nATRASO NA ESTRADA: %d HORAS\nA VIAGEM CONSOME O DIA. VOCE ACORDA AMANHA.\nCARGA NAO VENDIDA VOLTA PARA A BOLSA." % [Comercio.receita[0], Comercio.receita[1], Comercio.atraso])
		if Comercio.carona:
			_texto("A VIAJANTE PEDIU AO POMBO QUE VISITE SUA CASA.")
		_botao("VOLTAR E ENCERRAR O DIA", Comercio.voltar)
	if indice_foco >= 0 and not _botoes.is_empty():
		var indice := mini(indice_foco, _botoes.size() - 1)
		if not _botoes[indice].disabled:
			_botoes[indice].grab_focus()
		else:
			focar_inicio()
	Sons.ligar_botoes(self)

func _vinheta(mover: bool) -> void:
	var vista := preload("res://codigo/comercio/vista_viagem.gd").new()
	vista.andando = mover
	_lista.add_child(vista)

func _pedidos() -> void:
	var pedidos := Comercio.pedidos()
	for chave: String in pedidos:
		_texto("%s • RESTAM %d • %d MOEDAS/UN" % [Comercio.nome_produto(chave), maxi(0, int(pedidos[chave]) - int(Comercio.atendidos.get(chave, 0))), Comercio.preco_local(chave) * 2])
	_texto("FORA DO PEDIDO: PRECO BASE +1. COTAS COMPARTILHADAS.")

func _preparar(lado: int) -> void:
	_texto("IDA E VOLTA LEVAM O DIA. PARTIDA: 6H A 10H.\nCADA CASA LEVA UMA UNIDADE. NO COOP, OS DOIS VAO JUNTOS.")
	_pedidos()
	_botao("CONFIRMAR PARTIDA", Comercio.confirmar.bind(lado), Comercio.prontos.has(lado))
	_botao("FECHAR", _fechar)
	_texto("PELAGEM DO CAVALO")
	for cor in 3:
		_botao(["PRETO", "MARROM", "BRANCO"][cor] + (" • SELECIONADO" if Comercio.pelagem == cor else ""), Comercio.definir_pelagem.bind(cor), Comercio.pelagem == cor)
	if Comercio.nivel < 2:
		_botao("MELHORAR: +2 CASAS (%d MOEDAS)" % (120 + Comercio.nivel * 120), func(): Comercio.melhorar(EventosJogo.dono(self)))
	_carga(lado, false)
	_texto("CARREGAR DA BOLSA DA FAZENDA")
	for id: String in Plantas.ORDEM_PLANTAS:
		_produto("colheita:" + id, lado)
	for id: String in Pocoes.ORDEM:
		_produto("pocao:" + id, lado)

func _produto(chave: String, lado: int) -> void:
	var quantidade := Comercio.disponivel(chave)
	if quantidade > 0:
		_botao("+ %s (%d)" % [Comercio.nome_produto(chave), quantidade], Comercio.reservar.bind(chave, lado), Comercio.carga.size() >= Comercio.capacidade())

func _carga(lado: int, vender: bool) -> void:
	for i in Comercio.carga.size():
		var c: Dictionary = Comercio.carga[i]
		var texto := "%02d • P%d • %s" % [i + 1, int(c.lado), Comercio.nome_produto(c.chave)]
		if vender:
			texto += " • VENDER %d" % Comercio.preco(c.chave)
		else:
			texto += " • RETIRAR"
		_botao(texto, Comercio.vender.bind(i, lado) if vender else Comercio.retirar.bind(i, lado), int(c.lado) != lado)

func _fechar() -> void:
	EventosJogo.fechar_tela_de(self, "comercio")

func focar_inicio() -> void:
	for botao in _botoes:
		if not botao.disabled:
			botao.grab_focus()
			return
