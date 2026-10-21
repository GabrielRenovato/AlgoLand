extends SceneTree
## Capturas reais de todas as fachadas, com saves isolados e quatro estações.
const CASA := "res://codigo/cidade/casa_exterior.gd"
const ESTACOES := ["primavera","verao","outono","inverno"]
var falhas := 0
var relatorio := {}
var pasta: String
func _initialize() -> void: rodar.call_deferred()
func esperar(n := 6) -> void:
	for i in n: await process_frame
func conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)
func fotografar(nome: String) -> void:
	await esperar()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta+"/"+nome+".png")
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	pasta = ProjectSettings.globalize_path("res://arte/previas/nitidez_exteriores")
	DirAccess.make_dir_recursive_absolute(pasta)
	for cena in ["cidade","fazenda","praia"]:
		change_scene_to_file("res://cenas/"+cena+".tscn")
		await esperar(30)
		var jogador = current_scene.get_node("Jogador")
		jogador.set_physics_process(false)
		jogador.position = Vector2(4000,4000)
		jogador.visible = false
		var camera: Camera2D = jogador.camera
		camera.position_smoothing_enabled = false
		camera.set_as_top_level(true)
		camera.limit_enabled = false
		camera.zoom = Vector2.ONE
		for hud in get_nodes_in_group("hud"): hud.hide()
		if current_scene.has_node("Interface"): current_scene.get_node("Interface").hide()
		var luz = current_scene.get_node_or_null("Iluminacao")
		if luz != null:
			luz.hora = 12.0
			luz.set_process(false)
			luz._aplicar()
		var casas: Array[Node] = []
		for no in current_scene.find_children("*","Node2D",true,false):
			if no.get_script()!=null and no.get_script().resource_path==CASA: casas.append(no)
		var estacoes = current_scene.get_node_or_null("Terrains/Estacoes")
		for e in 4:
			if estacoes != null: estacoes.definir_estacao(e,true)
			root.get_node("Calendario").dia = e*root.get_node("Calendario").DIAS_POR_ESTACAO+1
			await esperar(12)
			for casa in casas:
				var sprite: Sprite2D = casa.get_node("Fachada")
				var detalhe = casa.get_node("DetalheAmbiente")
				conferir(detalhe.estacao==e,"Fachada usa estação do mapa: "+casa.id)
				conferir(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"Amostragem de alta resolução: "+casa.id)
				camera.global_position = casa.global_position + Vector2(0,-48)
				camera.reset_smoothing()
				await fotografar(cena+"-"+casa.id+"-"+ESTACOES[e])
				conferir(sprite.texture.get_image().has_mipmaps(),"Detalhes preservados nas escalas de tela: "+casa.id)
				var imagem := sprite.texture.get_image().get_region(Rect2i(0,0,int(sprite.texture.get_width()/sprite.hframes),sprite.texture.get_height()))
				var cores := {}
				var alfa_parcial := 0
				for y in imagem.get_height():
					for x in imagem.get_width():
						var cor := imagem.get_pixel(x,y)
						if cor.a>0.5: cores[cor.to_rgba32()]=true
						if cor.a>0.0 and cor.a<1.0: alfa_parcial+=1
				var chave: String = cena+"/"+casa.id+"/"+ESTACOES[e]
				relatorio[chave] = {"cores":cores.size(),"alfa_parcial":alfa_parcial,"tamanho":str(imagem.get_size()),"filtro":"linear_mipmaps"}
				var dados: Dictionary = load("res://codigo/cidade/fachadas_detalhadas.gd").dados(casa.id)
				conferir((sprite.texture.get_size()*sprite.scale).is_equal_approx(Vector2(dados.canvas_logico[0],dados.canvas_logico[1])),"Tamanho lógico preservado: "+chave)
				if casa.id in ["forja","carpintaria"]:
					conferir(sprite.scale.is_equal_approx(Vector2(.25,.25)),"Escala lógica preservada: "+chave)
					conferir(imagem.get_width()>=512,"Fonte em alta resolução: "+chave)
					var textura := sprite.texture
					var quadros := sprite.hframes
					var escala := sprite.scale
					var deslocamento := sprite.offset
					var filtro := sprite.texture_filter
					detalhe.set_process(false)
					var antiga := Image.load_from_file("res://arte/fontes/cenario/exteriores_nitidos/"+casa.id+"/referencia/"+str(e)+".png")
					sprite.texture = ImageTexture.create_from_image(antiga)
					sprite.hframes = 1
					sprite.scale = Vector2.ONE
					sprite.offset /= 4.0
					sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					await fotografar("antes-"+casa.id+"-"+ESTACOES[e])
					sprite.texture = textura
					sprite.hframes = quadros
					sprite.scale = escala
					sprite.offset = deslocamento
					sprite.texture_filter = filtro
					detalhe.set_process(true)
			camera.global_position = Vector2(352,288) if cena=="cidade" else (Vector2(400,300) if cena=="fazenda" else Vector2(400,240))
			await fotografar("geral-"+cena+"-"+ESTACOES[e])
		if cena=="cidade":
			luz.hora=21.0
			luz._aplicar()
			camera.global_position=Vector2(336,180)
			await esperar(100)
			await fotografar("geral-cidade-noite")
	var arquivo := FileAccess.open(pasta+"/auditoria.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(relatorio,"  "))
	print("NITIDEZ EXTERIORES: ",falhas," falhas; ",relatorio.size()," fachadas/estações conferidas")
	quit(1 if falhas else 0)
