extends Node2D

## Drops físicos de receitas e coletáveis. Inimigos nunca entregam equipamento pronto.
## criar_item conserva a construção de equipamentos para prévias e ferramentas de debug.
## A fabricação de itens reais é feita na bigorna do Ivo, depois de aprender a receita.

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const Raridades := preload("res://codigo/dados/raridades.gd")
const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
const IconesItens := preload("res://codigo/ui/icones_itens.gd")
const DadosItemScript := preload("res://codigo/modelos/dados_item.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
## Este script (soltar_de é estático e não tem `self` para instanciar)
const ROTEIRO := "res://codigo/logica/equipamento_drop.gd"

const CHANCE_NORMAL := 0.002
const CHANCE_MUTANTE := 0.01
const CHANCE_CHEFE := 0.20
const DEGRAUS_MUTANTE := 1
const DEGRAUS_CHEFE := 2
const RARIDADE_MINIMA_CHEFE := "raro"
## Chance de o drop vir no nível mais alto liberado (senão, sorteia entre os menores)
const CHANCE_NIVEL_MAXIMO := 0.6
## A partir de qual raridade o brilho e as faíscas aparecem no chão (índice em Raridades.ORDEM)
const BRILHO_A_PARTIR_DE := 1
const FAISCAS_A_PARTIR_DE := 3

const RAIO_IMA := 44.0
const RAIO_PEGAR := 9.0
const VELOCIDADE_IMA := 70.0
const ACELERACAO_IMA := 420.0
const DURACAO_PULO := 0.45
const ALTURA_PULO := 14.0
## Altura dos pés do jogador em relação à origem dele (o item mira os pés)
const PES := Vector2(0, 11)
const RECUO_PROFUNDIDADE := 6.0
## Depois de recusado por mochila cheia, espera isto antes de tentar de novo (e de avisar de novo)
const ESPERA_RECUSA := 1.5
const LADO_ICONE := 14.0

static var _sombra_cache: Texture2D = null
static var _brilho_cache: Texture2D = null

var item: DadosItem
var _sprite: Sprite2D
var _sombra: Sprite2D
var _brilho: Sprite2D = null
var _tempo := 0.0
var _pulo := 0.0
var _origem_pulo := Vector2.ZERO
var _destino_pulo := Vector2.ZERO
var _atraido := false
var _velocidade := 0.0
var _pego := false
var _recusado_ate := -1.0

# --- Sorteio ---------------------------------------------------------------------------------------------------------

## Pergaminhos raros: chefes têm chance maior, sem receita garantida por andar.
static func chance(mutante: bool, chefe: bool) -> float:
	if chefe:
		return CHANCE_CHEFE
	return CHANCE_MUTANTE if mutante else CHANCE_NORMAL

## Equipamento novo: tipo, raridade, nível e afixos sorteados. Sem sorteio de se cai: só o conteúdo
## `raridade_forcada` (e `tipo_forcado`) pulam o sorteio: usados pelo painel de debug para ver cada raridade
static func criar_item(rng: RandomNumberGenerator, onda: int, mutante: bool, chefe: bool, raridade_forcada: String = "", tipo_forcado: String = "") -> DadosItem:
	var tipo: String = tipo_forcado if Equipamentos.TIPOS_DROP.has(tipo_forcado) else Equipamentos.TIPOS_DROP[rng.randi_range(0, Equipamentos.TIPOS_DROP.size() - 1)]
	if tipo_forcado == "" and not Progresso.arma_liberada(tipo):
		var disponiveis: Array = Equipamentos.TIPOS_DROP.filter(func(id): return Progresso.arma_liberada(id))
		tipo = disponiveis[rng.randi_range(0, disponiveis.size() - 1)]
	if Conjuntos.de_tipo(tipo_forcado) != null:
		tipo = tipo_forcado
	elif tipo_forcado == "" and raridade_forcada == "" and chefe:
		var sorteado := Conjuntos.sortear(rng, onda, mutante, chefe)
		if not sorteado.is_empty():
			tipo = sorteado
	var degraus := DEGRAUS_CHEFE if chefe else (DEGRAUS_MUTANTE if mutante else 0)
	var raridade := raridade_forcada if Raridades.valida(raridade_forcada) else Raridades.sortear(rng, onda, degraus, RARIDADE_MINIMA_CHEFE if chefe else "comum")
	var liberado := Equipamentos.nivel_liberado(onda)
	var nivel := liberado
	if liberado > 1 and rng.randf() >= CHANCE_NIVEL_MAXIMO:
		nivel = rng.randi_range(1, liberado - 1)
	var novo := DadosItemScript.new()
	novo.id = StringName(tipo)
	novo.tipo = tipo
	var familia := Equipamentos.familia_de(tipo)
	novo.categoria = "escudo" if familia == "escudo" else "arma"
	novo.duas_maos = familia in ["lanca", "arco"]
	novo.nivel = nivel
	novo.raridade = raridade
	var conjunto := Conjuntos.de_tipo(tipo)
	if conjunto != null:
		novo.categoria = conjunto.TIPOS[tipo]["slot"]
		novo.raridade = conjunto.RARIDADE
		novo.duas_maos = false
		# Peça de conjunto cai sempre no nível 1: evolui na bigorna com a moeda de forja
		novo.nivel = 1
		raridade = novo.raridade
	var afixos := Raridades.sortear_afixos(rng, novo.categoria, raridade)
	if afixos.has("encantamento"):
		novo.encantamento = String(afixos["encantamento"])
		novo.nivel_encantamento = 1
		afixos.erase("encantamento")
	novo.afixos = afixos
	return novo

## Qualquer chefe tem esta chance de soltar a moeda de forja, que vai direto para a bolsa (InventarioJogador.moedas_forja)
const CHANCE_MOEDA_FORJA_CHEFE := 0.05
static func sortear_moeda_forja(rng: RandomNumberGenerator, chefe: bool) -> bool:
	return chefe and rng.randf() < CHANCE_MOEDA_FORJA_CHEFE

## Cria o equipamento do inimigo `inimigo` (que acabou de morrer) na cena `pai`, se o sorteio deixar. Devolve o drop ou null
static func soltar_de(inimigo: Node2D, pai: Node, rng: RandomNumberGenerator, onda: int, chefe: bool) -> Node2D:
	if not is_instance_valid(inimigo) or pai == null:
		return null
	var mutante := bool(inimigo.get("eh_mutante"))
	if rng.randf() >= chance(mutante, chefe):
		return null
	return load("res://codigo/logica/drops_forja.gd").soltar_receita(onda,inimigo.global_position,pai)

static func soltar_item(novo: DadosItem, onde: Vector2, pai: Node, rng: RandomNumberGenerator) -> Node2D:
	var drop: Node2D = (load(ROTEIRO) as GDScript).new()
	drop.item = novo
	drop.preparar_pulo(onde, onde + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 14.0))
	pai.add_child(drop)
	return drop

