extends Control

## Tela de pausa (Esc; no celular o botão II): o jogo para (get_tree().paused) enquanto ela está aberta. Abre sobre o menu principal com
## CONTINUAR, OPCOES (as mesmas da tela inicial: volume, tela cheia, FPS, vibração e desenho dos botões), VOLTAR AO MENU e SAIR DO JOGO;
## os dois últimos pedem confirmação. A Interface abre e fecha a tela (nome "pausa") e cuida de Esc/B para fechar.

const EstiloInicio := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const TecladoVirtual := preload("res://codigo/ui/teclado_virtual.gd")
const Opcoes := preload("res://codigo/globais/opcoes_jogo.gd")
const CENA_MENU := "res://cenas/inicio_do_jogo.tscn"
const VALORES_FPS := [30, 60, 120, 0]
const ROTULOS_FPS := ["30", "60", "120", "SEM LIMITE"]
const COR_NOME_OPCAO := Color(0.75, 0.7, 0.62)
const COR_AVISO := Color(1, 0.7, 0.55)
## Mesmo limite da criação do personagem
const MAX_APELIDO := 12

enum Vista { MENU, OPCOES, CONFIRMAR, APELIDO }

@onready var _titulo: Label = %Titulo
@onready var _detalhe: Label = %Detalhe
@onready var _menu: GridContainer = %Menu
@onready var _vista_opcoes: VBoxContainer = %Opcoes
@onready var _confirmar: HBoxContainer = %Confirmar
@onready var _botao_continuar: Button = %BotaoContinuar
@onready var _botao_opcoes: Button = %BotaoOpcoes
@onready var _botao_salvar: Button = %BotaoSalvar
@onready var _botao_menu: Button = %BotaoMenu
@onready var _botao_sair: Button = %BotaoSair
@onready var _botao_sim: Button = %BotaoSim
@onready var _botao_nao: Button = %BotaoNao

var _vista := Vista.MENU
var _opcoes: Dictionary
var _linhas: Array = []
var _botao_voltar: Button
var _rolagem_opcoes: ScrollContainer
## O que o SIM da confirmação faz: "menu" ou "sair"
var _pedido := ""
var _saindo := false
var _vista_apelido: VBoxContainer
var _campo_apelido: LineEdit
var _botao_salvar_apelido: Button
var _teclado: CanvasLayer

func _ready() -> void:
	_botao_continuar.pressed.connect(_continuar)
	var mapa := Button.new()
	mapa.name = "BotaoMapaMundi"
	mapa.text = "MAPA"
	mapa.pressed.connect(func():
		EventosJogo.fechar_tela_de(self,"pausa")
		EventosJogo.abrir_tela_de(self,"mapa_mundi"))
	_menu.add_child(mapa)
	_menu.move_child(mapa, _botao_continuar.get_index()+1)
	var cidade_online := Button.new()
	cidade_online.name = "BotaoLobbyCidade"
	cidade_online.text = "CHAT GLOBAL / ONLINE"
	cidade_online.pressed.connect(func():
		EventosJogo.fechar_tela_de(self,"pausa")
		EventosJogo.abrir_tela_de(self,"lobby"))
	_menu.add_child(cidade_online)
	var apelido := Button.new()
	apelido.name = "BotaoApelido"
	apelido.text = "APELIDO"
	apelido.pressed.connect(_mostrar.bind(Vista.APELIDO))
	_menu.add_child(apelido)
	_montar_vista_apelido()
	%BotaoFechar.pressed.connect(_continuar)
	_botao_opcoes.pressed.connect(_mostrar.bind(Vista.OPCOES))
	_botao_salvar.pressed.connect(_salvar_pelo_menu)
	_botao_menu.pressed.connect(_pedir.bind("menu"))
	_botao_sair.pressed.connect(_pedir.bind("sair"))
	_botao_sim.pressed.connect(_ao_sim)
	_botao_nao.pressed.connect(_mostrar.bind(Vista.MENU))
	_montar_opcoes()
	EstiloInicio.painel($Centro/Painel,false,10,true)
	for botao: Button in $Centro/Painel.find_children("*","Button",true,false):
		EstiloInicio.botao(botao,botao == _botao_continuar,16.0)
	for botao: Button in _menu.get_children(): botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rolagem_opcoes = ScrollContainer.new()
	_rolagem_opcoes.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem_opcoes.follow_focus = true
	var pai_opcoes := _vista_opcoes.get_parent()
	var indice_opcoes := _vista_opcoes.get_index()
	pai_opcoes.add_child(_rolagem_opcoes)
	pai_opcoes.move_child(_rolagem_opcoes, indice_opcoes)
	_vista_opcoes.reparent(_rolagem_opcoes)
	_vista_opcoes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rolagem_opcoes.hide()
	resized.connect(_ajustar_altura_opcoes)
	_ajustar_altura_opcoes.call_deferred()
	visibility_changed.connect(_ao_visibilidade_alterada)

