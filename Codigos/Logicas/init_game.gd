extends Node2D
@export var save_file_path: String = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
# Define o caminho para o diretório "Documentos"
	var documents_dir = OS.get_user_data_dir()
	save_file_path = documents_dir.path_join("configuracao_jogador.json")
	print("Arquivo será buscado em: ", save_file_path)



func _on_start_game_pressed() -> void:
	# Verifica se o arquivo de save existe usando FileAccess
	if FileAccess.file_exists(save_file_path):
		print("Arquivo de save encontrado!")
		
		# Carrega a cena "cenario"
		var scene = load("res://cenas/cenario.tscn")
		var instance = scene.instantiate()
		
		# Limpa a cena atual e adiciona a nova cena à árvore
		get_tree().root.add_child(instance)
		get_tree().current_scene.queue_free()  # Remove a cena atual
		get_tree().current_scene = instance    # Define a nova cena como atual
	else:
		var scene = load("res://cenas/customizacao-de-personagem.tscn")
		var instance = scene.instantiate()
		
		# Limpa a cena atual e adiciona a nova cena à árvore
		get_tree().root.add_child(instance)
		get_tree().current_scene.queue_free()  # Remove a cena atual
		get_tree().current_scene = instance    # Define a nova cena como atual