func preparar_pulo(de: Vector2, para: Vector2) -> void:
	_origem_pulo = de
	_destino_pulo = para
	global_position = de

# --- Desenho ---------------------------------------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("equipamento_drop")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = false
	_sombra = Sprite2D.new()
	_sombra.texture = _textura_sombra()
	_sombra.position = Vector2(0, 1)
	_sombra.modulate = Color(0, 0, 0, 0.35)
	add_child(_sombra)
	var indice := Raridades.indice(item.raridade)
	var cor := item.cor_raridade()
	if indice >= BRILHO_A_PARTIR_DE:
		# Halo aditivo (clareia o chão na cor da raridade); quanto mais rara, maior e mais forte
		_brilho = Sprite2D.new()
		_brilho.texture = _textura_brilho()
		_brilho.position = Vector2(0, -6)
		_brilho.scale = Vector2.ONE * (0.8 + 0.25 * indice)
		_brilho.modulate = cor
		var aditivo := CanvasItemMaterial.new()
		aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_brilho.material = aditivo
		add_child(_brilho)
		if indice >= FAISCAS_A_PARTIR_DE:
			var faiscas := CPUParticles2D.new()
			faiscas.name = "Faiscas"
			faiscas.position = Vector2(0, -6)
			faiscas.amount = 8 if item.raridade == "lendario" else 5
			faiscas.lifetime = 0.9
			faiscas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			faiscas.emission_rect_extents = Vector2(7, 5)
			faiscas.direction = Vector2.UP
			faiscas.spread = 15.0
			faiscas.gravity = Vector2.ZERO
			faiscas.initial_velocity_min = 8.0
			faiscas.initial_velocity_max = 18.0
			faiscas.scale_amount_min = 1.0
			faiscas.scale_amount_max = 2.0
			faiscas.color = cor.lightened(0.4)
			var some := Gradient.new()
			some.set_color(0, Color(1, 1, 1, 1))
			some.set_color(1, Color(1, 1, 1, 0))
			faiscas.color_ramp = some
			faiscas.material = aditivo
			add_child(faiscas)
	_sprite = Sprite2D.new()
	_sprite.texture = IconesItens.obter(item, get_tree())
	_sprite.material = preload("res://codigo/dados/ferramentas_madeira.gd").do_tipo(item.tipo,item.nivel)
	var maior := 1.0
	if _sprite.texture != null:
		maior = maxf(maxf(_sprite.texture.get_width(), _sprite.texture.get_height()), 1.0)
	_sprite.scale = Vector2.ONE * minf(1.0, LADO_ICONE / maior)
	_sprite.offset = Vector2(0, -7) / _sprite.scale.x
	add_child(_sprite)
	if _origem_pulo == Vector2.ZERO and _destino_pulo == Vector2.ZERO:
		_origem_pulo = global_position
		_destino_pulo = global_position
		_pulo = DURACAO_PULO
	global_position = _origem_pulo
	_atualizar_z()

