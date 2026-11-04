extends SceneTree

var falhas := 0
func _initialize() -> void:rodar.call_deferred()
func quadros(n:=8) -> void:
	for i in n:
		await physics_frame
		await process_frame
func verificar(nome:String,ok:bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1);return
	await process_frame
	var catalogo:=load("res://codigo/fendas/catalogo_andares.gd")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena=false
	root.get_node("Progresso").iniciar_partida()
	root.get_node("Fazenda").definir_clima_hoje(0)
	var transicao:Node=root.get_node("Transicao")
	transicao.retornando=true;transicao.estado={"onda_atual":4};transicao.iniciar_onda_ao_chegar=false
	change_scene_to_file(catalogo.cena(4))
	await quadros(12);transicao.retornando=false
	var gerente:Node=current_scene.get_node("enemySpawner/GerenciadorOndas")
	var gerador:Node=current_scene.get_node("enemySpawner")
	gerente.iniciar_onda(true);await quadros(4);gerente.set_physics_process(false)
	var por_grupo:Dictionary={}
	var adagas:=0;var machados:=0
	for mob in gerador._populacao:
		mob.set_physics_process(false)
		if mob.has_node("PatrulhaAndar"):mob.get_node("PatrulhaAndar").set_physics_process(false)
		var grupo:=str(mob.get_meta("grupo_andar",""))
		if not por_grupo.has(grupo):por_grupo[grupo]={"adaga":0,"machado":0}
		if mob.scene_file_path.ends_with("goblin_pomar.tscn"):
			adagas+=1;por_grupo[grupo].adaga+=1
		elif mob.scene_file_path.ends_with("goblin_machado_fenda.tscn"):
			machados+=1;por_grupo[grupo].machado+=1
			var ficha:Dictionary=load("res://assets/inimigos/goblin_machado_3d/atlas/animacoes.json").data
			verificar("machado tem seis animações e impactos marcados",ficha.animacoes.size()==6 and ficha.animacoes.ataque_1.impacto>0 and ficha.animacoes.ataque_2.impacto>0)
			mob.iniciar_ataque(Vector2.RIGHT)
			verificar("goblin de machado inicia um dos golpes",mob.animacao in ["ataque_1","ataque_2"])
			mob.set_physics_process(false)
	var misturadas:=por_grupo.size()==current_scene.get_node("Terrains/GruposCombate").get_child_count()
	for grupo in por_grupo.values():
		if int(grupo.adaga)<1 or int(grupo.machado)<1:misturadas=false
	verificar("as dez câmaras misturam adagas e machados",misturadas)
	verificar("ambas as espécies aparecem em quantidade",adagas>=10 and machados>=10)
	verificar("população sem morcegos ou outras criaturas Mana Seed",adagas+machados==gerador._populacao.size())
	var esperados:=int(catalogo.dados(4).combate.elites)
	for setor in catalogo.dados(4).setores:esperados+=int(setor.grupos)*int(catalogo.dados(4).combate.comuns_por_grupo)
	verificar("grupo de combate mantém a população planejada",gerador._populacao.size()==esperados)
	gerente.parar_ondas();await quadros(3)
	print("Goblin Gruta: %d falhas" % falhas)
	quit(1 if falhas else 0)
