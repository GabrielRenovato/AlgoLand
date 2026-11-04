extends SceneTree
const Elenco=preload("res://codigo/dados/moradores_primeira_raiz.gd")
const Gerador=preload("res://codigo/dados/gerador_npcs.gd")
var falhas:=0
var pasta:="res://capturas-movimentos-npcs/"
var tempos:Dictionary={}
func _initialize() -> void:rodar.call_deferred()
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func quadros(n:=3) -> void:
	for i in n:await process_frame
func pes(h: Node) -> Array[Vector3]:
	var resultado:Array[Vector3]=[]
	for lado in ["L","R"]:resultado.append(h._esqueleto.get_bone_global_pose(h._esqueleto.find_bone("DEF-foot."+lado)).origin)
	return resultado
func foto(h: Node,nome: String) -> void:
	await RenderingServer.frame_post_draw
	var im:Image=h._vp.get_texture().get_image()
	var r:=im.get_used_rect()
	verificar("quadro inteiro "+nome,r.has_area() and r.position.x>0 and r.position.y>0 and r.end.x<im.get_width() and r.end.y<im.get_height())
	im.save_png(pasta+nome+".png")
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	root.get_node("Ranking").conexao_habilitada=false
	DirAccess.make_dir_recursive_absolute(pasta)
	verificar("ficha legada usa movimento neutro",Gerador.normalizar({"versao":1}).movimento=="neutro")
	verificar("estilo não aceita arquivo externo",Gerador.normalizar({"versao":1,"movimento":"res://arquivo.gd"}).movimento=="neutro")
	var mulheres:=["dara","lia","rosa","estela","mara","cora","elia"]
	for id in Elenco.dados():verificar("perfil explícito do elenco "+id,Elenco.ficha(id).movimento==("feminino" if id in mulheres else "neutro"))
	var ficha:=Elenco.ficha("estela")
	verificar("exportação salva estilo",Gerador.salvar(ficha,"user://estela_movimento.json")==OK and Gerador.carregar("user://estela_movimento.json").movimento=="feminino")
	var npc=load("res://cenas/npcs/npc_gerado.tscn").instantiate()
	npc.ficha=ficha;npc.position=Vector2(160,220)
	root.add_child(npc);npc.set_physics_process(false)
	await quadros(6)
	var visual=npc.visual
	var h=visual.heroi
	var corpo:MeshInstance3D=h._modelo.find_child("CorpoBase",true,false)
	var geometria:=hash(corpo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var jogador_fonte:AnimationPlayer=h._player
	for nome in ["Caminhada_Feminina","Descanso_Feminino","Conversa_Feminina"]:
		var a:Animation=jogador_fonte.get_animation("npcs/"+nome)
		tempos[nome]=a.length
		verificar("ciclo contínuo "+nome,a.loop_mode==Animation.LOOP_LINEAR)
		verificar("clipe vem do FBX feminino "+nome,String(a.get_meta("fonte","")).contains("HumanF@"))
	var diferenca_rotacao:=0.0
	var trajetoria:Array=[[],[]]
	for d in 4:
		for andando in [false,true]:
			var acao:="andar" if andando else "parado"
			var duracao:float=tempos["Caminhada_Feminina" if andando else "Descanso_Feminino"]
			for q in 12:
				var rotacao:=Quaternion.IDENTITY
				for modo in ["neutro","feminino"]:
					visual.perfil_movimento=modo
					var duracao_modo:float=duracao if modo=="feminino" else h._player.get_animation("Walk_Loop" if andando else "Idle_Loop").length
					tempos[modo+"_"+acao]=duracao_modo
					visual.pose_caminhada(andando,d,duracao_modo*q/12.0)
					await quadros(2)
					if modo=="neutro":
						rotacao=h._esqueleto.get_bone_pose_rotation(h._esqueleto.find_bone("DEF-hips"))
					else:
						var atuais:=pes(h)
						for i in 2:
							if andando and d==0:trajetoria[i].append(atuais[i])
						diferenca_rotacao=maxf(diferenca_rotacao,rotacao.angle_to(h._esqueleto.get_bone_pose_rotation(h._esqueleto.find_bone("DEF-hips"))))
					await foto(h,"%s_%s_%d_%02d" % [modo,acao,d,q])
	print("MEDIDAS passada=",visual.passada_caminhada(),"px; diferença de postura=",rad_to_deg(diferenca_rotacao))
	verificar("passada calibrada para a distância real",visual.passada_caminhada()>2.0 and visual.passada_caminhada()<40.0 and is_equal_approx(visual.duracao_caminhada(),tempos.Caminhada_Feminina))
	for i in 2:
		var z:Array=trajetoria[i].map(func(p):return p.z)
		verificar("perna alterna contato e passagem %d" % i,z.max()-z.min()>.12 and trajetoria[i].all(func(p):return p.is_finite()))
	var cruzamentos:=0
	for q in 12:
		if signf(trajetoria[0][q].z-trajetoria[1][q].z)!=signf(trajetoria[0][(q+1)%12].z-trajetoria[1][(q+1)%12].z):cruzamentos+=1
	verificar("passada alterna as duas pernas",cruzamentos==2)
	verificar("postura altera quadril sem trocar corpo",diferenca_rotacao>deg_to_rad(1.0) and hash(corpo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])==geometria)
	visual.perfil_movimento="feminino"
	npc.iniciar_conversa(npc.position+Vector2(0,24))
	verificar("conversa usa gesto feminino importado",h._player.current_animation=="npcs/Conversa_Feminina")
	for d in 4:
		for q in 12:
			visual.pose_conversa(d,tempos.Conversa_Feminina*q/12.0)
			await quadros(2)
			await foto(h,"feminino_conversa_%d_%02d" % [d,q])
	for id in mulheres:
		var mulher:=Elenco.ficha(id)
		visual.mostrar(mulher.aparencia,mulher.aparencia.roupas_3d,0)
		for d in 4:
			for q in 4:
				visual.pose_caminhada(true,d,tempos.Caminhada_Feminina*q/4.0)
				await quadros(2)
				await foto(h,"elenco_%s_%d_%02d" % [id,d,q])
	FileAccess.open(pasta+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify(tempos))
	npc.queue_free();await quadros()
	print("FALHAS: ",falhas);quit(falhas)
