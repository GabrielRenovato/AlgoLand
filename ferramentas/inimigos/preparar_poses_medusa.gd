extends SceneTree
## Empacota quadros do PixelLab sem redimensionar ou recentralizar cada pose.
const FONTES := "res://arte/fontes/inimigos/medusa/pixellab/"
const DESTINO := "res://assets/inimigos/medusa/poses/"
const DIRECOES := ["baixo", "cima", "direita", "esquerda"]

func _initialize() -> void:
	for pagina in ["garras", "cauda", "bote", "olhar"]:
		var caminho: String = FONTES + pagina + "/manifesto.json"
		if not FileAccess.file_exists(caminho):
			continue
		var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho))
		# A página só é ativada depois de obter e revisar suas quatro direções.
		if not manifesto.get("integrar", false):
			continue
		if not preparar(pagina, manifesto):
			quit(1)
			return
	quit()

func preparar(pagina: String, manifesto: Dictionary) -> bool:
	var lado: int = manifesto.get("lado", 256)
	var animacoes := SpriteFrames.new()
	animacoes.remove_animation("default")
	animacoes.set_meta("raiz", Vector2(lado / 2, lado / 2 + 56))
	animacoes.set_meta("origem", str(manifesto.get("origem", "PixelLab")) + "; " + str(manifesto.jobs))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	for nome in DIRECOES:
		var quantidade: int = manifesto.quadros[nome] if manifesto.quadros is Dictionary else manifesto.quadros
		var chaves: Array = manifesto.chaves[nome] if manifesto.chaves is Dictionary else manifesto.chaves
		var colunas := mini(4, quantidade)
		var linhas := ceili(float(quantidade) / colunas)
		var atlas := Image.create(colunas * lado, linhas * lado, false, Image.FORMAT_RGBA8)
		for quadro in quantidade:
			var arquivo: String = FONTES + pagina + "/" + nome + "/quadro_%02d.png" % quadro
			var imagem := Image.load_from_file(arquivo)
			if imagem == null or imagem.get_size() not in [Vector2i(160, 160), Vector2i(lado, lado)]:
				push_error("Quadro ausente ou grade incorreta: " + arquivo)
				return false
			imagem.convert(Image.FORMAT_RGBA8)
			if imagem.get_width() != lado:
				var celula := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
				var margem := (lado - 160) / 2
				celula.blit_rect(imagem, Rect2i(0, 0, 160, 160), Vector2i(margem, margem))
				imagem = celula
			for y in lado:
				for x in lado:
					var cor := imagem.get_pixel(x, y)
					cor.a = 1 if cor.a >= 0.5 else 0
					imagem.set_pixel(x, y, cor if cor.a > 0 else Color.TRANSPARENT)
			atlas.blit_rect(imagem, Rect2i(0, 0, lado, lado), Vector2i((quadro % colunas) * lado, (quadro / colunas) * lado))
		var atlas_path: String = DESTINO + pagina + "_" + nome + ".png"
		atlas.save_png(atlas_path)
		if "--somente-atlas" in OS.get_cmdline_user_args():
			continue
		var textura := load(atlas_path) as Texture2D
		if textura == null:
			push_error("Importe o atlas no editor e execute o preparador novamente: " + atlas_path)
			return false
		animacoes.add_animation(nome)
		animacoes.set_animation_loop(nome, false)
		animacoes.set_animation_speed(nome, 16)
		animacoes.set_meta("chaves_" + nome, PackedInt32Array(chaves))
		for quadro in quantidade:
			var regiao := AtlasTexture.new()
			regiao.atlas = textura
			regiao.region = Rect2((quadro % colunas) * lado, (quadro / colunas) * lado, lado, lado)
			animacoes.add_frame(nome, regiao)
		if manifesto.has("olhos") and manifesto.olhos.has(nome):
			var pontos: Array = []
			for ponto in manifesto.olhos[nome]:
				pontos.append(Vector2(ponto[0], ponto[1]))
			animacoes.set_meta("olhos_" + nome, pontos)
	if "--somente-atlas" in OS.get_cmdline_user_args():
		return true
	return ResourceSaver.save(animacoes, DESTINO + pagina + ".tres") == OK
