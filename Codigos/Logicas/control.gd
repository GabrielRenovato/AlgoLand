extends CanvasLayer  # Agora o script pode ser usado no CanvasLayer

@onready var rotulo_onda = $wave/WaveLabel
@onready var rotulo_inimigos = $enemiesCount/enemies_label

var gerenciador_ondas

func _ready():
	gerenciador_ondas = get_tree().get_root().get_node("/root/cenario/enemySpawner/GerenciadorOndas")

	if gerenciador_ondas:
		# Conectar eventos para atualizar UI
		gerenciador_ondas.connect("onda_iniciada", Callable(self, "_ao_onda_iniciada"))
		gerenciador_ondas.connect("onda_completada", Callable(self, "_ao_onda_completada"))
	else:
		print("❌ ERRO: GerenciadorOndas não encontrado!")

func _ao_onda_iniciada(onda: int):
	rotulo_onda.text = str(onda)
	rotulo_inimigos.text = "Inimigos: " + str(gerenciador_ondas.inimigos_vivos)

func _ao_onda_completada(_onda: int) -> void:
	rotulo_inimigos.text = "Inimigos: 0"
