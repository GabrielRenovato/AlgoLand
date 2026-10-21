extends SceneTree
## Compara a renderização original/refinada sem mudar geometria, em save isolado.
const Raven := preload("res://codigo/dados/aparencia_raven.gd")
const Paleta := preload("res://codigo/dados/paleta_raven.gd")
var falhas := 0

func _initialize() -> void: rodar.call_deferred()

func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)

func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var vp := SubViewport.new()
	vp.size = Vector2i(480,80)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var sprites: Array[Sprite2D] = []
	var estilos := [
		["corpo_0","calca_marrom","camisa_azul","botas","luvas","ferramentas","cabelo_1"],
		["corpo_1","calca_jeans","camisa_verde","botas","luvas","capa","ferramentas","cabelo_3"],
		["corpo_2","calca_jeans","camisa_verde","botas","luvas","capa","ferramentas","cabelo_28"],
	]
	for estilo in 3:
		for versao in 2:
			for nome: String in estilos[estilo]:
				var sprite := Sprite2D.new()
				sprite.hframes = 4
				sprite.vframes = 4
				sprite.centered = false
				sprite.position.x = (estilo*2+versao)*80
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.set_meta("camada",nome)
				if versao == 1:
					sprite.material = Raven.material_cabelo() if nome.begins_with("cabelo_") else Raven.material_corpo()
				vp.add_child(sprite)
				sprites.append(sprite)
	var cores := {}
	for origem: String in Paleta.CORES:
		cores[origem.hex_to_int()] = str(Paleta.CORES[origem]).hex_to_int()
	var acoes: Array = JSON.parse_string(FileAccess.get_file_as_string(Raven.RAIZ+"camadas/acoes.json"))
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-raven-acabamento")
	var capturas := {}
	var comparacoes := 0
	for acao: String in acoes:
		for sprite in sprites: sprite.texture = Raven.folha(str(sprite.get_meta("camada")),acao)
		for quadro in 16:
			for sprite in sprites: sprite.frame = quadro
			await process_frame
			await RenderingServer.frame_post_draw
			var imagem := vp.get_texture().get_image()
			var pixels := imagem.get_data()
			var correto := true
			for estilo in 3:
				for y in 80:
					for x in 80:
						var a := (y*480+estilo*160+x)*4
						var b := a+80*4
						if pixels[a+3] != pixels[b+3]: correto = false
						if pixels[a+3] == 255:
							var rgb := (int(pixels[a])<<16)+(int(pixels[a+1])<<8)+int(pixels[a+2])
							var esperado: int = cores.get(rgb,rgb)
							if absi(int(pixels[b])-((esperado>>16)&255))>1 or absi(int(pixels[b+1])-((esperado>>8)&255))>1 or absi(int(pixels[b+2])-(esperado&255))>1:
								correto = false
			verificar(correto,"Paleta/alfa renderizados: %s quadro %d" % [acao,quadro])
			comparacoes += 3
			if acao in ["parado","correr","espada","espada_2"]:
				capturas["%s-%02d" % [acao,quadro]] = imagem
	for chave: String in capturas: capturas[chave].save_png("/tmp/algoland-raven-acabamento/"+chave+".png")
	print("ACABAMENTO RAVEN: ",falhas," falhas; ",comparacoes," comparações de cor e alfa, 25 ações, quatro direções, quatro quadros e três conjuntos.")
	vp.free()
	quit.call_deferred(1 if falhas else 0)
