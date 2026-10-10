extends Node2D

@onready var barraca_aberta = $BarracaAberta
@onready var barraca_fechada = $BarraFechada
@onready var gerenciador_ondas = $"../enemySpawner/GerenciadorOndas"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"BarraFechada/1".collision_enabled = false
	if gerenciador_ondas:
		gerenciador_ondas.connect("onda_iniciada", Callable(self, "_on_onda_iniciada"))
		gerenciador_ondas.connect("onda_completada", Callable(self, "_on_onda_completada"))
		gerenciador_ondas.connect("sinal_ondas_paradas",  Callable(self, "_on_ondas_paradas"))
	


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
