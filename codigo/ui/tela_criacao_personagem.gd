extends Control

## Criação do personagem (novo jogo): escolhe o cabelo, a roupa, a cor do cabelo e o nome, com prévia de corpo inteiro e giro manual.
## Acabamento pintado da tela inicial, fontes pixeladas e seleção com moldura dourada.
## Personagem e miniaturas preservam seus sprites e filtro nativo.
## Funciona com mouse, teclado, controle (foco nas casinhas; Q/E ou LB/RB trocam de aba; o nome abre o teclado virtual) e toque, com catálogo paginado e sem depender de passar o mouse.
## As peças vêm de aparencia_raven.gd. Ao confirmar grava aparencia_raven no arquivo do jogador,
## preservando os campos antigos para compatibilidade, e entra no jogo.

signal confirmada(dados: Dictionary)
signal cancelada
## Modo edição (menu de pausa / aviso de visual novo): sem trocar de cena, mescla com o save existente
## e conserva o cabelo/roupa escolhidos para o Raven 2D.
var modo_edicao := false
var _dados_existentes: Dictionary = {}

const Aparencia := preload("res://codigo/dados/aparencia_raven.gd")
const PreviaDigitacao := preload("res://codigo/ui/previa_digitacao.gd")
const TecladoVirtual := preload("res://codigo/ui/teclado_virtual.gd")
const EstiloInicio := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const TEMA := preload("res://recursos/ui/tema_sidebar.tres")
const FONTE_TITULO := preload("res://assets/ui/craftpix-net-775352-game-user-interface-pixel-art/6 Font/CraftPixNet Survival Kit.otf")
const SETA_ESQUERDA := preload("res://assets/ui/sem org/3 Icons/Icons_14.png")
const SETA_DIREITA := preload("res://assets/ui/sem org/3 Icons/Icons_15.png")
var _textura_corpo: Texture2D = Aparencia.corpo("andar", 0, 0)

const CENA_JOGO := "res://cenas/cidade.tscn"
const CENA_TITULO := "res://cenas/inicio_do_jogo.tscn"
const CAMINHO_SAVE := "user://configuracao_jogador.json"
const CENA_CRIACAO := "res://cenas/criacao_personagem.tscn"
## Mundo cooperativo novo: 1 = criando o jogador 1, 2 = criando o jogador 2 (depois entra no jogo); 0 = jogo solo
static var etapa_coop := 0
const NOME_PADRAO := "sem apelido"
const MAX_APELIDO := 12

## Cores de cabelo prontas: a cor que multiplica a folha cinza do cabelo (as folhas v00 são em tons de cinza)
const PALETA: Array[Color] = [
	Color(0.30, 0.28, 0.32), Color(0.55, 0.36, 0.22), Color(0.78, 0.50, 0.28), Color(0.90, 0.68, 0.40), Color(1.00, 0.86, 0.39),
	Color(1.00, 0.96, 0.75), Color(0.95, 0.42, 0.20), Color(0.75, 0.25, 0.18), Color(1.00, 1.00, 1.00), Color(0.70, 0.70, 0.78),
	Color(0.35, 0.60, 1.00), Color(0.25, 0.35, 0.80), Color(0.40, 0.85, 0.45), Color(0.30, 0.85, 0.80), Color(1.00, 0.55, 0.75),
	Color(0.65, 0.40, 0.95), Color(0.85, 0.30, 0.70), Color(1.00, 0.65, 0.20), Color(0.50, 0.15, 0.30), Color(0.60, 0.70, 0.30),
]
const COR_INICIAL := Color(0.55, 0.36, 0.22)

## Casinhas: quadro do personagem parado de frente (folha 8x8 de 64 px; ele ocupa mais ou menos x 24-40 e y 13-44) recortado em volta da
## cabeça (cabelos) ou do corpo todo (roupas)
const REGIAO_CABELO := Rect2(8, 0, 48, 52)
const REGIAO_ROUPA := Rect2(8, 0, 48, 52)
const MOLDURA_CASA := 3
const FOLGA_PREVIA_CASA := 6
const ESPACO_CASAS := 3
## Linha da folha de andar de cada direção, na ordem em que o personagem gira: baixo, direita, cima, esquerda
const LINHAS_DIRECAO := [0, 2, 1, 3]
const ESCALA_PREVIA := 3.0
## As casinhas dos cabelos mostram a cabeça em 2x (são poucas e o detalhe do penteado importa); as das roupas, o corpo todo em 1x
const ESCALA_CASA_CABELO := 2
const ESCALA_CASA_ROUPA := 1

const COR_TEXTO := Color(0.93, 0.9, 0.85)
const COR_DESCRICAO := Color(0.75, 0.7, 0.62)
const COR_OURO := Color(1, 0.85, 0.45)

enum Aba { CABELO, ROUPA, COR }

## true: ao confirmar entra no jogo (os testes desligam)
var trocar_cena := true
## Onde o personagem é gravado (os testes usam um arquivo deles)
var caminho_save := CAMINHO_SAVE

