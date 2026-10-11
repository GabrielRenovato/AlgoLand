extends Node

## Estações do ano da arena. Troca a folha de tiles (chão, lagoa, penhasco), o atlas das árvores e dos props
## sazonais, a visibilidade dos grupos "so_inverno"/"nao_inverno", o clima (partículas e, em Codigos/Design/clima.gd,
## chuva, neve, nuvens e raios em sprites) e o tom da luz.
## Fica como filho do nó raiz do terreno (cenas/terreno.tscn); o gerador (ferramentas/arena/gerar_arena.py) o cria.
##
## Índices: 0 primavera, 1 verão, 2 outono, 3 inverno. A estação avança a cada ONDAS_POR_ESTACAO ondas
## (1-5 primavera, 6-10 verão, 11-15 outono, 16-20 inverno, depois repete). Na tela de título não existe
## gerenciador de ondas: a estação fica fixa em `estacao_inicial` (inverno, por causa da neve do título).

signal estacao_mudou(indice: int)

const ONDAS_POR_ESTACAO := 5
## Texto do banner (a fonte do jogo não tem acentos)
const NOMES: Array[String] = ["PRIMAVERA", "VERAO", "OUTONO", "INVERNO"]
const Profundidade := preload("res://Codigos/Globais/profundidade.gd")
const ClimaScript := preload("res://Codigos/Design/clima.gd")

const FOLHAS: Array[Texture2D] = [
	preload("res://Tiles/Seasonal Forest/arena/spring.png"),
	preload("res://Tiles/Seasonal Forest/arena/summer.png"),
	preload("res://Tiles/Seasonal Forest/arena/autumn.png"),
	preload("res://Tiles/Seasonal Forest/arena/winter.png"),
]
const BRILHOS: Array[Texture2D] = [
	preload("res://Tiles/Seasonal Forest/seasonal water animations/spring water sparkles B.png"),
	preload("res://Tiles/Seasonal Forest/seasonal water animations/summer water sparkles B 16x16.png"),
	preload("res://Tiles/Seasonal Forest/seasonal water animations/autumn water sparkles B 16x16.png"),
	preload("res://Tiles/Seasonal Forest/seasonal water animations/winter water sparkles B 16x16.png"),
]
## Árvores evergreen: mesmo layout (80x112) nas 4 estações. `ARVORES_VARIACAO` é a segunda família de árvores
## do mapa (no inverno sem neve no topo, para quebrar a uniformidade)
const ARVORES: Array[Texture2D] = [
	preload("res://Tiles/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (spring) 80x112.png"),
	preload("res://Tiles/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (summer) 80x112.png"),
	preload("res://Tiles/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (autumn) 80x112.png"),
	preload("res://Tiles/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (winter, top snow) 80x112.png"),
]
const ARVORES_VARIACAO: Array[Texture2D] = [
	preload("res://Tiles/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (spring) 80x112.png"),
	preload("res://Tiles/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (summer) 80x112.png"),
	preload("res://Tiles/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (autumn) 80x112.png"),
	preload("res://Tiles/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (winter, no snow) 80x112.png"),
]

## Multiplicador leve aplicado por cima do ciclo dia/noite (Iluminacao.tom_estacao)
const TONS: Array[Color] = [
	Color(1.0, 0.99, 1.0),
	Color(1.0, 0.97, 0.9),
	Color(1.0, 0.91, 0.8),
	Color(0.9, 0.95, 1.0),
]

## Formas das partículas em pixel art ('X' = pixel branco, tingido pela cor da partícula)
const FORMA_PETALA: Array[String] = [".X.", "XXX", ".X."]
const FORMA_FOLHA: Array[String] = [".XXX.", "XXXXX", ".XXX."]
const FORMA_BRILHO: Array[String] = ["..X..", ".XXX.", "XXXXX", ".XXX.", "..X.."]

const DURACAO_FADE_SAIDA := 0.45
const DURACAO_FADE_ENTRADA := 0.6
## Espera depois da onda completada: o aviso "ONDA N CONCLUIDA" do HUD termina antes do fade
const ATRASO_TROCA := 1.9
## Retângulo do mundo (coordenadas do terreno) coberto pelas partículas de clima
const AREA_CLIMA_CENTRO := Vector2(332, 137)
const AREA_CLIMA_EXTENSAO := Vector2(470, 380)

## Estação usada quando não há gerenciador de ondas (tela de título)
@export_range(0, 3) var estacao_inicial: int = 3

var estacao_atual := -1

