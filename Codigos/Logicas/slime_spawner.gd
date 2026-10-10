extends Node2D

@onready var principal = get_node("/root/cenario")

@export var cenas_inimigos: Array[PackedScene] = [
	preload("res://cenas/inimigos/slime.tscn"),
]

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

func spawnar_inimigos(num_inimigos: int, multiplicador_vida: float, multiplicador_dano: float) -> void:
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
		var sucesso = await spawnar_inimigo_com_tentativas(ponto_spawn, multiplicador_vida, multiplicador_dano)
		total_spawnado += 1
		if not sucesso and is_instance_valid(gerenciador_ondas):
			gerenciador_ondas.descontar_inimigo_nao_spawnado()
		if gerenciador_ondas and gerenciador_ondas.ondas_paradas:
			return
		await get_tree().create_timer(atraso_spawn).timeout

func spawnar_inimigo_com_tentativas(spawn: Marker2D, multiplicador_vida: float, multiplicador_dano: float) -> bool:
	var tentativas = 0
	while tentativas < max_tentativas_spawn:
		var resultado = await spawnar_inimigo_em(spawn, multiplicador_vida, multiplicador_dano)
		if resultado:
			return true
		tentativas += 1
		await get_tree().create_timer(0.1).timeout
	return false

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

func spawnar_inimigo_em(spawn: Marker2D, multiplicador_vida: float, multiplicador_dano: float) -> bool:
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
	
	var indice_aleatorio = randi() % cenas_inimigos.size()
	var cena_inimigo = cenas_inimigos[indice_aleatorio]
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
	inimigo.z_index = 10
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

	if inimigo is CollisionObject2D:
		# Layer 3 = corpo do inimigo; mask só no mundo, então não bloqueia jogador nem outros slimes
		inimigo.collision_layer = 1 << 2
		inimigo.collision_mask = 1
	
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