var cabelo := 0
var roupa := 0
var pele := 0
## Cor dos olhos (índice em HeroiBase3D.OLHOS); o Raven 2D não desenha a íris, o personagem 3D usa.
var olhos := 0
const CORES_OLHOS: Array = preload("res://codigo/jogador/heroi_base_3d.gd").OLHOS
var _botoes_olhos: Array[Button] = []
## Personagem 3D: penteado e peças do catálogo de roupas 3D, com prévia do próprio modelo.
const Roupas3D := preload("res://codigo/dados/roupas_base_3d.gd")
const PreviaHeroi3D := preload("res://codigo/ui/previa_heroi_3d.gd")
const NOMES_CATEGORIA_3D := {"camisa":"PARTE DE CIMA","calca":"PARTE DE BAIXO","calcado":"CALCADO","cabelo":"PENTEADO"}
## O Raven 2D ainda desenha o jogador fora do modo 3D: cada penteado leva um cabelo parecido.
const CABELO_RAVEN_DO_3D := {"cabelo_curto":1, "cabelo_raspado":3}
var roupas_3d: Dictionary = Roupas3D.padrao()
var _previa_3d: Node2D
var _opcoes_3d: Dictionary = {} # categoria -> Array[[id, Button]]
var _tempo_animacao := 0.0
var cor: Color = COR_INICIAL
var cor_personalizada := true
var apelido := ""
var aba: Aba = Aba.CABELO

var _direcao := 0
var _saindo := false
var _atualizando_sliders := false

var _previa_roupa: Sprite2D
var _previa_cabelo: Sprite2D
var _previa_corpo: Sprite2D
var _modelo: Node2D
var _rotulo_cabelo: Label
var _rotulo_roupa: Label
var _botoes_aba: Array[Button] = []
var _botoes_pele: Array[Button] = []
var _paginas: Array[Control] = []
var _casas_cabelo: Array[Dictionary] = []
var _casas_roupa: Array[Dictionary] = []
var _limites_miniaturas: Dictionary = {}
var _casas_cor: Array[Button] = []
var _slider_matiz: HSlider
var _slider_saturacao: HSlider
var _slider_brilho: HSlider
var _amostra_cor: ColorRect
var _colunas: BoxContainer
var _painel_previa: Control
var _painel_edicao: Control
var _grade_cores: GridContainer
var _conteudo: Control
var _palco: Control
var _campo_nome: LineEdit
var _botao_confirmar: Button
var _botao_voltar: Button
var _botao_aleatorio: Button
var _teclado: CanvasLayer
var _catalogos: Array[Dictionary] = []
var _botoes_estrutura: Array[Button] = []
var _linhas_previa: VBoxContainer
var _linhas_edicao: VBoxContainer
var _rotulo_girar: Label
var _rotulo_pele: Label
var _rotulo_nome: Label
var _titulo_cor: Label
var _compacto := false
var _minimo := false
var _construtor_fazenda: RefCounted
var _cortina: ColorRect

func _ready() -> void:
	theme = TEMA
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# O arquivo do personagem fica na pasta do mundo (solo ou cooperativo); no co-op, um para cada jogador
	if trocar_cena:
		caminho_save = Saves.caminho_personagem(etapa_coop == 2)
	_montar()
	if modo_edicao:
		_campo_nome.text = apelido
		_botao_confirmar.text = "SALVAR"
		_botao_voltar.text = "CANCELAR"
	_atualizar_tudo()
	_abrir_aba(Aba.CABELO)
	_teclado = TecladoVirtual.new()
	add_child(_teclado)
	_teclado.confirmado.connect(_ao_nome_confirmado)
	PreviaDigitacao.ligar(_campo_nome, "NOME DO PERSONAGEM")
	Controle.modo_alterado.connect(_ao_modo_controle)
	if etapa_coop > 0:
		var quem := Label.new()
		quem.name = "QuemCria"
		quem.text = "PERSONAGEM DO JOGADOR %d" % etapa_coop
		quem.add_theme_font_size_override("font_size", 12)
		quem.add_theme_color_override("font_color", Color("e7c884") if etapa_coop == 1 else Color(0.55, 0.85, 1.0))
		quem.add_theme_color_override("font_outline_color", Color("211c2b"))
		quem.add_theme_constant_override("outline_size", 4)
		quem.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		quem.grow_horizontal = Control.GROW_DIRECTION_BOTH
		quem.offset_top = 4
		add_child(quem)
	_cortina = ColorRect.new()
	_cortina.color = Color(0.03, 0.04, 0.08, 1.0)
	_cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)
	create_tween().tween_property(_cortina, "modulate:a", 0.0, 0.4)
	_focar_inicio()

# --- Montagem da tela --------------------------------------------------------------------------------------------

func _montar() -> void:
	_construtor_fazenda = preload("res://codigo/ui/construtor_criacao_fazenda.gd").new()
	_construtor_fazenda.montar(self)

func _ajustar_layout() -> void:
	if _construtor_fazenda != null: _construtor_fazenda.ajustar()

func _ajustar_paginas() -> void:
	if _construtor_fazenda != null: _construtor_fazenda.ajustar_controles()

func _centralizar_previa() -> void:
	if _palco == null or _modelo == null: return
	if _previa_3d != null:
		# Personagem 3D: cerca de 40×44 px no mundo, com os pés na origem da prévia.
		var escala_3d := clampf(minf((_palco.size.x-8)/40.0,(_palco.size.y-8)/44.0),1.0,4.0)
		_modelo.scale = Vector2.ONE*escala_3d
		_modelo.position = Vector2(_palco.size.x/2.0, _palco.size.y-4).round()
		return
	var escala := minf(2.0 if _compacto else ESCALA_PREVIA,minf((_palco.size.x-10)/48.0,(_palco.size.y-10)/52.0))
	escala = maxf(0.5,escala)
	_modelo.scale = Vector2.ONE*escala
	_modelo.position = (_palco.size/2.0 + Vector2(0,6)*escala).round()

func _revelar_selecoes() -> void:
	for catalogo in _catalogos:
		var selecionado: Button = _casas_cabelo[cabelo].botao if catalogo.eh_cabelo else _casas_roupa[roupa].botao
		catalogo.pagina = maxi(0,catalogo.itens.find(selecionado))/catalogo.por_pagina
	_ajustar_paginas()

