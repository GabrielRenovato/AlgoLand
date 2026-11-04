extends SceneTree
## Regressões reais de pixels: silhueta, degraus e oclusão dos atores no portal.
var falhas := 0
func _initialize() -> void:
	rodar.call_deferred()
func conferir(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func rodar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A verificacao exige renderizacao grafica real.")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(512, 448)
	root.size = Vector2i(512, 448)
	var entrada := preload("res://codigo/campanha/entrada_dungeon_bacia_3d.gd").new()
	entrada.position = Vector2(256, 320)
	root.add_child(entrada)
	var camera: Camera3D = entrada._visor.get_camera_3d()
	for estacao in 4:
		entrada.definir_estacao(estacao)
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		var imagem: Image = entrada._visor.get_texture().get_image()
		var frente: Image = entrada._frente_visor.get_texture().get_image()
		var vazou := false
		for x in [-1.65, 1.65]:
			var p := Vector2i(camera.unproject_position(Vector3(x, 6.8, 0)))
			vazou = vazou or imagem.get_pixelv(p).a > 0.01
		conferir("fundo contido no arco, estacao %d" % estacao, not vazou)
		var externo := Vector2i(camera.unproject_position(Vector3(0, 0.18, 2.1)))
		conferir("fachada nao cobre degrau externo, estacao %d" % estacao, frente.get_pixelv(externo).a < 0.01 and imagem.get_pixelv(externo).a > 0.9)
		var topo := Vector2i(camera.unproject_position(Vector3(-1.6, 3.7, 0)))
		var baixo := Vector2i(camera.unproject_position(Vector3(1.6, 0.6, 0)))
		var cores: Dictionary = {}
		for y in range(topo.y, baixo.y):
			for x in range(topo.x, baixo.x):
				var cor := imagem.get_pixel(x, y)
				if cor.a > 0.9:
					cores[Vector3i(int(cor.r * 31), int(cor.g * 31), int(cor.b * 31))] = true
		conferir("interior tem paredes e variacao visivel, estacao %d" % estacao, cores.size() >= 20)
		# Um ator de cor conhecida testa a composição efetiva, além dos viewports.
		var ator := Polygon2D.new()
		ator.polygon = PackedVector2Array([Vector2(-5, -22), Vector2(5, -22), Vector2(5, 10), Vector2(-5, 10)])
		ator.color = Color("f51bcc")
		root.add_child(ator)
		var posicoes := [Vector2(0, 32), Vector2(0, -12), Vector2(40, -12)]
		for i in posicoes.size():
			ator.position = entrada.position + posicoes[i]
			ator.z_index = preload("res://codigo/globais/profundidade.gd").z_de(ator.position.y + 11)
			for quadro in 3: await process_frame
			await RenderingServer.frame_post_draw
			var tela := root.get_texture().get_image()
			if estacao == 0: tela.save_png("/tmp/entrada-oclusao-ator-%d.png" % i)
			var cor := tela.get_pixelv(Vector2i(ator.position + Vector2(0, -8)))
			var visivel := cor.r > 0.8 and cor.g < 0.2 and cor.b > 0.7
			conferir("ator %s, estacao %d" % [["visivel nos degraus", "visivel dentro do vao", "oculto pelo pilar"][i], estacao], visivel == (i < 2))
		ator.queue_free()
	entrada.queue_free()
	await process_frame
	print("FALHAS_ENTRADA_VISUAL: ", falhas)
	quit(1 if falhas else 0)