func _ajustar_altura_opcoes() -> void:
	_menu.columns = 2 if size.y < 270 else 1
	_rolagem_opcoes.custom_minimum_size.y = minf(_vista_opcoes.get_combined_minimum_size().y, maxf(size.y - 112, 40))

func _exit_tree() -> void:
	# Nunca deixa o jogo parado ao sair da cena por esta tela
	if get_tree() != null:
		get_tree().paused = false

func _ao_visibilidade_alterada() -> void:
	get_tree().paused = visible
	if visible:
		var dono := EventosJogo.dono(self)
		_menu.get_node("BotaoLobbyCidade").visible=dono!=null
		_menu.get_node("BotaoApelido").visible = dono != null
		_opcoes = Opcoes.carregar(_lado())
		_atualizar_linhas()
		_mostrar(Vista.MENU)

## Chamado pela Interface ao abrir a tela: no teclado e no controle o foco começa em CONTINUAR
func focar_inicio() -> void:
	_botao_continuar.grab_focus()

## Esc/B dentro de OPCOES ou da confirmação volta ao menu da pausa; no menu da pausa fecha a tela (quem decide é a Interface, que chama isto)
## Devolve true se tratou o pedido (havia uma subtela aberta)
func voltar_subtela() -> bool:
	if _vista == Vista.MENU:
		return false
	_mostrar(Vista.MENU)
	return true

func _continuar() -> void:
	EventosJogo.fechar_tela_de(self, "pausa")

func _mostrar(vista: Vista) -> void:
	_vista = vista
	_menu.visible = vista == Vista.MENU
	_vista_opcoes.visible = vista == Vista.OPCOES
	_rolagem_opcoes.visible = vista == Vista.OPCOES
	_ajustar_altura_opcoes()
	_confirmar.visible = vista == Vista.CONFIRMAR
	_vista_apelido.visible = vista == Vista.APELIDO
	_detalhe.visible = vista != Vista.OPCOES and _detalhe.text != ""
	match vista:
		Vista.MENU:
			_titulo.text = "PAUSADO"
			_detalhe.text = _texto_estado()
			_botao_continuar.grab_focus()
		Vista.OPCOES:
			_titulo.text = "OPCOES"
			_linhas[0]["menos"].grab_focus()
		Vista.CONFIRMAR:
			_botao_nao.grab_focus()
		Vista.APELIDO:
			_titulo.text = "APELIDO"
			_detalhe.text = "COMO VOCE APARECE NO CHAT E NO RANKING"
			_detalhe.visible = true
			var jogador := EventosJogo.dono(self)
			_campo_apelido.text = str(jogador.apelido) if jogador != null and str(jogador.apelido) != "sem apelido" else ""
			_campo_apelido.grab_focus()

