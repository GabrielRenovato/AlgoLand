extends Control

## Minimapa do andar da fenda, no estilo do automapa do Diablo: desenha a planta do andar (trilhas e áreas, de
## codigo/fendas/plantas/andar_NN.json) com neblina de exploração, então só aparece o que os jogadores já visitaram.
## PC: pequeno no canto. Celular: recolhido, abre pelo botão MAPA; "MAPA" (M, segurar R3 no controle ou o botão do toque) alterna a versão grande no centro.
## Marca os jogadores, o portal de entrada e o guardião (depois que a área dele foi vista). A memória do que foi explorado
## vale pela sessão (voltar ao mesmo andar mantém o mapa) e recomeça quando uma partida nova começa no andar 1.
const Catalogo := preload("res://codigo/fendas/catalogo_andares.gd")
const EstiloInterface := preload("res://codigo/ui/estilo_interface.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
const CELULA := 16.0
## Pixels de textura por célula: o desenho tem borda de meia célula
const SUB := 2
## Quanto do mundo cada jogador revela em volta de si (px)
const RAIO_VISAO := 176.0
const COR_TRILHA := Color("b99f6e")
const COR_AREA := Color("d2bb86")
const COR_BORDA := Color("3a2c1f")
const COR_PORTAL := Color("5ec8ff")
const COR_GUARDIAO := Color("ff5a4a")
const COR_JOGADOR := [Color("7dff7d"), Color("ffd24a")]
const LARGURA_PEQUENO := 108.0
static var _memoria: Dictionary = {}

var gerente: Node
var andar_indice := 1
var _planta: Dictionary
var _origem := Vector2.ZERO
var _tamanho_mundo := Vector2.ONE
var _gw := 1
var _gh := 1
var _base := PackedByteArray()
var _visto := PackedByteArray()
var _imagem: Image
var _textura: ImageTexture
var _painel: PanelContainer
var _titulo: Label
var _dica: Label
var _legenda: HBoxContainer
var _mapa: TextureRect
var _marcas: Control
var _grande := false
var _espera := 0.0
var _sujo := true

func _ready() -> void:
	name = "MinimapaAndar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Por cima do resto do HUD (a missão principal, os controles) quando o mapa grande está aberto
	z_index = 100
	add_to_group("minimapa_p2" if EventosJogo.eh_do_p2(self) else "minimapa_p1")
	if gerente == null:
		queue_free()
		return
	var raiz := gerente.get_parent().get_parent()
	andar_indice = int(raiz.get_meta("planta_andar", Catalogo.indice(int(gerente.onda_atual))))
	_planta = Catalogo.PLANTAS[clampi(andar_indice - 1, 0, Catalogo.PLANTAS.size() - 1)].data
	var limites: Array = _planta["limites"]
	_origem = Vector2(limites[0], limites[1])
	_tamanho_mundo = Vector2(limites[2], limites[3])
	_gw = ceili(_tamanho_mundo.x / CELULA)
	_gh = ceili(_tamanho_mundo.y / CELULA)
	_montar_base()
	if andar_indice == 1 and int(gerente.onda_atual) <= 1:
		_memoria.clear()
	_visto = _memoria.get(andar_indice, PackedByteArray())
	if _visto.size() != _gw * _gh:
		_visto = PackedByteArray()
		_visto.resize(_gw * _gh)
	_memoria[andar_indice] = _visto
	_imagem = Image.create(_gw * SUB, _gh * SUB, false, Image.FORMAT_RGBA8)
	_textura = ImageTexture.create_from_image(_imagem)
	_montar_interface()
	_revelar()
	_redesenhar()
	if gerente.has_signal("progresso_andar_alterado"):
		gerente.progresso_andar_alterado.connect(func(): _marcas.queue_redraw())

# --- Planta ----------------------------------------------------------------------------------------------

## Marca na grade de células o que é caminho (1), área de combate (2) e portal (3), pela planta do andar
func _montar_base() -> void:
	_base = PackedByteArray()
	_base.resize(_gw * _gh)
	for trilha: Dictionary in _planta.get("trilhas", []):
		var pontos: Array = trilha["pontos"]
		var raio := float(trilha.get("raio", 80.0)) * 0.55
		for i in pontos.size() - 1:
			_pintar_segmento(Vector2(pontos[i][0], pontos[i][1]), Vector2(pontos[i + 1][0], pontos[i + 1][1]), raio, 1)
	for setor: Dictionary in _planta.get("setores", []):
		var centro := Vector2(setor["centro"][0], setor["centro"][1])
		var raios := Vector2(setor["raios"][0], setor["raios"][1]) * 0.9
		_pintar_elipse(centro, raios, 2)
	var entrada: Array = _planta["entrada"]
	_pintar_elipse(Vector2(entrada[0], entrada[1]), Vector2(34, 30), 3)

func _celula_de(ponto: Vector2) -> Vector2i:
	return Vector2i(floori((ponto.x - _origem.x) / CELULA), floori((ponto.y - _origem.y) / CELULA))

func _pintar_segmento(a: Vector2, b: Vector2, raio: float, valor: int) -> void:
	var minimo := _celula_de(Vector2(minf(a.x, b.x) - raio, minf(a.y, b.y) - raio))
	var maximo := _celula_de(Vector2(maxf(a.x, b.x) + raio, maxf(a.y, b.y) + raio))
	for cy in range(maxi(0, minimo.y), mini(_gh, maximo.y + 1)):
		for cx in range(maxi(0, minimo.x), mini(_gw, maximo.x + 1)):
			var centro := _origem + Vector2(cx + 0.5, cy + 0.5) * CELULA
			var ponto := Geometry2D.get_closest_point_to_segment(centro, a, b)
			if centro.distance_to(ponto) <= raio and int(_base[cy * _gw + cx]) < valor:
				_base[cy * _gw + cx] = valor

func _pintar_elipse(centro: Vector2, raios: Vector2, valor: int) -> void:
	var minimo := _celula_de(centro - raios)
	var maximo := _celula_de(centro + raios)
	for cy in range(maxi(0, minimo.y), mini(_gh, maximo.y + 1)):
		for cx in range(maxi(0, minimo.x), mini(_gw, maximo.x + 1)):
			var ponto := _origem + Vector2(cx + 0.5, cy + 0.5) * CELULA
			var d := (ponto - centro) / raios
			if d.length_squared() <= 1.0 and int(_base[cy * _gw + cx]) < valor:
				_base[cy * _gw + cx] = valor

# --- Neblina -----------------------------------------------------------------------------------------------

func _jogadores() -> Array[Node2D]:
	var lista: Array[Node2D] = []
	for no in get_tree().get_nodes_in_group("jogadores"):
		if no is Node2D and no.get_world_2d() == get_world_2d() and not bool(no.get("estaMorto")):
			lista.append(no)
	return lista

func _revelar() -> void:
	var raio_celulas := ceili(RAIO_VISAO / CELULA)
	for jogador in _jogadores():
		var centro := _celula_de(gerente.get_parent().get_parent().to_local(jogador.global_position))
		for cy in range(maxi(0, centro.y - raio_celulas), mini(_gh, centro.y + raio_celulas + 1)):
			for cx in range(maxi(0, centro.x - raio_celulas), mini(_gw, centro.x + raio_celulas + 1)):
				if Vector2(cx - centro.x, cy - centro.y).length() <= raio_celulas and _visto[cy * _gw + cx] == 0:
					_visto[cy * _gw + cx] = 1
					_sujo = true

func _redesenhar() -> void:
	_imagem.fill(Color(0, 0, 0, 0))
	for cy in _gh:
		for cx in _gw:
			var i := cy * _gw + cx
			if _visto[i] == 0 or _base[i] == 0:
				continue
			var cor: Color = COR_AREA if _base[i] >= 2 else COR_TRILHA
			for sy in SUB:
				for sx in SUB:
					_imagem.set_pixel(cx * SUB + sx, cy * SUB + sy, cor)
	# Contorno escuro onde o chão encontra o que não é chão (ou o que ainda não foi visto): parece a parede do automapa
	for cy in _gh:
		for cx in _gw:
			var i := cy * _gw + cx
			if _visto[i] == 0 or _base[i] == 0:
				continue
			for lado in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var vx: int = cx + lado.x
				var vy: int = cy + lado.y
				var aberto: bool = vx < 0 or vy < 0 or vx >= _gw or vy >= _gh or _base[vy * _gw + vx] == 0 or _visto[vy * _gw + vx] == 0
				if not aberto:
					continue
				for k in SUB:
					var px := cx * SUB + k
					var py := cy * SUB + k
					if lado.x != 0:
						px = cx * SUB + (SUB - 1 if lado.x > 0 else 0)
					else:
						py = cy * SUB + (SUB - 1 if lado.y > 0 else 0)
					_imagem.set_pixel(px, py, COR_BORDA)
	_textura.update(_imagem)
	_sujo = false

# --- Interface ----------------------------------------------------------------------------------------------

func _montar_interface() -> void:
	_painel = PanelContainer.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_theme_stylebox_override("panel", EstiloInterface.painel(false, 10.0))
	_painel.gui_input.connect(_ao_painel_clicado)
	add_child(_painel)
	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_theme_constant_override("separation", 2)
	_painel.add_child(coluna)
	_titulo = Label.new()
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titulo.add_theme_font_override("font", FONTE)
	_titulo.add_theme_font_size_override("font_size", 8)
	_titulo.add_theme_color_override("font_color", Color("f6d879"))
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.text = "ANDAR %d" % andar_indice
	_titulo.visible = false
	coluna.add_child(_titulo)
	_mapa = TextureRect.new()
	_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mapa.texture = _textura
	_mapa.stretch_mode = TextureRect.STRETCH_SCALE
	_mapa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mapa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mapa.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mapa.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coluna.add_child(_mapa)
	_legenda = HBoxContainer.new()
	_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legenda.add_theme_constant_override("separation", 6)
	_legenda.visible = false
	coluna.add_child(_legenda)
	for item in [["VOCE", COR_JOGADOR[0]], ["PORTAL", COR_PORTAL], ["GUARDIAO", COR_GUARDIAO]]:
		var marca := ColorRect.new()
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marca.custom_minimum_size = Vector2(6, 6)
		marca.color = item[1]
		marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_legenda.add_child(marca)
		var texto := Label.new()
		texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texto.add_theme_font_override("font", FONTE)
		texto.add_theme_font_size_override("font_size", 8)
		texto.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		texto.text = item[0]
		_legenda.add_child(texto)
	_dica = Label.new()
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica.add_theme_font_override("font", FONTE)
	_dica.add_theme_font_size_override("font_size", 8)
	_dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_dica.text = "TOQUE PARA FECHAR" if Controle.usando_toque else "MAPA FECHA"
	_dica.size_flags_horizontal = Control.SIZE_SHRINK_END
	_dica.visible = false
	coluna.add_child(_dica)
	_marcas = MarcasMapa.new()
	_marcas.mapa = self
	_marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mapa.add_child(_marcas)
	_marcas.set_anchors_preset(Control.PRESET_FULL_RECT)

func alternar() -> void:
	_grande = not _grande
	_titulo.text = "ANDAR %d  -  %s" % [andar_indice, String(_planta.get("nome", "")).to_upper()]
	_titulo.visible = _grande
	_legenda.visible = _grande
	_dica.visible = _grande
	# Grande: tocar/clicar no mapa fecha; pequeno: não intercepta nada
	_painel.mouse_filter = Control.MOUSE_FILTER_STOP if _grande else Control.MOUSE_FILTER_IGNORE
	_ajustar()

func _ao_painel_clicado(evento: InputEvent) -> void:
	if _grande and ((evento is InputEventMouseButton and evento.pressed) or (evento is InputEventScreenTouch and evento.pressed)):
		alternar()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(evento: InputEvent) -> void:
	# Tab, como no Diablo; "MAPA" (M / R3 segurado / botão do toque) faz o mesmo pela Interface
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_TAB and not EventosJogo.eh_do_p2(self):
		alternar()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	visible = not Introducao.ativa() and is_instance_valid(gerente)
	_ajustar()
	_espera -= delta
	if _espera <= 0.0:
		_espera = 0.25
		_revelar()
		if _sujo:
			_redesenhar()
	_marcas.queue_redraw()

## Celular sem consulta aberta: apenas o botão MAPA do HUD, sem painel sobre o mundo.
func recolhido_no_toque() -> bool:
	return Controle.usando_toque and not _grande

## A consulta respeita largura e altura disponíveis, inclusive em paisagem e coop.
func _ajustar() -> void:
	_painel.visible = not recolhido_no_toque()
	if not _painel.visible:
		return
	var tela := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(self)
	var proporcao := _tamanho_mundo.y / _tamanho_mundo.x
	var largura := LARGURA_PEQUENO
	var altura_mapa := largura * proporcao
	_titulo.custom_minimum_size.x = 0
	_dica.text = "TOQUE PARA FECHAR" if Controle.usando_toque else "MAPA FECHA"
	if _grande:
		var largura_painel := minf(tela.x - 32, 350 if Controle.usando_toque else 440)
		# Reserva moldura, título com quebra, legenda e instrução de fechamento.
		altura_mapa = minf((largura_painel - 20) * proporcao, maxf(32, tela.y - 112))
		largura = altura_mapa / proporcao
		_titulo.custom_minimum_size.x = largura_painel - 20
	_mapa.custom_minimum_size = Vector2(largura, altura_mapa).floor()
	_painel.reset_size()
	if _grande:
		_painel.position = ((tela - _painel.size) / 2.0).round()
		_painel.modulate.a = 1.0
	else:
		var hud := get_parent()
		var base := 0.0
		for no in [hud.get("relogio"), hud.get("painel_onda"), hud.get_node_or_null("CantoDireito")]:
			if is_instance_valid(no) and no is Control:
				base = maxf(base, (no as Control).get_global_rect().end.y)
		_painel.position = Vector2(tela.x - _painel.size.x - 6.0, maxf(base, 40.0) + 6.0).round()
		_painel.modulate.a = 0.86

## Posição de um ponto do mundo (coordenadas da cena) dentro do TextureRect
func para_mapa(ponto: Vector2) -> Vector2:
	var relativo := (ponto - _origem) / _tamanho_mundo
	return relativo * _mapa.size

func visto_em(ponto: Vector2) -> bool:
	var c := _celula_de(ponto)
	return c.x >= 0 and c.y >= 0 and c.x < _gw and c.y < _gh and _visto[c.y * _gw + c.x] != 0

class MarcasMapa extends Control:
	var mapa: Control

	func _draw() -> void:
		if mapa == null or not is_instance_valid(mapa.gerente):
			return
		var raiz: Node = mapa.gerente.get_parent().get_parent()
		var entrada: Array = mapa._planta["entrada"]
		_losango(mapa.para_mapa(Vector2(entrada[0], entrada[1])), COR_PORTAL, 3.0)
		var guardiao: Array = mapa._planta["guardiao"]
		var ponto_g := Vector2(guardiao[0], guardiao[1])
		if mapa.visto_em(ponto_g):
			_losango(mapa.para_mapa(ponto_g), COR_GUARDIAO, 3.5)
		var i := 0
		for jogador in mapa._jogadores():
			var p: Vector2 = mapa.para_mapa(raiz.to_local(jogador.global_position))
			draw_circle(p, 3.0, Color.WHITE)
			draw_circle(p, 2.0, COR_JOGADOR[mini(i, 1)])
			i += 1

	func _losango(centro: Vector2, cor: Color, raio: float) -> void:
		var pontos := PackedVector2Array([centro + Vector2(0, -raio), centro + Vector2(raio, 0), centro + Vector2(0, raio), centro + Vector2(-raio, 0)])
		draw_colored_polygon(pontos, cor)
		draw_polyline(PackedVector2Array([pontos[0], pontos[1], pontos[2], pontos[3], pontos[0]]), Color(0, 0, 0, 0.8), 1.0)
