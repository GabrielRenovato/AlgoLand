extends SceneTree
## Liga o personagem base 3D na fazenda (save isolado) e fotografa no mapa:
## quatro direções × (parado, quatro quadros de corrida, quatro de golpe).
const SAIDA := "res://arte/previas/personagens/base_3d/"
var RECORTE := 150
var AMPLIAR := 2
func _initialize():
	rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	if "--perto" in OS.get_cmdline_user_args():
		RECORTE = 160
		AMPLIAR = 3
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	for i in 35: await process_frame
	root.get_node("Transicao").limpar()
	root.get_node("PainelDebug")._ativar_base_3d("--roupas" in OS.get_cmdline_user_args())
	var jogador = current_scene.get_node("Jogador")
	var heroi = jogador.get_node("HeroiBase3D")
	for i in 10: await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	root.get_texture().get_image().save_png(SAIDA+"no_mapa.png")
	heroi.set_process(false)
	var raven = jogador.get_node("HeroiRaven")
	var colunas := 9
	var folha := Image.create(RECORTE*AMPLIAR*colunas, RECORTE*AMPLIAR*4, false, Image.FORMAT_RGBA8)
	for d in 4:
		for q in colunas:
			heroi.visible = true
			raven.visible = false
			heroi._modelo.rotation.y = [0.0, PI/2.0, PI, -PI/2.0][d]
			var nome := "Idle_Loop" if q == 0 else (heroi._nome_animacao("correr") if q < 5 else "Sword_Attack")
			var anim: Animation = heroi._player.get_animation(nome)
			heroi._player.play(nome)
			heroi._player.speed_scale = 0.0
			var fracao := 0.0 if q == 0 else (((q-1)/4.0) if q < 5 else (0.15+(q-5)*0.2))
			heroi._player.seek(fracao*anim.length, true)
			heroi._encaixar_espada(q >= 5)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			heroi._vp.get_texture().get_image().save_png(SAIDA+"modelo_%d_%d.png" % [d,q])
			var img := root.get_texture().get_image()
			var escala := Vector2(img.get_size())/root.get_visible_rect().size
			var centro: Vector2 = heroi.get_global_transform_with_canvas().origin*escala
			var parte := img.get_region(Rect2i(Vector2i(centro)-Vector2i(RECORTE/2, RECORTE*3/4), Vector2i(RECORTE, RECORTE)))
			parte.convert(Image.FORMAT_RGBA8)
			parte.resize(RECORTE*AMPLIAR, RECORTE*AMPLIAR, Image.INTERPOLATE_NEAREST)
			folha.blit_rect(parte, Rect2i(0, 0, RECORTE*AMPLIAR, RECORTE*AMPLIAR), Vector2i(q*RECORTE*AMPLIAR, d*RECORTE*AMPLIAR))
	folha.save_png(SAIDA+("folha_perto.png" if "--perto" in OS.get_cmdline_user_args() else "folha_no_jogo.png"))
	print("BASE 3D REVISAO OK")
	quit()
