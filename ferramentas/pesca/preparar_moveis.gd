extends SceneTree

## Adapta os sprites desenhados em grade ampliada à resolução dos móveis do cenário.
## Uso: --script res://ferramentas/pesca/preparar_moveis.gd
func _initialize() -> void:
	var pasta := "res://assets/cenario/praia/mobiliario/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	for entrada: Array in [["bancada_pesca_v2", Vector2i(64, 48)], ["suporte_varas_v2", Vector2i(48, 48)]]:
		var nome: String = entrada[0]
		var limite: Vector2i = entrada[1]
		var imagem := Image.load_from_file("res://arte/fontes/praia/" + nome + "_original.png")
		if imagem == null or imagem.is_empty():
			push_error("Original ausente: " + nome)
			quit(1)
			return
		# Recupera a grade lógica inteira antes de remover margens transparentes.
		# Os originais foram desenhados com blocos ampliados, sem microtexturas.
		imagem.resize(limite.x, limite.y, Image.INTERPOLATE_NEAREST)
		imagem = imagem.get_region(imagem.get_used_rect())
		var erro := imagem.save_png(pasta + nome + ".png")
		if erro != OK:
			push_error("Falha ao salvar " + nome + ": " + str(erro))
			quit(1)
			return
		var importacao := ConfigFile.new()
		var caminho_importacao := pasta + nome + ".png.import"
		importacao.load(caminho_importacao)
		importacao.set_value("remap", "importer", "texture")
		importacao.set_value("remap", "type", "CompressedTexture2D")
		importacao.set_value("params", "mipmaps/generate", false)
		importacao.set_value("params", "process/size_limit", 0)
		importacao.save(caminho_importacao)
		print(nome, ": ", imagem.get_size())
	quit()