func _process(delta: float) -> void:
	if _pego:
		return
	_tempo += delta
	if _brilho != null:
		_brilho.modulate.a = 0.7 + 0.25 * sin(_tempo * (5.0 if item.raridade == "lendario" else 3.5))
		_brilho.position.y = _sprite.position.y - 6.0
	var jogador := _jogador()
	if _pulo < DURACAO_PULO:
		_pulo = minf(_pulo + delta, DURACAO_PULO)
		var t := _pulo / DURACAO_PULO
		global_position = _origem_pulo.lerp(_destino_pulo, t)
		_sprite.position.y = -sin(t * PI) * ALTURA_PULO
	elif jogador != null:
		var alvo := jogador.global_position + PES
		var distancia := global_position.distance_to(alvo)
		var recusado := _tempo < _recusado_ate
		if not _atraido and not recusado and distancia <= RAIO_IMA:
			_atraido = true
		if _atraido and not recusado:
			_velocidade = maxf(_velocidade, VELOCIDADE_IMA) + ACELERACAO_IMA * delta
			global_position = global_position.move_toward(alvo, _velocidade * delta)
			if global_position.distance_to(alvo) <= RAIO_PEGAR:
				_tentar_pegar()
				return
		# Balança parado no chão (só o desenho: a posição continua a do chão)
		_sprite.position.y = 0.0 if (_atraido and not recusado) else -absf(sin(_tempo * 3.0)) * 2.0
	_atualizar_z()

## Fim da onda: voa até o jogador, esteja onde estiver. Sem lugar (mochila e saque cheios) ou abaixo do filtro, vira ouro
func atrair() -> void:
	if _pego:
		return
	_jogador()
	_atraido = true
	_pulo = DURACAO_PULO

static func mochila_tem_espaco() -> bool:
	return InventarioJogador.tem_espaco()

## Cabe em algum lugar: na mochila ou no saque da partida
static func tem_lugar() -> bool:
	return InventarioJogador.tem_espaco() or Saque.tem_espaco()

