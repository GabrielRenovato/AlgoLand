extends Control

## Carta dos lugares permanentes. É uma ilustração de consulta, sem viagem rápida.
const DadosMapa := preload("res://codigo/ui/dados_mapa_mundi.gd")
const Moradores := preload("res://codigo/cidade/dados_cidade.gd")
const IconeServico := preload("res://codigo/ui/icone_servico_mapa.gd")
const IMAGEM := "res://assets/ui/mapa_mundi/algoland.png"
const PONTO_VILA := Vector2(0.72,0.34)
const DESCRICAO_VILA := "Praca e mural. Venda do Tomas, Forja do Ivo, Comunidade, Enfermaria, Pousada, Bento e Mistica."
var painel: PanelContainer
var _rolagem: ScrollContainer
var _carta: Control
var _imagem: TextureRect
var _detalhe: Label
var _objetivo_principal: Label
const Jornada := preload("res://codigo/cidade/jornada_limiar.gd")
var _atores: Dictionary = {}
var _servicos: Dictionary = {}
var _tempo_atores := 0.0
var _ocupados: Dictionary = {}
var _fechar: Button
var _zoom := 1.0
var _tamanho_area := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = preload("res://recursos/ui/tema_sidebar.tres")
	painel = PanelContainer.new()
	painel.add_theme_stylebox_override("panel", preload("res://codigo/ui/estilo_interface.gd").painel(false,8.0))
	add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 4)
	painel.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	coluna.add_child(cabecalho)
	var titulo := Label.new()
	titulo.text = "ALGOLAND"
	titulo.add_theme_font_size_override("font_size",12)
	titulo.size_flags_horizontal = SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	for texto in ["-", "+", "1:1"]:
		var botao := Button.new()
		botao.text = texto
		botao.custom_minimum_size = Vector2(24,24)
		botao.add_theme_font_size_override("font_size",8)
		botao.pressed.connect(_alterar_zoom.bind(texto))
		cabecalho.add_child(botao)
	_fechar = Button.new()
	_fechar.text = "X"
	_fechar.custom_minimum_size = Vector2(24,24)
	_fechar.pressed.connect(func(): EventosJogo.fechar_tela_de(self,"mapa_mundi"))
	cabecalho.add_child(_fechar)
	_objetivo_principal = Label.new()
	_objetivo_principal.add_theme_font_size_override("font_size",8)
	_objetivo_principal.add_theme_color_override("font_color",Color("f6d879"))
	_objetivo_principal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_objetivo_principal)
	_rolagem = ScrollContainer.new()
	_rolagem.name = "RolagemMapa"
	_rolagem.size_flags_vertical = SIZE_EXPAND_FILL
	_rolagem.follow_focus = true
	_rolagem.clip_contents = true
	coluna.add_child(_rolagem)
	_carta = Control.new()
	_carta.mouse_filter = MOUSE_FILTER_PASS
	_rolagem.add_child(_carta)
	_imagem = TextureRect.new()
	_imagem.texture = load(IMAGEM)
	_imagem.texture_filter = TEXTURE_FILTER_NEAREST
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.mouse_filter = MOUSE_FILTER_IGNORE
	_carta.add_child(_imagem)
	for id in DadosMapa.CASAS:
		var dados: Dictionary = DadosMapa.CASAS[id]
		var botao := Button.new()
		botao.tooltip_text = dados["nome"]
		_moldurar_icone(botao,Color("807055"),Color.WHITE)
		var icone := IconeServico.new()
		icone.tipo = dados["icone"]
		icone.mouse_filter = MOUSE_FILTER_IGNORE
		botao.add_child(icone)
		_encaixar_icone(icone)
		botao.pressed.connect(func(): _detalhe.text = dados["nome"]+": "+dados["texto"])
		_carta.add_child(botao)
		_servicos[id] = botao
	_detalhe = Label.new()
	_detalhe.add_theme_font_size_override("font_size",8)
	_detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalhe.custom_minimum_size.y = 28
	coluna.add_child(_detalhe)
	resized.connect(_ajustar)
	# A quebra de linha muda a altura mínima depois que os containers recebem largura.
	painel.minimum_size_changed.connect(_ajustar.call_deferred)
	visibility_changed.connect(_ao_abrir)
	_ajustar()
	_detalhe.text = DESCRICAO_VILA

