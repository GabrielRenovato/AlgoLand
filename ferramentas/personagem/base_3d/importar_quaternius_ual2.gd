extends SceneTree
## Transfere as poses CC0 do UAL2 ao rig canônico; não modifica o corpo ou os saves.
const FONTE := "res://arte/fontes/personagens/base_3d/quaternius_ual2/UAL2_Standard.glb"
const SAIDA := "res://assets/personagens/base_3d/quaternius_ual2.res"
const CLIPES := ["Sword_Regular_A","Sword_Regular_B","Sword_Regular_C","Sword_Regular_A_Rec","Sword_Regular_B_Rec","Sword_Regular_Combo"]
const MAPA := {"DEF-hips":"pelvis","DEF-spine.001":"spine_01","DEF-spine.002":"spine_02","DEF-spine.003":"spine_03","DEF-neck":"neck_01","DEF-head":"Head"}
var alvo: Skeleton3D
func _initialize(): rodar.call_deferred()
func mapa(nome: String) -> String:
	if MAPA.has(nome): return MAPA[nome]
	for lado in ["L","R"]:
		for par in [["shoulder","clavicle"],["upper_arm","upperarm"],["forearm","lowerarm"],["hand","hand"],["thigh","thigh"],["shin","calf"],["foot","foot"],["toe","ball"]]:
			if nome=="DEF-%s.%s" % [par[0],lado]: return "%s_%s" % [par[1],lado.to_lower()]
		for dedo in ["index","middle","ring","pinky","thumb"]:
			for numero in [1,2,3]:
				var prefixo: String = dedo if dedo=="thumb" else "f_"+dedo
				if nome=="DEF-%s.%02d.%s" % [prefixo,numero,lado]: return "%s_%02d_%s" % [dedo,numero,lado.to_lower()]
	return ""
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	var cena_alvo = load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
	root.add_child(cena_alvo)
	alvo = cena_alvo.find_children("*","Skeleton3D",true,false)[0]
	for modificador in alvo.find_children("*","SkeletonModifier3D",true,false): modificador.active=false
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	assert(doc.append_from_file(FONTE,estado)==OK)
	var cena := doc.generate_scene(estado)
	root.add_child(cena)
	var origem: Skeleton3D = cena.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer = cena.find_children("*","AnimationPlayer",true,false)[0]
	var biblioteca := AnimationLibrary.new()
	var relatorio: Array = []
	var base_origem := origem.global_basis.orthonormalized()
	var base_alvo := alvo.global_basis.orthonormalized()
	var quadril := alvo.find_bone("DEF-hips")
	var quadril_fonte := origem.find_bone("pelvis")
	var proporcao := alvo.get_bone_global_rest(quadril).origin.y/(origem.global_transform*origem.get_bone_global_rest(quadril_fonte).origin).y
	var pai_quadril := alvo.get_bone_parent(quadril)
	var base_pai := alvo.get_bone_global_rest(pai_quadril).basis.orthonormalized()
	var escala_perna: float = preload("res://codigo/jogador/proporcao_chibi.gd").ESCALAS["DEF-thigh.L"]
	var mao := alvo.get_bone_global_rest(alvo.find_bone("DEF-hand.R")).basis.orthonormalized()
	# No rig UE do UAL2 o eixo +Z sai pelo lado do indicador; a lâmina do jogo usa +Y.
	var pega := mao.inverse()*base_alvo.inverse()*base_origem*origem.get_bone_global_rest(origem.find_bone("hand_r")).basis.orthonormalized()*Basis(Vector3.RIGHT,PI/2)
	for nome in CLIPES:
		var fonte := player.get_animation(nome)
		var animacao := Animation.new()
		animacao.length=fonte.length
		animacao.set_meta("rotacao_arma",pega.orthonormalized().get_rotation_quaternion())
		animacao.set_meta("fonte","quaternius_ual2/"+nome)
		var pares: Array = []
		var trilhas := {}
		for osso in alvo.get_bone_count():
			var id_fonte := origem.find_bone(mapa(alvo.get_bone_name(osso)))
			if id_fonte<0:continue
			pares.append([osso,id_fonte])
			var trilha := animacao.add_track(Animation.TYPE_ROTATION_3D)
			animacao.track_set_path(trilha,NodePath(str(cena_alvo.get_path_to(alvo))+":"+alvo.get_bone_name(osso)))
			trilhas[osso]=trilha
		var posicao := animacao.add_track(Animation.TYPE_POSITION_3D)
		animacao.track_set_path(posicao,NodePath(str(cena_alvo.get_path_to(alvo))+":DEF-hips"))
		player.play(nome,0)
		player.speed_scale=0
		var amostras := ceili(fonte.length*30)
		for quadro in range(amostras+1):
			var tempo := fonte.length*quadro/amostras
			origem.reset_bone_poses()
			player.seek(tempo,true)
			alvo.reset_bone_poses()
			var desejadas := {}
			for par in pares:
				var repouso := base_origem*origem.get_bone_global_rest(par[1]).basis.orthonormalized()
				var pose := base_origem*origem.get_bone_global_pose(par[1]).basis.orthonormalized()
				desejadas[par[0]]=base_alvo.inverse()*pose*repouso.inverse()*base_alvo*alvo.get_bone_global_rest(par[0]).basis.orthonormalized()
			aplicar_poses(-1,desejadas)
			for par in pares:animacao.rotation_track_insert_key(trilhas[par[0]],tempo,alvo.get_bone_pose_rotation(par[0]))
			var delta := origem.global_basis*(origem.get_bone_global_pose(quadril_fonte).origin-origem.get_bone_global_rest(quadril_fonte).origin)*proporcao
			delta.x=0;delta.z=0 # A física continua controlando a posição no mapa.
			delta.y*=escala_perna # Abaixar o quadril acompanha as pernas curtas do modelo canônico.
			animacao.position_track_insert_key(posicao,tempo,alvo.get_bone_rest(quadril).origin+base_pai.inverse()*base_alvo.inverse()*delta)
		biblioteca.add_animation(nome,animacao)
		relatorio.append({"nome":nome,"duracao":fonte.length,"ossos":pares.size(),"amostras":amostras+1})
		print("UAL2 IMPORTADO: ",nome,"; ",pares.size()," ossos; ",fonte.length," s")
	assert(ResourceSaver.save(biblioteca,SAIDA,ResourceSaver.FLAG_COMPRESS)==OK)
	FileAccess.open("res://arte/fontes/personagens/base_3d/quaternius_ual2/importacao.json",FileAccess.WRITE).store_string(JSON.stringify(relatorio,"\t"))
	quit()
func aplicar_poses(pai: int,desejadas: Dictionary):
	for osso in (alvo.get_parentless_bones() if pai<0 else alvo.get_bone_children(pai)):
		if desejadas.has(osso):
			var acima := Basis.IDENTITY if pai<0 else alvo.get_bone_global_pose(pai).basis.orthonormalized()
			alvo.set_bone_pose_rotation(osso,(acima.inverse()*desejadas[osso]).get_rotation_quaternion())
		aplicar_poses(osso,desejadas)
