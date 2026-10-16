extends Node2D

@onready var principal = get_node("/root/cenario")

@export var cenas_inimigos: Array[PackedScene] = [
	preload("res://cenas/inimigos/slime.tscn"),
]

# Cada estágio dura ONDAS_POR_ESTAGIO ondas e usa uma única espécie, exceto os três esqueletos juntos.
# A espécie muda no próximo estágio. O mímico fica de fora: só aparece no estágio
# bônus (ver gerenciador_de_ondas.gd)
const CENA_SLIME := preload("res://cenas/inimigos/slime.tscn")
const CENA_MORCEGO := preload("res://cenas/inimigos/morcego.tscn")
const CENA_VESPA := preload("res://cenas/inimigos/vespa.tscn")
const CENA_COGUMELO := preload("res://cenas/inimigos/cogumelo.tscn")
const CENA_FLOR := preload("res://cenas/inimigos/flor.tscn")
const CENA_CARANGUEJO := preload("res://cenas/inimigos/caranguejo.tscn")
const CENA_GREMLIN := preload("res://cenas/inimigos/gremlin.tscn")
const CENA_FALCAO := preload("res://cenas/inimigos/falcao.tscn")
const CENA_ESQUELETO_GUERREIRO := preload("res://cenas/inimigos/esqueleto_guerreiro.tscn")
const CENA_ESQUELETO_ARQUEIRO := preload("res://cenas/inimigos/esqueleto_arqueiro.tscn")
const CENA_ESQUELETO_MAGO := preload("res://cenas/inimigos/esqueleto_mago.tscn")
const SementeDrop := preload("res://codigo/logica/semente_drop.gd")
const EquipamentoDrop := preload("res://codigo/logica/equipamento_drop.gd")
const ONDAS_POR_ESTAGIO := 2
const ESTAGIOS: Array[Array] = [
	[CENA_SLIME],
	[CENA_MORCEGO],
	[CENA_VESPA],
	[CENA_COGUMELO],
	[CENA_FLOR],
	[CENA_CARANGUEJO],
	[CENA_GREMLIN],
	[CENA_FALCAO],
	[CENA_ESQUELETO_GUERREIRO, CENA_ESQUELETO_ARQUEIRO, CENA_ESQUELETO_MAGO],
]
# Passado o último estágio, volta a repetir daqui (sem o estágio só de slimes); a vida e o dano seguem subindo por onda
const ESTAGIO_INICIO_CICLO := 1

# Variante "mutante": maior e mais forte, com uma coroa cinza acima da barra de vida; aparece nas ondas mais avançadas
const ONDA_INICIAL_MUTANTE := 6
const CHANCE_MUTANTE_BASE := 0.05
const CHANCE_MUTANTE_POR_ONDA := 0.015
const CHANCE_MUTANTE_MAXIMA := 0.35
# Teto com o evento ELITE (a chance é multiplicada depois do teto normal)
const CHANCE_MUTANTE_MAXIMA_ELITE := 0.9

var pontos_spawn := []
var gerenciador_ondas
## Identifica a leva: parar ou avançar uma onda invalida as rotinas que aguardam timers.
var _geracao_spawn := 0
var _ordem_especies: Array[PackedScene] = []
var _onda_especies := -1
var _rng_sementes := RandomNumberGenerator.new()
var _rng_equipamentos := RandomNumberGenerator.new()
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
	_rng_sementes.randomize()
	_rng_equipamentos.randomize()
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

## Invalida inclusive levas que ainda aguardam uma vaga no limite de inimigos ativos.
func cancelar_spawns() -> void:
	_geracao_spawn += 1
	_ordem_especies.clear()
	_onda_especies = -1

