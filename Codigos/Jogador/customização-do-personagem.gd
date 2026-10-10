extends Node2D

@onready var personalizacao_jogador = $PersonalizacaoJogador # O novo node com script "PersonalizacaoJogador.gd"

func _ready() -> void:
	# Conecta o sinal do personalizacao_jogador
	personalizacao_jogador.connect("personalizacao_finalizada", Callable(self, "_ao_personalizacao_jogador_finalizada"))

func _ao_personalizacao_jogador_finalizada(cabelo, roupa, cor, apelido):
	# Aqui você faz a lógica de salvamento em JSON (ou delega ao personalizacao_jogador).
	# Em seguida, carrega a cena principal do jogo.
	print("Personalização concluída! Cabelo:", cabelo, "Roupa:", roupa, "Cor:", cor, "Apelido:", apelido)

	# Salvar em JSON:
	var dados_cor_cabelo = {
		"r": cor.r,
		"g": cor.g,
		"b": cor.b,
		"a": cor.a
	}
	var dados = {
		"cabelo_atual": cabelo,
		"roupa_atual": roupa,
		"apelido": apelido,
		"cor_cabelo": dados_cor_cabelo
	}

	var diretorio_documentos = OS.get_user_data_dir()
	var caminho_arquivo = diretorio_documentos.path_join("configuracao_jogador.json")

	var arquivo = FileAccess.open(caminho_arquivo, FileAccess.WRITE)
	if arquivo == null:
		print("Erro ao abrir o arquivo para escrita.")
		return

	var string_json = JSON.stringify(dados)
	arquivo.store_string(string_json)
	arquivo.close()

	# Transição para a cena principal utilizando change_scene_to_file (Godot 4)
	get_tree().change_scene_to_file("res://cenas/cenario.tscn")