## Exige espaço na mochila inclusive com filtro de venda ligado. Sem espaço, permanece no chão.
func _tentar_pegar() -> void:
	var inventario := _inventario()
	if inventario.pode_receber(item):
		if Saque.vende_sozinho(item):
			vender()
			return
		var antes: Array = inventario.fotografar_mochila()
		if inventario.receber(item) >= 0 and inventario.salvar():
			_pego = true
			Sons.tocar("compra", 0.05)
			get_tree().call_group(_grupo_hud(), "avisar_equipamento", item)
			queue_free()
			return
		inventario.restaurar_mochila(antes)
	_atraido = false
	_velocidade = 0.0
	_recusado_ate = _tempo + ESPERA_RECUSA
	get_tree().call_group(_grupo_hud(), "avisar_equipamento_cheio", "MOCHILA CHEIA: LIBERE ESPACO")
	Sons.tocar("erro", 0.0)

## Vende o equipamento direto (sem a mochila) pelo preço da partida (Saque.preco_na_partida: pouco, para não deixar o
## jogador rico): o ouro entra e um aviso diz quanto
func vender() -> void:
	if _pego:
		return
	_pego = true
	var valor := Saque.preco(item)
	DadosJogo.adicionar_de(_dono, valor)
	get_tree().call_group(_grupo_hud(), "avisar_equipamento_vendido", item, valor)
	queue_free()

## Quem o ímã puxa: o jogador de pé mais perto (no cooperativo, o item vai para quem chegar); fixa depois de atraído
var _dono: Node2D
func _jogador() -> Node2D:
	if _atraido and is_instance_valid(_dono):
		return _dono
	var melhor: Node2D = null
	var menor := INF
	for jogador in get_tree().get_nodes_in_group("jogadores") if is_inside_tree() else []:
		if bool(jogador.get("estaMorto")) or jogador.get_world_2d()!=get_world_2d():
			continue
		var distancia := global_position.distance_squared_to(jogador.global_position)
		if distancia < menor:
			menor = distancia
			melhor = jogador
	_dono = melhor
	return melhor

func _grupo_hud() -> String:
	return _dono.grupo_hud() if is_instance_valid(_dono) and _dono.has_method("grupo_hud") else "hud_p1"

func _inventario() -> Node:
	return _dono.inventario if is_instance_valid(_dono) and _dono.get("inventario") != null else InventarioJogador

func _atualizar_z() -> void:
	z_index = Profundidade.z_de(global_position.y - RECUO_PROFUNDIDADE)

# Brilho redondo 28x28 (branco que some para as bordas; a cor vem do modulate), um só para todos
static func _textura_brilho() -> Texture2D:
	if _brilho_cache == null:
		var gradiente := GradientTexture2D.new()
		gradiente.width = 28
		gradiente.height = 28
		gradiente.fill = GradientTexture2D.FILL_RADIAL
		gradiente.fill_from = Vector2(0.5, 0.5)
		gradiente.fill_to = Vector2(0.5, 0.0)
		var cores := Gradient.new()
		cores.set_color(0, Color(1, 1, 1, 1))
		cores.set_color(1, Color(1, 1, 1, 0))
		gradiente.gradient = cores
		_brilho_cache = gradiente
	return _brilho_cache

# Sombrinha oval 8x3 (desenhada uma vez e reaproveitada por todos)
static func _textura_sombra() -> Texture2D:
	if _sombra_cache == null:
		var img := Image.create(8, 3, false, Image.FORMAT_RGBA8)
		for y in 3:
			for x in 8:
				var dx := (float(x) + 0.5 - 4.0) / 4.0
				var dy := (float(y) + 0.5 - 1.5) / 1.5
				if dx * dx + dy * dy <= 1.0:
					img.set_pixel(x, y, Color.WHITE)
		_sombra_cache = ImageTexture.create_from_image(img)
	return _sombra_cache
