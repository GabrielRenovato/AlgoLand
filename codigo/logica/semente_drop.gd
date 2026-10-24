extends Node2D

## Saquinho de semente no chão da arena: cai do inimigo que morreu, pula um pouco, fica balançando e é puxado
## quando o jogador chega perto (ímã). Ao encostar vai para a pilha da planta na mochila (Fazenda.dar_sementes). Mochila cheia
## sem pilha daquela planta: não é pego (avisa "MOCHILA CHEIA"); permanece no chão até haver espaço.
## No fim da onda todos os saquinhos que sobraram voam até o jogador (grupo "semente_drop", método atrair).
##
## Quem cria: o slime_spawner, ao morrer cada inimigo da onda (soltar_de). A tabela de drop fica aqui, no estilo dos
## MMORPGs: cada semente da estação tem a SUA chance por abate, sorteada separadamente, pela raridade da planta
## (Fazenda.PLANTAS[id]["raridade"]). As plantas das melhores poções (força e vampírica) são as raras e épicas.
## Mobs normais e mutantes soltam semente muito raramente; a fonte principal é o chefe (a cada 10 ondas).
##
##   raridade   mob normal (por abate)   mutante (x3)   chefe: chance extra de cada (x10)
##   comum      0,4%   (1 em 250)        1,2%           4%
##   incomum    0,16%  (1 em 625)        0,48%          1,6%
##   raro       0,05%  (1 em 2000)       0,15%          0,5%
##   epico      0,016% (1 em 6250)       0,048%         0,16%
##
## Além das chances extras, o chefe sempre solta QTD_GARANTIDA_CHEFE sementes sorteadas pelos pesos de PESO_CHEFE.
## Nas fendas, as chances extras caem para 25% desta tabela e cada guardião garante uma semente da estação.
## Só caem sementes que crescem na estação atual; no inverno, que não tem plantio, não cai nenhuma (nem a garantida do chefe).
## Saquinho raro ou épico brilha no chão com a cor da raridade.

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const IconesFazenda := preload("res://codigo/ui/icones_fazenda.gd")
## Este script (soltar_de é estático e não tem `self` para instanciar)
const ROTEIRO := "res://codigo/logica/semente_drop.gd"

const CHANCE_POR_RARIDADE := {"comum": 0.004, "incomum": 0.0016, "raro": 0.0005, "epico": 0.00016}
const MULT_MUTANTE := 3.0
const MULT_CHEFE := 10.0
const QTD_GARANTIDA_CHEFE := 1
## Andares têm mais inimigos e um guardião em cada mapa, em vez de um chefe a cada dez ondas.
const MULT_CHANCE_ANDAR := 0.25
const QTD_GARANTIDA_GUARDIAO := 1
## Sementes garantidas do chefe: peso de cada raridade no sorteio
const PESO_CHEFE := {"comum": 50, "incomum": 30, "raro": 15, "epico": 5}
## Raridades que brilham no chão (na cor de Fazenda.COR_RARIDADE)
const RARIDADES_COM_BRILHO := ["raro", "epico"]

const RAIO_IMA := 44.0
const RAIO_PEGAR := 9.0
const VELOCIDADE_IMA := 70.0
const ACELERACAO_IMA := 420.0
const DURACAO_PULO := 0.45
const ALTURA_PULO := 14.0
## Altura dos pés do jogador em relação à origem dele (o saquinho mira os pés)
const PES := Vector2(0, 11)
## O saquinho é rasteiro: fica atrás de quem está na mesma altura do chão
const RECUO_PROFUNDIDADE := 6.0
## Depois de recusado por mochila cheia, espera isto antes de tentar de novo (e de avisar de novo)
const ESPERA_RECUSA := 1.5

static var _sombra_cache: Texture2D = null

var semente: String = ""
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

static func raridade(id: String) -> String:
	return String(Fazenda.PLANTAS[id].get("raridade", "comum")) if Fazenda.PLANTAS.has(id) else "comum"

