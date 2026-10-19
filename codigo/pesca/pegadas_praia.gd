extends Node2D

## Impressões temporárias na areia, na escala dos pés do jogador e da trilha de mar.gdshader.
## Sola de 2×5 pixels, pivô central nos pés, sem colisão; desenho sob sombras e objetos.
## As quatro paletas acompanham estacao_visual(), inclusive a prévia do F3.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const ESPACO_PASSOS := 12.0
const DURACAO := 8.0
const DESVANECER := 3.0
const LIMITE := 160
const SOLA := [Vector2(-1,-2),Vector2(0,-2),Vector2(-1,-1),Vector2(0,-1),Vector2(0,1),Vector2(0,2)]
const TONS := [Color("987348"),Color("aa7c45"),Color("8e704e"),Color("888174")]
const BORDAS := [Color("ead2a0"),Color("f5da9c"),Color("dec89f"),Color("dcd8c8")]
var marcas: Array[Dictionary] = []
var _passos := {}
var _praia: Node2D
var _costa_base := 310.0
var _curvas := Vector4.ZERO
var _pisos: Array[TileMapLayer] = []

func configurar(praia: Node2D, layout: Dictionary) -> void:
	_praia = praia
	_costa_base = float(layout["costa_base"])
	var curvas: Array = layout["curvas_costa"]
	_curvas = Vector4(curvas[0],curvas[1],curvas[2],curvas[3])
	for caminho in ["Terrains/Pier","Terrains/CalcadaOrla","Terrains/VegetacaoOrla"]:
		_pisos.append(praia.get_node(caminho))

func _ready() -> void:
	name = "PegadasPraia"
	z_as_relative = false
	z_index = -999
	texture_filter = TEXTURE_FILTER_NEAREST
	process_physics_priority = 10

func areia_no_ponto(ponto: Vector2) -> bool:
	if not _praia.limites.has_point(ponto): return false
	# A espuma avança até cinco pixels para dentro da costa; a sola fica fora dela.
	var costa := _costa_base + _curvas.x*sin(ponto.x*_curvas.y) + _curvas.z*sin(ponto.x*_curvas.w)
	if ponto.y >= costa - 8: return false
	var global := _praia.to_global(ponto)
	for piso in _pisos:
		if piso.get_cell_source_id(piso.local_to_map(piso.to_local(global))) >= 0:
			return false
	return true

func _physics_process(delta: float) -> void:
	for i in range(marcas.size()-1,-1,-1):
		marcas[i]["idade"] += delta
		if marcas[i]["idade"] >= DURACAO:
			marcas.remove_at(i)
	var presentes := {}
	for jogador in get_tree().get_nodes_in_group("jogadores"):
		if Cooperativo.cena_de(jogador) != _praia: continue
		var chave: int = jogador.get_instance_id()
		presentes[chave] = true
		var ponto := _praia.to_local(jogador.global_position + Vector2(0,Profundidade.PES_JOGADOR))
		if not _passos.has(chave):
			_passos[chave] = {"anterior":ponto,"distancia":0.0,"lado":1.0}
		var estado: Dictionary = _passos[chave]
		var anterior: Vector2 = estado["anterior"]
		estado["anterior"] = ponto
		var distancia := anterior.distance_to(ponto)
		if distancia < 0.01 or distancia > 48 or not jogador.movimento_habilitado \
				or jogador.esta_sentado or jogador.caido or jogador.esta_em_dash \
				or jogador.esta_em_acao_fazenda or jogador.temporizador_knockback > 0:
			estado["distancia"] = 0.0
			continue
		var direcao := (ponto-anterior)/distancia
		var avancar: float = ESPACO_PASSOS - estado["distancia"]
		while avancar <= distancia:
			var centro: Vector2 = anterior + direcao*avancar + direcao.orthogonal()*2*estado["lado"]
			_registrar(centro,direcao)
			estado["lado"] *= -1.0
			avancar += ESPACO_PASSOS
		estado["distancia"] = fmod(float(estado["distancia"])+distancia,ESPACO_PASSOS)
	for chave in _passos.keys():
		if not presentes.has(chave): _passos.erase(chave)
	queue_redraw()

func _registrar(centro: Vector2, direcao: Vector2) -> void:
	var pixels := PackedVector2Array()
	var angulo := direcao.angle() + PI/2
	for pixel in SOLA:
		var ponto: Vector2 = (centro+pixel.rotated(angulo)).round()
		if not areia_no_ponto(ponto) or not areia_no_ponto(ponto+Vector2.DOWN): return
		pixels.append(ponto)
	marcas.append({"pixels":pixels,"idade":0.0})
	if marcas.size() > LIMITE: marcas.pop_front()

func _draw() -> void:
	if _praia == null: return
	var estacao: int = _praia.estacao_visual()
	for marca in marcas:
		var opacidade := minf(1.0,(DURACAO-float(marca["idade"]))/DESVANECER)
		var borda: Color = BORDAS[estacao]
		borda.a = opacidade*0.65
		var sombra: Color = TONS[estacao]
		sombra.a = opacidade*0.70
		for ponto in marca["pixels"]:
			draw_rect(Rect2(ponto+Vector2.DOWN,Vector2.ONE),borda)
		for ponto in marca["pixels"]:
			draw_rect(Rect2(ponto,Vector2.ONE),sombra)
