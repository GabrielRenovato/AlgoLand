extends "res://codigo/logica/interagivel.gd"

const Criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
var acao := ""
var dica := ""
var _descricao: Label

func _ready() -> void:
	nome_tela = "cuidado_direto"
	so_entre_ondas = false
	super._ready()
	_descricao = Label.new()
	_descricao.add_theme_font_override("font",FONTE_AVISO)
	_descricao.add_theme_font_size_override("font_size",8)
	_descricao.add_theme_color_override("font_color",Color("fff3d6"))
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("241b20")
	fundo.set_content_margin_all(4)
	_descricao.add_theme_stylebox_override("normal",fundo)
	_descricao.z_as_relative = false
	_descricao.z_index = 901
	add_child(_descricao)

func _process(delta: float) -> void:
	super._process(delta)
	_descricao.visible = _aviso.visible
	if not _descricao.visible: return
	match acao:
		"preparar_feno": _descricao.text = "FENO: 2 FIBRAS = 14 PORCOES"
		"recolher": _descricao.text = "NINHOS: %d OVOS" % Criacao.total_ovos(Fazenda)
		"incubar": _descricao.text = "CHOCANDO: %d DIAS" % maxi(0,Fazenda.galinheiro.incubacao-Calendario.dia) if Fazenda.galinheiro.incubacao >= 0 else "COLOCAR OVO PARA CHOCAR"
		"portinha": _descricao.text = "FECHAR PORTINHA" if Fazenda.galinheiro.portinha_aberta else "AGUARDANDO AS AVES" if Fazenda.bando.portinha_aberta() else "ABRIR PORTINHA"
	_descricao.reset_size()
	_descricao.position = Vector2(-_descricao.size.x/2,-43-_descricao.size.y)

func abrir_tela() -> void: executar(Cooperativo._jogador1())
func abrir_tela_p2() -> void: executar(Cooperativo.jogador2())

func executar(quem: Node) -> void:
	if quem == null or not quem.movimento_habilitado: return
	var erro := Criacao.executar(Fazenda,quem,acao)
	var texto := erro if erro != "" else dica
	get_tree().call_group(quem.grupo_hud(),"avisar_barra",texto)
	Sons.tocar("erro" if erro != "" else "menu_confirmar",0)

static func tentar_usar_feno(quem: Node2D) -> bool:
	if quem.inventario.vara_na_mao: return false
	var tipo: String = quem.get_meta("item_uso","")
	if tipo != "produto:feno" and (not quem.modo_fazenda or Fazenda.ferramenta_de(Fazenda.lado_de(quem)) != "produto:feno"): return false
	var interiores := quem.get_tree().get_nodes_in_group("interiores_galinheiro")
	for interior in interiores:
		if interior.get_world_2d() == quem.get_world_2d():
			interior.jogar_feno(quem)
			return true
	quem.get_tree().call_group(quem.grupo_hud(),"avisar_barra","JOGUE O FENO NO COMEDOURO DO GALINHEIRO")
	return true