## Chance de a semente `id` cair de um inimigo comum (sem multiplicador)
static func chance(id: String) -> float:
	return float(CHANCE_POR_RARIDADE.get(raridade(id), 0.0))

## Plantas cujas sementes caem na estação: só as que crescem nela (inverno: nenhuma)
static func plantas_que_caem(estacao: int) -> Array[String]:
	return Fazenda.plantas_da_estacao(estacao)

## Se o inimigo conta como chefe para o drop: os que viraram chefe (tornar_chefe) e o golem, que já nasce chefe
static func eh_chefe(inimigo: Object) -> bool:
	if inimigo == null:
		return false
	if bool(inimigo.get("eh_chefe")):
		return true
	var roteiro := inimigo.get_script() as Script
	return roteiro != null and roteiro.get_script_constant_map().get("CHEFE_NATIVO", false) == true

## Sementes que um inimigo solta: cada semente da estação é sorteada separadamente pela chance da raridade dela
## (vezes o multiplicador do mutante ou do chefe); o chefe ainda solta QTD_GARANTIDA_CHEFE pelos pesos de raridade
static func sortear(estacao: int, mutante: bool, chefe: bool, rng: RandomNumberGenerator, modo_andares: bool = false) -> Array[String]:
	var saida: Array[String] = []
	var mult := MULT_CHEFE if chefe else (MULT_MUTANTE if mutante else 1.0)
	if modo_andares:
		mult *= MULT_CHANCE_ANDAR
	for id in plantas_que_caem(estacao):
		if rng.randf() < minf(chance(id) * mult, 1.0):
			saida.append(id)
	if chefe and not plantas_que_caem(estacao).is_empty():
		for i in (QTD_GARANTIDA_GUARDIAO if modo_andares else QTD_GARANTIDA_CHEFE):
			saida.append(sortear_planta(estacao, rng))
	return saida

## Uma planta da estação pelos pesos de raridade de PESO_CHEFE (as comuns mais prováveis, as épicas raras); "" se nada cresce nela
static func sortear_planta(estacao: int, rng: RandomNumberGenerator) -> String:
	var plantas := plantas_que_caem(estacao)
	if plantas.is_empty():
		return ""
	var total := 0
	for id in plantas:
		total += int(PESO_CHEFE.get(raridade(id), 1))
	var sorteio := rng.randi_range(1, total)
	for id in plantas:
		sorteio -= int(PESO_CHEFE.get(raridade(id), 1))
		if sorteio <= 0:
			return id
	return plantas[plantas.size() - 1]

## Cria os saquinhos do inimigo `inimigo` (que acabou de morrer) na cena `pai`. Devolve os criados
static func soltar_de(inimigo: Node2D, pai: Node, rng: RandomNumberGenerator, modo_andares: bool = false) -> Array[Node2D]:
	var criados: Array[Node2D] = []
	if not is_instance_valid(inimigo) or pai == null:
		return criados
	var sementes := sortear(Calendario.estacao(), bool(inimigo.get("eh_mutante")), eh_chefe(inimigo), rng, modo_andares)
	for i in sementes.size():
		var drop: Node2D = (load(ROTEIRO) as GDScript).new()
		drop.semente = sementes[i]
		# Vários saquinhos (chefe) se espalham em leque em volta do ponto da morte
		var angulo := TAU * float(i) / maxf(sementes.size(), 1.0) + rng.randf_range(-0.4, 0.4)
		var distancia := rng.randf_range(10.0, 18.0) if sementes.size() > 1 else rng.randf_range(0.0, 8.0)
		drop.preparar_pulo(inimigo.global_position, inimigo.global_position + Vector2.from_angle(angulo) * distancia)
		pai.add_child(drop)
		criados.append(drop)
	return criados