var _terreno: Node2D
var _fonte_chao: TileSetAtlasSource
var _fonte_brilho: TileSetAtlasSource
var _atlas_arvores: Array[AtlasTexture] = []
var _atlas_variacao: Array[AtlasTexture] = []
var _atlas_amostra: Array[AtlasTexture] = []
var _gerenciador: Node
var _clima: Node2D
## Chuva, neve, nuvens e raios (clima.gd); filho deste nó
var meteorologia: Node
var _petalas: CPUParticles2D
var _vagalumes: CPUParticles2D
var _folhas: CPUParticles2D
var _camada_fade: CanvasLayer
var _painel_fade: ColorRect
var _tween_fade: Tween
var _tween_tom: Tween
var _id_troca := 0

@warning_ignore("integer_division")
static func estacao_da_onda(onda: int) -> int:
	return ((maxi(onda, 1) - 1) / ONDAS_POR_ESTACAO) % NOMES.size()

func _ready() -> void:
	_terreno = get_parent() as Node2D
	var chao := _terreno.get_node_or_null("Chao") as TileMapLayer
	if chao and chao.tile_set:
		_fonte_chao = chao.tile_set.get_source(0) as TileSetAtlasSource
	var brilho := _terreno.get_node_or_null("Brilho") as TileMapLayer
	if brilho and brilho.tile_set:
		_fonte_brilho = brilho.tile_set.get_source(0) as TileSetAtlasSource
	_coletar_atlas()
	_criar_clima()
	_criar_fade()
	meteorologia = ClimaScript.new()
	meteorologia.name = "Meteorologia"
	add_child(meteorologia)
	meteorologia.clima_mudou.connect(_ao_clima_mudou)
	# Na tela de título o gerenciador não existe: estação fixa
	_gerenciador = get_node_or_null("../../enemySpawner/GerenciadorOndas")
	var inicial := estacao_inicial
	if _gerenciador:
		inicial = estacao_da_onda(_gerenciador.onda_inicial)
		_gerenciador.onda_iniciada.connect(_ao_onda_iniciada)
		_gerenciador.onda_completada.connect(_ao_onda_completada)
		_gerenciador.sinal_ondas_paradas.connect(_ao_ondas_paradas)
		if _gerenciador.has_signal("onda_inicial_definida"):
			_gerenciador.onda_inicial_definida.connect(_ao_onda_inicial_definida)
	definir_estacao(inicial, true)
	# A Iluminacao do cenario vem depois do terreno na árvore: o tom inicial entra quando ela já está no grupo
	_aplicar_tom.call_deferred(inicial, true)

## Troca para a estação `indice`. Com `imediato` não há fade (usado ao carregar e nas ferramentas de render).
func definir_estacao(indice: int, imediato := false) -> void:
	indice = clampi(indice, 0, NOMES.size() - 1)
	_id_troca += 1
	# qualquer troca com fade em andamento é cancelada (ex.: a morte zera a partida no meio do fade)
	if _tween_fade:
		_tween_fade.kill()
	if imediato or not is_inside_tree():
		_painel_fade.color.a = 0.0
		_aplicar(indice, true)
		return
	_tween_fade = create_tween()
	_tween_fade.tween_property(_painel_fade, "color:a", 1.0, DURACAO_FADE_SAIDA)
	_tween_fade.tween_callback(_aplicar.bind(indice, false))
	_tween_fade.tween_property(_painel_fade, "color:a", 0.0, DURACAO_FADE_ENTRADA)

func _aplicar(indice: int, imediato: bool) -> void:
	var anterior := estacao_atual
	estacao_atual = indice
	if _fonte_chao:
		_fonte_chao.texture = FOLHAS[indice]
	if _fonte_brilho:
		_fonte_brilho.texture = BRILHOS[indice]
	for t in _atlas_arvores:
		t.atlas = ARVORES[indice]
	for t in _atlas_variacao:
		t.atlas = ARVORES_VARIACAO[indice]
	for t in _atlas_amostra:
		t.atlas = FOLHAS[indice]
	_alternar_grupo("so_inverno", indice == 3)
	_alternar_grupo("nao_inverno", indice != 3)
	meteorologia.definir_estacao(indice, imediato)
	_atualizar_clima(indice)
	_aplicar_tom(indice, imediato)
	if anterior != indice:
		estacao_mudou.emit(indice)

