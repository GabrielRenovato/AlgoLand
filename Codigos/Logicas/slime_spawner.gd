extends Node2D

@onready var principal = get_node("/root/cenario")

@export var cenas_inimigos: Array[PackedScene] = [
	preload("res://cenas/inimigos/slime.tscn"),
]

# Cada estágio dura ONDAS_POR_ESTAGIO ondas e tem no máximo 2 tipos de inimigo: os antigos saem de cena
# conforme os novos entram, em vez de acumular uma mistura. O mímico fica de fora: só aparece no estágio
# bônus (ver Gerenciador-de-ondas.gd)
const CENA_SLIME := preload("res://cenas/inimigos/slime.tscn")
const CENA_MORCEGO := preload("res://cenas/inimigos/morcego.tscn")
const CENA_VESPA := preload("res://cenas/inimigos/vespa.tscn")
const CENA_COGUMELO := preload("res://cenas/inimigos/cogumelo.tscn")
const CENA_FLOR := preload("res://cenas/inimigos/flor.tscn")
const CENA_CARANGUEJO := preload("res://cenas/inimigos/caranguejo.tscn")
const CENA_GREMLIN := preload("res://cenas/inimigos/gremlin.tscn")
const CENA_FALCAO := preload("res://cenas/inimigos/falcao.tscn")
const ONDAS_POR_ESTAGIO := 2
const ESTAGIOS: Array[Array] = [
	[CENA_SLIME],
	[CENA_SLIME, CENA_MORCEGO],
	[CENA_MORCEGO, CENA_VESPA],
	[CENA_COGUMELO],
	[CENA_COGUMELO, CENA_FLOR],
	[CENA_FLOR, CENA_CARANGUEJO],
	[CENA_CARANGUEJO, CENA_GREMLIN],
	[CENA_GREMLIN, CENA_FALCAO],
	[CENA_FALCAO, CENA_VESPA],
]
# Passado o último estágio, volta a repetir daqui (sem o estágio só de slimes); a vida e o dano seguem subindo por onda
const ESTAGIO_INICIO_CICLO := 2

# Variante "mutante": maior e mais forte, com uma coroa cinza acima da barra de vida; aparece nas ondas mais avançadas
const ONDA_INICIAL_MUTANTE := 6
const CHANCE_MUTANTE_BASE := 0.05
const CHANCE_MUTANTE_POR_ONDA := 0.015
const CHANCE_MUTANTE_MAXIMA := 0.35

var pontos_spawn := []
var gerenciador_ondas
@export var atraso_spawn: float = 0.5
@export var max_tentativas_spawn: int = 3
@export var prevenir_spawns_consecutivos: bool = true
var ultimo_indice_spawn: int = -1
const VELOCIDADE_INIMIGO_MAXIMA: int = 85
@export var velocidade_extra_por_onda: float = 1.5

func tem_propriedade(obj: Object, nome_propriedade: String) -> bool:
	for prop in obj.get_property_list():
		if prop.name == nome_propriedade:
			return true
	return false

func _ready() -> void:
	randomize()
	await get_tree().process_frame
	# Coleta todos os pontos de spawn
	for child in get_children():
		if child is Marker2D:
			pontos_spawn.append(child)
	
	# Obtém o GerenciadorOndas a partir do principal
	if is_instance_valid(principal):
		gerenciador_ondas = principal.get_node("enemySpawner/GerenciadorOndas")
		if gerenciador_ondas:
			gerenciador_ondas.gerador = self
	else:
		push_error("Nó principal não encontrado ou inválido")

## cena vazia = sorteia de cenas_inimigos
func spawnar_inimigos(num_inimigos: int, multiplicador_vida: float, multiplicador_dano: float, cena: PackedScene = null) -> void:
	if pontos_spawn.size() == 0:
		push_error("Nenhum ponto de spawn disponível")
		return
	
	var total_spawnado: int = 0
	while total_spawnado < num_inimigos:
		while gerenciador_ondas and get_tree().get_nodes_in_group("enemy").size() >= gerenciador_ondas.MAX_INIMIGOS_ATIVOS:
			if gerenciador_ondas.ondas_paradas:
				return
			await get_tree().create_timer(0.5).timeout
		if gerenciador_ondas and gerenciador_ondas.ondas_paradas:
			return

		var ponto_spawn = obter_melhor_ponto_spawn()
		var sucesso = await spawnar_inimigo_com_tentativas(ponto_spawn, multiplicador_vida, multiplicador_dano, cena)
		total_spawnado += 1
		if not sucesso and is_instance_valid(gerenciador_ondas):
			gerenciador_ondas.descontar_inimigo_nao_spawnado()
		if gerenciador_ondas and gerenciador_ondas.ondas_paradas:
			return
		await get_tree().create_timer(atraso_spawn).timeout

func spawnar_inimigo_com_tentativas(spawn: Marker2D, multiplicador_vida: float, multiplicador_dano: float, cena: PackedScene = null) -> bool:
	var tentativas = 0
	while tentativas < max_tentativas_spawn:
		var resultado = await spawnar_inimigo_em(spawn, multiplicador_vida, multiplicador_dano, cena)
		if resultado:
			return true
		tentativas += 1
		await get_tree().create_timer(0.1).timeout
	return false