## Onde o jogador está e quanto tem a perder: na onda em andamento, voltar ao menu descarta o progresso dela
func _texto_estado() -> String:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null and bool(gerenciador.get("onda_em_andamento")):
		return "ANDAR %d EM ANDAMENTO" % int(gerenciador.get("onda_atual"))
	return ""

func _pedir(que: String) -> void:
	_pedido = que
	_titulo.text = "VOLTAR AO MENU?" if que == "menu" else "SAIR DO JOGO?"
	_detalhe.add_theme_color_override("font_color", COR_AVISO if _perde_onda() else COR_NOME_OPCAO)
	_mostrar(Vista.CONFIRMAR)
	# _mostrar põe o título do menu; a confirmação usa o dela
	_titulo.text = "VOLTAR AO MENU?" if que == "menu" else "SAIR DO JOGO?"
	_detalhe.text = "O ANDAR ATUAL SE PERDE" if _perde_onda() else "SEU JOGO FICA SALVO"

func _perde_onda() -> bool:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	return gerenciador != null and bool(gerenciador.get("onda_em_andamento"))

func _ao_sim() -> void:
	if _saindo:
		return
	_saindo = true
	_salvar_tudo()
	if _pedido == "sair":
		get_tree().quit()
		return
	get_tree().paused = false
	Transicao.limpar()
	var erro := await Transicao.carregar_cena(CENA_MENU)
	if erro != OK:
		_saindo = false
		get_tree().paused = true
		push_error("Nao foi possivel abrir o menu inicial.")

func _salvar_tudo() -> void:
	Saves.salvar_tudo()

## Botão SALVAR: grava o jogo sem sair e avisa no detalhe da pausa
func _salvar_pelo_menu() -> void:
	_salvar_tudo()
	Sons.tocar("moeda", 0.0)
	_detalhe.text = "JOGO SALVO"
	_detalhe.visible = true
	_botao_salvar.grab_focus()

# --- Apelido ---------------------------------------------------------------------------------------------------------

func _montar_vista_apelido() -> void:
	_vista_apelido = VBoxContainer.new()
	_vista_apelido.add_theme_constant_override("separation", 6)
	_vista_apelido.hide()
	_menu.get_parent().add_child(_vista_apelido)
	_campo_apelido = LineEdit.new()
	_campo_apelido.placeholder_text = "sem apelido"
	_campo_apelido.max_length = MAX_APELIDO
	_campo_apelido.custom_minimum_size = Vector2(0, 22)
	_campo_apelido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EstiloInicio.campo(_campo_apelido)
	_campo_apelido.text_submitted.connect(func(_texto: String): _salvar_apelido())
	_campo_apelido.gui_input.connect(_ao_entrada_apelido)
	_vista_apelido.add_child(_campo_apelido)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	_vista_apelido.add_child(linha)
	_botao_salvar_apelido = Button.new()
	_botao_salvar_apelido.text = "SALVAR"
	_botao_salvar_apelido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_botao_salvar_apelido.pressed.connect(_salvar_apelido)
	linha.add_child(_botao_salvar_apelido)
	var cancelar := Button.new()
	cancelar.text = "CANCELAR"
	cancelar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancelar.pressed.connect(_mostrar.bind(Vista.MENU))
	linha.add_child(cancelar)
	_teclado = TecladoVirtual.new()
	add_child(_teclado)
	_teclado.confirmado.connect(func(texto: String):
		_campo_apelido.text = texto
		_botao_salvar_apelido.grab_focus())
	_teclado.ligar_toque(_campo_apelido)

func _ao_entrada_apelido(evento: InputEvent) -> void:
	# No controle, confirmar (A) no campo abre o teclado virtual, como na criação do personagem
	if evento is InputEventJoypadButton and evento.is_action_pressed("ui_accept"):
		_teclado.abrir(_campo_apelido.text, MAX_APELIDO)
		_campo_apelido.accept_event()