## cena vazia = sorteia de cenas_inimigos
## config_chefe: {nome, escala, mult_vida, mult_dano, habilidade, altura_coroa}; vazio = inimigo comum (ver Inimigo-base.tornar_chefe)
func spawnar_inimigos(num_inimigos: int, multiplicador_vida: float, multiplicador_dano: float, cena: PackedScene = null, config_chefe: Dictionary = {}) -> void:
	var geracao := _geracao_spawn
	if pontos_spawn.size() == 0:
		push_error("Nenhum ponto de spawn disponível")
		return
	
	var total_spawnado: int = 0
	while total_spawnado < num_inimigos:
		if geracao != _geracao_spawn:
			return
		while gerenciador_ondas and get_tree().get_nodes_in_group("enemy").size() >= gerenciador_ondas.MAX_INIMIGOS_ATIVOS:
			if geracao != _geracao_spawn or gerenciador_ondas.ondas_paradas:
				return
			await get_tree().create_timer(0.5).timeout
		if geracao != _geracao_spawn or (gerenciador_ondas and gerenciador_ondas.ondas_paradas):
			return

		var ponto_spawn = obter_melhor_ponto_spawn()
		var sucesso = await spawnar_inimigo_com_tentativas(ponto_spawn, multiplicador_vida, multiplicador_dano, cena, config_chefe)
		if geracao != _geracao_spawn:
			return
		total_spawnado += 1
		if not sucesso and is_instance_valid(gerenciador_ondas):
			gerenciador_ondas.descontar_inimigo_nao_spawnado()
		if gerenciador_ondas and gerenciador_ondas.ondas_paradas:
			return
		await get_tree().create_timer(atraso_spawn).timeout

func spawnar_inimigo_com_tentativas(spawn: Marker2D, multiplicador_vida: float, multiplicador_dano: float, cena: PackedScene = null, config_chefe: Dictionary = {}) -> bool:
	var geracao := _geracao_spawn
	var tentativas = 0
	while tentativas < max_tentativas_spawn:
		if geracao != _geracao_spawn:
			return false
		var resultado = await spawnar_inimigo_em(spawn, multiplicador_vida, multiplicador_dano, cena, config_chefe)
		if resultado:
			return true
		tentativas += 1
		await get_tree().create_timer(0.1).timeout
	return false

## Espécie da onda ou as três classes de esqueleto; ver ESTAGIOS.
func obter_pool_especies(onda: int) -> Array[PackedScene]:
	var estagio := (maxi(onda, 1) - 1) / ONDAS_POR_ESTAGIO
	if estagio >= ESTAGIOS.size():
		estagio = ESTAGIO_INICIO_CICLO + (estagio - ESTAGIOS.size()) % (ESTAGIOS.size() - ESTAGIO_INICIO_CICLO)
	var pool: Array[PackedScene] = []
	pool.assign(ESTAGIOS[estagio])
	return pool

## Embaralha cada rodada de espécies: os três esqueletos entram antes de repetir qualquer classe.
func _sortear_especie(onda: int) -> PackedScene:
	if onda != _onda_especies or _ordem_especies.is_empty():
		_ordem_especies = obter_pool_especies(onda)
		_ordem_especies.shuffle()
		_onda_especies = onda
	return _ordem_especies.pop_back()

func _deve_ser_mutante(onda: int) -> bool:
	return randf() < chance_mutante(onda, _mult_evento("mutante"))

## Chance de um inimigo sorteado nascer mutante. O evento ELITE (mult > 1) multiplica a chance e vale
## também antes da onda em que os mutantes costumam aparecer
func chance_mutante(onda: int, mult_evento: float = 1.0) -> float:
	if onda < ONDA_INICIAL_MUTANTE and mult_evento <= 1.0:
		return 0.0
	var base := minf(CHANCE_MUTANTE_BASE + CHANCE_MUTANTE_POR_ONDA * maxi(onda - ONDA_INICIAL_MUTANTE, 0), CHANCE_MUTANTE_MAXIMA)
	return minf(base * mult_evento, CHANCE_MUTANTE_MAXIMA_ELITE) if mult_evento > 1.0 else base

## Modificador do evento da onda (1.0 se não houver); chaves: vida, dano, velocidade, mutante
func _mult_evento(chave: String) -> float:
	if is_instance_valid(gerenciador_ondas) and gerenciador_ondas.has_method("mult_evento"):
		return gerenciador_ondas.mult_evento(chave)
	return 1.0

