extends SceneTree
## Alcance do combo contra o corpo real dos mobs, usando as mesmas distâncias em cada direção.
var jogador: Node2D
var heroi: Node2D
var verificacoes:=0
var falhas:=0
func conferir(ok: bool,texto: String):
	verificacoes+=1
	if not ok:
		falhas+=1
		push_error(texto)
func _initialize(): rodar.call_deferred()
func quadros(n:=5):
	for i in n: await process_frame
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1152,648)
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/casa.tscn")
	await quadros(30)
	jogador=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.position=Vector2(1000,1000)
	jogador.camera.zoom=Vector2.ONE*4
	jogador.camera.position_smoothing_enabled=false
	jogador.modo_fazenda=false
	heroi=jogador.get_node("HeroiBase3D")
	var item=preload("res://codigo/dados/forja_armas.gd").criar_item("espada_basica")
	jogador.inventario.mochila[20]=item
	jogador.inventario.equipar(item)
	await quadros()
	for especie in ([] if "--duelo" in OS.get_cmdline_user_args() else ["slime","esqueleto_guerreiro","gremlin"]):
		for direcao in ([Vector2.UP] if "--cima" in OS.get_cmdline_user_args() else [Vector2.UP,Vector2.UP.rotated(PI/4),Vector2.UP.rotated(-PI/4),Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]):
			var mobs: Array[Node2D]=[]
			for distancia in range(12,73,2):
				var mob=load("res://cenas/inimigos/"+especie+".tscn").instantiate()
				mob.usar_barra_vida=false
				current_scene.add_child(mob)
				mob.set_physics_process(false)
				if mob.arvore_animacao!=null: mob.arvore_animacao.active=false
				mob.sprite.frame=32 if especie=="slime" else 0
				mob.global_position=jogador.global_position+direcao*distancia
				mob.visible=distancia==28
				mob.set_meta("distancia",distancia)
				mobs.append(mob)
			await quadros()
			for fase in [1,2,3]:
				for mob in mobs: mob.vida=100000
				jogador._direcao_ataque=direcao
				jogador._cardinal_anterior=jogador._cardinal_de(direcao)
				jogador._fase_combo=fase
				jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1",.6)
				await create_timer(.18 if fase<3 else .24).timeout
				await RenderingServer.frame_post_draw
				if direcao==Vector2.UP:
					root.get_texture().get_image().save_png("/tmp/espada-cima-"+especie+"-%d.png"%fase)
				await create_timer(.4).timeout
				var acertos: Array[int]=[]
				for mob in mobs:
					if mob.vida<100000: acertos.append(mob.get_meta("distancia"))
				print("ALCANCE ",especie," ",direcao," combo=",fase," acertos=",acertos)
				conferir(12 in acertos,"Sem ponto cego perto: %s / %s / %d"%[especie,direcao,fase])
				conferir(not 72 in acertos,"Alvo distante não recebe golpe: %s / %s / %d"%[especie,direcao,fase])
				if direcao==Vector2.UP:
					var alcance: int=([36,36,32][fase-1] if especie=="slime" else (50 if especie=="esqueleto_guerreiro" else 38))
					for perto in range(12,alcance+1,2):
						conferir(perto in acertos,"Corte para cima cobre %d px sem lacuna: %s / %d"%[perto,especie,fase])
			for mob in mobs: mob.queue_free()
			await quadros()
	# Chão navegável isolado: a casa não possui malha de combate.
	var navegacao:=NavigationRegion2D.new()
	var malha:=NavigationPolygon.new()
	malha.vertices=PackedVector2Array([Vector2(900,900),Vector2(1100,900),Vector2(1100,1100),Vector2(900,1100)])
	malha.add_polygon(PackedInt32Array([0,1,2,3]))
	navegacao.navigation_polygon=malha
	current_scene.add_child(navegacao)
	await physics_frame
	await physics_frame
	NavigationServer2D.map_force_update(jogador.get_world_2d().navigation_map)
	# Um slime que avança deve ser repelido pelo primeiro corte antes do toque.
	for fase in [1,2,3]:
		var mob=load("res://cenas/inimigos/slime.tscn").instantiate()
		mob.position=jogador.position+Vector2(0,-40)
		mob.vida=100000
		current_scene.add_child(mob)
		jogador.hp_atual=jogador.estatisticas.hp_maximo
		jogador.invulneravel=false
		jogador._direcao_ataque=Vector2.UP
		jogador._cardinal_anterior=Vector2.UP
		jogador._fase_combo=fase
		jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1",.6)
		await create_timer(.55).timeout
		print("DUELO combo=",fase," distancia_final=",mob.global_position.distance_to(jogador.global_position)," dano_jogador=",jogador.estatisticas.hp_maximo-jogador.hp_atual," dano_mob=",100000-mob.vida)
		conferir(mob.vida<100000,"Corte %d intercepta slime em movimento"%fase)
		conferir(jogador.hp_atual==jogador.estatisticas.hp_maximo,"Corte %d repele antes do dano de contato"%fase)
		mob.queue_free()
		await quadros()
	print("ESPADA CIMA: %d verificações, %d falhas"%[verificacoes,falhas])
	current_scene.queue_free()
	await quadros()
	quit(1 if falhas else 0)
