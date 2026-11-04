extends "res://ferramentas/personagem/base_3d/importar_melee.gd"
## Retarget real dos FBX femininos baixados da página oficial do Kevin Iglesias.
const DESTINO_NPC:="res://assets/personagens/base_3d/movimentos_npcs.res"
const CLIPES_NPC={
	"Movement/Walk/HumanF@Walk01_Forward.fbx":"Caminhada_Feminina",
	"Idles/HumanF@Idle01.fbx":"Descanso_Feminino",
	"Social/Conversation/HumanF@Talk01.fbx":"Conversa_Feminina"}

func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	var pasta:="/tmp/algoland-human-basic-free/Animations/Female"
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--fonte="):pasta=argumento.trim_prefix("--fonte=")
	cena_alvo=load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
	root.add_child(cena_alvo)
	alvo=cena_alvo.find_children("*","Skeleton3D",true,false)[0]
	for m in alvo.find_children("*","SkeletonModifier3D",true,false):m.active=false
	for arquivo in CLIPES_NPC:
		await importar(pasta+"/"+arquivo,pasta)
		var nome:String=arquivo.get_file().get_basename().replace("@","_")
		biblioteca.rename_animation(nome,CLIPES_NPC[arquivo])
		var animacao:=biblioteca.get_animation(CLIPES_NPC[arquivo])
		animacao.loop_mode=Animation.LOOP_LINEAR
		animacao.set_meta("fonte",arquivo)
	biblioteca.set_meta("autor","Kevin Iglesias")
	biblioteca.set_meta("fonte","https://kevdev.itch.io/basic-motions-free")
	biblioteca.set_meta("passada_feminina_px",medir_passada())
	assert(ResourceSaver.save(biblioteca,DESTINO_NPC,ResourceSaver.FLAG_COMPRESS)==OK)
	var destino:="res://arte/fontes/personagens/base_3d/movimentos_npcs/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
	FileAccess.open(destino+"retarget.json",FileAccess.WRITE).store_string(JSON.stringify({"fonte":"https://kevdev.itch.io/basic-motions-free","autor":"Kevin Iglesias","clipes":relatorio,"destino":DESTINO_NPC,"metodo":"retarget de rotações globais e repousos via importar_melee.gd; poses do FBX preservadas"},"  "))
	cena_alvo.free()
	print("NPCs: 3 animações femininas reais importadas")
	quit()

func medir_passada() -> float:
	var player:AnimationPlayer=cena_alvo.find_children("*","AnimationPlayer",true,false)[0]
	player.add_animation_library("npcs",biblioteca)
	var proporcao=load("res://codigo/jogador/proporcao_chibi.gd").new()
	alvo.add_child(proporcao);proporcao.active=false
	var duracao:float=biblioteca.get_animation("Caminhada_Feminina").length
	var amostras:=ceili(duracao*120)
	var pes:Array=[[],[]]
	for q in amostras:
		alvo.reset_bone_poses()
		player.play("npcs/Caminhada_Feminina",0);player.speed_scale=0
		player.seek(duracao*q/amostras,true)
		proporcao._aplicar()
		for i in 2:pes[i].append(alvo.get_bone_global_pose(alvo.find_bone("DEF-foot."+["L","R"][i])).origin)
	var velocidades:Array[float]=[]
	for pontos in pes:
		var piso:float=pontos.map(func(p):return p.y).min()
		for i in range(1,pontos.size()):
			if pontos[i].y>piso+.018 or pontos[i-1].y>piso+.018:continue
			var velocidade:float=-(pontos[i].z-pontos[i-1].z)/(duracao/amostras)
			if velocidade>.05:velocidades.append(velocidade)
	assert(not velocidades.is_empty(),"Sem amostras de pé apoiado")
	velocidades.sort()
	# HeroiBase3D: 80 px lógicos / câmera ortográfica de 4 m = 20 px/m.
	var passada:float=velocidades[velocidades.size()/2]*duracao*20.0
	assert(passada>2.0 and passada<40.0)
	print("PASSADA FEMININA: ",passada," px/ciclo, ",duracao,"s")
	return passada
