extends Control

const Receitas := preload("res://codigo/dados/forja_armas.gd")
const Desafios := preload("res://codigo/dados/desafios_armas.gd")
const DadosCidade := preload("res://codigo/cidade/dados_cidade.gd")
const Estilo := preload("res://codigo/ui/estilo_interface.gd")
const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")
const Ferramentas := preload("res://codigo/dados/melhorias_ferramentas.gd")
var _modo_ferramentas := false
var _categorias: HBoxContainer
var painel: PanelContainer
var _nome: Label
var _custos: VBoxContainer
var _receitas_coluna: VBoxContainer
var _papel: PanelContainer
var _abas: HBoxContainer
var _aba_detalhes := false
var _legenda: Label
var _bigorna: TextureRect
var _coluna: VBoxContainer
var _material_titulo: Label
var _icone_previa: TextureRect
var _dados_arma: Label
var _resumo_receitas: Label
var _fontes: Label
var _rolagem_receitas: ScrollContainer
var _grade_receitas: GridContainer
var _situacao: Label
var _fabricar: Button
var _fechar: Button
var _botoes := {}
var _tipo := "arco_curto"
var _mensagem := ""
var _ajuste_pendente := false
var _compacto := false
var _espera_atendimento := 0.0
var _estado_atendimento := ""

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_espera_atendimento -= delta
	if _espera_atendimento > 0:
		return
	_espera_atendimento = 0.25
	var estado := _situacao_atendimento()
	if estado != _estado_atendimento:
		_mensagem = ""
		_atualizar()

func _oficina() -> Node:
	var cena := Cooperativo.cena_de(self)
	return cena.get_node_or_null("Bigorna/TrabalhoFerreiro") if cena != null else null

