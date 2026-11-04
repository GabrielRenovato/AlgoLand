extends Control

## Navegação opt-in: mundo → regiões → cenário de teste.
const Controlador := preload("res://codigo/campanha/controlador_campanha.gd")
const CENARIOS_PROTOTIPO := Controlador.Catalogo.REGIOES_HABILITADAS
const POSICOES := {
	"chegada":Vector2(0.19,0.82), "estrada":Vector2(0.28,0.61), "vila":Vector2(0.35,0.52),
	"pomar":Vector2(0.16,0.50), "moinho":Vector2(0.41,0.66), "varzeas":Vector2(0.70,0.83),
	"pedreira":Vector2(0.84,0.66), "tuneis":Vector2(0.87,0.50), "mata":Vector2(0.64,0.45),
	"observatorio":Vector2(0.20,0.235), "jardins":Vector2(0.465,0.21), "bastiao":Vector2(0.79,0.27)}
var controlador := Controlador.new()
var dialogo_salas: CanvasLayer
var tela := "mundo"
var selecionado := "andar_01"
var _catalogo := Controlador.Catalogo.dados()
var _titulo: Label
var _voltar: Button
var _conteudo: Control
var _area_mapa := Rect2()
var _nos: Dictionary = {}
var _nome: Label
var _descricao: Label
var _entrar: Button
var _rodape: PanelContainer
var _raiz: VBoxContainer
var _fundo: ColorRect
var _mundo: ColorRect
var _tabuleiro: TextureRect
var _campo_regional: Control
var _transicao: ColorRect
var _em_transicao := false
const Estilo := preload("res://codigo/ui/estilo_campanha.gd")
const Miniatura := preload("res://codigo/campanha/miniatura_andar.gd")
const Marcador := preload("res://codigo/campanha/marcador_regiao.gd")
const MapaRegional := preload("res://codigo/campanha/mapa_regional.gd")
const RAIZ_ARTE := "res://assets/ui/campanha/tabuleiro/"
# Interior da célula pintada (coluna 4, linha 3), na imagem de 1536 × 1024.
# Cada domínio ocupa um único espaço; as outras células permanecem livres.
const CELULAS_DOMINIOS := {"andar_01": Rect2(616,342,150,106)}


func _ready() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") and get_tree().root.get_node("Saves").mundo != "campanha":
		push_error("Abra pelo launcher de campanha isolada.")
		get_tree().quit(1); return
	if controlador.iniciar("user://percurso_primeira_raiz","prototipo") != OK:
		push_error("Não foi possível abrir o progresso da campanha.")
		get_tree().quit(1); return
	_montar()
	Estilo.fontes(self)
	if get_tree().get_meta("campanha_mapa_regional",false):
		get_tree().remove_meta("campanha_mapa_regional")
		mostrar_regioes()
	else:
		mostrar_mundo()

func _painel() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("302318")
	estilo.border_color = Color("b18b46")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	return estilo

