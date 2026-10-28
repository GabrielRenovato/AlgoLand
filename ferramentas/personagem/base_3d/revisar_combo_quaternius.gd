extends SceneTree
## Revisão das poses originais retargetadas, sem trocar o combo ativo durante o estudo.
const SAIDA := "/tmp/algoland-quaternius/"
var registros: Array=[]
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(SAIDA)
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.
	change_scene_to_file("res://cenas/fazenda.tscn")
	for i in 30:await process_frame
	var j=current_scene.get_node("Jogador")
	var h=j.get_node("HeroiBase3D")
	j.set_physics_process(false)
	h.set_process(false)
	h._acao="espada"
	h._demonstracao=true
	h._encaixar_espada(true)
	h._espada.quaternion=h._player.get_animation("quaternius/Sword_Regular_Combo").get_meta("rotacao_arma")
	h._escudo.visible=false
	var clipes: Array=["Sword_Regular_Combo"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clipe="):clipes=[arg.trim_prefix("--clipe=")]
	for nome in clipes:
		var a=h._player.get_animation("quaternius/"+nome)
		for argumento in OS.get_cmdline_user_args():
			if argumento.begins_with("--pega="):h._espada.quaternion=Basis(Vector3.RIGHT,deg_to_rad(float(argumento.trim_prefix("--pega=")))).get_rotation_quaternion()
		for direcao in 4:
			h._modelo.rotation.y=[0.,PI/2,PI,-PI/2][direcao]
			h._player.play("quaternius/"+nome,0)
			h._player.speed_scale=0
			for q in 91:
				var tempo=a.length*q/90.
				h._player.seek(tempo,true)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				h._vp.get_texture().get_image().save_png(SAIDA+"%s_%d_%03d.png" % [nome,direcao,q])
				var pontos := {}
				for osso in ["DEF-head","DEF-hips","DEF-hand.R","DEF-foot.L","DEF-foot.R"]:
					var p: Vector3=h._esqueleto.global_transform*h._esqueleto.get_bone_global_pose(h._esqueleto.find_bone(osso)).origin
					pontos[osso]=[p.x,p.y,p.z]
				var ponta: Vector3=h._espada.global_transform*Vector3(0,.8,0)
				pontos["ponta"]=[ponta.x,ponta.y,ponta.z]
				registros.append({"clipe":nome,"direcao":direcao,"tempo":tempo,"pontos":pontos})
	FileAccess.open(SAIDA+"movimento.json",FileAccess.WRITE).store_string(JSON.stringify(registros))
	print("UAL2 REVISAO: ",registros.size()," quadros no Godot")
	quit()
