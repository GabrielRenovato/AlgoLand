extends Node

signal onda_iniciada(onda: int)
signal onda_completada(onda: int)
signal jogo_ganho()
signal sinal_ondas_paradas
signal inimigos_alterados(vivos: int, total: int)

@export var onda_inicial: int = 1
@export var max_inimigos: int = 5	
@export var intervalo_onda: float = 15.0
@export var max_ondas: int = 1000
@export var aumento_deteccao_por_onda: float = 0.2
@export var inimigos_extra_por_onda: int = 3
@export var recompensa_ouro_base: int = 25
@export var recompensa_ouro_por_onda: int = 15
@export var moedas_por_inimigo_base: int = 3
@onready var comerciante = $"../../Merchant"
## A cada N ondas vem o chefe (10, 20, 30...); 0 desliga
@export var intervalo_chefe: int = 10
## Slimes que acompanham o chefe; poucos para a luta ser contra ele
@export var escolta_chefe: int = 4
const CENA_CHEFE := preload("res://cenas/inimigos/golem.tscn")
const MAX_INIMIGOS_POR_ONDA: int = 60
const MAX_INIMIGOS_ATIVOS: int = 25
@export var caminho_area_spawn: NodePath = NodePath("/root/cenario/SpawnArea")

var onda_atual: int = 1
var inimigos_vivos: int = 0
var total_inimigos_onda: int = 0
var gerador
var area_spawn: Area2D
var ondas_paradas: bool = false

var multiplicador_vida_inimigo: float = 1.0
var multiplicador_dano_inimigo: float = 1.0

var onda_em_andamento: bool = false

@onready var jogador = get_node("/root/cenario/Jogador")
func _ready() -> void:
	add_to_group("gerenciador_ondas")
	await get_tree().create_timer(0.0).timeout
	onda_atual = onda_inicial
	gerador = get_tree().get_root().get_node("/root/cenario/enemySpawner")
	area_spawn = get_node(caminho_area_spawn)

func iniciar_onda() -> void:
	ondas_paradas = false
	if jogador.estaMorto:
		onda_atual = 1
		jogador.estaMorto = false
	if ondas_paradas:
		return
	if onda_atual > max_ondas:
		emit_signal("jogo_ganho")
		return
	comerciante.visible = false
	onda_em_andamento = true
	var chefe := eh_onda_chefe(onda_atual)
	if chefe:
		inimigos_vivos = 1 + escolta_chefe
	else:
		inimigos_vivos = min(max_inimigos + inimigos_extra_por_onda * (onda_atual - 1), MAX_INIMIGOS_POR_ONDA)
	total_inimigos_onda = inimigos_vivos
	multiplicador_vida_inimigo = 1.0 + 0.15 * (onda_atual - 1)
	multiplicador_dano_inimigo = 1.0 + 0.08 * (onda_atual - 1)
	emit_signal("onda_iniciada", onda_atual)
	atualizar_ui()
	if chefe:
		gerador.spawnar_inimigos(1, multiplicador_vida_inimigo, multiplicador_dano_inimigo, CENA_CHEFE)
		gerador.spawnar_inimigos(escolta_chefe, multiplicador_vida_inimigo, multiplicador_dano_inimigo)
	else:
		gerador.spawnar_inimigos(inimigos_vivos, multiplicador_vida_inimigo, multiplicador_dano_inimigo)

func eh_onda_chefe(onda: int) -> bool:
	return intervalo_chefe > 0 and onda % intervalo_chefe == 0

func atualizar_ui() -> void:
	inimigos_alterados.emit(inimigos_vivos, total_inimigos_onda)

func inimigo_morreu() -> void:
	DadosJogo.adicionar_moedas(moedas_por_inimigo_base + int(onda_atual / 4.0))
	_descontar_inimigo()

# Spawn que falhou: encerra a onda sem dar moedas de abate
func descontar_inimigo_nao_spawnado() -> void:
	_descontar_inimigo()

func _descontar_inimigo() -> void:
	inimigos_vivos -= 1
	atualizar_ui()
	if inimigos_vivos <= 0:
		var recompensa = recompensa_ouro_base + recompensa_ouro_por_onda * onda_atual
		DadosJogo.adicionar_moedas(recompensa)
		comerciante.visible = true
		get_tree().call_group("tela_mercante", "atualizar_exibicao_moedas")
		onda_em_andamento = false
		emit_signal("onda_completada", onda_atual)
		onda_atual += 1

func parar_ondas() -> void:
	ondas_paradas = true
	emit_signal("sinal_ondas_paradas")
	comerciante.visible = true
	var lista_inimigos = get_tree().get_nodes_in_group("enemy")
	for inimigo in lista_inimigos:
		inimigo.queue_free()
	onda_atual = 1
	inimigos_vivos = 0
	onda_em_andamento = false
