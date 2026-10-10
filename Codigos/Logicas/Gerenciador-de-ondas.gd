extends Node

signal onda_iniciada(onda: int)
signal onda_completada(onda: int)
signal jogo_ganho()
signal sinal_ondas_paradas

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
const MAX_INIMIGOS_POR_ONDA: int = 60
const MAX_INIMIGOS_ATIVOS: int = 25
@export var caminho_area_spawn: NodePath = NodePath("/root/cenario/SpawnArea")

var onda_atual: int = 1
var inimigos_vivos: int = 0
var gerador
var area_spawn: Area2D
var ondas_paradas: bool = false

var multiplicador_vida_inimigo: float = 1.0
var multiplicador_dano_inimigo: float = 1.0

var onda_em_andamento: bool = false

@onready var jogador = get_node("/root/cenario/Jogador")
@onready var ui = get_node("/root/cenario/UI")
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
	emit_signal("onda_iniciada", onda_atual)
	comerciante.visible = false
	onda_em_andamento = true
	# Define o total de inimigos para a onda no início
	inimigos_vivos = min(max_inimigos + inimigos_extra_por_onda * (onda_atual - 1), MAX_INIMIGOS_POR_ONDA)
	multiplicador_vida_inimigo = 1.0 + 0.15 * (onda_atual - 1)
	multiplicador_dano_inimigo = 1.0 + 0.08 * (onda_atual - 1)
	var banner_onda = get_tree().get_root().get_node("cenario/UI/wave")
	if banner_onda:
		banner_onda.show_wave_number(onda_atual)
	atualizar_ui()
	# Chama o gerador para criar os inimigos
	gerador.spawnar_inimigos(inimigos_vivos, multiplicador_vida_inimigo, multiplicador_dano_inimigo)

func atualizar_ui() -> void:
	if ui:
		ui.rotulo_inimigos.text = "Inimigos: " + str(inimigos_vivos)

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
	if ui:
		ui.rotulo_inimigos.text = "Inimigos"
