extends SceneTree

func _initialize() -> void:
	var tipo := load("res://recursos/personagens/campo_movimento_medusa.gd")
	for pagina in ["movimento", "garras", "cauda", "bote", "olhar"]:
		for sentido in ["frente", "volta"]:
			var nome: String = pagina + "_" + sentido
			var dados := FileAccess.get_file_as_bytes("res://arte/fontes/inimigos/medusa/fluidez/campos/" + nome + ".bin")
			if dados.size() != 480 * 320 * 2:
				push_error("Campo inválido: " + nome)
				quit(1)
				return
			var campo: Resource = tipo.new()
			campo.vetores = dados
			var erro := ResourceSaver.save(campo, "res://recursos/personagens/medusa/fluxos/" + nome + ".res", ResourceSaver.FLAG_COMPRESS)
			if erro != OK:
				quit(erro)
				return
	quit()
