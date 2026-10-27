extends SceneTree
## Folga física de cada rota e curva, além dos nascimentos reais.
var verificacoes:=0
var falhas:=0
func _initialize(): rodar.call_deferred()
func quadros(n:=8):
	for i in n:
		await physics_frame
		await process_frame
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	Engine.physics_ticks_per_second=600
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").iniciar_partida()
	var catalogo=load("res://codigo/fendas/catalogo_andares.gd")
	for andar in range(1,22):
		var t=root.get_node("Transicao")
		t.retornando=true
		t.estado={"onda_atual":andar}
		t.iniciar_onda_ao_chegar=false
		change_scene_to_file(catalogo.cena(andar))
		await quadros(15)
		var j=current_scene.get_node("Jogador")
		j.set_physics_process(false)
		var terreno=current_scene.get_node("Terrains")
		var mapa=terreno.get_world_2d().navigation_map
		for variante in ([] if "--somente-nascimentos" in OS.get_cmdline_user_args() else range(6)):
			var especie: String=["slime","slime","golem","esqueleto_guerreiro","esqueleto_guerreiro","caranguejo"][variante]
			var mob=load("res://cenas/inimigos/"+especie+".tscn").instantiate()
			current_scene.add_child(mob)
			if variante in [1,4,5]: mob.tornar_mutante()
			mob.set_physics_process(false)
			var deslocamento: Vector2=mob.get_node("colision_body").global_position-mob.global_position
			var bloqueios:=0
			var cortes:=0
			for a in terreno.get_node("Setores").get_children():
				for b in terreno.get_node("Setores").get_children():
					if a==b: continue
					var rota=NavigationServer2D.map_get_path(mapa,a.global_position,b.global_position,true,1<<mob.classe_de_navegacao())
					for k in range(1,rota.size()):
						var inicio: Transform2D=mob.global_transform
						inicio.origin=rota[k-1]-deslocamento
						verificacoes+=1
						if mob.test_move(inicio,rota[k]-rota[k-1]):
							bloqueios+=1
							if bloqueios<3: print("BLOQUEADO ",andar," ",variante," ",rota[k-1]," ",rota[k])
					for k in range(1,rota.size()-1):
						var d: float=mob._agente.path_desired_distance*.95
						var entrada: Vector2=rota[k].move_toward(rota[k-1],minf(d,rota[k].distance_to(rota[k-1])*.5))
						var saida: Vector2=rota[k].move_toward(rota[k+1],minf(d,rota[k].distance_to(rota[k+1])*.5))
						var inicio: Transform2D=mob.global_transform
						inicio.origin=entrada-deslocamento
						verificacoes+=1
						if mob.test_move(inicio,saida-entrada):
							cortes+=1
							if cortes<3: print("CORTE ",andar," ",variante," ",entrada," ",saida)
			falhas+=bloqueios+cortes
			print("AUDITORIA ",andar," ",variante," bloqueios=",bloqueios," cortes=",cortes)
			mob.queue_free()
			await quadros()
		var gerador=current_scene.get_node("enemySpawner")
		gerador.montar_populacao(0)
		var dados: Dictionary=catalogo.dados(andar)
		var esperado:=int(dados.combate.elites)
		for setor in dados.setores: esperado+=int(setor.grupos)*int(dados.combate.comuns_por_grupo)
		verificacoes+=1
		if gerador._populacao.size()!=esperado:
			falhas+=1
			push_error("População incompleta %d: %d/%d"%[andar,gerador._populacao.size(),esperado])
		var presos:=0
		for inimigo in gerador._populacao:
			inimigo.set_physics_process(false)
			if inimigo.has_node("PatrulhaAndar"): inimigo.get_node("PatrulhaAndar").set_physics_process(false)
			if inimigo.collision_mask==0: continue
			var corpo=inimigo.get_node("colision_body")
			var consulta:=PhysicsShapeQueryParameters2D.new()
			consulta.shape=corpo.shape
			consulta.transform=corpo.global_transform
			consulta.collision_mask=64
			verificacoes+=1
			if not inimigo.get_world_2d().direct_space_state.intersect_shape(consulta,1).is_empty():
				presos+=1
				print("SPAWN PRESO ",andar," ",inimigo.scene_file_path," ",inimigo.position)
		falhas+=presos
		print("NASCIMENTOS ",andar," presos=",presos," total=",gerador._populacao.size())
		gerador.limpar_populacao()
		await quadros()
	print("ROTAS MOBS: ",verificacoes," verificações, ",falhas," falhas")
	quit(1 if falhas else 0)