## Tipos de inimigo da onda (no máximo 2); ver ESTAGIOS
func obter_pool_especies(onda: int) -> Array[PackedScene]:
	var estagio := (maxi(onda, 1) - 1) / ONDAS_POR_ESTAGIO
	if estagio >= ESTAGIOS.size():
		estagio = ESTAGIO_INICIO_CICLO + (estagio - ESTAGIOS.size()) % (ESTAGIOS.size() - ESTAGIO_INICIO_CICLO)
	var pool: Array[PackedScene] = []
	pool.assign(ESTAGIOS[estagio])
	return pool

func _deve_ser_mutante(onda: int) -> bool:
	if onda < ONDA_INICIAL_MUTANTE:
		return false
	var chance := minf(CHANCE_MUTANTE_BASE + CHANCE_MUTANTE_POR_ONDA * (onda - ONDA_INICIAL_MUTANTE), CHANCE_MUTANTE_MAXIMA)
	return randf() < chance

func obter_melhor_ponto_spawn() -> Marker2D:
	if pontos_spawn.size() <= 1:
		return pontos_spawn[0]
	
	var indice: int
	if prevenir_spawns_consecutivos and pontos_spawn.size() > 1:
		var indices_disponiveis = range(pontos_spawn.size())
		if ultimo_indice_spawn != -1:
			indices_disponiveis.erase(ultimo_indice_spawn)
		indice = indices_disponiveis[randi() % indices_disponiveis.size()]
	else:
		indice = randi() % pontos_spawn.size()
	
	ultimo_indice_spawn = indice
	return pontos_spawn[indice]

func obter_ponto_spawn_aleatorio() -> Marker2D:
	var indice = randi() % pontos_spawn.size()
	return pontos_spawn[indice]

func spawnar_inimigo_em(spawn: Marker2D, multiplicador_vida: float, multiplicador_dano: float, cena: PackedScene = null) -> bool:
	# Verificações de segurança
	if spawn == null or not is_instance_valid(spawn):
		push_error("Ponto de spawn inválido")
		return false
	
	if cenas_inimigos.size() == 0:
		push_error("Nenhuma cena de inimigo disponível")
		return false
	
	if not is_instance_valid(principal):
		push_error("Cena principal não é válida")
		return false
	
	var onda_atual: int = gerenciador_ondas.onda_atual if is_instance_valid(gerenciador_ondas) else 1
	var pool := obter_pool_especies(onda_atual)
	var cena_inimigo = cena if cena != null else pool[randi() % pool.size()]
	if cena_inimigo == null:
		push_error("Cena de inimigo selecionada é nula")
		return false

	var inimigo = cena_inimigo.instantiate()
	if inimigo == null:
		push_error("Falha ao instanciar inimigo")
		return false

	inimigo.name = "Inimigo_" + str(randi() % 10000)
	var deslocamento = Vector2(randf_range(-20, 20), randf_range(-20, 20))
	inimigo.position = spawn.global_position + deslocamento

	# Mutante: só nos sorteios normais (não no chefe nem na escolta, que vêm com "cena" fixa)
	if cena == null and inimigo.has_method("tornar_mutante") and _deve_ser_mutante(onda_atual):
		inimigo.tornar_mutante()

	if tem_propriedade(inimigo, "vida"):
		inimigo.vida = int(round(inimigo.vida * multiplicador_vida))
	if tem_propriedade(inimigo, "dano"):
		inimigo.dano *= multiplicador_dano
	if tem_propriedade(inimigo, "velocidade") and is_instance_valid(gerenciador_ondas):
		inimigo.velocidade = min(int(inimigo.velocidade + velocidade_extra_por_onda * (gerenciador_ondas.onda_atual - 1)), VELOCIDADE_INIMIGO_MAXIMA)

	principal.add_child(inimigo)
	if inimigo.has_node("HPBar"):
		var barra = inimigo.get_node("HPBar")
		barra.vida_maxima = inimigo.vida
		barra.definir_vida_atual(inimigo.vida)
	if inimigo.has_node("Sprite2D"):
		var sprite = inimigo.get_node("Sprite2D")
		sprite.modulate.a = 1.0
	
	# Aguarda um frame para garantir que o inimigo foi adicionado
	await get_tree().process_frame
	if not is_instance_valid(inimigo) or not inimigo.is_inside_tree():
		push_error("Inimigo não foi adicionado corretamente à árvore de cena")
		if is_instance_valid(inimigo) and inimigo.get_parent() == null:
			inimigo.queue_free()
		return false

	inimigo.add_to_group("enemy")
	if is_instance_valid(gerenciador_ondas):
		if inimigo.has_signal("inimigo_morreu"):
			inimigo.connect("inimigo_morreu", Callable(gerenciador_ondas, "inimigo_morreu"))
		else:
			push_warning("Inimigo não possui o sinal 'inimigo_morreu'")
	
	if inimigo.has_method("verify_lifespan"):
		inimigo.call_deferred("verify_lifespan")
	
	if inimigo.has_node("collision_body"):
		var colisao = inimigo.get_node("collision_body")
		if is_instance_valid(colisao):
			colisao.set_deferred("disabled", true)
			await get_tree().process_frame
			if is_instance_valid(colisao):
				colisao.set_deferred("disabled", false)
	
	var timer = get_tree().create_timer(0.1)
	await timer.timeout
	
	return true