func _mudar_pagina(passo: int, catalogo: Dictionary) -> void:
	catalogo.pagina += passo
	_ajustar_paginas()

func _novo_painel(titulo: String) -> Array:
	var painel := PanelContainer.new()
	painel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	EstiloInicio.painel(painel,false,14)
	var linhas := VBoxContainer.new()
	linhas.add_theme_constant_override("separation", 6)
	painel.add_child(linhas)
	var rotulo := Label.new()
	rotulo.text = titulo
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	linhas.add_child(rotulo)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var configuracao := LabelSettings.new()
	configuracao.font = FONTE_TITULO
	configuracao.font_color = Color(0.93, 0.85, 0.68)
	rotulo.label_settings = configuracao

	return [painel, linhas]

# Painel da esquerda: o personagem de corpo inteiro girando, o nome da peça e os botões de girar
func _montar_painel_previa() -> Control:
	var par := _novo_painel("PERSONAGEM")
	var painel: PanelContainer = par[0]
	var linhas: VBoxContainer = par[1]
	_linhas_previa = linhas
	painel.custom_minimum_size = Vector2(150, 0)
	painel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var palco := Control.new()
	_palco = palco
	palco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palco.custom_minimum_size = Vector2(0, 150)
	palco.clip_contents = true
	linhas.add_child(palco)
	_modelo = Node2D.new()
	_modelo.scale = Vector2(ESCALA_PREVIA, ESCALA_PREVIA)
	palco.add_child(_modelo)
	# O personagem fica no meio do palco, qualquer que seja o tamanho da tela
	palco.resized.connect(_centralizar_previa)
	var sombra := Polygon2D.new()
	var pontos := PackedVector2Array()
	for i in 24:
		var angulo := TAU * float(i) / 24.0
		pontos.append(Vector2(cos(angulo) * 9.0, 11.5 + sin(angulo) * 2.6))
	sombra.polygon = pontos
	sombra.color = Color(0, 0, 0, 0.35)
	_modelo.add_child(sombra)
	_previa_corpo = _nova_camada(_textura_corpo)
	_previa_corpo.scale = Vector2.ONE * (512.0 / _textura_corpo.get_width())
	_previa_corpo.material = Aparencia.material_corpo()
	_previa_roupa = _nova_camada(null)
	_previa_cabelo = _nova_camada(null)
	for camada in [_previa_corpo,_previa_roupa,_previa_cabelo]: camada.visible = false
	sombra.visible = false
	_previa_3d = PreviaHeroi3D.new()
	_modelo.add_child(_previa_3d)
	var girar := HBoxContainer.new()
	girar.alignment = BoxContainer.ALIGNMENT_CENTER
	girar.add_theme_constant_override("separation", 6)
	linhas.add_child(girar)
	girar.add_child(_botao_seta(SETA_ESQUERDA, -1))
	var texto_girar := Label.new()
	_rotulo_girar = texto_girar
	texto_girar.text = "GIRAR"
	girar.add_child(texto_girar)
	girar.add_child(_botao_seta(SETA_DIREITA, 1))
	_rotulo_cabelo = _rotulo_centro(COR_OURO)
	linhas.add_child(_rotulo_cabelo)
	_rotulo_roupa = _rotulo_centro(COR_DESCRICAO)
	linhas.add_child(_rotulo_roupa)
	var tons := HBoxContainer.new()
	tons.alignment = BoxContainer.ALIGNMENT_CENTER
	tons.add_theme_constant_override("separation",6)
	linhas.add_child(tons)
	var rotulo_pele := Label.new()
	_rotulo_pele = rotulo_pele
	rotulo_pele.text = "PELE"
	tons.add_child(rotulo_pele)
	var grupo_pele := ButtonGroup.new()
	for i in 3:
		var tom := Button.new()
		tom.text = "%d" % (i+1)
		EstiloInicio.botao(tom,false,16.0)
		_botoes_estrutura.append(tom)
		tom.tooltip_text = "Tom de pele %d" % (i+1)
		tom.custom_minimum_size = Vector2(30,26)
		tom.toggle_mode = true
		tom.button_group = grupo_pele
		tom.set_pressed_no_signal(i == pele)
		_botoes_pele.append(tom)
		tom.pressed.connect(_escolher_pele.bind(i))
		tons.add_child(tom)
	var linha_olhos := HBoxContainer.new()
	linha_olhos.alignment = BoxContainer.ALIGNMENT_CENTER
	linha_olhos.add_theme_constant_override("separation",4)
	linhas.add_child(linha_olhos)
	var rotulo_olhos := Label.new()
	rotulo_olhos.text = "OLHOS"
	linha_olhos.add_child(rotulo_olhos)
	for i in CORES_OLHOS.size():
		var casa := Button.new()
		casa.theme_type_variation = &"BotaoSlot"
		EstiloInicio.casa(casa)
		casa.custom_minimum_size = Vector2(22,22)
		casa.tooltip_text = "Cor dos olhos %d" % (i+1)
		var miolo := ColorRect.new()
		miolo.color = CORES_OLHOS[i]
		miolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		miolo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for lado in ["offset_left","offset_top"]: miolo.set(lado, 4)
		for lado in ["offset_right","offset_bottom"]: miolo.set(lado, -4)
		casa.add_child(miolo)
		casa.pressed.connect(_escolher_olhos.bind(i))
		linha_olhos.add_child(casa)
		_botoes_olhos.append(casa)
	return painel

