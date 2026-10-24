extends PanelContainer

const Jornada := preload("res://codigo/cidade/jornada_limiar.gd")
const MARGEM_TEXTO := 10.0
var _titulo: Label
var _texto: Label
var _chave := ""
var _espera := 0.0
var _aviso_ate := 0
var atualizacoes := 0
## Dentro de um andar da fenda a missão principal fica reduzida ao título, a não ser que a etapa atual seja da fenda
var minimizado := false

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
	_titulo.add_theme_font_size_override("font_size",7)
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
	minimizado = _em_andar() and not bool(dados.get("andares", false))
	_texto.visible = not minimizado
	_titulo.text = "OBJETIVO ATUALIZADO" if Time.get_ticks_msec() < _aviso_ate else ("LIMIAR CONCLUIDO" if dados.id == "" else "MISSAO PRINCIPAL")
	modulate.a = 0.6 if minimizado else 1.0
	_texto.text = dados.texto
	tooltip_text = dados.titulo+"\n"+dados.texto

## Está dentro de um andar da fenda (a cena do jogador desta tela tem o gerenciador de andar)
func _em_andar() -> bool:
	if not is_inside_tree() or get_viewport() == null:
		return false
	var cena := Cooperativo.cena_de(self)
	return cena != null and cena.scene_file_path.begins_with("res://cenas/fendas/andar_")

func _process(delta: float) -> void:
	visible = not Introducao.ativa() and not (Controle.usando_toque and minimizado)
	var hud := get_parent()
	var status: Control = hud.get_node("Status")
	var tela := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(self)
	# Ajusta o cartão ao conteúdo curto; objetivos longos quebram na largura máxima.
	var largura_texto := _titulo.get_theme_font("font").get_string_size(_titulo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	if not minimizado:
		largura_texto = maxf(largura_texto, _texto.get_theme_font("font").get_string_size(_texto.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var limite := minf(148.0,maxf(108.0,status.size.x))
	var esquerda := status.position.x
	# Na fazenda com toque, preservar a coluna reservada à energia vertical.
	if Controle.usando_toque and is_instance_valid(hud.barra_energia) and hud.barra_energia.visible:
		esquerda = maxf(esquerda,hud.barra_energia.position.x+hud.barra_energia.size.x+6)
		limite -= esquerda-status.position.x
	var largura := minf(clampf(largura_texto + 2 * MARGEM_TEXTO, minf(108.0,limite), limite), tela.x - esquerda - 6)
	custom_minimum_size.x = largura
	_texto.custom_minimum_size.x = largura-2*MARGEM_TEXTO
	_titulo.custom_minimum_size.x = largura-2*MARGEM_TEXTO
	reset_size()
	size.x = largura
	var topo := status.position.y+status.size.y+6
	if hud.painel_chefe.visible: topo = maxf(topo,hud.painel_chefe.position.y+hud.painel_chefe.size.y+4)
	position = Vector2(esquerda,topo).round()
	_espera -= delta
	if _espera <= 0:
		_espera = 0.4
		atualizar()