## Troca o apelido do jogador (chat, ranking e mapa leem dele) e grava no save do personagem
func _salvar_apelido() -> void:
	var jogador := EventosJogo.dono(self)
	var texto := _campo_apelido.text.strip_edges()
	if jogador == null:
		return
	if texto.is_empty():
		_detalhe.text = "ESCREVA UM APELIDO"
		_detalhe.visible = true
		Sons.tocar("erro", 0.0)
		return
	var novo := Ranking.apelido_personagem(texto.to_upper()).left(MAX_APELIDO)
	jogador.definir_apelido(novo)
	_gravar_apelido_no_personagem(jogador, novo)
	Ranking.capturar_jogador(jogador)
	Sons.tocar("moeda", 0.0)
	_mostrar(Vista.MENU)
	_detalhe.text = "APELIDO: " + novo
	_detalhe.visible = true

func _gravar_apelido_no_personagem(jogador: Node2D, novo: String) -> void:
	var caminho := Saves.caminho_personagem(bool(jogador.get("eh_p2")))
	var dados := {}
	var leitura := FileAccess.open(caminho, FileAccess.READ)
	if leitura != null:
		var lido = JSON.parse_string(leitura.get_as_text())
		if lido is Dictionary:
			dados = lido
		leitura.close()
	dados["apelido"] = novo
	var escrita := FileAccess.open(caminho, FileAccess.WRITE)
	if escrita == null:
		push_error("Apelido: não consegui gravar " + caminho)
		return
	escrita.store_string(JSON.stringify(dados))
	escrita.close()

# --- Opcoes ----------------------------------------------------------------------------------------------------------

## Cooperativo: a pausa do jogador 2 mexe só nas opções dele (vibração, zoom e botões); volume, tela e FPS são da janela
func _lado() -> int:
	return 2 if EventosJogo.eh_do_p2(self) else 1

func _montar_opcoes() -> void:
	if _lado() == 2:
		_adicionar_linha("vibracao", "VIBRACAO", [false, true], ["NAO", "SIM"])
		_adicionar_linha("zoom", "ZOOM", Opcoes.ZOOMS, Opcoes.ROTULOS_ZOOM)
		_adicionar_linha("escala_interface", "INTERFACE", Opcoes.ESCALAS_INTERFACE, Opcoes.ROTULOS_INTERFACE)
		_adicionar_linha("layout_controle", "BOTOES", Opcoes.LAYOUTS_CONTROLE, ["AUTO", "XBOX", "NINTENDO", "PS"])
		_terminar_opcoes()
		return
	var volumes: Array = []
	var rotulos_volume: Array = []
	for i in 11:
		volumes.append(i / 10.0)
		rotulos_volume.append("%d%%" % (i * 10))
	_adicionar_linha("volume", "VOLUME", volumes, rotulos_volume)
	for item in [["volume_musica","MUSICA"],["volume_efeitos","EFEITOS"],["volume_ambiente","AMBIENTE"]]:
		_adicionar_linha(item[0],item[1],volumes,rotulos_volume)
	if not Controle.usando_toque:
		_adicionar_linha("tela_cheia", "TELA CHEIA", [false, true], ["NAO", "SIM"])
	_adicionar_linha("max_fps", "FPS MAXIMO", VALORES_FPS, ROTULOS_FPS)
	_adicionar_linha("vibracao", "VIBRACAO", [false, true], ["NAO", "SIM"])
	_adicionar_linha("zoom", "ZOOM", Opcoes.ZOOMS, Opcoes.ROTULOS_ZOOM)
	_adicionar_linha("escala_interface", "INTERFACE", Opcoes.ESCALAS_INTERFACE, Opcoes.ROTULOS_INTERFACE)
	if not Controle.usando_toque:
		_adicionar_linha("layout_controle", "BOTOES", Opcoes.LAYOUTS_CONTROLE, ["AUTO", "XBOX", "NINTENDO", "PS"])
	_terminar_opcoes()