func _escolher_olhos(indice: int) -> void:
	olhos = clampi(indice,0,CORES_OLHOS.size()-1)
	_atualizar_tudo()

func _escolher_pele(indice: int) -> void:
	pele = clampi(indice,0,2)
	for i in _botoes_pele.size(): _marcar(_botoes_pele[i], i == pele)
	_textura_corpo = Aparencia.corpo("andar",pele)
	_previa_corpo.texture = _textura_corpo
	_atualizar_tudo()

func _nova_camada(textura: Texture2D) -> Sprite2D:
	var camada := Sprite2D.new()
	camada.texture = textura
	camada.hframes = 8
	camada.vframes = 8
	camada.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_modelo.add_child(camada)
	return camada

func _rotulo_centro(cor_texto: Color) -> Label:
	var rotulo := Label.new()
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_color_override("font_color", cor_texto)
	rotulo.custom_minimum_size = Vector2(0, 0)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return rotulo

func _botao_seta(icone: Texture2D, passo: int) -> Button:
	var botao := Button.new()
	botao.theme_type_variation = &"BotaoAba"
	botao.custom_minimum_size = Vector2(30, 22)
	EstiloInicio.botao(botao,false,16.0)
	_botoes_estrutura.append(botao)
	botao.icon = icone
	botao.expand_icon = true
	botao.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	botao.add_theme_constant_override("icon_max_width",8)
	for estado in ["icon_normal_color","icon_hover_color","icon_focus_color","icon_pressed_color"]:
		botao.add_theme_color_override(estado,Color("49321e"))
	botao.set_meta(Sons.META_SOM_PROPRIO, false)
	botao.pressed.connect(_girar.bind(passo))
	return botao

# Painel da direita: abas, a lista da aba, o nome e os botões de baixo
func _montar_painel_edicao() -> Control:
	var par := _novo_painel("EDITAR VISUAL" if modo_edicao else "CRIAR PERSONAGEM")
	var painel: PanelContainer = par[0]
	var linhas: VBoxContainer = par[1]
	_linhas_edicao = linhas
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	painel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 3)
	linhas.add_child(abas)
	var grupo := ButtonGroup.new()
	for entrada in [["CABELO", Aba.CABELO], ["ROUPA", Aba.ROUPA], ["COR", Aba.COR]]:
		var botao := Button.new()
		botao.theme_type_variation = &"BotaoAba"
		botao.toggle_mode = true
		botao.button_group = grupo
		botao.text = entrada[0]
		EstiloInicio.botao(botao,false,16.0)
		_botoes_estrutura.append(botao)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.custom_minimum_size = Vector2(0, 22)
		botao.pressed.connect(_abrir_aba.bind(entrada[1]))
		abas.add_child(botao)
		_botoes_aba.append(botao)
	var conteudo := Control.new()
	_conteudo = conteudo
	conteudo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conteudo.custom_minimum_size = Vector2.ZERO
	conteudo.resized.connect(func(): _ajustar_paginas.call_deferred())
	linhas.add_child(conteudo)
	_paginas = [
		_montar_opcoes_3d(["cabelo"]),
		_montar_opcoes_3d(["camisa","calca","calcado"]),
		_montar_cores(),
	]
	for pagina in _paginas:
		pagina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		conteudo.add_child(pagina)
	# Nome
	var linha_nome := HBoxContainer.new()
	linha_nome.add_theme_constant_override("separation", 6)
	linhas.add_child(linha_nome)
	var rotulo_nome := Label.new()
	_rotulo_nome = rotulo_nome
	rotulo_nome.text = "NOME"
	linha_nome.add_child(rotulo_nome)
	_campo_nome = LineEdit.new()
	_campo_nome.placeholder_text = NOME_PADRAO
	EstiloInicio.campo(_campo_nome)
	_campo_nome.max_length = MAX_APELIDO
	_campo_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campo_nome.custom_minimum_size = Vector2(0, 22)
	_campo_nome.text_changed.connect(_ao_nome_alterado)
	_campo_nome.gui_input.connect(_ao_entrada_nome)
	linha_nome.add_child(_campo_nome)
	# Rodapé
	var rodape := HFlowContainer.new()
	rodape.add_theme_constant_override("separation", 4)
	linhas.add_child(rodape)
	_botao_voltar = _botao_rodape("VOLTAR", &"")
	_botao_voltar.pressed.connect(voltar)
	rodape.add_child(_botao_voltar)
	_botao_aleatorio = _botao_rodape("ALEATORIO", &"")
	_botao_aleatorio.pressed.connect(sortear)
	rodape.add_child(_botao_aleatorio)
	_botao_confirmar = _botao_rodape("CONFIRMAR", &"BotaoPrimario")
	_botao_confirmar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_botao_confirmar.pressed.connect(confirmar)
	rodape.add_child(_botao_confirmar)
	return painel

func _botao_rodape(texto: String, variacao: StringName) -> Button:
	var botao := Button.new()
	botao.text = texto
	EstiloInicio.botao(botao,variacao == &"BotaoPrimario",16.0)
	_botoes_estrutura.append(botao)
	if variacao != &"":
		botao.theme_type_variation = variacao
	botao.custom_minimum_size = Vector2(70, 24)
	return botao

