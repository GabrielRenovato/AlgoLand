extends Node2D  # Mantém o Node2D como base

func _ready():
	# Criar um nó de partículas
	var particulas_de_neve = CPUParticles2D.new()
	add_child(particulas_de_neve)  # Adicionar ao nó principal

	# Configurar as partículas
	particulas_de_neve.emitting = true
	particulas_de_neve.amount = 500  # Número de partículas (flocos de neve)
	particulas_de_neve.lifetime = 5.0  # Tempo de vida dos flocos
	particulas_de_neve.one_shot = false  # Neve contínua
	particulas_de_neve.speed_scale = 0.5  # Velocidade mais lenta
	particulas_de_neve.position = Vector2(0, -100)  # Posição inicial das partículas

	# **Espalhar os flocos na tela**
	particulas_de_neve.emission_rect_extents = Vector2(300, 50)  # Área de emissão mais larga
	particulas_de_neve.gravity = Vector2(0, 10)  # Faz os flocos caírem mais devagar

	# Configuração do movimento dos flocos
	particulas_de_neve.direction = Vector2(0, 1)  # Direção para baixo
	particulas_de_neve.spread = 180  # Faz os flocos irem para várias direções
	particulas_de_neve.initial_velocity_min = 5
	particulas_de_neve.initial_velocity_max = 15