func _terminar_opcoes() -> void:
	var controles := Button.new()
	controles.text = "REMAPEAR COMANDOS"
	controles.pressed.connect(func(): preload("res://codigo/ui/tela_controles.gd").new().abrir(self,_lado()))
	_vista_opcoes.add_child(controles)
	_botao_voltar = Button.new()
	_botao_voltar.text = "VOLTAR"
	_botao_voltar.custom_minimum_size = Vector2(0, 18)
	_botao_voltar.pressed.connect(_mostrar.bind(Vista.MENU))
	_vista_opcoes.add_child(_botao_voltar)
	# Foco: cima e baixo andam pelas linhas (menos com menos, mais com mais) e o último desce para VOLTAR
	for i in _linhas.size():
		var linha: Dictionary = _linhas[i]
		for lado in ["menos", "mais"]:
			var botao: Button = linha[lado]
			var acima: Button = _linhas[maxi(i - 1, 0)][lado]
			var abaixo: Button = _linhas[i + 1][lado] if i + 1 < _linhas.size() else controles
			botao.focus_neighbor_top = botao.get_path_to(acima)
			botao.focus_neighbor_bottom = botao.get_path_to(abaixo)
	controles.focus_neighbor_top = controles.get_path_to(_linhas[_linhas.size()-1]["menos"])
	controles.focus_neighbor_bottom = controles.get_path_to(_botao_voltar)
	_botao_voltar.focus_neighbor_top = _botao_voltar.get_path_to(controles)

## Uma linha "NOME  -  valor  +": os botões mudam o valor um passo e as setas do teclado/controle também
func _adicionar_linha(chave: String, nome: String, valores: Array, rotulos: Array) -> void:
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 4)
	var rotulo_nome := Label.new()
	rotulo_nome.text = nome
	rotulo_nome.custom_minimum_size = Vector2(76, 0)
	rotulo_nome.add_theme_color_override("font_color", COR_NOME_OPCAO)
	caixa.add_child(rotulo_nome)
	var menos := Button.new()
	menos.text = "-"
	menos.custom_minimum_size = Vector2(16, 16)
	caixa.add_child(menos)
	var rotulo_valor := Label.new()
	rotulo_valor.custom_minimum_size = Vector2(52, 0)
	rotulo_valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(rotulo_valor)
	var mais := Button.new()
	mais.text = "+"
	mais.custom_minimum_size = Vector2(16, 16)
	caixa.add_child(mais)
	_vista_opcoes.add_child(caixa)
	var numero := _linhas.size()
	_linhas.append({"chave": chave, "valores": valores, "rotulos": rotulos, "indice": 0, "rotulo": rotulo_valor, "menos": menos, "mais": mais})
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

## Põe nas linhas os valores salvos (ao abrir a tela)
func _atualizar_linhas() -> void:
	for linha in _linhas:
		var indice: int = (linha["valores"] as Array).find(_opcoes.get(linha["chave"]))
		if linha["chave"] == "volume":
			indice = roundi(float(_opcoes["volume"]) * 10.0)
		linha["indice"] = maxi(indice, 0)
		(linha["rotulo"] as Label).text = linha["rotulos"][linha["indice"]]

func _mudar_linha(numero: int, passo: int) -> void:
	var linha: Dictionary = _linhas[numero]
	var indice := clampi(linha["indice"] + passo, 0, linha["valores"].size() - 1)
	if indice == linha["indice"]:
		return
	linha["indice"] = indice
	(linha["rotulo"] as Label).text = linha["rotulos"][indice]
	_opcoes[linha["chave"]] = linha["valores"][indice]
	Opcoes.aplicar(_opcoes, _lado())
	Opcoes.salvar(_opcoes, _lado())
	# Quem liga a vibração sente na hora que funciona
	if linha["chave"] == "vibracao" and _opcoes["vibracao"]:
		Controle.vibrar(0.6, 0.6, 0.2, self)