## Botões com o nome de cada peça 3D, agrupados por categoria; a prévia mostra a escolha.
func _montar_opcoes_3d(categorias: Array) -> Control:
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 3)
	rolagem.add_child(coluna)
	for categoria in categorias:
		if categorias.size() > 1:
			var titulo := Label.new()
			titulo.text = NOMES_CATEGORIA_3D[categoria]
			titulo.add_theme_color_override("font_color", COR_DESCRICAO)
			titulo.add_theme_font_size_override("font_size", 8)
			coluna.add_child(titulo)
		var grade := GridContainer.new()
		grade.columns = 2
		grade.add_theme_constant_override("h_separation", 3)
		grade.add_theme_constant_override("v_separation", 3)
		grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		coluna.add_child(grade)
		_opcoes_3d[categoria] = []
		var grupo := ButtonGroup.new()
		for modelo in Roupas3D.MODELOS[categoria]:
			var botao := Button.new()
			botao.text = String(modelo.nome).to_upper().replace(" COM MEIA-CALÇA","").replace(" DE MANGAS BUFANTES"," BUFANTE").replace(" ANTIGO","")
			botao.tooltip_text = String(modelo.nome)
			botao.clip_text = true
			botao.toggle_mode = true
			botao.button_group = grupo
			EstiloInicio.botao(botao, false, 16.0)
			_botoes_estrutura.append(botao)
			botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			botao.custom_minimum_size = Vector2(0, 22)
			botao.pressed.connect(_escolher_peca_3d.bind(categoria, String(modelo.id)))
			grade.add_child(botao)
			_opcoes_3d[categoria].append([String(modelo.id), botao])
	return rolagem

func _escolher_peca_3d(categoria: String, id: String) -> void:
	roupas_3d[categoria] = Roupas3D.modelo(categoria, id).id
	_atualizar_tudo()

# Grade de casinhas (cabelos ou roupas) com rolagem
func _montar_lista(itens: Array[Dictionary], eh_cabelo: bool) -> Control:
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",3)
	var grade := GridContainer.new()
	grade.add_theme_constant_override("h_separation",3)
	grade.add_theme_constant_override("v_separation",3)
	grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_child(grade)
	var navegacao := HBoxContainer.new()
	navegacao.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_child(navegacao)
	var anterior := _botao_rodape("<",&"")
	var rotulo := Label.new()
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.custom_minimum_size.x = 44
	rotulo.add_theme_font_size_override("font_size",8)
	var proxima := _botao_rodape(">",&"")
	navegacao.add_child(anterior)
	navegacao.add_child(rotulo)
	navegacao.add_child(proxima)
	var catalogo := {"grade":grade,"itens":[],"eh_cabelo":eh_cabelo,"pagina":0,"por_pagina":1,"rotulo":rotulo,"anterior":anterior,"proxima":proxima}
	_catalogos.append(catalogo)
	anterior.pressed.connect(_mudar_pagina.bind(-1,catalogo))
	proxima.pressed.connect(_mudar_pagina.bind(1,catalogo))
	var regiao := REGIAO_CABELO if eh_cabelo else REGIAO_ROUPA
	var escala := ESCALA_CASA_CABELO if eh_cabelo else ESCALA_CASA_ROUPA
	for i in itens.size():
		var casa := _nova_casa(regiao, escala)
		casa.botao.tooltip_text = String(itens[i]["nome"])
		casa.botao.pressed.connect(_escolher_cabelo.bind(i) if eh_cabelo else _escolher_roupa.bind(i))
		casa.botao.focus_entered.connect(_mostrar_nome.bind(i, eh_cabelo))
		grade.add_child(casa.botao)
		if not eh_cabelo and (itens[i]["grupo"] == "ARMADURA" or not Aparencia.roupa_completa(i)):
			casa.botao.visible = false
		else:
			catalogo.itens.append(casa.botao)
		if eh_cabelo:
			_casas_cabelo.append(casa)
		else:
			_casas_roupa.append(casa)
	return coluna

# Uma casinha: o corpo, a roupa e o cabelo empilhados e recortados no quadro 0 (parado, de frente)
func _nova_casa(regiao: Rect2, escala: int) -> Dictionary:
	var botao := Button.new()
	botao.theme_type_variation = &"BotaoSlot"
	EstiloInicio.casa(botao)
	botao.focus_mode = Control.FOCUS_ALL
	botao.custom_minimum_size = regiao.size * escala + Vector2(MOLDURA_CASA * 2, MOLDURA_CASA * 2)
	botao.clip_contents = true
	botao.set_meta(Sons.META_SOM_PROPRIO, false)
	var camadas := {}
	for nome in ["corpo", "roupa", "cabelo"]:
		var imagem := TextureRect.new()
		imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		imagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		imagem.offset_left = FOLGA_PREVIA_CASA
		imagem.offset_top = FOLGA_PREVIA_CASA
		imagem.offset_right = -FOLGA_PREVIA_CASA
		imagem.offset_bottom = -FOLGA_PREVIA_CASA
		imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		botao.add_child(imagem)
		camadas[nome] = imagem
	camadas["cabelo"].material = Aparencia.material_cabelo()
	camadas["corpo"].material = Aparencia.material_corpo()
	camadas["roupa"].material = Aparencia.material_corpo()
	camadas["corpo"].texture = _recorte(_textura_corpo, Rect2(regiao.position * (_textura_corpo.get_width() / 512.0), regiao.size * (_textura_corpo.get_width() / 512.0)))
	return {"botao": botao, "corpo": camadas["corpo"], "roupa": camadas["roupa"], "cabelo": camadas["cabelo"], "regiao": regiao}

