extends SceneTree

var falhas := 0
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
	var catalogo = load("res://codigo/fendas/catalogo_andares.gd")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena=false
	root.get_node("Cooperativo").sair()
	root.get_node("Progresso").iniciar_partida()
	for andar in [1,3,10]:
		var transicao: Node=root.get_node("Transicao")
		transicao.retornando=true
		transicao.estado={"onda_atual":andar}
		transicao.iniciar_onda_ao_chegar=false
		change_scene_to_file(catalogo.cena(andar))
		await quadros(15)
		transicao.retornando=false
		var jogador: Node2D=current_scene.get_node("Jogador")
		jogador.set_physics_process(false)
		jogador.invulneravel=true
		jogador.temporizador_invul=10000
		var gerente: Node=current_scene.get_node("enemySpawner/GerenciadorOndas")
		var gerador: Node=current_scene.get_node("enemySpawner")
		gerente.iniciar_onda(true)
		await quadros(5)
		gerente.set_physics_process(false)
		var origens := {}
		var total := 0
		var disponivel := 0
		var alvo: Node2D
		var dados: Dictionary=catalogo.dados(andar)
		for inimigo in gerador._populacao:
			disponivel += int(dados.combate.pontos_elite if inimigo.has_meta("elite_andar") else dados.combate.pontos_comum)
			if inimigo.get("parado")==true: continue
			origens[inimigo.get_instance_id()]=inimigo.global_position
			total+=1
			if alvo==null: alvo=inimigo
		var contagem := 0
		for s in dados.setores: contagem+=int(s.grupos)*int(dados.combate.comuns_por_grupo)
		contagem+=int(dados.combate.elites)
		verificar("populacao ampliada completa %d" % andar,gerador._populacao.size()==contagem)
		verificar("barra preserva ritmo de 60 a 72 por cento com arredondamento %d" % andar,gerente.META_PROGRESSO>=disponivel*.60 and gerente.META_PROGRESSO<=ceili(disponivel*.72))
		verificar("entrada nao atrai o mapa inteiro %d" % andar,gerente._adormecidos.size()==gerador._populacao.size())
		await quadros(180)
		var andando := 0
		var locais := true
		for inimigo in gerador._populacao:
			if not origens.has(inimigo.get_instance_id()): continue
			var distancia: float=inimigo.global_position.distance_to(origens[inimigo.get_instance_id()])
			if distancia>4: andando+=1
			if distancia>150: locais=false
		verificar("maioria se desloca patrulhando %d: %d/%d" % [andar,andando,total],andando>=maxi(1,ceili(total*.55)))
		verificar("patrulhas permanecem no setor %d" % andar,locais)
		for inimigo in gerador._populacao:
			if inimigo.has_node("PatrulhaAndar"): inimigo.get_node("PatrulhaAndar").set_physics_process(false)
		if is_instance_valid(alvo):
			var grupo: String=str(alvo.get_meta("grupo_andar"))
			alvo.vida-=1
			gerente._physics_process(.21)
			var grupo_ativo := true
			var outros_dormem := false
			for inimigo in gerador._populacao:
				if str(inimigo.get_meta("grupo_andar"))==grupo and not inimigo.is_physics_processing(): grupo_ativo=false
				if str(inimigo.get_meta("grupo_andar"))!=grupo and not inimigo.is_physics_processing(): outros_dormem=true
			verificar("dano alerta o grupo sem acordar todo mapa %d" % andar,grupo_ativo and outros_dormem)
		gerente.parar_ondas()
		await quadros()
	quit(1 if falhas else 0)
