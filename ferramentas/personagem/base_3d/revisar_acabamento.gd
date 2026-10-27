extends SceneTree
## Retrato do personagem base 3D, com roupa, parado nas oito direções e de perto (render interno, sem o mapa).
const SAIDA := "res://arte/previas/personagens/base_3d/acabamento/"
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/fazenda.tscn")
	for i in 35: await process_frame
	root.get_node("Transicao").limpar()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--aparencia="):
			# --aparencia=pele,r,g,b,olhos
			var v := a.get_slice("=", 1).split_floats(",")
			var jog = current_scene.get_node("Jogador")
			jog.aparencia_raven = jog.aparencia_raven.duplicate()
			jog.aparencia_raven["pele"] = int(v[0])
			jog.aparencia_raven["cor"] = [v[1], v[2], v[3], 1.0]
			jog.aparencia_raven["olhos"] = int(v[4])
	root.get_node("PainelDebug")._ativar_base_3d("--sem-roupa" not in OS.get_cmdline_user_args(), false)
	var heroi = current_scene.get_node("Jogador/HeroiBase3D")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--roupas="):
			# --roupas=camisa,calca,calcado,cabelo
			var v := a.get_slice("=", 1).split(",")
			heroi.definir_roupas_3d({"camisa": v[0], "calca": v[1], "calcado": v[2], "cabelo": v[3]})
	for i in 20: await process_frame
	heroi.set_process(false)
	var vp: SubViewport = heroi._vp
	var lado: int = vp.size.x
	var folha := Image.create(lado*4, lado*2, false, Image.FORMAT_RGBA8)
	folha.fill(Color("5d6b55"))
	var animacao: String = heroi._nome_animacao("parado")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--animacao="): animacao = a.get_slice("=", 1)
	for d in 8:
		heroi._modelo.rotation.y = d*TAU/8.0
		heroi._player.play(animacao)
		heroi._player.speed_scale = 0.0
		heroi._player.seek(0.0, true)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		folha.blend_rect(img, Rect2i(0, 0, lado, lado), Vector2i((d%4)*lado, (d/4)*lado))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var nome := "sem_roupa.png" if "--sem-roupa" in OS.get_cmdline_user_args() else "com_roupa.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): nome = a.get_slice("=", 1)
	folha.save_png(SAIDA+nome)
	print("ACABAMENTO salvo ", nome, " ", lado)
	quit()