# Sprites com AtlasTexture marcada pelo gerador (resource_name): "arvore", "arvore_var" e "amostra"
func _coletar_atlas() -> void:
	var vistos := {}
	var objetos := _terreno.get_node_or_null("Objetos3D")
	if objetos == null:
		return
	for no in objetos.get_children():
		var sprite := no as Sprite2D
		if sprite == null or not (sprite.texture is AtlasTexture):
			continue
		var t := sprite.texture as AtlasTexture
		if vistos.has(t):
			continue
		vistos[t] = true
		match t.resource_name:
			"arvore":
				_atlas_arvores.append(t)
			"arvore_var":
				_atlas_variacao.append(t)
			"amostra":
				_atlas_amostra.append(t)

func _alternar_grupo(grupo: String, visivel: bool) -> void:
	for no in get_tree().get_nodes_in_group(grupo):
		if _terreno.is_ancestor_of(no) and no is CanvasItem:
			no.visible = visivel

# --- Clima -----------------------------------------------------------------------------------------------

func _criar_clima() -> void:
	_clima = Node2D.new()
	_clima.name = "Clima"
	_clima.z_index = Profundidade.Z_TOPO
	_clima.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_clima)
	# Pétalas da primavera: caem devagar, balançando
	_petalas = _novo_emissor(80, 9.0, Vector2(0.45, 1.0), 28.0, Vector2(6, 9), 5.0, 13.0, 1.0, 1.6,
			[Color(1.0, 0.72, 0.84), Color(1.0, 0.9, 0.95), Color(0.97, 0.78, 0.9)], false, FORMA_PETALA)
	_petalas.angular_velocity_min = -90.0
	_petalas.angular_velocity_max = 90.0
	_petalas.tangential_accel_min = -6.0
	_petalas.tangential_accel_max = 6.0
	# Vaga-lumes do verão: flutuam em qualquer direção e piscam
	_vagalumes = _novo_emissor(40, 6.0, Vector2(0, -1), 180.0, Vector2(0, 0), 2.5, 8.0, 0.8, 1.2,
			[Color(0.9, 1.0, 0.5), Color(1.0, 0.95, 0.55), Color(0.75, 1.0, 0.6)], true, FORMA_BRILHO)
	_vagalumes.tangential_accel_min = -9.0
	_vagalumes.tangential_accel_max = 9.0
	# Folhas do outono: caem na diagonal, girando
	_folhas = _novo_emissor(70, 8.0, Vector2(0.55, 1.0), 30.0, Vector2(12, 16), 8.0, 17.0, 1.0, 1.5,
			[Color(0.92, 0.52, 0.14), Color(0.72, 0.26, 0.1), Color(0.95, 0.76, 0.2), Color(0.62, 0.34, 0.12)], false, FORMA_FOLHA)
	_folhas.angular_velocity_min = -140.0
	_folhas.angular_velocity_max = 140.0
	for p in [_petalas, _folhas]:
		p.emitting = false
		p.visible = false
		_clima.add_child(p)
	# Os vaga-lumes ficam numa camada própria que acompanha a câmera: assim o tom da noite (CanvasModulate) não os
	# apaga e eles brilham de verdade no escuro. Nessa camada as coordenadas são do mundo, não do terreno
	var camada := CanvasLayer.new()
	camada.name = "CamadaVagalumes"
	camada.layer = 1
	camada.follow_viewport_enabled = true
	add_child(camada)
	_vagalumes.position += _terreno.global_position
	_vagalumes.emitting = false
	_vagalumes.visible = false
	camada.add_child(_vagalumes)

func _novo_emissor(quantidade: int, vida: float, direcao: Vector2, abertura: float, gravidade: Vector2,
		vel_min: float, vel_max: float, esc_min: float, esc_max: float, cores: Array, aditivo: bool,
		forma: Array[String]) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _textura_da_forma(forma)
	p.amount = quantidade
	p.lifetime = vida
	p.preprocess = vida
	p.local_coords = false
	p.position = AREA_CLIMA_CENTRO
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = AREA_CLIMA_EXTENSAO
	p.direction = direcao
	p.spread = abertura
	p.gravity = gravidade
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.scale_amount_min = esc_min
	p.scale_amount_max = esc_max
	# cor de cada partícula sorteada da lista; o alfa entra e sai suavemente (ou pulsa, nos vaga-lumes)
	var sorteio := Gradient.new()
	var offsets := PackedFloat32Array()
	var cores_pack := PackedColorArray()
	for i in cores.size():
		offsets.append(float(i) / maxf(cores.size() - 1, 1))
		cores_pack.append(cores[i])
	sorteio.offsets = offsets
	sorteio.colors = cores_pack
	sorteio.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = sorteio
	var vida_alfa := Gradient.new()
	if aditivo:
		vida_alfa.offsets = PackedFloat32Array([0.0, 0.15, 0.35, 0.55, 0.8, 1.0])
		vida_alfa.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25),
				Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = material
	else:
		vida_alfa.offsets = PackedFloat32Array([0.0, 0.12, 0.85, 1.0])
		vida_alfa.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0)])
	p.color_ramp = vida_alfa
	return p

