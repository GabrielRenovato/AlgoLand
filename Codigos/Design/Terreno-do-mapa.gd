extends Node2D

@onready var barraca_aberta = $BarracaAberta
@onready var barraca_fechada = $BarraFechada
# Na tela inicial o spawner não existe, por isso o get_node_or_null
@onready var gerenciador_ondas = get_node_or_null("../enemySpawner/GerenciadorOndas")

func _ready() -> void:
	$"BarraFechada/1".collision_enabled = false
	if gerenciador_ondas:
		gerenciador_ondas.onda_iniciada.connect(onda_iniciada)
		gerenciador_ondas.onda_completada.connect(onda_completada)
		gerenciador_ondas.sinal_ondas_paradas.connect(ondas_paradas)

func onda_iniciada(_onda: int) -> void:
	barraca_aberta.visible = false
	barraca_fechada.visible = true
	$"BarraFechada/1".collision_enabled = true

func onda_completada(_onda: int) -> void:
	barraca_aberta.visible = true
	barraca_fechada.visible = false
	$"BarraFechada/1".collision_enabled = false

func ondas_paradas() -> void:
	barraca_aberta.visible = true
	barraca_fechada.visible = false
	$"BarraFechada/1".collision_enabled = false
