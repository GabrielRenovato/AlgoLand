extends SceneTree
var falhas := 0
var catalogo: GDScript
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas+=1
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	catalogo=load("res://codigo/fendas/catalogo_andares.gd")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena=false
	root.get_node("Cooperativo").sair()
	var prog := root.get_node("Progresso")
	prog.iniciar_partida()
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.adicionar(preload("res://codigo/dados/forja_armas.gd").criar_item("picareta"))
	for andar in [6,9]:
		var transicao := root.get_node("Transicao")
		transicao.retornando=true
		transicao.estado={"onda_atual":andar}
		transicao.iniciar_onda_ao_chegar=false
		change_scene_to_file(catalogo.cena(andar))
		await quadros(14)
		transicao.retornando=false
		var gerente: Node=current_scene.get_node("enemySpawner/GerenciadorOndas")
		var gerador: Node=current_scene.get_node("enemySpawner")
		var jogador: Node=current_scene.get_node("Jogador")
		jogador.set_physics_process(false)
		jogador.invulneravel=true
		jogador.temporizador_invul=10000
		gerente.iniciar_onda(true)
		await quadros(10)
		gerente.set_physics_process(false)
		for inimigo in gerador._populacao:
			inimigo.set_physics_process(false)
			if inimigo.has_node("PatrulhaAndar"): inimigo.get_node("PatrulhaAndar").set_physics_process(false)
		var mineracao: Node=current_scene.get_node("MineracaoArena")
		verificar("veio da arena aparece no andar %d" % andar,mineracao._veios.size()==1)
		if not mineracao._veios.is_empty():
			var veio: Node2D=mineracao._veios.values()[0]
			var centro_veio: Vector2=veio.global_position-Vector2(0,6)
			var mapa: RID=current_scene.get_world_2d().navigation_map
			var recorte := true
			for camada in [1,2,4]:
				var entrada: Vector2=current_scene.get_node("Terrains/Chegada_portal").global_position
				var rota := NavigationServer2D.map_get_path(mapa,entrada,centro_veio,true,camada)
				if rota.is_empty() or rota[-1].distance_to(centro_veio)<18: recorte=false
			verificar("navegacao contorna a base do minerio %d" % andar,recorte)
			verificar("veio não nasce sobre mobs %d" % andar,gerador._populacao.all(func(i): return i.global_position.distance_to(veio.global_position)>=64))
			jogador.global_position=veio.global_position-Vector2(0,29)
			jogador._direcao_ataque=Vector2.DOWN
			root.get_node("Fazenda")._definir_energia(1,100)
			for golpe in 3:
				verificar("picareta funciona no andar %d" % andar,mineracao.pedir_golpe(jogador))
				for i in 80:
					await physics_frame
					if not jogador.esta_em_acao_fazenda: break
			await quadros()
			verificar("extrair reabre o chao na navegacao %d" % andar,NavigationServer2D.map_get_closest_point(mapa,centro_veio).distance_to(centro_veio)<2)
			verificar("ferro é item físico no andar %d" % andar,get_nodes_in_group("equipamento_drop").any(func(d): return d.item.tipo=="material:ferro") or inv.quantidade_tipo("material:ferro")>0)
		gerente._invocar_guardiao(gerente._geracao)
		await create_timer(2).timeout
		var chefe: Node2D=gerente.guardiao
		chefe.set_physics_process(false)
		gerador._concluir_abate(chefe,0,true,gerente._geracao)
		await quadros()
		for tipo in ["fragmento","nucleo"]:
			verificar("guardião entrega material físico %s no andar %d" % [tipo,andar],get_nodes_in_group("equipamento_drop").any(func(d): return d.item.tipo=="material:"+tipo))
		verificar("guardião entrega receita no andar %d" % andar,get_nodes_in_group("equipamento_drop").any(func(d): return d.item.categoria=="receita"))
		gerente.parar_ondas()
		current_scene.queue_free()
		current_scene=null
		await quadros()
	quit(0 if falhas==0 else 1)