func preparar_pulo(de: Vector2, para: Vector2) -> void:
	_origem_pulo = de
	_destino_pulo = para
	global_position = de

func _ready() -> void:
	add_to_group("semente_drop")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = false
	_sombra = Sprite2D.new()
	_sombra.texture = _textura_sombra()
	_sombra.position = Vector2(0, 1)
	_sombra.modulate = Color(0, 0, 0, 0.35)
	add_child(_sombra)
	if raridade(semente) in RARIDADES_COM_BRILHO:
		var cor: Color = Fazenda.COR_RARIDADE[raridade(semente)]
		# Halo aditivo (clareia o chão na cor da raridade) e faíscas subindo, como item raro de MMORPG
		_brilho = Sprite2D.new()
		_brilho.texture = _textura_brilho()
		_brilho.position = Vector2(0, -6)
		_brilho.modulate = cor
		var aditivo := CanvasItemMaterial.new()
		aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_brilho.material = aditivo
		add_child(_brilho)
		var faiscas := CPUParticles2D.new()
		faiscas.name = "Faiscas"
		faiscas.position = Vector2(0, -6)
		faiscas.amount = 6 if raridade(semente) == "epico" else 3
		faiscas.lifetime = 0.9
		faiscas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		faiscas.emission_rect_extents = Vector2(7, 5)
		faiscas.direction = Vector2.UP
		faiscas.spread = 15.0
		faiscas.gravity = Vector2.ZERO
		faiscas.initial_velocity_min = 8.0
		faiscas.initial_velocity_max = 16.0
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
	_sprite.texture = IconesFazenda.saco_de_semente(semente) if Fazenda.PLANTAS.has(semente) else null
	_sprite.offset = Vector2(0, -7)
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
		_brilho.modulate.a = 0.75 + 0.25 * sin(_tempo * 4.0)
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
		if _atraido:
			_velocidade = maxf(_velocidade, VELOCIDADE_IMA) + ACELERACAO_IMA * delta
			global_position = global_position.move_toward(alvo, _velocidade * delta)
			if global_position.distance_to(alvo) <= RAIO_PEGAR:
				_pegar()
				return
		# Balança parado no chão (só o desenho: a posição continua a do chão)
		_sprite.position.y = 0.0 if _atraido else -absf(sin(_tempo * 3.0)) * 2.0
	_atualizar_z()

## Fim da onda: voa até o jogador; se não couber, permanece no chão.
func atrair() -> void:
	_atraido = true
	_recusado_ate = -1.0
	_pulo = DURACAO_PULO

## Já tem a pilha da planta (sempre cabe) ou uma casa livre
static func cabe_na_mochila(id: String) -> bool:
	return InventarioJogador.quantidade_sementes(id) > 0 or InventarioJogador.tem_espaco()

func _pegar() -> void:
	if not Fazenda.dar_sementes(semente, 1):
		# Mochila cheia: o saquinho volta a ficar no chão por um tempo e o jogador é avisado
		_atraido = false
		_velocidade = 0.0
		_recusado_ate = _tempo + ESPERA_RECUSA
		get_tree().call_group("hud_p1", "avisar_equipamento_cheio")
		Sons.tocar("erro", 0.0)
		return
	_pego = true
	Sons.tocar("pegar_semente", 0.08)
	get_tree().call_group("hud_p1", "avisar_semente", semente)
	queue_free()

func _jogador() -> Node2D:
	var cena := get_tree().current_scene if is_inside_tree() else null
	return cena.get_node_or_null("Jogador") as Node2D if cena != null else null

func _atualizar_z() -> void:
	z_index = Profundidade.z_de(global_position.y - RECUO_PROFUNDIDADE)

# Brilho redondo 28x28 (branco que some para as bordas; a cor vem do modulate), um só para todos
static var _brilho_cache: Texture2D = null
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

# Sombrinha oval 8x3 (desenhada uma vez e reaproveitada por todos os saquinhos)
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
