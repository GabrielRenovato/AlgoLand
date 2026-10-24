extends Node2D

# preload em vez de class_name: classe global nova pode nao estar no cache fora do editor
const EstiloInicio := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const Opcoes := preload("res://codigo/globais/opcoes_jogo.gd")
const Raven := preload("res://codigo/dados/aparencia_raven.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")

const CENA_JOGO := "res://cenas/cidade.tscn"
const CENA_CUSTOMIZACAO := "res://cenas/criacao_personagem.tscn"
const VALORES_FPS := [30, 60, 120, 0]
const ROTULOS_FPS := ["30", "60", "120", "SEM LIMITE"]
const BRILHO_FOCO := Color(1.15, 1.15, 1.15)
const PASSO_ROLAGEM_CREDITOS := 24
const COR_TITULO_CREDITOS := Color(1.0, 0.82, 0.3)
const COR_LINK_CREDITOS := Color(0.65, 0.8, 1.0)
const FONTE_CREDITOS := preload("res://assets/ui/Planes_ValMore.ttf")
const LOGO := preload("res://assets/ui/identidade/logo_algoland.png")
# Textos em ASCII maiusculo (a fonte nao tem acentos). Cada bloco: titulo, link opcional e linhas de descricao.
# Origem de cada informacao: leia os arquivos de licenca/readme das pastas de assets (Mana Seed, Farm RPG, craftpix, PixyMoon).
const CREDITOS := [
	{"titulo": "ALGOLAND", "linhas": ["DESENVOLVIDO POR GABRIEL RENOVATO"]},
	{"titulo": "SELIEL THE SHAPER - MANA SEED", "link": "SELIEL-THE-SHAPER.ITCH.IO",
			"linhas": ["PERSONAGEM, ROUPAS E CABELOS", "ANIMACOES DE COMBATE", "INIMIGOS E NPCS",
			"CENARIOS: TRAVELER'S CAMP E ARCTIC WOODLAND", "CENARIOS: SEASONAL FOREST E STARTER PACK",
			"EFEITOS DE CLIMA"]},
	{"titulo": "EMANUELLEDEV", "link": "EMANUELLEDEV.ITCH.IO",
			"linhas": ["FARM RPG - TINY ASSET PACK", "PLANTAS, ICONES E OBJETOS DA FAZENDA"]},
	{"titulo": "CRAFTPIX.NET",
			"linhas": ["INTERFACE, FONTES, ICONES E MOEDAS"]},
	{"titulo": "PIXYMOON", "link": "PIXYMOON.ITCH.IO", "linhas": ["CUTE RPG - ICONS"]},
	{"titulo": "TAKANAZWA5", "linhas": ["GDCONSOLE (LICENCA MIT)"]},
	{"titulo": "SONS", "linhas": ["SONS GERADOS POR CODIGO"]},
]

const CriacaoPersonagem := preload("res://codigo/ui/tela_criacao_personagem.gd")
@export var caminho_save_personagem := "user://configuracao_jogador.json"
@export var caminho_save_inventario := "user://inventario.json"

@onready var titulo: Label = %Titulo
@onready var personagem: Node2D = %Personagem
@onready var sprite_corpo: Sprite2D = %Corpo
@onready var sprite_roupa: Sprite2D = %Roupa
@onready var sprite_cabelo: Sprite2D = %Cabelo
@onready var menu: GridContainer = %Menu
@onready var botao_continuar: Button = %BotaoContinuar
@onready var botao_novo_jogo: Button = %BotaoNovoJogo
@onready var botao_opcoes: Button = %BotaoOpcoes
@onready var botao_creditos: Button = %BotaoCreditos
@onready var botao_sair: Button = %BotaoSair
@onready var painel_opcoes: Control = %PainelOpcoes
@onready var botao_voltar_opcoes: Button = %BotaoVoltarOpcoes
@onready var painel_creditos: Control = %PainelCreditos
@onready var botao_voltar_creditos: Button = %BotaoVoltarCreditos
@onready var rolagem_creditos: ScrollContainer = %Rolagem
@onready var lista_creditos: VBoxContainer = %Lista
@onready var confirmar_novo_jogo: Control = %ConfirmarNovoJogo
@onready var botao_sim: Button = %BotaoSim
@onready var botao_nao: Button = %BotaoNao
@onready var transicao: ColorRect = %Transicao
@onready var escurecer: ColorRect = %Escurecer