func _situacao_atendimento() -> String:
	var oficina := _oficina()
	var trabalho: String = oficina.situacao(EventosJogo.inventario_de(self),_tipo) if oficina != null else ""
	return DadosCidade.atendimento_forja(Cooperativo.cena_de(self),Calendario.dia_da_semana())+"|"+trabalho

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://recursos/ui/tema_sidebar.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel = PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.add_theme_stylebox_override("panel", Estilo.painel(false,10.0))
	add_child(painel)
	var coluna := VBoxContainer.new()
	_coluna = coluna
	coluna.add_theme_constant_override("separation",5)
	painel.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	cabecalho.add_theme_constant_override("separation",8)
	coluna.add_child(cabecalho)
	var bigorna := TextureRect.new()
	_bigorna = bigorna
	var recorte := AtlasTexture.new()
	recorte.atlas = preload("res://assets/cenario/cidade/ambientes/interior/forja/fornalha/primavera.png")
	recorte.region = Rect2(47,23,32,30)
	bigorna.texture = recorte
	bigorna.custom_minimum_size = Vector2(28,28)
	bigorna.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bigorna.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cabecalho.add_child(bigorna)
	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = SIZE_EXPAND_FILL
	titulos.add_theme_constant_override("separation",0)
	cabecalho.add_child(titulos)
	var titulo := _rotulo(titulos,11)
	titulo.text = "BIGORNA DO IVO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var legenda := _rotulo(titulos,8)
	_legenda = legenda
	legenda.text = "8H AS 18H - FOLGA: QUARTA"
	legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legenda.add_theme_color_override("font_color",Color("e4bd72"))
	_fechar = Button.new()
	_fechar.text = "X"
	_fechar.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fechar.custom_minimum_size = Vector2(32,32)
	_fechar.pressed.connect(func(): EventosJogo.fechar_tela_de(get_parent(),"forja"))
	cabecalho.add_child(_fechar)
	_categorias=HBoxContainer.new()
	_categorias.add_theme_constant_override("separation",5)
	coluna.add_child(_categorias)
	var categorias_grupo:=ButtonGroup.new()
	for entrada in [["FABRICAR",false],["FERRAMENTAS",true]]:
		var categoria:=Button.new()
		categoria.text=entrada[0]
		categoria.toggle_mode=true
		categoria.button_group=categorias_grupo
		categoria.theme_type_variation=&"BotaoAba"
		categoria.alignment=HORIZONTAL_ALIGNMENT_CENTER
		categoria.size_flags_horizontal=SIZE_EXPAND_FILL
		categoria.custom_minimum_size.y=28
		categoria.set_pressed_no_signal(not entrada[1])
		categoria.pressed.connect(_mudar_categoria.bind(entrada[1]))
		_categorias.add_child(categoria)
	_abas = HBoxContainer.new()
	coluna.add_child(_abas)
	for entrada in [["RECEITAS",false],["ITEM E MATERIAIS",true]]:
		var aba := Button.new()
		aba.text = entrada[0]
		aba.size_flags_horizontal = SIZE_EXPAND_FILL
		aba.custom_minimum_size.y = 28
		aba.theme_type_variation = &"BotaoAba"
		aba.toggle_mode = true
		aba.pressed.connect(_mostrar_detalhes.bind(entrada[1]))
		_abas.add_child(aba)
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation",8)
	coluna.add_child(corpo)
	_receitas_coluna = VBoxContainer.new()
	_receitas_coluna.size_flags_horizontal = SIZE_EXPAND_FILL
	corpo.add_child(_receitas_coluna)
	_resumo_receitas = _rotulo(_receitas_coluna,8)
	_resumo_receitas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rolagem_receitas = ScrollContainer.new()
	_rolagem_receitas.size_flags_vertical = SIZE_EXPAND_FILL
	_rolagem_receitas.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem_receitas.follow_focus = true
	_receitas_coluna.add_child(_rolagem_receitas)
	_grade_receitas = GridContainer.new()
	_grade_receitas.size_flags_horizontal = SIZE_EXPAND_FILL
	_grade_receitas.add_theme_constant_override("h_separation",4)
	_grade_receitas.add_theme_constant_override("v_separation",4)
	_rolagem_receitas.add_child(_grade_receitas)
	var grupo := ButtonGroup.new()
	for tipo in Receitas.RECEITAS.keys()+Ferramentas.TIPOS:
		var botao := Button.new()
		botao.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var margem := MarginContainer.new()
		margem.name = "Conteudo"
		margem.mouse_filter = MOUSE_FILTER_IGNORE
		botao.add_child(margem)
		margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for lado in ["left","right","top","bottom"]: margem.add_theme_constant_override("margin_"+lado,8)
		var conteudo := VBoxContainer.new()
		conteudo.mouse_filter = MOUSE_FILTER_IGNORE
		conteudo.add_theme_constant_override("separation",2)
		margem.add_child(conteudo)
		var icone := TextureRect.new()
		icone.name = "Icone"
		icone.texture = Icones.obter(Receitas.criar_item(tipo),get_tree())
		icone.custom_minimum_size = Vector2(16,16)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.mouse_filter = MOUSE_FILTER_IGNORE
		conteudo.add_child(icone)
		var nome := _rotulo(conteudo,8)
		nome.name = "Nome"
		nome.text = Receitas.nome(tipo)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nome.size_flags_vertical = SIZE_EXPAND_FILL
		nome.add_theme_color_override("font_color",Color("34292c"))
		nome.mouse_filter = MOUSE_FILTER_IGNORE
		botao.toggle_mode = true
		botao.button_group = grupo
		botao.theme_type_variation = &"BotaoAba"
		botao.pressed.connect(_selecionar.bind(tipo))
		_grade_receitas.add_child(botao)
		_botoes[tipo] = botao
		botao.visible=not tipo in Ferramentas.TIPOS
	_papel = PanelContainer.new()
	_papel.size_flags_horizontal = SIZE_EXPAND_FILL
	_papel.size_flags_stretch_ratio = 1.35
	_papel.add_theme_stylebox_override("panel",Estilo.painel(true,10.0))
	corpo.add_child(_papel)
	var detalhes_scroll := ScrollContainer.new()
	detalhes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detalhes_scroll.follow_focus = true
	_papel.add_child(detalhes_scroll)
	var detalhes := VBoxContainer.new()
	detalhes.size_flags_horizontal = SIZE_EXPAND_FILL
	detalhes.add_theme_constant_override("separation",5)
	detalhes_scroll.add_child(detalhes)
	var previa := HBoxContainer.new()
	previa.add_theme_constant_override("separation",6)
	detalhes.add_child(previa)
	var moldura := PanelContainer.new()
	moldura.add_theme_stylebox_override("panel",preload("res://codigo/ui/estilo_slot.gd").caixa())
	previa.add_child(moldura)
	_icone_previa = TextureRect.new()
	_icone_previa.custom_minimum_size = Vector2(36,36)
	_icone_previa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icone_previa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moldura.add_child(_icone_previa)
	var nomes := VBoxContainer.new()
	nomes.size_flags_horizontal = SIZE_EXPAND_FILL
	previa.add_child(nomes)
	_nome = _rotulo(nomes,10)
	_nome.add_theme_color_override("font_color",Color("493020"))
	_dados_arma = _rotulo(nomes,8)
	_dados_arma.add_theme_color_override("font_color",Color("805532"))
	var materiais := _rotulo(detalhes,8)
	_material_titulo = materiais
	materiais.text = "MATERIAIS NA MOCHILA"
	materiais.add_theme_color_override("font_color",Color("805532"))
	_custos = VBoxContainer.new()
	_custos.name = "Materiais"
	_custos.add_theme_constant_override("separation",3)
	detalhes.add_child(_custos)
	_situacao = _rotulo(detalhes,8)
	_situacao.add_theme_color_override("font_color",Color("65472f"))
	var ajuda := Button.new()
	ajuda.text = "ONDE CONSEGUIR"
	ajuda.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ajuda.toggle_mode = true
	ajuda.custom_minimum_size.y = 24
	ajuda.add_theme_font_size_override("font_size",8)
	detalhes.add_child(ajuda)
	_fontes = _rotulo(detalhes,8)
	_fontes.add_theme_color_override("font_color",Color("65472f"))
	_fontes.hide()
	ajuda.toggled.connect(func(aberto: bool): _fontes.visible = aberto)
	_fabricar = Button.new()
	_fabricar.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fabricar.theme_type_variation = &"BotaoPrimario"
	_fabricar.custom_minimum_size.y = 32
	_fabricar.pressed.connect(_ao_fabricar)
	coluna.add_child(_fabricar)
	Progresso.materiais_forja_alterados.connect(_atualizar)
	Progresso.armas_liberadas_alteradas.connect(_atualizar)
	EventosJogo.inventario_de(self).mochila_alterada.connect(_atualizar)
	visibility_changed.connect(_ao_visibilidade)
	resized.connect(_ajustar)
	painel.minimum_size_changed.connect(_agendar_ajuste)
	_ajustar()
	_atualizar()