func regiao_atual() -> String:
	var jogador := EventosJogo.dono(self)
	var cena := Cooperativo.cena_de(jogador) if jogador != null else null
	if cena == null: return ""
	var caminho: String = cena.scene_file_path
	if caminho in ["res://cenas/fazenda.tscn", "res://cenas/casa.tscn"]: return "fazenda"
	if caminho == "res://cenas/cidade.tscn" or caminho.begins_with("res://cenas/cidade/"): return "cidade"
	if caminho == "res://cenas/praia.tscn": return "praia"
	if caminho == "res://cenas/palafita.tscn": return "palafita"
	return ""

func _ao_abrir() -> void:
	if not is_visible_in_tree(): return
	_zoom = 1.0
	_detalhe.text = DESCRICAO_VILA
	_ajustar()

func _centralizar_vila() -> void:
	if _zoom > 1.0:
		var ponto: Vector2 = _imagem.position + PONTO_VILA * _imagem.size
		_rolagem.scroll_horizontal = int(ponto.x - _rolagem.size.x / 2)
		_rolagem.scroll_vertical = int(ponto.y - _rolagem.size.y / 2)

func _alterar_zoom(acao: String) -> void:
	_zoom = 1.0 if acao == "1:1" else clampf(_zoom + (0.5 if acao == "+" else -0.5),1.0,3.0)
	_tamanho_area = Vector2.ZERO
	_dimensionar_carta()
	_centralizar_vila()

func _ajustar() -> void:
	if painel == null: return
	var medida := Vector2(minf(size.x-16,800),size.y-16)
	painel.size = medida
	painel.position = (size-medida)/2
	_tamanho_area = Vector2.ZERO
	_dimensionar_carta.call_deferred()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_dimensionar_carta()
	_tempo_atores -= delta
	if _tempo_atores <= 0:
		_tempo_atores = 0.1
		_atualizar_atores()

func _dimensionar_carta() -> void:
	var area := _rolagem.size - Vector2(12,12)
	if area.x <= 0 or area.y <= 0 or area.is_equal_approx(_tamanho_area): return
	_tamanho_area = area
	var textura := Vector2(_imagem.texture.get_size())
	var fator := minf(area.x/textura.x,area.y/textura.y) * _zoom
	_imagem.size = (textura*fator).floor()
	_carta.custom_minimum_size = area.max(_imagem.size)
	_carta.size = _carta.custom_minimum_size
	_imagem.position = ((_carta.size-_imagem.size)/2).floor()
	for id in _servicos:
		var botao: Button = _servicos[id]
		botao.custom_minimum_size = Vector2.ONE * (14 if painel.size.x >= 400 else 12)
		botao.size = botao.custom_minimum_size
		botao.position = (_imagem.position+DadosMapa.CASAS[id]["ponto"]*_imagem.size-botao.size/2).floor()
	_atualizar_atores()

func focar_inicio() -> void:
	_fechar.grab_focus()

func _moldurar_icone(botao: Button, cor := Color("ffe491"), fundo_cor := Color("111111")) -> void:
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = fundo_cor
	fundo.border_color = cor
	fundo.set_border_width_all(1)
	fundo.set_corner_radius_all(100)
	fundo.set_content_margin_all(0)
	for estado in ["normal","hover","pressed","focus"]:
		botao.add_theme_stylebox_override(estado,fundo)

func _encaixar_icone(icone: TextureRect) -> void:
	icone.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# O desenho inteiro cabe no círculo, inclusive os cantos, sem recortar o atlas.
	icone.offset_left = 3
	icone.offset_top = 3
	icone.offset_right = -3
	icone.offset_bottom = -3

func _ator(chave: String, nome: String, textura: Texture2D = null) -> Button:
	if _atores.has(chave): return _atores[chave]
	var botao := Button.new()
	botao.tooltip_text = nome
	botao.add_theme_color_override("font_color",Color("65d9ff") if chave=="p2" else Color("ffe491"))
	botao.custom_minimum_size = Vector2(13,13)
	botao.size = botao.custom_minimum_size
	_moldurar_icone(botao,Color("65d9ff") if chave=="p2" else Color("ffe491"))
	if textura != null:
		var retrato := TextureRect.new()
		retrato.texture = textura
		retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		retrato.mouse_filter = MOUSE_FILTER_IGNORE
		botao.add_child(retrato)
		_encaixar_icone(retrato)
	else:
		botao.set_meta("jogador_mapa",chave)
		var rotulo := preload("res://codigo/ui/rotulo_jogador_mapa.gd").new()
		rotulo.texto = "P1" if chave=="p1" else "P2"
		rotulo.cor = Color("65d9ff") if chave=="p2" else Color("ffe491")
		botao.add_child(rotulo)
		rotulo.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	botao.pressed.connect(func(): _detalhe.text = botao.tooltip_text)
	_carta.add_child(botao)
	_atores[chave] = botao
	return botao