func _recorte(folha: Texture2D, regiao: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = folha
	atlas.region = regiao
	# Limita o desenho ao recorte: a folha contém pixels além da moldura da prévia.
	atlas.filter_clip = true
	return atlas

func _limites_miniatura(folha: Texture2D, regiao: Rect2) -> Rect2:
	var chave := str(folha.get_instance_id()) + ":" + str(regiao)
	if _limites_miniaturas.has(chave):
		return _limites_miniaturas[chave]
	var fator := folha.get_width() / 512.0
	var pixels := Rect2i(regiao.position * fator, regiao.size * fator)
	var usados := folha.get_image().get_region(pixels).get_used_rect()
	var limites := Rect2()
	if usados.has_area():
		limites = Rect2(regiao.position + Vector2(usados.position) / fator, Vector2(usados.size) / fator)
	_limites_miniaturas[chave] = limites
	return limites

func _centralizar_casa(casa: Dictionary, folha_roupa: Texture2D, folha_cabelo: Texture2D) -> void:
	var folhas := {"corpo": _textura_corpo, "roupa": folha_roupa, "cabelo": folha_cabelo}
	var limites := Rect2()
	# O centro é o da silhueta visível das três camadas, não o do recorte da folha.
	for folha: Texture2D in folhas.values():
		var usados := _limites_miniatura(folha, casa.regiao)
		if usados.has_area():
			limites = limites.merge(usados) if limites.has_area() else usados
	if not limites.has_area():
		return
	for nome: String in folhas:
		var folha: Texture2D = folhas[nome]
		var fator := folha.get_width() / 512.0
		var atlas := _recorte(folha, Rect2(limites.position * fator, limites.size * fator))
		# Folga transparente igual nas quatro bordas; todas as camadas mantêm o mesmo encaixe.
		atlas.margin = Rect2(Vector2.ONE * fator, Vector2.ONE * 2 * fator)
		casa[nome].texture = atlas

# Aba COR: paleta pronta e os três controles (matiz, saturação e brilho) para a cor que quiser
func _montar_cores() -> Control:
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 2)
	var grade := GridContainer.new()
	_grade_cores = grade
	grade.columns = 10
	grade.add_theme_constant_override("h_separation", ESPACO_CASAS)
	grade.add_theme_constant_override("v_separation", ESPACO_CASAS)
	coluna.add_child(grade)
	for i in PALETA.size():
		var casa := Button.new()
		casa.theme_type_variation = &"BotaoSlot"
		EstiloInicio.casa(casa)
		casa.custom_minimum_size = Vector2(30, 30)
		casa.tooltip_text = "COR %d" % (i + 1)
		var miolo := ColorRect.new()
		miolo.color = _cor_vista(PALETA[i])
		miolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		miolo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		miolo.offset_left = 4
		miolo.offset_top = 4
		miolo.offset_right = -4
		miolo.offset_bottom = -4
		casa.add_child(miolo)
		casa.pressed.connect(_escolher_cor.bind(PALETA[i]))
		grade.add_child(casa)
		_casas_cor.append(casa)
	var titulo := Label.new()
	_titulo_cor = titulo
	titulo.text = "OU AJUSTE A COR"
	titulo.add_theme_color_override("font_color", COR_DESCRICAO)
	coluna.add_child(titulo)
	_slider_matiz = _novo_slider(coluna, "MATIZ", 360.0)
	_slider_saturacao = _novo_slider(coluna, "FORCA", 100.0)
	_slider_brilho = _novo_slider(coluna, "BRILHO", 100.0)
	_slider_matiz.value_changed.connect(_ao_slider_alterado)
	_slider_saturacao.value_changed.connect(_ao_slider_alterado)
	_slider_brilho.value_changed.connect(_ao_slider_alterado)
	return coluna

func _novo_slider(pai: Control, nome: String, maximo: float) -> HSlider:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	pai.add_child(linha)
	var rotulo := Label.new()
	rotulo.text = nome
	rotulo.custom_minimum_size = Vector2(44, 0)
	linha.add_child(rotulo)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = maximo
	slider.step = 1.0
	EstiloInicio.slider(slider)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 18)
	slider.gui_input.connect(_ao_entrada_slider.bind(slider))
	linha.add_child(slider)
	if nome == "MATIZ":
		_amostra_cor = ColorRect.new()
		_amostra_cor.custom_minimum_size = Vector2(22, 14)
		linha.add_child(_amostra_cor)
	return slider

# O que o jogador vê de um cabelo tingido: a cor multiplica o cinza médio da folha (uns 0,5)
func _cor_vista(tinta: Color) -> Color:
	return Color(tinta.r * 0.85, tinta.g * 0.85, tinta.b * 0.85)

# --- Estado e atualização -------------------------------------------------------------------------------------

func _atualizar_tudo() -> void:
	for i in _botoes_pele.size(): _marcar(_botoes_pele[i], i == pele)
	_atualizar_previa()
	_atualizar_casas()
	_atualizar_sliders()
	_revelar_selecoes()

func _atualizar_previa() -> void:
	_rotulo_girar.text = ["Frente", "Direita", "Costas", "Esquerda"][_direcao]
	if _previa_3d != null:
		_previa_3d.mostrar({"pele":pele,"cabelo":cabelo,"roupa":roupa,"cor":[cor.r,cor.g,cor.b,cor.a],"olhos":olhos,"cor_cabelo_personalizada":cor_personalizada}, roupas_3d.duplicate(), _direcao)
	var quadro: int = int(LINHAS_DIRECAO[_direcao]) * 8 + int(fmod(_tempo_animacao,0.8)/0.2)
	_previa_corpo.frame = quadro
	Aparencia.aplicar_roupa(_previa_roupa, roupa, "andar")
	_previa_roupa.frame = quadro
	Aparencia.aplicar_cabelo(_previa_cabelo, cabelo, "andar", roupa)
	_previa_cabelo.frame = quadro
	_previa_cabelo.modulate = cor
	_rotulo_cabelo.text = String(Roupas3D.modelo("cabelo", roupas_3d.cabelo).nome).to_upper()
	_rotulo_roupa.text = String(Roupas3D.modelo("camisa", roupas_3d.camisa).nome).to_upper()

