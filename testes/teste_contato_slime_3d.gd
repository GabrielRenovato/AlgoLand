extends SceneTree
## Contato e combos contra o slime real, sem gravar na partida do usuário.
var jogador: Node2D
var heroi: Node2D
var slime: Node2D
var verificacoes := 0
var falhas := 0
func conferir(ok: bool, texto: String):
	verificacoes+=1
	if not ok:
		falhas+=1
		push_error(texto)
func _initialize(): rodar.call_deferred()
func esperar(n:=4):
	for i in n: await process_frame
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1152,648)
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/casa.tscn")
	await esperar(30)
	jogador=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.position=Vector2(1000,1000)
	jogador.camera.zoom=Vector2.ONE*4
	jogador.camera.position_smoothing_enabled=false
	heroi=jogador.get_node("HeroiBase3D")
	slime=load("res://cenas/inimigos/slime.tscn").instantiate()
	current_scene.add_child(slime)
	slime.set_physics_process(false)
	slime.arvore_animacao.active=false
	slime.sprite.frame=32
	await esperar()
	# A pose fica parada nesta etapa: receber dano toca a animação de ferido.
	heroi.set_process(false)
	heroi._player.pause()
	var antigos := [22,24,17,24,27,23,16,24]
	var proximos := [16,12,10,12,14,12,10,12]
	for i in 8:
		var dir := Vector2.DOWN.rotated(-i*PI/4)
		for perto in [false,true]:
			slime.global_position=jogador.global_position+dir*(proximos[i] if perto else antigos[i])
			await physics_frame
			await physics_frame
			jogador.hp_atual=jogador.estatisticas.hp_maximo
			jogador.invulneravel=false
			var vida: int=jogador.hp_atual
			slime.aplicar_dano_contato()
			conferir((jogador.hp_atual<vida)==perto,"Contato real, direção %d, perto=%s"%[i,perto])
			if perto:
				vida=jogador.hp_atual
				slime.aplicar_dano_contato()
				conferir(jogador.hp_atual==vida,"Invulnerabilidade impede dano repetido: %d"%i)
			if i==3:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/slime-contato-%s.png"%str(perto))
	heroi.set_process(true)
	await create_timer(.35).timeout
	var item = preload("res://codigo/dados/forja_armas.gd").criar_item("espada_basica")
	jogador.inventario.mochila[20]=item
	conferir(jogador.inventario.equipar(item),"Equipa espada de uma mão")
	jogador.modo_fazenda=false
	await esperar()
	for distancia in [20,60]:
		for i in 8:
			for fase in ([1,2,3] if distancia==20 else [1]):
				slime.global_position=jogador.global_position+Vector2.DOWN.rotated(-i*PI/4)*distancia
				slime.vida=100000
				jogador._direcao_ataque=Vector2.DOWN.rotated(-i*PI/4)
				jogador._cardinal_anterior=jogador._cardinal_de(jogador._direcao_ataque)
				jogador._fase_combo=fase
				jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1",.6)
				await create_timer(.2).timeout
				if distancia==20 and fase==1:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("/tmp/slime-espada-%d.png"%i)
				await create_timer(.4).timeout
				var acertou: bool=slime.vida<100000
				conferir(acertou==(distancia==20),"Espada: distância %d, direção %d, combo %d, acertou=%s"%[distancia,i,fase,acertou])
	print("CONTATO SLIME: %d verificações, %d falhas"%[verificacoes,falhas])
	current_scene.queue_free()
	await esperar(5)
	quit(1 if falhas else 0)
