extends PanelContainer

const Jornada := preload("res://codigo/cidade/jornada_limiar.gd")
const MARGEM_TEXTO := 10.0
var _titulo: Label
var _texto: Label
var _chave := ""
var _espera := 0.0
var _aviso_ate := 0
var atualizacoes := 0

func _ready() -> void:
	name = "ObjetivoPrincipal"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := preload("res://codigo/ui/estilo_interface.gd").painel(false,MARGEM_TEXTO)
	add_theme_stylebox_override("panel",estilo)
	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_theme_constant_override("separation",2)
	add_child(coluna)
	for i in 2:
		var rotulo := Label.new()
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rotulo.add_theme_font_override("font",preload("res://assets/ui/Planes_ValMore.ttf"))
		rotulo.add_theme_font_size_override("font_size",8)
		rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		coluna.add_child(rotulo)
		if i == 0: _titulo = rotulo
		else: _texto = rotulo
	_titulo.add_theme_color_override("font_color",Color("f6d879"))
	Cidade.alterado.connect(atualizar)
	Fazenda.bolsas_alteradas.connect(atualizar)
	Progresso.checkpoint_alterado.connect(atualizar)
	atualizar()

func atualizar(_valor: Variant = null) -> void:
	if _titulo == null: return
	var dados := Jornada.rastreio(Cidade,EventosJogo.dono(self))
	var chave: String = dados.id+":"+dados.fase
	if _chave != "" and chave != _chave:
		_aviso_ate = Time.get_ticks_msec()+4000
		atualizacoes += 1
	_chave = chave
	_titulo.text = "OBJETIVO ATUALIZADO" if Time.get_ticks_msec() < _aviso_ate else ("LIMIAR CONCLUIDO" if dados.id == "" else "MISSAO PRINCIPAL - LIMIAR")
	_texto.text = dados.texto
	tooltip_text = dados.titulo+"\n"+dados.texto

func _process(delta: float) -> void:
	visible = not Introducao.ativa()
	var hud := get_parent()
	var status: Control = hud.get_node("Status")
	var tela := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(self)
	var largura := minf(174,tela.x-40)
	custom_minimum_size.x = largura
	_texto.custom_minimum_size.x = largura-2*MARGEM_TEXTO
	_titulo.custom_minimum_size.x = largura-2*MARGEM_TEXTO
	reset_size()
	size.x = largura
	var topo := status.position.y+status.size.y+6
	if hud.painel_chefe.visible: topo = maxf(topo,hud.painel_chefe.position.y+hud.painel_chefe.size.y+4)
	position = Vector2(status.position.x+16,topo).round()
	_espera -= delta
	if _espera <= 0:
		_espera = 0.4
		atualizar()
