extends SceneTree
## Perseguição física entre margens e setores: a existência de uma rota não basta.
var falhas := 0
var visual := "--visual" in OS.get_cmdline_user_args()
class Inspecao extends Node2D:
	var rota: PackedVector2Array
	var mob: Node2D
	func _process(_delta): queue_redraw()
	func _draw():
		if rota.size()>1: draw_polyline(rota,Color(.2,1,.3,.7),1.0)
		if not is_instance_valid(mob): return
		var corpo=mob.get_node("colision_body")
		draw_set_transform_matrix(corpo.global_transform)
		draw_rect(corpo.shape.get_rect(),Color.CYAN,false,.6)

func _initialize(): rodar.call_deferred()
func quadros(n:=5):
	for i in n: await physics_frame
func comprimento(rota: PackedVector2Array) -> float:
	var total:=0.0
	for i in range(1,rota.size()): total+=rota[i-1].distance_to(rota[i])
	return total
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	Engine.physics_ticks_per_second=600
	Engine.time_scale=10
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").iniciar_partida()
	var catalogo=load("res://codigo/fendas/catalogo_andares.gd")
	for andar in ([2] if visual else [2,5,7,13,18]):
		var t=root.get_node("Transicao")
		t.retornando=true
		t.estado={"onda_atual":andar}
		t.iniciar_onda_ao_chegar=false
		change_scene_to_file(catalogo.cena(andar))
		await quadros(15)
		var jogador=current_scene.get_node("Jogador")
		jogador.set_physics_process(false)
		jogador.invulneravel=true
		jogador.temporizador_invul=100000
		var terreno=current_scene.get_node("Terrains")
		var mapa=terreno.get_world_2d().navigation_map
		for variante in ([1,4] if visual else [0,1,2]):
			var especie: String="esqueleto_guerreiro" if variante==4 else ("golem" if variante==2 else "slime")
			var mob=load("res://cenas/inimigos/"+especie+".tscn").instantiate()
			current_scene.add_child(mob)
			if variante in [1,4]: mob.tornar_mutante()
			mob.set_physics_process(false)
			var melhor:=PackedVector2Array()
			var desvio:=0.0
			var setores=terreno.get_node("Setores").get_children()
			for a in setores:
				for b in setores:
					if a==b: continue
					var rota=NavigationServer2D.map_get_path(mapa,a.global_position,b.global_position,true,1<<mob.classe_de_navegacao())
					if rota.size()<3 or rota[-1].distance_to(b.global_position)>8: continue
					var diferenca=comprimento(rota)-rota[0].distance_to(rota[-1])
					if diferenca>desvio:
						desvio=diferenca
						melhor=rota
			if melhor.is_empty():
				print("SEM CASO ",andar," ",variante)
				mob.queue_free()
				continue
			var offset: Vector2=mob.get_node("colision_body").global_position-mob.global_position
			var pes: Vector2=jogador.get_node("CollisionShape2D").global_position-jogador.global_position
			mob.global_position=melhor[0]-offset
			jogador.global_position=melhor[-1]-pes
			await quadros()
			var desenho: Inspecao
			if visual:
				root.size=Vector2i(1152,648)
				root.content_scale_size=Vector2i(576,324)
				jogador.camera.position_smoothing_enabled=false
				jogador.camera.zoom=Vector2.ONE*(.5 if "--geral" in OS.get_cmdline_user_args() else 2.0)
				desenho=Inspecao.new()
				desenho.rota=melhor
				desenho.mob=mob
				desenho.z_index=100
				current_scene.add_child(desenho)
			var passos:=mini(ceili(comprimento(melhor)/mob.velocidade*60*2)+300,30000)
			var ultima: Vector2=mob.position
			var parado:=0
			var max_parado:=0
			for i in passos:
				mob._physics_process(1.0/60)
				await physics_frame
				if visual:
					jogador.camera.global_position=(melhor[0]+melhor[-1])*.5 if "--geral" in OS.get_cmdline_user_args() else mob.global_position
					if i in [300,600,900]:
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("/tmp/mobs-rios-%s-%d-%d.png"%["geral" if "--geral" in OS.get_cmdline_user_args() else "perto",variante,i])
				if mob.position.distance_to(ultima)<.05: parado+=1
				else: parado=0
				max_parado=maxi(parado,max_parado)
				ultima=mob.position
				if mob._centro_de_navegacao().distance_to(jogador.get_node("CollisionShape2D").global_position)<mob.raio_parada+8: break
			var chegou: bool=mob._centro_de_navegacao().distance_to(jogador.get_node("CollisionShape2D").global_position)<mob.raio_parada+8
			if not chegou: falhas+=1
			print("PERSEGUICAO andar=",andar," variante=",variante," chegou=",chegou," rota=",snappedf(comprimento(melhor),1)," restante=",snappedf(mob._centro_de_navegacao().distance_to(jogador.get_node("CollisionShape2D").global_position),1)," parado_frames=",max_parado," mob=",mob.position," alvo=",jogador.position)
			if is_instance_valid(desenho): desenho.queue_free()
			mob.queue_free()
			await quadros()
	print("PERSEGUICAO RIOS: ",falhas," falhas")
	quit(1 if falhas else 0)
