extends SceneTree

## Projeção com a população real dos mapas. Não substitui uma sessão com jogador novo.
## Considera 2 golpes/s, 65% de tempo acertando, sem comida, poções ou melhorias permanentes.
var linhas: Array = []
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.get_node("Introducao").pular_prologo()
	root.get_node("Introducao").aula_arena = false
	var inv = root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	root.get_node("Progresso").iniciar_partida()
	var catalogo = load("res://codigo/fendas/catalogo_andares.gd")
	var banco = load("res://codigo/dados/equipamentos.gd").new()
	for andar in range(1,11):
		var transicao = root.get_node("Transicao")
		transicao.retornando = true
		transicao.estado = {"onda_atual":andar}
		change_scene_to_file(catalogo.cena(andar))
		await quadros(12)
		transicao.retornando = false
		var gerente = current_scene.get_node("enemySpawner/GerenciadorOndas")
		gerente.chance_evento = 0.0
		gerente.iniciar_onda(true)
		await quadros()
		gerente.set_physics_process(false)
		var vida_total := 0.0
		var pontos_totais := 0
		var dados: Dictionary = catalogo.dados(andar)
		for inimigo in gerente.gerador._populacao:
			inimigo.set_physics_process(false)
			vida_total += inimigo.vida
			pontos_totais += int(dados.combate.pontos_elite if inimigo.has_meta("elite_andar") else dados.combate.pontos_comum)
		var fracao: float = float(gerente.META_PROGRESSO)/pontos_totais
		var hp_guardiao: float = (180+24*(andar-1))*gerente.multiplicador_vida_inimigo
		var nivel := 1 if andar < 4 else (2 if andar < 8 else 3)
		var dano: float = float(banco.obter_dados_nivel_arma("espada_basica",nivel).dano)+5.0
		var dps := dano*2.0*0.65*1.06
		var estimativa := (vida_total*fracao+hp_guardiao)/dps
		var comuns_estimados := ceili(gerente.gerador._populacao.size()*fracao)
		var ouro: int = comuns_estimados*gerente.ouro_por_abate(andar)+gerente.ouro_fim_onda(andar)
		linhas.append({"andar":andar,"populacao":gerente.gerador._populacao.size(),"meta":gerente.META_PROGRESSO,"fracao":fracao,"vida_guardiao":hp_guardiao,"espada_projetada":nivel,"combate_segundos_estimados":roundi(estimativa),"ouro_estimado":ouro})
		print("RITMO ",JSON.stringify(linhas[-1]))
	banco.free()
	var arquivo := FileAccess.open("/tmp/algoland-metricas-10-andares.json",FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"premissas":"2 golpes/s, 65% de acertos, critico medio de 6%, arma projetada nv1/2/3, sem deslocamento, mortes, comida ou escolhas. Projecao, nao medicao de sessao humana.","andares":linhas},"\t"))
	arquivo.close()
	quit()