# Refaz as miniaturas: cabelo e roupa escolhidos aparecem em todas, e a escolhida de cada lista fica na moldura dourada
func _atualizar_casas() -> void:
	if _construtor_fazenda != null: _construtor_fazenda.atualizar_seletores()
	for i in _casas_cabelo.size():
		var casa: Dictionary = _casas_cabelo[i]
		_centralizar_casa(casa, Aparencia.roupa_refinada(roupa, "andar"), Aparencia.cabelo_refinado(i, "andar", roupa))
		casa["cabelo"].modulate = cor
		_marcar(casa["botao"], i == cabelo)
	for i in _casas_roupa.size():
		var casa: Dictionary = _casas_roupa[i]
		_centralizar_casa(casa, Aparencia.roupa_refinada(i, "andar"), Aparencia.cabelo_refinado(cabelo, "andar", i))
		casa["cabelo"].modulate = cor
		_marcar(casa["botao"], i == roupa)
	for i in _casas_cor.size():
		_marcar(_casas_cor[i], PALETA[i].is_equal_approx(cor))
	for i in _botoes_olhos.size():
		_marcar(_botoes_olhos[i], i == olhos)
	for categoria in _opcoes_3d:
		for par in _opcoes_3d[categoria]:
			# Escolhida aparece afundada, como a aba ativa.
			par[1].set_pressed_no_signal(par[0] == roupas_3d[categoria])

# A escolhida mantém a moldura dourada mesmo sem foco ou mouse.
func _marcar(botao: Button, escolhida: bool) -> void:
	botao.add_theme_stylebox_override("normal", preload("res://codigo/ui/estilo_criacao_fazenda.gd").caixa(Color("fff0c9"), Color("916039") if escolhida else Color("c4a370"), 3, 3 if escolhida else 1))

func _atualizar_sliders() -> void:
	_atualizando_sliders = true
	_slider_matiz.value = cor.h * 360.0
	_slider_saturacao.value = cor.s * 100.0
	_slider_brilho.value = cor.v * 100.0
	_amostra_cor.color = _cor_vista(cor)
	_atualizando_sliders = false

func _mostrar_nome(indice: int, eh_cabelo: bool) -> void:
	# Com o foco (controle/teclado) a prévia mostra a peça sem precisar confirmar
	if eh_cabelo:
		_rotulo_cabelo.text = Aparencia.nome_cabelo(indice)
	else:
		_rotulo_roupa.text = Aparencia.nome_roupa(indice)

func _escolher_cabelo(indice: int) -> void:
	cabelo = Aparencia.indice_cabelo(indice)
	_atualizar_tudo()

func _escolher_roupa(indice: int) -> void:
	roupa = Aparencia.indice_roupa(indice)
	_atualizar_tudo()

func _escolher_cor(nova: Color) -> void:
	cor = nova
	cor_personalizada = true
	_atualizar_tudo()

func _ao_slider_alterado(_valor: float) -> void:
	if _atualizando_sliders:
		return
	cor_personalizada = true
	cor = Color.from_hsv(_slider_matiz.value / 360.0, _slider_saturacao.value / 100.0, _slider_brilho.value / 100.0)
	_atualizar_previa()
	_atualizar_casas()
	_amostra_cor.color = _cor_vista(cor)

func _abrir_aba(nova: Aba) -> void:
	aba = nova
	for i in _paginas.size():
		_paginas[i].visible = i == int(nova)
	for i in _botoes_aba.size():
		_botoes_aba[i].set_pressed_no_signal(i == int(nova))
	_ajustar_layout.call_deferred()

# --- Girar o personagem ---------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_tempo_animacao += delta
	var quadro: int = int(LINHAS_DIRECAO[_direcao])*8 + int(fmod(_tempo_animacao,0.8)/0.2)
	for camada in [_previa_corpo,_previa_roupa,_previa_cabelo]: camada.frame = quadro

func _girar(passo: int) -> void:
	_direcao = posmod(_direcao + passo, LINHAS_DIRECAO.size())
	_atualizar_previa()

# --- Nome, sorteio, confirmar e voltar --------------------------------------------------------------------------

func _ao_nome_alterado(texto: String) -> void:
	apelido = texto.strip_edges().to_upper()

func _ao_entrada_nome(evento: InputEvent) -> void:
	# No controle, confirmar (A) no campo abre o teclado virtual; no teclado físico o campo segue como sempre
	if evento is InputEventJoypadButton and evento.is_action_pressed("ui_accept"):
		_teclado.abrir(_campo_nome.text, MAX_APELIDO)
		_campo_nome.accept_event()

func _ao_nome_confirmado(texto: String) -> void:
	_campo_nome.text = texto
	_ao_nome_alterado(texto)
	_botao_confirmar.grab_focus()

## Sorteia cabelo, roupa e cor
func sortear() -> void:
	var sorteio := RandomNumberGenerator.new()
	sorteio.randomize()
	cabelo = Aparencia.cabelo_aleatorio(sorteio)
	roupa = Aparencia.roupa_aleatoria(sorteio)
	cor = PALETA[sorteio.randi_range(0, PALETA.size() - 1)]
	pele = sorteio.randi_range(0,2)
	olhos = sorteio.randi_range(0,CORES_OLHOS.size()-1)
	for categoria in Roupas3D.CATEGORIAS:
		var lista: Array = Roupas3D.MODELOS[categoria]
		roupas_3d[categoria] = lista[sorteio.randi_range(0, lista.size()-1)].id
	_textura_corpo = Aparencia.corpo("andar",pele)
	_previa_corpo.texture = _textura_corpo
	_atualizar_tudo()

