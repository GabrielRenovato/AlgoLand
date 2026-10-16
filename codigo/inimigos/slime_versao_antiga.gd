extends "inimigo_base.gd"

class_name InimigoSlime

# Referência ao jogador
@onready var jogador = get_node("/root/cenario/Jogador")

# -----------------------------
# CONFIGURAÇÕES ESPECÍFICAS DO SLIME
# -----------------------------
@export var propriedade_especifica_slime: int = 42  # Exemplo de propriedade específica do slime

# -----------------------------
# IMPLEMENTAÇÃO DE MÉTODOS ABSTRATOS
# -----------------------------
func obter_jogador() -> Node2D:
	return jogador

# -----------------------------
# COMPORTAMENTOS ESPECÍFICOS DO SLIME
# -----------------------------
func _ready() -> void:
	# Chama o _ready do BaseInimigo
	super()
	
	# Configurações específicas do slime
	if arvore_animacao:
		arvore_animacao.active = true
		definir_animacao("run")  # Define animação inicial específica do slime

func _physics_process(delta: float) -> void:
	# Chama o _physics_process do BaseInimigo, passando o argumento delta
	super(delta)
	
	# Adiciona comportamentos específicos do slime aqui, se necessário
	pass

# Exemplo de método específico do slime
func comportamento_especial_slime():
	print("Executando comportamento especial do slime!")