func _montar() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color("092e32")
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fundo)
	_mundo = ColorRect.new()
	_mundo.name = "OceanoAnimado"
	_mundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mar := ShaderMaterial.new()
	mar.shader = preload("res://codigo/campanha/oceano_tabuleiro.gdshader")
	mar.set_shader_parameter("pintura",load(RAIZ_ARTE+"referencia_oceano.png"))
	mar.set_shader_parameter("ilha",load(RAIZ_ARTE+"tabuleiro.png"))
	_mundo.material = mar
	add_child(_mundo)
	_tabuleiro = TextureRect.new()
	_tabuleiro.texture = load(RAIZ_ARTE+"tabuleiro.png")
	_tabuleiro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tabuleiro.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tabuleiro.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tabuleiro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tabuleiro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tabuleiro)
	_campo_regional = MapaRegional.new()
	_campo_regional.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_campo_regional)
	resized.connect(_ajustar_mar)
	resized.connect(_posicionar)
	var margens := MarginContainer.new()
	margens.z_index = 20
	margens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left","right","top","bottom"]:
		margens.add_theme_constant_override("margin_"+lado,10)
	add_child(margens)
	_raiz = VBoxContainer.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_theme_constant_override("separation",8)
	margens.add_child(_raiz)
	var topo := HBoxContainer.new()
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topo.add_theme_constant_override("separation",10)
	var capa := PanelContainer.new()
	Estilo.painel(capa,false,7)
	_raiz.add_child(capa)
	capa.add_child(topo)
	_voltar = Button.new()
	_voltar.text = "Mundo"
	_voltar.add_theme_font_size_override("font_size",11)
	Estilo.botao(_voltar)
	_voltar.pressed.connect(mostrar_mundo)
	topo.add_child(Estilo.brasao(Vector2(24,28)))
	topo.add_child(_voltar)
	_titulo = Label.new()
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titulo.add_theme_font_override("font",Estilo.FONTE_TITULO)
	_titulo.add_theme_font_size_override("font_size",14)
	_titulo.add_theme_color_override("font_color",Estilo.VERDE)
	_titulo.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	_titulo.add_theme_constant_override("shadow_offset_x",1)
	_titulo.add_theme_constant_override("shadow_offset_y",1)
	topo.add_child(_titulo)
	_conteudo = Control.new()
	_conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_conteudo.clip_contents = true
	_conteudo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_conteudo.custom_minimum_size.y = 100
	_raiz.add_child(_conteudo)
	_rodape = PanelContainer.new()
	_rodape.z_index = 20
	Estilo.painel(_rodape,false,10,true)
	add_child(_rodape)
	var coluna := HBoxContainer.new()
	coluna.add_theme_constant_override("separation",10)
	_rodape.add_child(coluna)
	_nome = Label.new()
	_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nome.add_theme_font_override("font",Estilo.FONTE_TITULO)
	_nome.add_theme_font_size_override("font_size",11)
	_nome.add_theme_color_override("font_color",Estilo.TINTA)
	_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coluna.add_child(_nome)
	_descricao = Label.new()
	_descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_descricao.add_theme_font_override("font",Estilo.FONTE)
	_descricao.add_theme_font_size_override("font_size",10)
	coluna.add_child(_descricao)
	_descricao.hide()
	_entrar = Button.new()
	_entrar.add_theme_font_size_override("font_size",11)
	_entrar.custom_minimum_size = Vector2(96,28)
	Estilo.botao(_entrar,true)
	_entrar.focus_mode = Control.FOCUS_NONE
	_entrar.pressed.connect(entrar_selecionado)
	coluna.add_child(_entrar)
	var menu := Button.new()
	menu.text = "MENU"
	menu.add_theme_font_size_override("font_size",10)
	Estilo.botao(menu)
	menu.focus_mode = Control.FOCUS_NONE
	menu.custom_minimum_size = Vector2(64,28)
	menu.z_index = 20
	menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	menu.pressed.connect(func() -> void:
		if not _em_transicao: get_tree().change_scene_to_file("res://cenas/inicio_do_jogo.tscn"))
	add_child(menu)
	_conteudo.draw.connect(_desenhar_ligacao)
	_conteudo.resized.connect(_posicionar)
	_transicao = ColorRect.new()
	_transicao.z_index = 30
	_transicao.color = Color(0.025,0.08,0.07,0)
	_transicao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transicao.mouse_filter = Control.MOUSE_FILTER_STOP
	_transicao.hide()
	add_child(_transicao)

func _limpar_nos() -> void:
	for botao in _nos.values():
		botao.hide()
		botao.queue_free()
	_nos.clear()

func mostrar_mundo() -> void:
	tela = "mundo"
	_rodape.hide()
	_campo_regional.hide()
	_conteudo.show()
	selecionado = "andar_01"
	_voltar.hide()
	_titulo.text = "Mapa de Relíquias"
	_mundo.show()
	_tabuleiro.show()
	_limpar_nos()
	for i in 1:
		var id := "andar_01"
		var botao := Miniatura.new()
		botao.numero = i+1
		botao.revelada = controlador.progresso.acesso_liberado(id)
		botao.tooltip_text = _catalogo.destinos[id].nome
		botao.pressed.connect(_abrir_dominio.bind(id))
		_conteudo.add_child(botao)
		_nos[id] = botao
	_posicionar.call_deferred()
	selecionar(selecionado)

func _abrir_dominio(id: String) -> void:
	if _em_transicao or tela != "mundo" or not controlador.progresso.acesso_liberado(id): return
	_em_transicao = true
	_transicao.show()
	var fechar := create_tween()
	fechar.tween_property(_transicao,"color:a",1.0,0.16)
	await fechar.finished
	mostrar_regioes()
	# O minimapa assume o lugar do tabuleiro enquanto a tela está coberta.
	await get_tree().process_frame
	var abrir := create_tween()
	abrir.tween_property(_transicao,"color:a",0.0,0.2)
	await abrir.finished
	_transicao.hide()
	_em_transicao = false