func _colocar_ator(botao: Button, ponto: Vector2) -> void:
	botao.custom_minimum_size = Vector2.ONE*(14 if painel.size.x>=400 else 12)
	if botao.has_meta("jogador_mapa"):
		# Diâmetro ímpar mantém os sete pixels do rótulo no centro exato do círculo.
		botao.custom_minimum_size += Vector2.ONE
	botao.size = botao.custom_minimum_size
	botao.visible = ponto.x >= 0
	botao.set_meta("ponto_carta",ponto)
	if botao.visible:
		var chave := Vector2i(ponto*512)
		var indice: int = _ocupados.get(chave,0)
		_ocupados[chave] = indice+1
		var desvio := Vector2((indice%3)*10,(indice/3)*10) if indice>0 else Vector2.ZERO
		botao.position = (_imagem.position+ponto*_imagem.size-botao.size/2+desvio).floor()

func _atualizar_atores() -> void:
	if _imagem == null or _imagem.size.x <= 0: return
	_ocupados.clear()
	var cena := get_tree().current_scene
	if cena == null: return
	var objetivo := Jornada.rastreio(Cidade,EventosJogo.dono(self))
	_objetivo_principal.text = "! PRINCIPAL: "+objetivo.texto
	for id in _servicos:
		_marcar_principal(_servicos[id],objetivo.fase == "cumprir" and id == "casa")
	var luz := cena.get_node_or_null("Iluminacao")
	var hora: float = float(luz.hora) if luz != null else maxf(6,Transicao.hora_salva)
	var clima: int = preload("res://codigo/cenario/clima.gd").clima_do_mundo(Calendario.estacao())
	for id in Moradores.MORADORES:
		var agenda: Dictionary = Moradores.agenda(id,hora,Calendario.estacao(),clima,Calendario.dia_da_semana())
		var local: String = agenda.get("local", "")
		var ponto: Vector2 = agenda.get("ponto",Vector2.ZERO)
		# Moradores instanciados seguem a caminhada real, inclusive durante a troca de rotina.
		for npc in get_tree().get_nodes_in_group("moradores_cidade"):
			if npc.id == id and npc.visible:
				local = npc.vila.local
				ponto = npc.position
				break
		var botao: Button
		if _atores.has("npc_"+id): botao = _atores["npc_"+id]
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://assets/npcs/retratos/"+Moradores.MORADORES[id]["folha"]+".png")
			atlas.region = Rect2(0,0,128,128)
			botao = _ator("npc_"+id,Moradores.MORADORES[id]["nome"],atlas)
		botao.tooltip_text = Moradores.MORADORES[id]["nome"]+" - "+str(agenda.get("atividade",""))
		_marcar_principal(botao,objetivo.dono == id)
		if objetivo.dono == id: botao.tooltip_text += "\nMISSAO PRINCIPAL: "+objetivo.texto
		_colocar_ator(botao,DadosMapa.projetar(local,ponto))
	for par in [["p1",Cooperativo._jogador1()],["p2",Cooperativo.jogador2()]]:
		var jogador: Node2D = par[1]
		if jogador == null:
			if _atores.has(par[0]): _atores[par[0]].hide()
			continue
		var ambiente := Cooperativo.cena_de(jogador)
		var local: String = ambiente.scene_file_path.get_file().get_basename()
		var posicao := DadosMapa.projetar(local,jogador.position)
		_colocar_ator(_ator(par[0],"JOGADOR "+par[0].substr(1)+" - "+jogador.apelido),posicao)

func _marcar_principal(botao: Button, ativo: bool) -> void:
	var marca := botao.get_node_or_null("MissaoPrincipal") as Label
	if marca == null:
		marca = Label.new()
		marca.name = "MissaoPrincipal"
		marca.text = "!"
		marca.position = Vector2(-4,-9)
		marca.add_theme_font_size_override("font_size",12)
		marca.add_theme_color_override("font_color",Color("ffe27a"))
		marca.add_theme_color_override("font_outline_color",Color("302117"))
		marca.add_theme_constant_override("outline_size",3)
		marca.mouse_filter = MOUSE_FILTER_IGNORE
		botao.add_child(marca)
	marca.visible = ativo
