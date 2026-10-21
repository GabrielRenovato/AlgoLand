extends SceneTree
## Revisão da corrida vestida nas quatro direções, sempre em projeto com saves isolados.
const RAIZ := "res://assets/personagens/raven_fantasy/estudo_corrida/"
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		falhas += 1
		push_error(mensagem)
func rodar() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RAIZ+"manifesto.json"))
	verificar(int(dados.quadros) == 6 and int(dados.pivo[0]) == 40 and int(dados.pivo[1]) == 47,"Grade e pivô do estudo")
	# Os 28 cabelos devem conservar cada quadro original, incluindo o balanço da cabeça.
	var acoes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/personagens/raven_fantasy/camadas/acoes.json"))
	var y := int(acoes.find("correr"))*320
	for cabelo in range(1,29):
		var caminho := "cabelo_%d.png" % cabelo
		var adaptado := (load(RAIZ+caminho) as Texture2D).get_image()
		var original := (load("res://assets/personagens/raven_fantasy/camadas/"+caminho) as Texture2D).get_image()
		for direcao in 4:
			for i in 6:
				var origem: int = dados.sequencia_origem[i]
				verificar(adaptado.get_region(Rect2i(i*80,direcao*80,80,80)).get_data() == original.get_region(Rect2i(origem*80,y+direcao*80,80,80)).get_data(),"Cabelo preservado %d / %d / %d" % [cabelo,direcao,i])
	var vp := SubViewport.new()
	vp.size = Vector2i(160,320)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var sprites: Array[Sprite2D] = []
	for direcao in 4:
		for indice in 2:
			var nome: String = ["azul_sem_capa","verde_com_capa"][indice]
			for camada: String in dados.exemplos[nome]:
				var sprite := Sprite2D.new()
				sprite.texture = load(RAIZ+camada+".png")
				sprite.hframes = 6
				sprite.vframes = 4
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.position = Vector2(40+indice*80,40+direcao*80)
				sprite.set_meta("direcao",direcao)
				vp.add_child(sprite)
				sprites.append(sprite)
	var tela := TextureRect.new()
	tela.texture = vp.get_texture()
	tela.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tela.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tela.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(tela)
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-raven-corrida-vestida")
	for ciclo in 2:
		for i in 6:
			for sprite in sprites: sprite.frame = int(sprite.get_meta("direcao"))*6+i
			await create_timer(float(dados.duracoes_ms[i])/1000.0).timeout
			await RenderingServer.frame_post_draw
			if ciclo == 0:
				var imagem := vp.get_texture().get_image()
				imagem.save_png("/tmp/algoland-raven-corrida-vestida/%02d.png" % i)
				for direcao in 4:
					for indice in 2:
						var nome: String = ["azul_sem_capa","verde_com_capa"][indice]
						var esperado := (load(RAIZ+"previa_"+nome+".png") as Texture2D).get_image().get_region(Rect2i(i*80,direcao*80,80,80))
						for py in 80:
							for px in 80:
								var cor := esperado.get_pixel(px,py)
								var atual := imagem.get_pixel(indice*80+px,direcao*80+py)
								if absf(cor.a-atual.a)>0.01 or (cor.a>0.5 and (absf(cor.r-atual.r)>0.01 or absf(cor.g-atual.g)>0.01 or absf(cor.b-atual.b)>0.01)):
									verificar(false,"Ordem/encaixe: %s direção %d quadro %d" % [nome,direcao,i])
									break
	print("CORRIDA RAVEN VESTIDA: ",falhas," falhas; 28 cabelos intactos, duas roupas, quatro direções, seis poses e dois ciclos no Godot.")
	tela.free()
	vp.free()
	quit.call_deferred(1 if falhas else 0)