func mostrar_regioes() -> void:
	tela = "regioes"
	_rodape.show()
	_campo_regional.show()
	_conteudo.hide()
	_voltar.show()
	_titulo.text = "Primeira Raiz • Regiões"
	_mundo.hide()
	_tabuleiro.hide()
	_limpar_nos()
	for id in POSICOES:
		var botao := Marcador.new()
		botao.z_index = 15
		botao.tooltip_text = _catalogo.destinos[id].nome
		botao.disponivel = controlador.progresso.acesso_liberado(id) and id in CENARIOS_PROTOTIPO
		botao.concluido = _regiao_concluida(id)
		botao.pressed.connect(_clicar_estagio.bind(id))
		_campo_regional.camada.add_child(botao)
		_nos[id] = botao
	_posicionar.call_deferred()
	selecionar(_proximo_destino())
	_posicionar()

func _proximo_destino() -> String:
	var id := str(get_tree().get_meta("campanha_regiao_selecionada",""))
	if get_tree().has_meta("campanha_regiao_selecionada"):
		get_tree().remove_meta("campanha_regiao_selecionada")
	if id in CENARIOS_PROTOTIPO and controlador.progresso.acesso_liberado(id): return id
	var objetivo := controlador.objetivo_atual()
	id = str(objetivo.get("regiao",""))
	if id in CENARIOS_PROTOTIPO and controlador.progresso.acesso_liberado(id): return id
	id = str(controlador.progresso.ponto_retorno().get("regiao","chegada"))
	return id if id in CENARIOS_PROTOTIPO and controlador.progresso.acesso_liberado(id) else "chegada"

func _regiao_concluida(id: String) -> bool:
	var missoes := {"chegada":"sobreviver_queda","estrada":"estrada_interrompida","vila":"acolhimento","pomar":"pomar_sulcos","moinho":"moinho_vazao"}
	return missoes.has(id) and controlador.progresso.missao_concluida(missoes[id])

func selecionar(id: String) -> void:
	if not _nos.has(id): return
	selecionado = id
	_nome.text = "Domínio da Primeira Raiz" if tela == "mundo" and id == "andar_01" else _catalogo.destinos[id].nome
	var liberado := controlador.progresso.acesso_liberado(id)
	if tela == "mundo":
		_entrar.text = "Explorar domínio" if id == "andar_01" else "Em preparação"
		_entrar.disabled = id != "andar_01"
		_descricao.text = "Uma vila entre raízes antigas. Confirme para explorar suas regiões." if id == "andar_01" else "A relíquia da Primeira Raiz revela este lugar. Conteúdo em preparação."
		for chave in _nos:
			_nos[chave].selecionada = chave == selecionado
			_nos[chave].queue_redraw()
	else:
		var tipo: String = _catalogo.destinos[id].tipo
		var papel := "Cidade • encontro e serviços" if tipo == "cidade" else ("Dungeon • desafio de grupo" if tipo == "dungeon" else "Região de exploração")
		_descricao.text = papel
		if not liberado:
			_descricao.text += " • avance nas missões para liberar."
		elif not id in CENARIOS_PROTOTIPO:
			_descricao.text += " • cenário em preparação."
		else:
			_descricao.text += " • cenário provisório disponível."
		if _regiao_concluida(id): _descricao.text += " Missão concluída. Rejogar inicia uma nova tentativa."
		_entrar.text = ("Rejogar" if _regiao_concluida(id) else "Entrar") if liberado and id in CENARIOS_PROTOTIPO else ("Bloqueada" if not liberado else "Em preparação")
		_entrar.disabled = not liberado or not id in CENARIOS_PROTOTIPO
		if id=="vila" and liberado:
			_entrar.text="Visitar cidade"
			_descricao.text="Cidade • encontro online e serviços."
		_campo_regional.focar(POSICOES[id])
	for no in _nos:
		if tela == "regioes":
			_nos[no].selecionado = no == selecionado
			_nos[no].queue_redraw()