## Velocidade que o inimigo de velocidade `base` tem na onda: sobe por onda, com teto
func velocidade_na_onda(base: int, onda: int) -> int:
	return mini(int(base + velocidade_extra_por_onda * (onda - 1)), VELOCIDADE_INIMIGO_MAXIMA)

## Vida, dano e velocidade de um inimigo recém-criado (antes de entrar na árvore): multiplicadores da onda,
## velocidade que cresce por onda (com teto) e os modificadores do evento em andamento
func aplicar_atributos(inimigo: Node, multiplicador_vida: float, multiplicador_dano: float) -> void:
	if tem_propriedade(inimigo, "vida"):
		inimigo.vida = int(round(inimigo.vida * multiplicador_vida * _mult_evento("vida")))
	if tem_propriedade(inimigo, "dano"):
		inimigo.dano *= multiplicador_dano * _mult_evento("dano")
	if tem_propriedade(inimigo, "velocidade") and is_instance_valid(gerenciador_ondas):
		inimigo.velocidade = int(round(velocidade_na_onda(inimigo.velocidade, gerenciador_ondas.onda_atual) * _mult_evento("velocidade")))

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

func spawnar_inimigo_em(spawn: Marker2D, multiplicador_vida: float, multiplicador_dano: float, cena: PackedScene = null, config_chefe: Dictionary = {}) -> bool:
	var geracao := _geracao_spawn
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
	var cena_inimigo = cena if cena != null else _sortear_especie(onda_atual)
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

	# Chefe: vira chefe antes dos multiplicadores, que então valem sobre a vida já ampliada
	if not config_chefe.is_empty() and inimigo.has_method("tornar_chefe"):
		inimigo.tornar_chefe(config_chefe["nome"], config_chefe["escala"], config_chefe["mult_vida"], config_chefe.get("mult_dano", 1.0), config_chefe.get("habilidade", ""), config_chefe.get("altura_coroa", -1.0))

	aplicar_atributos(inimigo, multiplicador_vida, multiplicador_dano)

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
	if geracao != _geracao_spawn:
		return false
	if not is_instance_valid(inimigo) or not inimigo.is_inside_tree():
		push_error("Inimigo não foi adicionado corretamente à árvore de cena")
		if is_instance_valid(inimigo) and inimigo.get_parent() == null:
			inimigo.queue_free()
		return false

	inimigo.add_to_group("enemy")
	if is_instance_valid(gerenciador_ondas):
		if inimigo.has_signal("inimigo_morreu"):
			# Sementes para a fazenda (os lacaios dos chefes não passam por aqui: não soltam nada). Liga antes do
			# gerenciador: os saquinhos do último inimigo já existem quando a onda termina e são atraídos junto
			inimigo.connect("inimigo_morreu", _soltar_sementes.bind(inimigo))
			inimigo.connect("inimigo_morreu", _soltar_equipamento.bind(inimigo))
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

## Saquinhos de semente no lugar onde o inimigo morreu (chance e sorteio em semente_drop.gd)
## No combate do prólogo os inimigos não soltam nada (nem sementes, nem equipamento, nem moeda da forja).
func _soltar_sementes(inimigo: Node2D) -> void:
	if Introducao.ativa():
		return
	SementeDrop.soltar_de(inimigo, principal, _rng_sementes)

## Equipamento com raridade no lugar onde o inimigo morreu (chance e sorteio em equipamento_drop.gd)
func _soltar_equipamento(inimigo: Node2D) -> void:
	if Introducao.ativa():
		return
	var onda: int = gerenciador_ondas.onda_atual if is_instance_valid(gerenciador_ondas) else 1
	var chefe := SementeDrop.eh_chefe(inimigo)
	EquipamentoDrop.soltar_de(inimigo, principal, _rng_equipamentos, onda, chefe)
	if EquipamentoDrop.sortear_moeda_forja(_rng_equipamentos, chefe):
		InventarioJogador.adicionar_moedas_forja()
		InventarioJogador.salvar()
		get_tree().call_group("hud", "avisar_moeda_forja")
