extends SceneTree
## Espada de uma mão e montante no personagem 3D: parado (nas costas) e quatro momentos do golpe,
## de frente e de lado, no andar 1. Save isolado.
const SAIDA := "res://arte/previas/personagens/base_3d/espadas/"
const RECORTE := 120
const AMPLIAR := 3
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/cidade.tscn")
	for i in 40: await process_frame
	root.get_node("Transicao").limpar()
	set_meta("visual_base_3d_p1", true)
	root.get_node("Transicao").entrar_na_arena()
	for i in 600:
		await process_frame
		if current_scene.scene_file_path.contains("fendas/andar_") and not root.get_node("Transicao").ocupada: break
	for i in 60: await process_frame
	var j = current_scene.get_node("Jogador")
	var heroi = j.get_node("HeroiBase3D")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var folha := Image.create(RECORTE*AMPLIAR*5, RECORTE*AMPLIAR*4, false, Image.FORMAT_RGBA8)
	var linha := 0
	for arma in ["espada_basica", "espada_gemea"]:
		for direcao in [Vector2.DOWN, Vector2.RIGHT]:
			j.usando_espada = true
			j.usando_arco = false
			j.usando_lanca = false
			j.id_arma_atual = arma
			j._direcao_ataque = direcao
			for i in 30: await physics_frame
			for q in 5:
				if q == 1:
					j._direcao_ataque = direcao
					j._pedido_ataque = true
				for i in (1 if q == 0 else 5): await physics_frame
				await RenderingServer.frame_post_draw
				var img := root.get_texture().get_image()
				var escala := Vector2(img.get_size())/root.get_visible_rect().size
				var centro: Vector2 = j.get_global_transform_with_canvas().origin*escala
				var parte := img.get_region(Rect2i(Vector2i(centro)-Vector2i(RECORTE/2, RECORTE*2/3), Vector2i(RECORTE, RECORTE)))
				parte.convert(Image.FORMAT_RGBA8)
				parte.resize(RECORTE*AMPLIAR, RECORTE*AMPLIAR, Image.INTERPOLATE_NEAREST)
				folha.blit_rect(parte, Rect2i(0, 0, RECORTE*AMPLIAR, RECORTE*AMPLIAR), Vector2i(q*RECORTE*AMPLIAR, linha*RECORTE*AMPLIAR))
			for i in 40: await physics_frame
			linha += 1
	folha.save_png(SAIDA+"folha.png")
	print("ESPADAS ok duas_maos_no_fim=", heroi._arma_de_duas_maos())
	quit()