func entrar_selecionado() -> Error:
	if _entrar.disabled:
		return ERR_UNAVAILABLE
	if tela == "mundo":
		_abrir_dominio(selecionado)
		return OK
	if not selecionado in CENARIOS_PROTOTIPO or not controlador.progresso.acesso_liberado(selecionado):
		return ERR_UNAUTHORIZED
	if selecionado=="vila":
		jogar_solo()
		return OK
	if is_instance_valid(dialogo_salas): return ERR_BUSY
	dialogo_salas = preload("res://codigo/campanha/dialogo_salas.gd").new()
	dialogo_salas.regiao = selecionado
	dialogo_salas.nome_regiao = _catalogo.destinos[selecionado].nome
	dialogo_salas.solo.connect(jogar_solo)
	add_child(dialogo_salas)
	return OK

func _clicar_estagio(id: String) -> void:
	selecionar(id)
	entrar_selecionado()

func jogar_solo() -> void:
	get_tree().set_meta("campanha_nova_instancia",selecionado!="vila")
	get_tree().set_meta("campanha_destino",selecionado)
	get_tree().change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")

func _posicionar() -> void:
	if _conteudo == null or size.x <= 0: return
	_ajustar_mar()
	var largura := minf(420,size.x-20)
	_rodape.position = Vector2((size.x-largura)/2,size.y-70)
	_rodape.size = Vector2(largura,60)
	if tela == "mundo":
		for id in _nos:
			var celula := retangulo_celula(id)
			_nos[id].size = celula.size
			_nos[id].global_position = celula.position
	else:
		_campo_regional.ajustar()
		_area_mapa = Rect2(Vector2.ZERO,_campo_regional.camada.size)
		for id in _nos:
			_nos[id].size = Vector2(28,28)
			_nos[id].position = POSICOES[id]*_area_mapa.size-Vector2(14,14)
	_conteudo.queue_redraw()

func _desenhar_ligacao() -> void:
	# A expansão do mundo aparece como novas miniaturas, sem linha entre cartões.
	pass

func _ajustar_mar() -> void:
	if _mundo == null or _tabuleiro.texture == null: return
	var imagem := Vector2(_tabuleiro.texture.get_size())
	var escala := minf(size.x/imagem.x,size.y/imagem.y)
	var exibida := imagem*escala
	_mundo.material.set_shader_parameter("resolucao",size)
	_mundo.material.set_shader_parameter("origem_ilha",(size-exibida)/2)
	_mundo.material.set_shader_parameter("tamanho_ilha",exibida)

func retangulo_celula(id: String) -> Rect2:
	if not CELULAS_DOMINIOS.has(id): return Rect2()
	var imagem := Vector2(_tabuleiro.texture.get_size())
	var escala := minf(_tabuleiro.size.x/imagem.x,_tabuleiro.size.y/imagem.y)
	var origem := _tabuleiro.global_position+(_tabuleiro.size-imagem*escala)/2
	var celula: Rect2 = CELULAS_DOMINIOS[id]
	return Rect2(origem+celula.position*escala,celula.size*escala)

func _unhandled_input(evento: InputEvent) -> void:
	if is_instance_valid(dialogo_salas) or _em_transicao or not evento.is_pressed() or evento.is_echo(): return
	if tela == "regioes":
		var direcao := Vector2.ZERO
		if evento.is_action_pressed("ui_left"): direcao = Vector2.LEFT
		elif evento.is_action_pressed("ui_right"): direcao = Vector2.RIGHT
		elif evento.is_action_pressed("ui_up"): direcao = Vector2.UP
		elif evento.is_action_pressed("ui_down"): direcao = Vector2.DOWN
		elif evento.is_action_pressed("ui_accept"):
			entrar_selecionado()
			accept_event()
			return
		if direcao != Vector2.ZERO:
			_selecionar_vizinho(direcao)
			accept_event()
		return
	if evento.is_action_pressed("ui_left") or evento.is_action_pressed("ui_up"):
		selecionar("andar_01")
		accept_event()
	elif evento.is_action_pressed("ui_right") or evento.is_action_pressed("ui_down"):
		selecionar("andar_01")
		accept_event()
	elif evento.is_action_pressed("ui_accept"):
		entrar_selecionado()
		accept_event()

func _selecionar_vizinho(direcao: Vector2) -> void:
	var melhor := ""
	var menor := INF
	for id in POSICOES:
		if id == selecionado: continue
		var delta: Vector2 = (POSICOES[id]-POSICOES[selecionado])*_campo_regional.camada.size
		var avanco := delta.dot(direcao)
		if avanco <= 1: continue
		var lateral := absf(delta.cross(direcao))
		var custo := delta.length()+lateral*1.5
		if custo < menor:
			menor = custo
			melhor = id
	if not melhor.is_empty(): selecionar(melhor)
