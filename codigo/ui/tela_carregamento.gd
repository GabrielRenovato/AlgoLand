extends Control

const Estilo := preload("res://codigo/ui/estilo_interface.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
var painel: PanelContainer
var _marca: Label
var _coluna: VBoxContainer
var _papel: PanelContainer
var _viagem: VBoxContainer
var _destino: Label
var _estado: Label
var _percentual: Label
var _barra: ProgressBar
var _dica: Label
var _via: Control
var _heroi: Node2D
var _camadas: Array[Sprite2D] = []
var _tempo := 0.0
var _progresso := 0.0
var _origem := ""
var _rota: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = preload("res://recursos/ui/tema_sidebar.tres")
	texture_filter = TEXTURE_FILTER_NEAREST
	mouse_filter = MOUSE_FILTER_STOP
	add_child(preload("res://codigo/ui/fundo_interface.gd").new())
	var sombra := ColorRect.new()
	sombra.color = Color(0.04,0.06,0.05,0.65)
	sombra.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(sombra)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(preload("res://codigo/ui/brilhos_interface.gd").new())
	painel = PanelContainer.new()
	painel.add_theme_stylebox_override("panel",Estilo.painel(false,12))
	add_child(painel)
	var coluna := VBoxContainer.new()
	_coluna = coluna
	coluna.add_theme_constant_override("separation",8)
	painel.add_child(coluna)
	var marca := _rotulo(coluna,"ALGOLAND",24,Color("efd08b"))
	_marca = marca
	marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rota = _rotulo(coluna,"",8,Color("d4bb92"))
	_rota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var papel := PanelContainer.new()
	_papel = papel
	papel.add_theme_stylebox_override("panel",Estilo.painel(true,10))
	coluna.add_child(papel)
	var viagem := VBoxContainer.new()
	_viagem = viagem
	viagem.add_theme_constant_override("separation",4)
	papel.add_child(viagem)
	_destino = _rotulo(viagem,"",11,Color("493020"))
	_destino.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_via = Control.new()
	_via.custom_minimum_size.y = 48
	viagem.add_child(_via)
	_via.draw.connect(func():
		_via.draw_line(Vector2(8,_via.size.y-2),Vector2(_via.size.x-8,_via.size.y-2),Color("bfa16f"),2)
		_via.draw_dashed_line(Vector2(8,_via.size.y-2),Vector2(_via.size.x-8,_via.size.y-2),Color("816644"),1,3))
	_heroi = Node2D.new()
	_via.add_child(_heroi)
	for textura in [Aparencia.corpo("andar",2,0),Aparencia.roupa(2,"andar"),Aparencia.cabelo(0,"andar")]:
		var sprite := Sprite2D.new()
		sprite.texture = textura
		sprite.hframes = 8
		sprite.vframes = 8
		sprite.scale = Vector2.ONE*(512.0/textura.get_width())
		_heroi.add_child(sprite)
		_camadas.append(sprite)
	_camadas[0].material = Aparencia.material_corpo()
	_camadas[2].modulate = Color("ba8047")
	var andamento := HBoxContainer.new()
	viagem.add_child(andamento)
	_estado = _rotulo(andamento,"CARREGANDO",8,Color("805532"))
	_percentual = _rotulo(andamento,"0%",8,Color("493020"))
	_percentual.size_flags_horizontal = SIZE_SHRINK_END
	_percentual.custom_minimum_size.x = 28
	_percentual.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_barra = ProgressBar.new()
	_barra.show_percentage = false
	_barra.custom_minimum_size.y = 10
	_barra.add_theme_stylebox_override("background",Estilo.recorte(Estilo.CAMPO,4,0))
	var preenchimento := Estilo.recorte(preload("res://assets/ui/bosque/barra_neutra.png"),3,0)
	preenchimento.modulate_color = Color("b4c073")
	_barra.add_theme_stylebox_override("fill",preenchimento)
	viagem.add_child(_barra)
	_dica = _rotulo(coluna,"",9,Color("d8c8a9"))
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resized.connect(_ajustar)
	painel.minimum_size_changed.connect(_agendar_ajuste)
	_ajustar()
	hide()

func _rotulo(pai: Node, texto: String, tamanho: int, cor: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",tamanho)
	label.add_theme_color_override("font_color",cor)
	pai.add_child(label)
	return label

static func nome_do_destino(caminho: String) -> String:
	var nomes := {"cidade":"VILA DAS FLORES","cenario":"ARENA","andar_fenda":"FENDA DO BOSQUE","fazenda":"SUA FAZENDA","floresta":"FLORESTA DO CAMINHO","casa":"LAR, DOCE LAR","palafita":"CAIS DO NILO","criacao_personagem":"SEU PERSONAGEM","inicio_do_jogo":"INICIO","enfermaria":"ENFERMARIA","forja":"FORJA DO IVO"}
	var id := caminho.get_file().get_basename()
	return nomes.get(id,id.replace("_"," ").to_upper())

func iniciar(caminho: String, origem := "") -> void:
	_tempo = 0
	_origem = origem
	_destino.text = nome_do_destino(caminho)
	_rota.text = "SUA JORNADA CONTINUA" if origem.is_empty() else origem+"  >  "+_destino.text
	_dica.text = {"FENDA DO BOSQUE":"Derrote grupos para completar a barra. Elites valem mais progresso.","ARENA":"Encontre receitas na arena e use na mochila para aprender.","CAIS DO NILO":"Pedras de refinamento melhoram sua vara na oficina do Nilo.","SUA FAZENDA":"Materiais da fazenda tambem entram nas receitas do ferreiro."}.get(_destino.text,"Receitas aprendidas ficam disponiveis na bigorna do Ivo.")
	atualizar(0)
	show()
	_ajustar.call_deferred()

func atualizar(progresso: float, preparando := false) -> void:
	_progresso = clampf(progresso,0,1)
	_barra.value = _progresso*100
	_percentual.text = "%d%%" % roundi(_progresso*100)
	_estado.text = "PREPARANDO O DESTINO" if preparando else "CARREGANDO"

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_tempo += delta
	for sprite in _camadas: sprite.frame = 16+int(_tempo/0.12)%8
	_heroi.position = Vector2(lerpf(24,maxf(24,_via.size.x-24),_progresso),_via.size.y-16)

func _ajustar() -> void:
	if painel == null: return
	var compacto := size.y < 270 or size.x < 400
	_marca.add_theme_font_size_override("font_size",20 if compacto else 24)
	_coluna.add_theme_constant_override("separation",4 if compacto else 8)
	_viagem.add_theme_constant_override("separation",3 if compacto else 4)
	_papel.add_theme_stylebox_override("panel",Estilo.painel(true,8 if compacto else 10))
	painel.add_theme_stylebox_override("panel",Estilo.painel(false,10 if compacto else 12))
	_via.custom_minimum_size.y = 40 if compacto else 48
	var largura := minf(420,size.x-24)
	var altura := painel.get_combined_minimum_size().y
	painel.size = Vector2(largura,altura)
	painel.position = ((size-painel.size)/2).round()

var _ajuste_pendente := false
func _agendar_ajuste() -> void:
	if _ajuste_pendente: return
	_ajuste_pendente = true
	_apos_layout.call_deferred()
func _apos_layout() -> void:
	_ajuste_pendente = false
	_ajustar()