func _rotulo(pai: Node, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.size_flags_horizontal = SIZE_EXPAND_FILL
	pai.add_child(rotulo)
	return rotulo

func _ao_visibilidade() -> void:
	if visible:
		_mensagem = ""
		_atualizar()

func _selecionar(tipo: String) -> void:
	_tipo = tipo
	_botoes[tipo].grab_focus()
	_mostrar_detalhes(true)
	_mensagem = ""
	_atualizar()

func _atualizar() -> void:
	if not is_instance_valid(_nome):
		return
	if _modo_ferramentas:
		_atualizar_ferramenta()
		return
	_nome.text = Receitas.nome(_tipo)
	_icone_previa.material=null
	_icone_previa.texture = Icones.obter(Receitas.criar_item(_tipo),get_tree())
	var item = Receitas.criar_item(_tipo)
	var prazo := Receitas.dias_fabricacao(_tipo)
	_dados_arma.text = "%s - NIVEL 1\nPRAZO: %d DIA%s DO JOGO" % [item.categoria.to_upper(),prazo,"S" if prazo != 1 else ""]
	var encomendada := str(Progresso.encomenda_forja.get("tipo","")) == _tipo
	_material_titulo.text = "MATERIAIS ENTREGUES" if encomendada else "MATERIAIS NECESSARIOS"
	for filho in _custos.get_children():
		filho.free()
	for id in Receitas.RECEITAS[_tipo]:
		var tem := Progresso.quantidade_material_forja(id,EventosJogo.inventario_de(self))
		var precisa: int = Receitas.RECEITAS[_tipo][id]
		if encomendada: tem = precisa
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation",6)
		_custos.add_child(linha)
		var icone := TextureRect.new()
		icone.texture = load("res://assets/ui/coletaveis/%s.png" % id)
		icone.custom_minimum_size = Vector2(12,12) if _compacto else Vector2(16,16)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		linha.add_child(icone)
		var nome_material := _rotulo(linha,8)
		nome_material.text = Receitas.MATERIAIS[id]["nome"]
		nome_material.add_theme_color_override("font_color",Color("493629"))
		var quantidade := Label.new()
		quantidade.text = "%d / %d" % [tem,precisa]
		quantidade.add_theme_font_size_override("font_size",8)
		quantidade.add_theme_color_override("font_color",Color("44602c") if tem >= precisa else Color("9a3d32"))
		quantidade.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		linha.add_child(quantidade)
	var origens: Array[String] = []
	for id in Receitas.RECEITAS[_tipo]:
		origens.append(Receitas.MATERIAIS[id]["origem"])
	_fontes.text = "\n".join(origens)
	var aprendidas := 0
	for tipo in Receitas.RECEITAS:
		if Progresso.receita_liberada(tipo): aprendidas += 1
	_resumo_receitas.text = "RECEITAS: %d / %d" % [aprendidas,Receitas.RECEITAS.size()]
	var fabricada := Progresso.arma_liberada(_tipo)
	var receita := Progresso.receita_liberada(_tipo)
	_situacao.text = _mensagem
	if _mensagem.is_empty():
		_situacao.text = "MODELO PERMANENTE.\nReceba comum, nivel 1, a cada partida." if fabricada else ("RECEITA APRENDIDA.\nOs materiais serao consumidos da sua mochila." if receita else "ENCONTRE A RECEITA NA ARENA E USE NA MOCHILA.\nA PARTIR DO ANDAR %d." % Receitas.onda_receita(_tipo))
	var inventario := EventosJogo.inventario_de(self)
	var falta_entregar: bool = fabricada and not _tipo in inventario.armas_permanentes_entregues
	_fabricar.text = "RETIRAR ITEM" if falta_entregar else ("JA FABRICADA" if fabricada else "ENCOMENDAR")
	_fabricar.disabled = not falta_entregar if fabricada else Progresso.motivo_fabricar_arma(_tipo,EventosJogo.inventario_de(self)) != ""
	_fabricar.tooltip_text = Progresso.motivo_fabricar_arma(_tipo,EventosJogo.inventario_de(self)) if not fabricada else "Uma copia por jogador e por partida."
	if not Progresso.encomenda_forja.is_empty():
		_fabricar.text = "RETIRAR ENCOMENDA" if encomendada and Progresso.encomenda_forja_pronta() else "EM FABRICACAO"
		_fabricar.disabled = not (encomendada and Progresso.encomenda_forja_pronta())
		_fabricar.tooltip_text = Progresso.texto_encomenda_forja()
	var fechado := DadosCidade.atendimento_forja(Cooperativo.cena_de(self), Calendario.dia_da_semana())
	_estado_atendimento = _situacao_atendimento()
	if not fechado.is_empty():
		_situacao.text = fechado + ".\nATENDIMENTO: 8H AS 18H. FOLGA: QUARTA."
		_fabricar.disabled = true
		_fabricar.tooltip_text = fechado
	var oficina := _oficina()
	if oficina != null:
		var trabalho: String = oficina.situacao(inventario,_tipo)
		if _mensagem.is_empty() and not trabalho.is_empty() and (not Progresso.encomenda_forja.is_empty() or fechado.is_empty()):
			_situacao.text = trabalho
			if not fechado.is_empty(): _situacao.text += "\n"+fechado+"."
		if oficina.pedido_atual() != null and not Progresso.encomenda_forja_pronta():
			_fabricar.disabled = true
			_fabricar.tooltip_text = "AGUARDE IVO TERMINAR O PEDIDO"
	for tipo in _botoes:
		if tipo in Ferramentas.TIPOS: continue
		_botoes[tipo].set_pressed_no_signal(tipo == _tipo)
		_botoes[tipo].tooltip_text = "RECEITA APRENDIDA" if Progresso.receita_liberada(tipo) else "RECEITA A PARTIR DO ANDAR %d" % Receitas.onda_receita(tipo)

func _ao_fabricar() -> void:
	var cena := Cooperativo.cena_de(self)
	var fechado := DadosCidade.atendimento_forja(cena, Calendario.dia_da_semana())
	if fechado != "":
		_mensagem = fechado
		_atualizar()
		return
	if _modo_ferramentas:
		var oficina_ferramentas := _oficina()
		if oficina_ferramentas!=null and oficina_ferramentas.pedido_atual()!=null and not Progresso.encomenda_forja_pronta():
			_mensagem="AGUARDE IVO TERMINAR O PEDIDO"
		else:
			_mensagem=Ferramentas.melhorar(EventosJogo.inventario_de(self),_tipo)
			if _mensagem.is_empty():
				_mensagem="FERRAMENTA MELHORADA!"
				Sons.tocar("compra",.05)
		_atualizar()
		return
	if not Progresso.encomenda_forja.is_empty():
		if str(Progresso.encomenda_forja["tipo"]) != _tipo:
			_mensagem = "RETIRE A ENCOMENDA ATUAL ANTES DE PEDIR OUTRA"
		else:
			_mensagem = Progresso.retirar_encomenda_forja(EventosJogo.inventario_de(self))
			if _mensagem.is_empty(): _mensagem = "ENCOMENDA RETIRADA! MODELO LIBERADO PARA SEMPRE."
		_atualizar()
		return
	if not Progresso.arma_liberada(_tipo):
		var oficina := _oficina()
		_mensagem = oficina.iniciar(_tipo,EventosJogo.inventario_de(self)) if oficina != null else "OFICINA INDISPONIVEL"
		_atualizar()
		if _mensagem.is_empty():
			EventosJogo.fechar_tela_de(get_parent(),"forja")
		return
	var inventario := EventosJogo.inventario_de(self)
	inventario.entregar_armas_liberadas()
	_mensagem = "MODELO LIBERADO PARA SEMPRE!" if _tipo in inventario.armas_permanentes_entregues else "MODELO LIBERADO! MOCHILA CHEIA: LIBERE ESPACO E RETIRE SEM CUSTO."
	_atualizar()

func _mostrar_detalhes(aberto: bool) -> void:
	_aba_detalhes = aberto
	if _receitas_coluna == null or _papel == null: return
	_receitas_coluna.visible = not _compacto or not aberto
	_papel.visible = not _compacto or aberto
	_fabricar.visible = not _compacto or aberto
	for i in _abas.get_child_count():
		_abas.get_child(i).set_pressed_no_signal(aberto == (i == 1))

func _mudar_categoria(ferramentas: bool) -> void:
	_modo_ferramentas=ferramentas
	for i in _categorias.get_child_count(): _categorias.get_child(i).set_pressed_no_signal(ferramentas==(i==1))
	_tipo=Ferramentas.TIPOS[0] if ferramentas else "arco_curto"
	_mensagem=""
	for tipo in _botoes: _botoes[tipo].visible=(tipo in Ferramentas.TIPOS)==ferramentas
	_mostrar_detalhes(false)
	_atualizar()
	_agendar_ajuste()

func _atualizar_ferramenta() -> void:
	var inventario := EventosJogo.inventario_de(self)
	var grau := Ferramentas.nivel(inventario,_tipo)
	var proximo := mini(3,grau+1)
	_nome.text=Receitas.nome(_tipo)
	_icone_previa.texture=Icones.obter(Receitas.criar_item(_tipo),get_tree())
	_icone_previa.material=preload("res://codigo/dados/ferramentas_madeira.gd").do_tipo(_tipo,grau)
	_dados_arma.text="%s > %s\n%s" % [Ferramentas.NOMES[grau-1],Ferramentas.NOMES[proximo-1],Ferramentas.descricao(_tipo,proximo)]
	_resumo_receitas.text="FERRAMENTAS - MELHORIA IMEDIATA"
	_material_titulo.text="MATERIAIS PARA MELHORAR"
	for filho in _custos.get_children(): filho.free()
	if grau<3:
		for id in Ferramentas.CUSTOS[proximo]:
			var linha:=HBoxContainer.new()
			linha.add_theme_constant_override("separation",6)
			_custos.add_child(linha)
			var icone:=TextureRect.new()
			icone.texture=load("res://assets/ui/coletaveis/%s.png" % id)
			icone.custom_minimum_size=Vector2(16,16)
			icone.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			icone.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			linha.add_child(icone)
			var texto:=_rotulo(linha,8)
			var precisa: int=Ferramentas.CUSTOS[proximo][id]
			var tem: int=inventario.quantidade_tipo("material:"+id)
			texto.text="%s: %d / %d" % [str(id).to_upper(),tem,precisa]
			texto.add_theme_color_override("font_color",Color("47603a") if tem>=precisa else Color("9a4632"))
	var motivo := Ferramentas.motivo(inventario,_tipo)
	var fechado := DadosCidade.atendimento_forja(Cooperativo.cena_de(self),Calendario.dia_da_semana())
	_situacao.text=_mensagem if not _mensagem.is_empty() else ("TRAGA OS MATERIAIS DA SUA MOCHILA.\nNAO PRECISA DE RECEITA." if motivo.is_empty() else motivo)
	if not fechado.is_empty(): _situacao.text=fechado
	_fabricar.text="NIVEL MAXIMO" if grau==3 else "MELHORAR FERRAMENTA"
	_fabricar.disabled=not motivo.is_empty() or not fechado.is_empty()
	_fontes.text="Madeira, pedra e fibra: fazenda. Ferro: andares. A vara continua com Nilo."
	for tipo in _botoes:
		_botoes[tipo].set_pressed_no_signal(tipo==_tipo)
		if tipo in Ferramentas.TIPOS:
			var n := Ferramentas.nivel(inventario,tipo)
			var icone: TextureRect=_botoes[tipo].find_child("Icone",true,false)
			icone.material=preload("res://codigo/dados/ferramentas_madeira.gd").do_tipo(tipo,n)
			_botoes[tipo].tooltip_text=Ferramentas.NOMES[n-1]+" - "+Ferramentas.descricao(tipo,n)

func _ajustar() -> void:
	if painel == null or _fabricar == null: return
	_compacto = size.x < 540 or size.y < 280
	_abas.visible = _compacto
	_legenda.visible = not _compacto
	_material_titulo.visible = not _compacto
	_bigorna.custom_minimum_size = Vector2(20,20) if _compacto else Vector2(28,28)
	_fechar.custom_minimum_size = Vector2(24,24) if _compacto else Vector2(32,32)
	_fabricar.custom_minimum_size.y = 28 if _compacto else 32
	_coluna.add_theme_constant_override("separation",4 if _compacto else 5)
	painel.add_theme_stylebox_override("panel",Estilo.painel(false,8 if _compacto else 10))
	_papel.add_theme_stylebox_override("panel",Estilo.painel(true,8 if _compacto else 10))
	for aba in _abas.get_children(): aba.custom_minimum_size.y = 24
	for linha in _custos.get_children(): linha.get_child(0).custom_minimum_size = Vector2(12,12) if _compacto else Vector2(16,16)
	_grade_receitas.columns = 3 if _compacto else 2
	_rolagem_receitas.custom_minimum_size.x = 0
	for botao in _botoes.values():
		botao.size_flags_horizontal = SIZE_EXPAND_FILL
		botao.custom_minimum_size = Vector2(0,80 if _compacto else 72)
	_icone_previa.custom_minimum_size = Vector2(20,20)
	var medida := Vector2(minf(600,size.x-16),minf(340,size.y-16))
	painel.custom_minimum_size = medida
	painel.size = medida
	painel.position = ((size-medida)/2).round()
	_mostrar_detalhes(_aba_detalhes)

func _agendar_ajuste() -> void:
	if _ajuste_pendente:
		return
	_ajuste_pendente = true
	_ajustar_apos_layout.call_deferred()

func _ajustar_apos_layout() -> void:
	_ajuste_pendente = false
	_ajustar()

func focar_inicio() -> void:
	_atualizar()
	_botoes[_tipo].grab_focus()