var _opcoes: Dictionary
var _linhas: Array = []
var _painel_aberto: Control = null
var _botao_origem: Button = null
var _saindo := false
var _rolagens_paineis := {}
var _rolagem_menu: ScrollContainer
var _menu_painel: PanelContainer
var _menu_centro: CenterContainer
var _cartao_jornada: Control
var _moldura_coop: PanelContainer
var _layout_pendente := false
var _logo: TextureRect

func _ready() -> void:
	# Voltando de um mundo cooperativo para o título: o menu principal é o do jogo solo
	if Saves.mundo != Saves.SOLO:
		Saves.trocar(Saves.SOLO)
	_opcoes = Opcoes.carregar()
	Opcoes.aplicar(_opcoes)
	_montar_personagem()
	_animar_respiracao()
	_montar_opcoes()
	_montar_creditos()
	_montar_menu()
	_montar_layout_flex()
	_animar_titulo()
	_fade_entrada()
	# Fogo no máximo: a tela inicial é sempre crepúsculo
	get_tree().call_group("luzes_noturnas", "set", "multiplicador_noite", 1.0)

## Fluxo vertical com rolagem para manter título, menu e opções dentro da janela.
func _montar_layout_flex() -> void:
	var raiz := $Interface/Raiz as Control
	raiz.theme = preload("res://recursos/ui/tema_sidebar.tres")
	$Interface/Raiz/FundoLateral.hide()
	$Interface/Raiz/Versao.hide()
	var fundo := preload("res://codigo/ui/fundo_vila_viva.gd").new()
	fundo.name = "VilaViva"
	raiz.add_child(fundo)
	raiz.move_child(fundo,0)
	var sombra := ColorRect.new()
	sombra.color = Color(0.04,0.07,0.05,0.16)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(sombra)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.move_child(sombra,1)
	var brilhos := preload("res://codigo/ui/brilhos_interface.gd").new()
	raiz.add_child(brilhos)
	raiz.move_child(brilhos,2)
	var margem := MarginContainer.new()
	raiz.add_child(margem)
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left","right","top","bottom"]: margem.add_theme_constant_override("margin_"+lado,16)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.move_child(margem,escurecer.get_index())
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation",16)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(linha)
	_menu_centro = CenterContainer.new()
	_menu_centro.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	linha.add_child(_menu_centro)
	_menu_painel = PanelContainer.new()
	EstiloInicio.painel(_menu_painel)
	_menu_centro.add_child(_menu_painel)
	_menu_painel.minimum_size_changed.connect(_agendar_layout_inicio)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",6)
	_menu_painel.add_child(coluna)
	titulo.hide()
	_logo = TextureRect.new()
	_logo.name = "LogoAlgoLand"
	var recorte := AtlasTexture.new()
	recorte.atlas = LOGO
	# Remove apenas as margens externas; preserva a silhueta inteira da logo.
	recorte.region = Rect2(0,144,1536,720)
	recorte.filter_clip = true
	_logo.texture = recorte
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(_logo)
	var legenda := Label.new()
	legenda.text = "CULTIVE. EXPLORE. ENFRENTE."
	legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legenda.add_theme_font_override("font",EstiloInicio.FONTE)
	legenda.add_theme_font_size_override("font_size",8)
	legenda.add_theme_color_override("font_color",Color("d2b88e"))
	coluna.add_child(legenda)
	_rolagem_menu = ScrollContainer.new()
	_rolagem_menu.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem_menu.follow_focus = true
	_rolagem_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(_rolagem_menu)
	menu.reparent(_rolagem_menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_theme_constant_override("h_separation",6)
	menu.add_theme_constant_override("v_separation",4)
	for botao in menu.get_children():
		botao.custom_minimum_size = Vector2(0,24)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.alignment = HORIZONTAL_ALIGNMENT_CENTER
		EstiloInicio.botao(botao,botao == (botao_continuar if botao_continuar.visible else botao_novo_jogo))
	(botao_continuar if botao_continuar.visible else botao_novo_jogo).theme_type_variation = &"BotaoPrimario"
	var rodape := Label.new()
	rodape.text = "TECLADO / CONTROLE / TOQUE"
	rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rodape.add_theme_font_override("font",EstiloInicio.FONTE)
	rodape.add_theme_font_size_override("font_size",8)
	rodape.add_theme_color_override("font_color",Color("a7977f"))
	coluna.add_child(rodape)
	var direita := VBoxContainer.new()
	direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(direita)
	_cartao_jornada = direita
	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	direita.add_child(espaco)
	var papel := PanelContainer.new()
	EstiloInicio.painel(papel,true,14)
	direita.add_child(papel)
	var resumo := HBoxContainer.new()
	resumo.add_theme_constant_override("separation",8)
	papel.add_child(resumo)
	var retrato := Control.new()
	retrato.custom_minimum_size = Vector2(36,44)
	resumo.add_child(retrato)
	personagem.reparent(retrato)
	personagem.position = Vector2(18,40)
	personagem.get_node("Profundidade").set_process(false)
	personagem.get_node("Profundidade").queue_free()
	personagem.z_as_relative = true
	personagem.z_index = 0
	for sprite in [sprite_corpo,sprite_roupa,sprite_cabelo]: sprite.z_index = 0
	var boas_vindas := VBoxContainer.new()
	boas_vindas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resumo.add_child(boas_vindas)
	for entrada in [["VILA DAS FLORES",10],["Sua proxima aventura comeca aqui.",9],["ALGOLAND / v0.1",8]]:
		var texto := Label.new()
		texto.text = entrada[0]
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.add_theme_font_override("font",EstiloInicio.FONTE)
		texto.add_theme_font_size_override("font_size",entrada[1])
		texto.add_theme_color_override("font_color",Color("694a32"))
		boas_vindas.add_child(texto)
	direita.move_child(espaco,direita.get_child_count()-1)
	for painel in [painel_opcoes,painel_creditos,confirmar_novo_jogo]:
		EstiloInicio.painel(painel,false,14)
		EstiloInicio.botoes_do_painel(painel)
		EstiloInicio.textos_do_painel(painel)
		var conteudo := painel.get_child(0) as Container
		var rolagem := ScrollContainer.new()
		rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		rolagem.follow_focus = true
		var coluna_painel := VBoxContainer.new()
		coluna_painel.add_theme_constant_override("separation",8)
		painel.add_child(coluna_painel)
		var cabecalho := conteudo.get_child(0) as Label
		cabecalho.reparent(coluna_painel)
		cabecalho.label_settings = cabecalho.label_settings.duplicate()
		cabecalho.label_settings.font_color = Color("efdab2")
		cabecalho.label_settings.font = EstiloInicio.FONTE_TITULO
		cabecalho.label_settings.font_size = 12
		coluna_painel.add_child(rolagem)
		rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
		conteudo.reparent(rolagem)
		conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rolagens_paineis[painel] = conteudo
		conteudo.minimum_size_changed.connect(_agendar_layout_inicio)
		cabecalho.minimum_size_changed.connect(_agendar_layout_inicio)
	_moldura_coop = PanelContainer.new()
	EstiloInicio.painel(_moldura_coop)
	EstiloInicio.botoes_do_painel(_painel_coop)
	EstiloInicio.textos_do_painel(_painel_coop)
	raiz.add_child(_moldura_coop)
	raiz.move_child(_moldura_coop,transicao.get_index())
	_painel_coop.reparent(_moldura_coop)
	_painel_coop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_painel_coop.visibility_changed.connect(func(): _moldura_coop.visible = _painel_coop.visible)
	_moldura_coop.hide()
	rolagem_creditos.custom_minimum_size.y = 100
	raiz.resized.connect(_ajustar_layout_flex)
	_ajustar_layout_flex.call_deferred()

func _ajustar_layout_flex() -> void:
	var medida := ($Interface/Raiz as Control).size
	var compacto := medida.x < 480 or medida.y < 300
	menu.columns = 2 if compacto else 1
	_logo.custom_minimum_size.y = 24 if medida.y < 240 else 48
	(_rolagem_menu.get_parent() as VBoxContainer).add_theme_constant_override("separation",4 if compacto else 6)
	_menu_centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compacto else Control.SIZE_SHRINK_BEGIN
	_menu_painel.custom_minimum_size = Vector2(minf(288,medida.x-32) if compacto else 216,minf(292,medida.y-32))
	_cartao_jornada.visible = not compacto
	for painel in _rolagens_paineis:
		var largura := minf(340,medida.x-24)
		var conteudo: Control = _rolagens_paineis[painel]
		var coluna: VBoxContainer = conteudo.get_parent().get_parent()
		var cabecalho: Control = coluna.get_child(0)
		var moldura: Vector2 = painel.get_theme_stylebox("panel").get_minimum_size()
		# O título fica fora da rolagem: reservar sua altura e a moldura inteira.
		var altura_conteudo := conteudo.get_combined_minimum_size().y + cabecalho.get_combined_minimum_size().y
		var altura := minf(ceilf(altura_conteudo + coluna.get_theme_constant("separation") + moldura.y),medida.y-24)
		painel.custom_minimum_size = Vector2(largura,altura)
		painel.size = Vector2(largura,altura)
		painel.position = ((medida-painel.size)/2).round()
	if _moldura_coop != null:
		_moldura_coop.custom_minimum_size = Vector2(minf(340,medida.x-24),0)
		_moldura_coop.size = Vector2(minf(340,medida.x-24),_painel_coop.get_combined_minimum_size().y+24)
		_moldura_coop.position = ((medida-_moldura_coop.size)/2).round()

func _agendar_layout_inicio() -> void:
	if _layout_pendente: return
	_layout_pendente = true
	_layout_inicio_depois.call_deferred()

func _layout_inicio_depois() -> void:
	_layout_pendente = false
	_ajustar_layout_flex()

func _unhandled_input(evento: InputEvent) -> void:
	if _saindo or _painel_aberto == null:
		return
	if evento.is_action_pressed("close_menu"):
		_fechar_painel()
		get_viewport().set_input_as_handled()

func tem_save() -> bool:
	return FileAccess.file_exists(caminho_save_personagem) or FileAccess.file_exists(caminho_save_inventario)

func _montar_menu() -> void:
	botao_continuar.visible = tem_save()
	var botoes: Array[Button] = [botao_continuar, botao_novo_jogo, botao_opcoes, botao_creditos, botao_sair,
			botao_voltar_opcoes, botao_voltar_creditos, botao_sim, botao_nao]
	for botao in botoes:
		_configurar_botao(botao)
	botao_continuar.pressed.connect(_ao_continuar)
	botao_novo_jogo.pressed.connect(_ao_novo_jogo)
	botao_opcoes.pressed.connect(_abrir_painel.bind(painel_opcoes, botao_opcoes, %BotaoVolumeMenos))
	botao_creditos.pressed.connect(_abrir_painel.bind(painel_creditos, botao_creditos, botao_voltar_creditos))
	botao_sair.pressed.connect(_ao_sair)
	botao_voltar_opcoes.pressed.connect(_fechar_painel)
	botao_voltar_creditos.pressed.connect(_fechar_painel)
	botao_sim.pressed.connect(_ao_confirmar_novo_jogo)
	botao_nao.pressed.connect(_fechar_painel)
	_montar_coop()
	var primeiro := botao_continuar if botao_continuar.visible else botao_novo_jogo
	primeiro.grab_focus()
	# Depois do foco inicial, para a tela não abrir com um "tick"; mover o foco e confirmar soam
	Sons.ligar_botoes(self)

func _configurar_botao(botao: Button) -> void:
	botao.set_meta("texto_base", botao.text)
	botao.focus_entered.connect(_destacar.bind(botao, true))
	botao.focus_exited.connect(_destacar.bind(botao, false))
	botao.mouse_entered.connect(botao.grab_focus)

func _destacar(botao: Button, ativo: bool) -> void:
	var texto_base: String = botao.get_meta("texto_base")
	botao.text = texto_base
	botao.modulate = BRILHO_FOCO if ativo else Color.WHITE

func _montar_opcoes() -> void:
	var conteudo := %BotaoVolumeMenos.get_parent().get_parent()
	var volumes: Array = []
	var rotulos_volume: Array = []
	for i in 11:
		volumes.append(i / 10.0)
		rotulos_volume.append("%d%%" % (i * 10))
	var indice_fps := VALORES_FPS.find(_opcoes["max_fps"])
	_adicionar_linha("volume", volumes, rotulos_volume, roundi(float(_opcoes["volume"]) * 10.0),
			%BotaoVolumeMenos, %ValorVolume, %BotaoVolumeMais)
	for item in [["volume_musica","MUSICA"],["volume_efeitos","EFEITOS"],["volume_ambiente","AMBIENTE"]]:
		_adicionar_volume_extra(item[0],item[1],conteudo,volumes,rotulos_volume)
	_adicionar_linha("tela_cheia", [false, true], ["NAO", "SIM"], 1 if _opcoes["tela_cheia"] else 0,
			%BotaoTelaCheiaMenos, %ValorTelaCheia, %BotaoTelaCheiaMais)
	_adicionar_linha("max_fps", VALORES_FPS, ROTULOS_FPS, indice_fps if indice_fps != -1 else 1,
			%BotaoFpsMenos, %ValorFps, %BotaoFpsMais)
	_adicionar_linha("vibracao", [false, true], ["NAO", "SIM"], 1 if _opcoes["vibracao"] else 0,
			%BotaoVibracaoMenos, %ValorVibracao, %BotaoVibracaoMais)
	var indice_layout := maxi(Opcoes.LAYOUTS_CONTROLE.find(_opcoes["layout_controle"]), 0)
	_adicionar_linha("layout_controle", Opcoes.LAYOUTS_CONTROLE, ["AUTO", "XBOX", "NINTENDO", "PS"], indice_layout,
			%BotaoBotoesMenos, %ValorBotoes, %BotaoBotoesMais)
	var linha_interface := HBoxContainer.new()
	linha_interface.add_theme_constant_override("separation",4)
	var nome_interface := Label.new()
	nome_interface.text = "INTERFACE"
	nome_interface.custom_minimum_size.x = 76
	linha_interface.add_child(nome_interface)
	var menos_interface := Button.new()
	menos_interface.text = "-"
	menos_interface.custom_minimum_size = Vector2(16,16)
	linha_interface.add_child(menos_interface)
	var valor_interface := Label.new()
	valor_interface.custom_minimum_size.x = 52
	valor_interface.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	linha_interface.add_child(valor_interface)
	var mais_interface := Button.new()
	mais_interface.text = "+"
	mais_interface.custom_minimum_size = Vector2(16,16)
	linha_interface.add_child(mais_interface)
	conteudo = %BotaoBotoesMenos.get_parent().get_parent()
	conteudo.add_child(linha_interface)
	conteudo.move_child(linha_interface,%BotaoBotoesMenos.get_parent().get_index()+1)
	_adicionar_linha("escala_interface", Opcoes.ESCALAS_INTERFACE, Opcoes.ROTULOS_INTERFACE, maxi(Opcoes.ESCALAS_INTERFACE.find(_opcoes["escala_interface"]),0), menos_interface, valor_interface, mais_interface)
	Controle.dicas_alteradas.connect(_atualizar_dica_botoes)
	_atualizar_dica_botoes()
	# Celular: não existe tela cheia nem desenho de botões de controle para escolher
	if Controle.usando_toque:
		%BotaoTelaCheiaMenos.get_parent().visible = false
		%BotaoBotoesMenos.get_parent().visible = false
		%DicaBotoes.visible = false
	for i in _linhas.size():
		var anterior: Dictionary = _linhas[maxi(i - 1, 0)]
		var proxima: Dictionary = _linhas[i + 1] if i + 1 < _linhas.size() else {}
		var linha: Dictionary = _linhas[i]
		for lado in ["menos", "mais"]:
			var botao: Button = linha[lado]
			botao.focus_neighbor_top = botao.get_path_to(anterior[lado])
			var abaixo: Button = proxima[lado] if not proxima.is_empty() else botao_voltar_opcoes
			botao.focus_neighbor_bottom = botao.get_path_to(abaixo)
	botao_voltar_opcoes.focus_neighbor_top = botao_voltar_opcoes.get_path_to(_linhas[_linhas.size() - 1]["menos"])
	var controles := Button.new()
	controles.text = "REMAPEAR COMANDOS"
	conteudo.add_child(controles)
	conteudo.move_child(botao_voltar_opcoes,conteudo.get_child_count()-1)
	controles.pressed.connect(func(): preload("res://codigo/ui/tela_controles.gd").new().abrir(botao_opcoes))
	for lado in ["menos","mais"]:
		var anterior: Button = _linhas[-1][lado]
		anterior.focus_neighbor_bottom = anterior.get_path_to(controles)
	controles.focus_neighbor_top = controles.get_path_to(_linhas[-1]["menos"])
	controles.focus_neighbor_bottom = controles.get_path_to(botao_voltar_opcoes)
	botao_voltar_opcoes.focus_neighbor_top = botao_voltar_opcoes.get_path_to(controles)

func _adicionar_volume_extra(chave: String, nome: String, pai: Node, valores: Array, rotulos: Array) -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation",4)
	pai.add_child(linha)
	pai.move_child(linha,%BotaoVolumeMenos.get_parent().get_index()+_linhas.size())
	var titulo_volume := Label.new()
	titulo_volume.text = nome
	titulo_volume.custom_minimum_size.x = 76
	linha.add_child(titulo_volume)
	var menos := Button.new()
	menos.text = "-"
	linha.add_child(menos)
	var valor := Label.new()
	valor.custom_minimum_size.x = 52
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	linha.add_child(valor)
	var mais := Button.new()
	mais.text = "+"
	linha.add_child(mais)
	_adicionar_linha(chave,valores,rotulos,roundi(float(_opcoes.get(chave,1.0))*10),menos,valor,mais)

# Diz como o jogo escreve os botões agora; se estiver trocado (A e B invertidos), é só mudar BOTOES
func _atualizar_dica_botoes() -> void:
	var a := Controle.rotulo_botao(JOY_BUTTON_A)
	var b := Controle.rotulo_botao(JOY_BUTTON_B)
	%DicaBotoes.text = "EM USO: %s  (CONFIRMA = %s, VOLTA = %s)" % [Controle.layout.to_upper(), a, b]

# Monta a lista de creditos a partir de CREDITOS. A rolagem funciona no controle: cima/baixo no botao VOLTAR
func _montar_creditos() -> void:
	for bloco in CREDITOS:
		_adicionar_texto_credito(bloco["titulo"], COR_TITULO_CREDITOS)
		if bloco.has("link"):
			_adicionar_texto_credito(bloco["link"], COR_LINK_CREDITOS)
		for linha in bloco["linhas"]:
			_adicionar_texto_credito(linha, Color.WHITE)
		var espaco := Control.new()
		espaco.custom_minimum_size = Vector2(0, 4)
		lista_creditos.add_child(espaco)
	botao_voltar_creditos.focus_neighbor_top = NodePath(".")
	botao_voltar_creditos.focus_neighbor_bottom = NodePath(".")
	botao_voltar_creditos.gui_input.connect(_ao_entrada_creditos)

func _adicionar_texto_credito(texto: String, cor: Color) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.add_theme_font_override("font", FONTE_CREDITOS)
	rotulo.add_theme_font_size_override("font_size", 8)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_shadow_color", Color.BLACK)
	lista_creditos.add_child(rotulo)

func _ao_entrada_creditos(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_up"):
		rolagem_creditos.scroll_vertical -= PASSO_ROLAGEM_CREDITOS
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("ui_down"):
		rolagem_creditos.scroll_vertical += PASSO_ROLAGEM_CREDITOS
		get_viewport().set_input_as_handled()

func _adicionar_linha(chave: String, valores: Array, rotulos: Array, indice: int, menos: Button, rotulo_valor: Label, mais: Button) -> void:
	var linha := {"chave": chave, "valores": valores, "rotulos": rotulos, "indice": indice,
			"rotulo": rotulo_valor, "menos": menos, "mais": mais}
	var numero := _linhas.size()
	_linhas.append(linha)
	rotulo_valor.text = rotulos[indice]
	menos.pressed.connect(_mudar_linha.bind(numero, -1))
	mais.pressed.connect(_mudar_linha.bind(numero, 1))
	for botao in [menos, mais]:
		botao.gui_input.connect(_ao_entrada_linha.bind(numero))

func _ao_entrada_linha(evento: InputEvent, numero: int) -> void:
	if evento.is_action_pressed("ui_left"):
		_mudar_linha(numero, -1)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("ui_right"):
		_mudar_linha(numero, 1)
		get_viewport().set_input_as_handled()

func _mudar_linha(numero: int, passo: int) -> void:
	var linha: Dictionary = _linhas[numero]
	var indice := clampi(linha["indice"] + passo, 0, linha["valores"].size() - 1)
	if indice == linha["indice"]:
		return
	linha["indice"] = indice
	(linha["rotulo"] as Label).text = linha["rotulos"][indice]
	_opcoes[linha["chave"]] = linha["valores"][indice]
	_aplicar_e_salvar_opcoes()
	# Quem liga a vibração sente na hora que funciona
	if linha["chave"] == "vibracao" and _opcoes["vibracao"]:
		Controle.vibrar(0.6, 0.6, 0.2)

func _aplicar_e_salvar_opcoes() -> void:
	Opcoes.aplicar(_opcoes)
	Opcoes.salvar(_opcoes)

func _abrir_painel(painel: Control, origem: Button, foco: Control) -> void:
	if _saindo:
		return
	_painel_aberto = painel
	_botao_origem = origem
	menu.hide()
	escurecer.show()
	painel.show()
	_ajustar_layout_flex.call_deferred()
	if painel == painel_creditos:
		rolagem_creditos.scroll_vertical = 0
	foco.grab_focus()

func _fechar_painel() -> void:
	if _saindo or _painel_aberto == null:
		return
	_painel_aberto.hide()
	_painel_aberto = null
	escurecer.hide()
	menu.show()
	_botao_origem.grab_focus()

func _ao_continuar() -> void:
	if FileAccess.file_exists(caminho_save_personagem):
		_trocar_cena(Saves.preparar_continuacao())
	else:
		_trocar_cena(CENA_CUSTOMIZACAO)

func _ao_novo_jogo() -> void:
	if tem_save():
		# Foca NAO por segurança: SIM apaga o progresso
		_abrir_painel(confirmar_novo_jogo, botao_novo_jogo, botao_nao)
	else:
		Progresso.apagar()
		Calendario.apagar()
		Fazenda.apagar()
		Cidade.apagar()
		BauCasa.apagar()
		Comercio.apagar()
		Transicao.limpar()
		Introducao.iniciar()
		_trocar_cena(CENA_CUSTOMIZACAO)

func _ao_confirmar_novo_jogo() -> void:
	if _saindo:
		return
	for caminho in [caminho_save_personagem, caminho_save_inventario]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	# Brasas, melhorias e moradores também recomeçam do zero (apaga user://progresso.json)
	Progresso.apagar()
	# O calendário volta ao dia 1 (apaga user://calendario.json) e nada fica guardado de trocas de cena anteriores
	Calendario.apagar()
	# A fazenda também recomeça: solo, plantas, sementes, bolsa de colheita e poções (apaga user://fazenda.json)
	Fazenda.apagar()
	Cidade.apagar()
	BauCasa.apagar()
	Comercio.apagar()
	Transicao.limpar()
	InventarioJogador.limpar()
	DadosJogo.resetar_moedas()
	Introducao.iniciar()
	_trocar_cena(CENA_CUSTOMIZACAO)

# --- Co-op local: mundo próprio (Saves.COOP), com dois personagens -------------------------------------------------

var _painel_coop: VBoxContainer
var _botao_coop: Button
var _botao_continuar_coop: Button
var _botao_novo_coop: Button
var _confirmando_novo_coop := false

func _montar_coop() -> void:
	_botao_coop = botao_novo_jogo.duplicate() as Button
	_botao_coop.name = "BotaoCoop"
	_botao_coop.unique_name_in_owner = false
	_botao_coop.text = "CO-OP LOCAL"
	menu.add_child(_botao_coop)
	menu.move_child(_botao_coop, botao_novo_jogo.get_index() + 1)
	_painel_coop = VBoxContainer.new()
	_painel_coop.name = "PainelCoop"
	_painel_coop.alignment = BoxContainer.ALIGNMENT_CENTER
	_painel_coop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_painel_coop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_painel_coop.grow_vertical = Control.GROW_DIRECTION_BOTH
	_painel_coop.hide()
	confirmar_novo_jogo.get_parent().add_child(_painel_coop)
	var aviso := Label.new()
	aviso.text = "DOIS JOGADORES NA MESMA TELA (TELA DIVIDIDA)\nO JOGADOR 2 USA UM CONTROLE. MUNDO SEPARADO DO SOLO."
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", 8)
	_painel_coop.add_child(aviso)
	_botao_continuar_coop = _novo_botao_coop("CONTINUAR CO-OP", _ao_continuar_coop)
	_botao_novo_coop = _novo_botao_coop("NOVO MUNDO CO-OP", _ao_novo_coop)
	var voltar := _novo_botao_coop("VOLTAR", _fechar_painel)
	_botao_coop.pressed.connect(func() -> void:
		_confirmando_novo_coop = false
		_botao_novo_coop.set_meta("texto_base", "NOVO MUNDO CO-OP")
		_botao_novo_coop.text = "NOVO MUNDO CO-OP"
		_botao_continuar_coop.visible = Saves.existe_mundo(Saves.COOP)
		_abrir_painel(_painel_coop, _botao_coop, _botao_continuar_coop if _botao_continuar_coop.visible else _botao_novo_coop))
	_configurar_botao(_botao_coop)
	voltar.focus_mode = Control.FOCUS_ALL

func _novo_botao_coop(texto: String, acao: Callable) -> Button:
	var botao := botao_novo_jogo.duplicate() as Button
	botao.unique_name_in_owner = false
	botao.text = texto
	for sinal in botao.get_signal_connection_list("pressed"):
		botao.pressed.disconnect(sinal["callable"])
	botao.pressed.connect(acao)
	_painel_coop.add_child(botao)
	_configurar_botao(botao)
	return botao

func _ao_continuar_coop() -> void:
	if _saindo:
		return
	Saves.trocar(Saves.COOP)
	_trocar_cena(Saves.preparar_continuacao())

## Novo mundo co-op: apaga o anterior (pedindo confirmação se ele existe), começa sem o prólogo, com o kit inicial e as
## sementes para os dois, e vai criar os dois personagens
func _ao_novo_coop() -> void:
	if _saindo:
		return
	if Saves.existe_mundo(Saves.COOP) and not _confirmando_novo_coop:
		_confirmando_novo_coop = true
		_botao_novo_coop.set_meta("texto_base", "APAGAR O MUNDO CO-OP E COMECAR?")
		_destacar(_botao_novo_coop, true)
		return
	Saves.trocar(Saves.COOP)
	for jogador_2 in [false, true]:
		var caminho := Saves.caminho_personagem(jogador_2)
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	Progresso.apagar()
	Calendario.apagar()
	Fazenda.apagar()
	Cidade.apagar()
	BauCasa.apagar()
	Comercio.apagar()
	Transicao.limpar()
	DadosJogo.resetar_moedas()
	Introducao.pular_prologo()
	for inventario in [InventarioJogador, InventarioJogador2]:
		inventario.limpar()
		inventario.criar_itens_iniciais(false)
		inventario.adicionar_sementes("cenoura", 6)
		inventario.adicionar_sementes("morango", 4)
		inventario.salvar()
	CriacaoPersonagem.etapa_coop = 1
	_trocar_cena(CENA_CUSTOMIZACAO)

func _ao_sair() -> void:
	if _saindo:
		return
	get_tree().quit()

func _trocar_cena(caminho: String) -> void:
	if _saindo:
		return
	_saindo = true
	transicao.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(transicao, "modulate:a", 1.0, 0.35)
	await tween.finished
	var erro := await Transicao.carregar_cena(caminho)
	if erro != OK:
		_saindo = false
		transicao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		create_tween().tween_property(transicao, "modulate:a", 0.0, 0.25)
		push_error("Nao foi possivel abrir a cena: "+caminho)

func _fade_entrada() -> void:
	transicao.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(transicao, "modulate:a", 0.0, 0.5)

func _animar_titulo() -> void:
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_logo,"modulate",Color(1.06,1.03,0.97),1.8)
	tween.tween_property(_logo,"modulate",Color.WHITE,1.8)

func _animar_respiracao() -> void:
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(personagem, "scale:y", 1.02, 1.2)
	tween.tween_property(personagem, "scale:y", 1.0, 1.2)

func _montar_personagem() -> void:
	var visual := {"pele":0,"cabelo":0,"roupa":1,"cor":[1,1,1,1]}
	if FileAccess.file_exists(caminho_save_personagem):
		var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho_save_personagem))
		if dados is Dictionary:
			var anterior: Dictionary = dados.get("cor_cabelo",{})
			visual = dados.get("aparencia_raven",{
				"pele":0,"cabelo":clampi(int(dados.get("cabelo_atual",0))+1,1,28),"roupa":1,
				"cor":[anterior.get("r",1.0),anterior.get("g",1.0),anterior.get("b",1.0),anterior.get("a",1.0)]})
	var pele := clampi(int(visual.get("pele",0)),0,2)
	var cabelo := Raven.indice_cabelo(int(visual.get("cabelo",0)))
	var roupa := Raven.indice_roupa(int(visual.get("roupa",1)))
	sprite_corpo.texture = Raven.carregar(Raven.RAIZ+"paginas/corpo_%d/andar.png" % pele)
	sprite_corpo.material = Raven.material_corpo()
	sprite_cabelo.texture = Aparencia.cabelo(cabelo,"andar")
	sprite_cabelo.material = Raven.material_cabelo()
	sprite_roupa.texture = Aparencia.roupa_refinada(roupa,"andar")
	sprite_roupa.material = Raven.material_corpo()
	for sprite in [sprite_corpo,sprite_cabelo,sprite_roupa]: sprite.scale=Vector2.ONE
	var cor: Array = visual.get("cor",[1,1,1,1])
	sprite_cabelo.modulate = Color(cor[0],cor[1],cor[2],cor[3])
