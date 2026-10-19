extends Node

## Estações do ano da arena. Troca a folha de tiles (chão, lagoa, penhasco), o atlas das árvores e dos props
## sazonais, a visibilidade dos grupos "so_inverno"/"nao_inverno", o clima (partículas e, em codigo/cenario/clima.gd,
## chuva, neve, nuvens e raios em sprites) e o tom da luz.
## Fica como filho do nó raiz do terreno (cenas/terreno.tscn); o gerador (ferramentas/arena/gerar_arena.py) o cria.
##
## Índices: 0 primavera, 1 verão, 2 outono, 3 inverno. A estação segue o calendário de dias (autoload Calendario,
## que só avança ao dormir) na arena e na fazenda; as ondas não mexem nela. Na tela de título não há calendário a
## seguir: a estação fica fixa em `estacao_inicial` (inverno, por causa da neve do título).

signal estacao_mudou(indice: int)

## Texto do banner (a fonte do jogo não tem acentos)
const NOMES: Array[String] = ["PRIMAVERA", "VERAO", "OUTONO", "INVERNO"]
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const ClimaScript := preload("res://codigo/cenario/clima.gd")

const FOLHAS: Array[Texture2D] = [
	preload("res://assets/cenario/Seasonal Forest/arena/spring.png"),
	preload("res://assets/cenario/Seasonal Forest/arena/summer.png"),
	preload("res://assets/cenario/Seasonal Forest/arena/autumn.png"),
	preload("res://assets/cenario/Seasonal Forest/arena/winter.png"),
]
const BRILHOS: Array[Texture2D] = [
	preload("res://assets/cenario/Seasonal Forest/seasonal water animations/spring water sparkles B.png"),
	preload("res://assets/cenario/Seasonal Forest/seasonal water animations/summer water sparkles B 16x16.png"),
	preload("res://assets/cenario/Seasonal Forest/seasonal water animations/autumn water sparkles B 16x16.png"),
	preload("res://assets/cenario/Seasonal Forest/seasonal water animations/winter water sparkles B 16x16.png"),
]
## Árvores evergreen: mesmo layout (80x112) nas 4 estações. `ARVORES_VARIACAO` é a segunda família de árvores
## do mapa (no inverno sem neve no topo, para quebrar a uniformidade)
const ARVORES: Array[Texture2D] = [
	preload("res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (spring) 80x112.png"),
	preload("res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (summer) 80x112.png"),
	preload("res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (autumn) 80x112.png"),
	preload("res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (winter, top snow) 80x112.png"),
]
const ARVORES_VARIACAO: Array[Texture2D] = [
	preload("res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (spring) 80x112.png"),
	preload("res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (summer) 80x112.png"),
	preload("res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (autumn) 80x112.png"),
	preload("res://assets/cenario/23.05a - Arctic Woodland 1.1/evergreen trees/evergreen trees (winter, no snow) 80x112.png"),
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
## Espera entre o fim do fade e o aviso de "NOVA ESTACAO"
const ATRASO_AVISO := 0.15
## Retângulo do mundo (coordenadas do terreno) coberto pelas partículas de clima
const AREA_CLIMA_CENTRO := Vector2(332, 137)
const AREA_CLIMA_EXTENSAO := Vector2(470, 380)

## Estação usada quando não há calendário a seguir (tela de título)
@export_range(0, 3) var estacao_inicial: int = 3
## Segue o Calendario (a fazenda liga isto; a arena é detectada pelo gerenciador de ondas irmão do terreno)
@export var seguir_calendario: bool = false
## Grutas seguem a paleta sazonal, protegidas de chuva, neve e folhas.
@export var ambiente_interno := false
## Mapas com margens de água próprias podem fornecer suas quatro folhas sazonais.
@export var folhas_personalizadas: Array[Texture2D] = []
## Conjuntos com animação de água própria preservam o recurso mesmo ao reaplicar a estação atual.
@export var brilhos_personalizados: Array[Texture2D] = []

## Mapas maiores fornecem a extensão sem alterar as dimensões da arena original.
@export var area_clima_centro := AREA_CLIMA_CENTRO
@export var area_clima_extensao := AREA_CLIMA_EXTENSAO
var estacao_atual := -1

var _terreno: Node2D
var _fonte_chao: TileSetAtlasSource
var _fonte_brilho: TileSetAtlasSource
var _atlas_arvores: Array[AtlasTexture] = []
var _atlas_variacao: Array[AtlasTexture] = []
var _atlas_amostra: Array[AtlasTexture] = []
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
var _calendario_ligado := false

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
	# Na tela de título não há gerenciador de ondas nem calendário a seguir: estação fixa
	_calendario_ligado = seguir_calendario or get_node_or_null("../../enemySpawner/GerenciadorOndas") != null
	var inicial := estacao_inicial
	if _calendario_ligado:
		inicial = Calendario.estacao()
		Calendario.estacao_mudou.connect(_ao_calendario_estacao_mudou)
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
		_fonte_chao.texture = _folha_da_estacao(indice)
	if _fonte_brilho:
		_fonte_brilho.texture = brilhos_personalizados[indice] if brilhos_personalizados.size() == 4 else BRILHOS[indice]
	for t in _atlas_arvores:
		t.atlas = ARVORES[indice]
	for t in _atlas_variacao:
		t.atlas = ARVORES_VARIACAO[indice]
	for t in _atlas_amostra:
		t.atlas = _folha_da_estacao(indice)
	_alternar_grupo("so_inverno", indice == 3)
	_alternar_grupo("nao_inverno", indice != 3)
	meteorologia.definir_estacao(indice, imediato)
	_atualizar_clima(indice)
	_aplicar_tom(indice, imediato)
	if anterior != indice:
		estacao_mudou.emit(indice)

# Sprites com AtlasTexture marcada pelo gerador (resource_name): "arvore", "arvore_var" e "amostra"
func _folha_da_estacao(indice: int) -> Texture2D:
	return folhas_personalizadas[indice] if folhas_personalizadas.size() == 4 else FOLHAS[indice]

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
	p.position = area_clima_centro
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area_clima_extensao
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
	_alternar_emissor(_petalas, indice == 0 and not ambiente_interno)
	_alternar_emissor(_vagalumes, _vagalumes_acesos(indice) and not ambiente_interno)
	_alternar_emissor(_folhas, indice == 2 and not ambiente_interno)
	# A neve (inverno) é de sprite e vem do clima.gd, junto com a chuva

func _alternar_emissor(p: CPUParticles2D, ligado: bool) -> void:
	p.visible = ligado
	p.emitting = ligado
	if ligado:
		p.restart()

# Os vaga-lumes do verão se escondem na chuva (pétalas e folhas continuam, o vento as carrega)
func _vagalumes_acesos(indice: int) -> bool:
	return not ambiente_interno and indice == 1 and not ClimaScript.eh_chuva(meteorologia.clima_atual if meteorologia else ClimaScript.Estado.LIMPO)

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

# --- Fade e calendário -----------------------------------------------------------------------------

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

## O calendário virou de estação (dormiu no último dia): troca com fade e avisa no HUD
func _ao_calendario_estacao_mudou(alvo: int) -> void:
	if alvo == estacao_atual:
		return
	definir_estacao(alvo)
	var id := _id_troca  # definir_estacao já o incrementou: outra troca no meio cancela o aviso
	await get_tree().create_timer(DURACAO_FADE_SAIDA + ATRASO_AVISO).timeout
	if id == _id_troca and is_inside_tree():
		Sons.tocar("estacao", 0.0)
		get_tree().call_group("hud", "anunciar", NOMES[alvo], "NOVA ESTACAO", 2.0)
