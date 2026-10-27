extends CanvasLayer
## Edita o visual do personagem durante o jogo, com a mesma tela da criação (modo edição):
## pele, olhos, cor e penteado/roupas 3D. Não apaga o jogo nem troca de cena.
## Também monta o aviso "visual novo" mostrado uma vez a quem veio de um save antigo.
const CENA_CRIACAO := "res://cenas/criacao_personagem.tscn"
const EstiloInicio := preload("res://codigo/ui/estilo_inicio_detalhado.gd")
const TEMA := preload("res://recursos/ui/tema_sidebar.tres")
signal fechado
var jogador: Node2D
var _tela: Control

## Abre o editor sobre o jogo (funciona com o jogo pausado).
static func abrir(dono: Node2D) -> CanvasLayer:
	var editor = load("res://codigo/ui/editor_visual.gd").new()
	editor.jogador = dono
	return editor

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela = load(CENA_CRIACAO).instantiate()
	_tela.trocar_cena = false
	_tela.modo_edicao = true
	_tela.caminho_save = Saves.caminho_personagem(bool(jogador.get("eh_p2")))
	_tela.carregar_dados(jogador.carregar_de_json())
	add_child(_tela)
	_tela.confirmada.connect(_ao_confirmar)
	_tela.cancelada.connect(_fechar)

func _ao_confirmar(dados: Dictionary) -> void:
	# O Raven e o 3D leem aparencia_raven a cada quadro; as peças 3D trocam na hora.
	jogador.aparencia_raven = dados.get("aparencia_raven", jogador.aparencia_raven).duplicate(true)
	var cor: Array = jogador.aparencia_raven.get("cor", [1., 1., 1., 1.])
	jogador.definir_cor_cabelo(Color(cor[0], cor[1], cor[2], cor[3] if cor.size() > 3 else 1.))
	var heroi := jogador.get_node_or_null("HeroiBase3D")
	if heroi != null:
		heroi.definir_roupas_3d(dados.get("roupas_3d", {}))
		heroi._aplicar_cores()
	_fechar()

func _fechar() -> void:
	fechado.emit()
	queue_free()

## Aviso único para saves antigos: AJUSTAR AGORA abre o editor; DEPOIS fecha. Os dois apagam a marca.
static func aviso(dono: Node2D) -> CanvasLayer:
	var camada := CanvasLayer.new()
	camada.layer = 85
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	var raiz := Control.new()
	raiz.theme = TEMA
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(raiz)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(centro)
	var painel := PanelContainer.new()
	EstiloInicio.painel(painel, false, 10)
	painel.custom_minimum_size = Vector2(240, 0)
	centro.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	painel.add_child(coluna)
	var texto := Label.new()
	texto.text = "SEU PERSONAGEM GANHOU UM VISUAL NOVO!\nQUER AJUSTAR ROUPA, CABELO E CORES?\n(DEPOIS: MENU DE PAUSA > EDITAR VISUAL)"
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.add_theme_font_size_override("font_size", 9)
	coluna.add_child(texto)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	coluna.add_child(linha)
	var mover_antes: bool = dono.movimento_habilitado
	dono.movimento_habilitado = false
	var concluir := func(ajustar: bool) -> void:
		_limpar_aviso(dono)
		camada.queue_free()
		if ajustar:
			var editor := abrir(dono)
			editor.fechado.connect(func() -> void: dono.movimento_habilitado = mover_antes)
			dono.get_tree().root.add_child(editor)
		else:
			dono.movimento_habilitado = mover_antes
	for par in [["DEPOIS", false], ["AJUSTAR AGORA", true]]:
		var botao := Button.new()
		botao.text = par[0]
		EstiloInicio.botao(botao, par[1], 16.0)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.custom_minimum_size = Vector2(0, 24)
		botao.pressed.connect(concluir.bind(par[1]))
		linha.add_child(botao)
	(linha.get_child(1) as Button).grab_focus.call_deferred()
	return camada

static func _limpar_aviso(dono: Node2D) -> void:
	var caminho: String = Saves.caminho_personagem(bool(dono.get("eh_p2")))
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho)) if FileAccess.file_exists(caminho) else null
	if dados is Dictionary and dados.has("aviso_visual_3d"):
		dados.erase("aviso_visual_3d")
		preload("res://codigo/modelos/modelo_inventario.gd").gravar_dados(caminho, dados)