func dados_do_personagem() -> Dictionary:
	return {
		"cabelo_atual": 0,
		"roupa_atual": 2,
		"apelido": apelido if apelido != "" else NOME_PADRAO,
		"cor_cabelo": {"r": cor.r, "g": cor.g, "b": cor.b, "a": cor.a},
		"aparencia_raven": {"versao":1,"pele":pele,"cabelo":CABELO_RAVEN_DO_3D.get(roupas_3d.cabelo, 1),"roupa":maxi(roupa,1),"cor":[cor.r,cor.g,cor.b,cor.a],"olhos":olhos,"cor_cabelo_personalizada":cor_personalizada},
		"roupas_3d": roupas_3d.duplicate(),
	}

## Grava o personagem e entra no jogo
## Edição: começa do personagem salvo (cores, olhos, peças 3D e apelido).
func carregar_dados(dados: Dictionary) -> void:
	_dados_existentes = dados.duplicate(true)
	var aparencia: Dictionary = dados.get("aparencia_raven", {})
	pele = clampi(int(aparencia.get("pele", 0)), 0, 2)
	cabelo = int(aparencia.get("cabelo", cabelo))
	roupa = int(aparencia.get("roupa", roupa))
	olhos = clampi(int(aparencia.get("olhos", 0)), 0, CORES_OLHOS.size()-1)
	var c: Array = aparencia.get("cor", [1, 1, 1, 1])
	cor = Color(c[0], c[1], c[2], c[3] if c.size() > 3 else 1.0)
	cor_personalizada = aparencia.get("cor_cabelo_personalizada", not cor.is_equal_approx(Color.WHITE))
	var heroi_script := preload("res://codigo/jogador/heroi_base_3d.gd")
	roupas_3d = Roupas3D.normalizar(dados.get("roupas_3d", heroi_script.roupas_do_raven(aparencia)))
	apelido = str(dados.get("apelido", ""))
	if apelido == NOME_PADRAO: apelido = ""
	_textura_corpo = Aparencia.corpo("andar", pele)

func confirmar() -> void:
	if _saindo:
		return
	var dados := dados_do_personagem()
	if modo_edicao:
		var mesclado := _dados_existentes.duplicate(true)
		var aparencia: Dictionary = dados.aparencia_raven
		# Raven 2D: mantém cabelo e roupa que o jogador já tinha.
		aparencia.cabelo = cabelo
		aparencia.roupa = roupa
		for chave in ["aparencia_raven", "roupas_3d", "apelido", "cor_cabelo"]:
			mesclado[chave] = dados[chave]
		mesclado.erase("aviso_visual_3d")
		dados = mesclado
	var arquivo := FileAccess.open(caminho_save, FileAccess.WRITE)
	if arquivo == null:
		push_error("Criação de personagem: não consegui gravar " + caminho_save)
		return
	arquivo.store_string(JSON.stringify(dados))
	arquivo.close()
	confirmada.emit(dados)
	if trocar_cena and etapa_coop == 1:
		etapa_coop = 2
		_sair_para(CENA_CRIACAO)
	elif trocar_cena:
		etapa_coop = 0
		_sair_para(Introducao.cena_continuar())

func voltar() -> void:
	if modo_edicao:
		cancelada.emit()
		return
	if not _saindo and trocar_cena:
		etapa_coop = 0
		_sair_para(CENA_TITULO)

func _sair_para(caminho: String) -> void:
	_saindo = true
	_cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_cortina, "modulate:a", 1.0, 0.35)
	await tween.finished
	var erro := await Transicao.carregar_cena(caminho)
	if erro != OK:
		_saindo = false
		_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
		create_tween().tween_property(_cortina, "modulate:a", 0.0, 0.25)
		push_error("Nao foi possivel abrir a cena: "+caminho)

# --- Teclado, controle e toque ---------------------------------------------------------------------------------

func _unhandled_input(evento: InputEvent) -> void:
	if _teclado != null and _teclado.visible:
		return
	if evento.is_action_pressed("ferramenta_proxima"):
		_trocar_aba(1)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("ferramenta_anterior"):
		_trocar_aba(-1)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("close_menu") and not (_campo_nome.has_focus()):
		voltar()
		get_viewport().set_input_as_handled()

func _trocar_aba(passo: int) -> void:
	_abrir_aba(posmod(int(aba) + passo, 3) as Aba)
	_focar_inicio()

# As setas do slider andam de 1 em 1; com o controle seguram o passo de 5
func _ao_entrada_slider(evento: InputEvent, slider: HSlider) -> void:
	var passo := 0.0
	if evento.is_action_pressed("ui_left", true):
		passo = -5.0
	elif evento.is_action_pressed("ui_right", true):
		passo = 5.0
	if passo != 0.0:
		slider.value += passo
		slider.accept_event()

func _ao_modo_controle(usando_controle: bool) -> void:
	if usando_controle and get_viewport().gui_get_focus_owner() == null:
		_focar_inicio()

# O foco começa na peça escolhida da aba aberta (ou na primeira cor)
func _focar_inicio() -> void:
	_revelar_selecoes()
	match aba:
		Aba.CABELO:
			Controle.focar(_opcoes_3d["cabelo"][0][1])
		Aba.ROUPA:
			_construtor_fazenda.focar_roupa()
		Aba.COR:
			Controle.focar(_casas_cor[0])