func _textura_da_forma(forma: Array[String]) -> ImageTexture:
	var img := Image.create(forma[0].length(), forma.size(), false, Image.FORMAT_RGBA8)
	for y in forma.size():
		for x in forma[y].length():
			if forma[y][x] == "X":
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)

func _atualizar_clima(indice: int) -> void:
	_alternar_emissor(_petalas, indice == 0)
	_alternar_emissor(_vagalumes, _vagalumes_acesos(indice))
	_alternar_emissor(_folhas, indice == 2)
	# A neve (inverno) é de sprite e vem do clima.gd, junto com a chuva

func _alternar_emissor(p: CPUParticles2D, ligado: bool) -> void:
	p.visible = ligado
	p.emitting = ligado
	if ligado:
		p.restart()

# Os vaga-lumes do verão se escondem na chuva (pétalas e folhas continuam, o vento as carrega)
func _vagalumes_acesos(indice: int) -> bool:
	return indice == 1 and not ClimaScript.eh_chuva(meteorologia.clima_atual if meteorologia else ClimaScript.Estado.LIMPO)

func _ao_clima_mudou(_estado: int) -> void:
	if estacao_atual < 0:
		return
	var acesos := _vagalumes_acesos(estacao_atual)
	if _vagalumes.emitting != acesos:
		_alternar_emissor(_vagalumes, acesos)

# --- Tom da luz ---------------------------------------------------------------------------------------------

func _aplicar_tom(indice: int, imediato: bool) -> void:
	var luz := get_tree().get_first_node_in_group("iluminacao")
	if luz == null or not ("tom_estacao" in luz):
		return
	if _tween_tom:
		_tween_tom.kill()
	if imediato:
		luz.tom_estacao = TONS[indice]
		return
	_tween_tom = create_tween()
	_tween_tom.tween_property(luz, "tom_estacao", TONS[indice], 1.2)

# --- Fade e ciclo por ondas -----------------------------------------------------------------------------

func _criar_fade() -> void:
	_camada_fade = CanvasLayer.new()
	_camada_fade.name = "FadeEstacao"
	# mesma camada da vinheta e do HUD, mas antes deles na árvore: o HUD continua visível durante o fade
	_camada_fade.layer = 1
	_painel_fade = ColorRect.new()
	_painel_fade.color = Color(0.04, 0.05, 0.09, 0.0)
	_painel_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada_fade.add_child(_painel_fade)
	add_child(_camada_fade)

func _ao_onda_completada(onda: int) -> void:
	# O bônus não avança a onda: a próxima é a mesma que ficou esperando
	var proxima := onda if _gerenciador.onda_bonus else onda + 1
	var alvo := estacao_da_onda(proxima)
	if alvo == estacao_atual:
		return
	var id := _id_troca + 1
	_id_troca = id
	await get_tree().create_timer(ATRASO_TROCA).timeout
	if id != _id_troca or not is_inside_tree():
		return  # outra troca, ondas paradas ou onda já iniciada
	definir_estacao(alvo)
	await get_tree().create_timer(DURACAO_FADE_SAIDA + 0.15).timeout
	if is_inside_tree():
		Sons.tocar("estacao", 0.0)
		get_tree().call_group("hud", "anunciar", NOMES[alvo], "NOVA ESTACAO", 2.0)

func _ao_onda_iniciada(onda: int) -> void:
	# Segurança: se a onda começou antes da troca agendada (ou o checkpoint mudou a onda), alinha sem fade
	var alvo := estacao_da_onda(onda)
	if alvo != estacao_atual:
		definir_estacao(alvo, true)
	else:
		_id_troca += 1  # cancela troca pendente

func _ao_ondas_paradas() -> void:
	# Morreu/parou: volta para a estação da onda inicial da próxima partida
	definir_estacao(estacao_da_onda(_gerenciador.onda_inicial), true)

func _ao_onda_inicial_definida(onda: int) -> void:
	# Mística: a partida vai começar em outra onda (e portanto em outra estação)
	definir_estacao(estacao_da_onda(onda))
