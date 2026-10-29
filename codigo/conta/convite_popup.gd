extends CanvasLayer
## Aviso de convite de sala de um amigo: ENTRAR leva direto para a sala (coop). Some sozinho em 30 s.
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
var convite: Dictionary = {}
var _restante := 30.0

func _ready() -> void:
	layer = 135
	process_mode = Node.PROCESS_MODE_ALWAYS
	var centro := Control.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var painel := PanelContainer.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	painel.offset_bottom = -64
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.17, 0.11, 0.10, 0.97)
	estilo.border_color = Color("ffd966")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(8)
	painel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	painel.add_child(coluna)
	var tipo := "COOP" if str(convite.get("tipo", "coop")) == "coop" else "DUELO"
	coluna.add_child(_texto("%s CONVIDOU VOCE PARA O %s" % [str(convite.get("de", "UM AMIGO")).to_upper(), tipo], 9, Color("f7e5bd")))
	if str(convite.get("tipo", "")) == "coop":
		coluna.add_child(_texto("ANDAR %d" % int(convite.get("andar", 1)), 8, Color(0.78, 0.68, 0.55)))
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	coluna.add_child(linha)
	linha.add_child(_botao("ENTRAR", _entrar, Color(0.27, 0.50, 0.24)))
	linha.add_child(_botao("IGNORAR", _ignorar, Color(0.25, 0.17, 0.14)))

func _process(delta: float) -> void:
	_restante -= delta
	if _restante <= 0.0: _ignorar()

func _texto(t: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONTE)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l

func _botao(t: String, acao: Callable, cor: Color) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(80, 26)
	b.add_theme_font_override("font", FONTE)
	b.add_theme_font_size_override("font_size", 9)
	b.add_theme_color_override("font_color", Color("f7e5bd"))
	for estado in ["normal", "hover", "pressed", "focus"]:
		var c := StyleBoxFlat.new()
		c.bg_color = cor.lightened(0.12) if estado == "hover" else cor
		c.border_color = cor.lightened(0.3)
		c.set_border_width_all(1)
		c.set_corner_radius_all(3)
		c.set_content_margin_all(4)
		b.add_theme_stylebox_override(estado, c)
	b.pressed.connect(acao)
	return b

func _ignorar() -> void:
	var conta = load("res://codigo/conta/cliente_conta.gd").obter(get_tree())
	conta.amigos.descartar(int(convite.get("id", 0)))
	queue_free()

func _entrar() -> void:
	var sessao = load("res://codigo/coop_online/conexao_coop.gd").obter(get_tree())
	var jogador = load("res://codigo/duelo/conexao_duelo.gd").jogador_local(get_tree())
	if jogador == null:
		get_tree().call_group("hud", "anunciar", "CONVITE", "ENTRE NO JOGO E ABRA O CONVITE DE NOVO PELO AMIGO", 3.0)
	elif str(convite.get("tipo", "")) == "coop" and not sessao.ativo and sessao.codigo.is_empty():
		sessao.abrir_tela("")
		sessao.entrar(jogador, str(convite.get("sala", "")))
	elif str(convite.get("tipo", "")) == "duelo":
		# "numero|senha": o convite entra direto; as mensagens ficam na fila até a conexão do duelo abrir.
		var partes := str(convite.get("sala", "")).split("|")
		var duelo = load("res://codigo/duelo/conexao_duelo.gd").obter(get_tree())
		if partes.size() >= 1 and str(partes[0]).is_valid_int():
			duelo.conectar(jogador)
			duelo.entrar(int(partes[0]), str(partes[1]) if partes.size() > 1 else "")
			duelo.abrir_tela()
	var conta = load("res://codigo/conta/cliente_conta.gd").obter(get_tree())
	conta.amigos.descartar(int(convite.get("id", 0)))
	queue_free()
