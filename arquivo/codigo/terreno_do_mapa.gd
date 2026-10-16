extends Node2D

@onready var barraca_aberta = $BarracaAberta
@onready var barraca_fechada = $BarraFechada
# Colisão da barraca aberta (faixa no chão que segue o contorno da lona); some junto com ela nas ondas
@onready var colisao_barraca_aberta: CollisionPolygon2D = $BarracaAberta/Colisao/Forma
# Na tela inicial o spawner não existe, por isso o get_node_or_null
@onready var gerenciador_ondas = get_node_or_null("../enemySpawner/GerenciadorOndas")

func _ready() -> void:
	_mostrar_barraca(true)
	if gerenciador_ondas:
		gerenciador_ondas.onda_iniciada.connect(onda_iniciada)
		gerenciador_ondas.onda_completada.connect(onda_completada)
		gerenciador_ondas.sinal_ondas_paradas.connect(ondas_paradas)

func onda_iniciada(_onda: int) -> void:
	_mostrar_barraca(false)

func onda_completada(_onda: int) -> void:
	_mostrar_barraca(true)

func ondas_paradas() -> void:
	_mostrar_barraca(true)

# Barraca aberta (mercador atendendo) entre as ondas, fechada durante a onda
func _mostrar_barraca(aberta: bool) -> void:
	barraca_aberta.visible = aberta
	barraca_fechada.visible = not aberta
	colisao_barraca_aberta.set_deferred("disabled", not aberta)
	$"BarraFechada/1".collision_enabled = not aberta
