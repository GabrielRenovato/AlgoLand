extends SceneTree
# Rodar com save isolado (AlgoLand testes...): as poções seguem a estação do calendário. Duas por estação, o caldeirão só faz as da
# época, o inverno usa peixes no lugar de plantas e os efeitos novos (regeneração e crítico) funcionam.

var falhas := 0
func v(nome: String, ok: bool, det := "") -> void:
	print("OK " if ok else "FALHA ", nome, " ", det)
	if not ok: falhas += 1
func q(n := 4) -> void:
	for i in n: await process_frame
func _initialize() -> void: _rodar.call_deferred()

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use um save isolado AlgoLand testes.")
		quit(1)
		return
	await process_frame
	var Pocoes := load("res://codigo/dados/pocoes.gd")
	var fazenda: Node = root.get_node("Fazenda"); fazenda.caminho_save = "user://teste_pe_fazenda.json"; fazenda.apagar()
	var cal: Node = root.get_node("Calendario"); cal.caminho_save = "user://teste_pe_calendario.json"
	var inv: Node = root.get_node("InventarioJogador"); inv.limpar(); inv.criar_itens_iniciais()
	# Duas poções por estação
	for estacao in 4:
		var da_estacao: Array = Pocoes.ORDEM.filter(func(id): return Pocoes.estacao_de(id) == estacao)
		v("estação %d tem duas poções" % estacao, da_estacao.size() == 2, str(da_estacao))
	v("toda poção tem estação e ordem", Pocoes.ORDEM.size() == 8 and Pocoes.ORDEM.all(func(id): return Pocoes.estacao_de(id) >= 0))
	# Verão x primavera: com os ingredientes de verão no inventário
	cal.dia = 1 + cal.DIAS_POR_ESTACAO          # verão
	for item in [["tomate",2],["melancia",1],["cenoura",2],["morango",1]]:
		inv.adicionar_coletavel("colheita", item[0], item[1])
	v("verão faz força", fazenda.motivo_para_nao_fazer("forca") == "", fazenda.motivo_para_nao_fazer("forca"))
	v("verão não faz cura, mesmo com os ingredientes", fazenda.motivo_para_nao_fazer("cura") == "SO NA PRIMAVERA", fazenda.motivo_para_nao_fazer("cura"))
	v("verão não faz poção de inverno", fazenda.motivo_para_nao_fazer("regeneracao") == "SO NO INVERNO", fazenda.motivo_para_nao_fazer("regeneracao"))
	v("fazer fora de época é recusado", fazenda.fazer_pocao("cura") == "SO NA PRIMAVERA" and fazenda.quantidade_colhida("cenoura") == 2)
	v("fazer força consome as plantas", fazenda.fazer_pocao("forca") == "" and fazenda.quantidade_pocoes("forca") == 1 and fazenda.quantidade_colhida("tomate") == 0)
	# Inverno: peixes
	cal.dia = 1 + cal.DIAS_POR_ESTACAO * 3
	v("inverno sem peixes não faz", fazenda.motivo_para_nao_fazer("regeneracao") == fazenda.MSG_FALTA_INGREDIENTE)
	inv.adicionar_peixe("truta", 0, 2); inv.adicionar_peixe("tainha", 0, 1)
	inv.adicionar_peixe("linguado", 0, 2); inv.adicionar_peixe("sargo", 0, 1)
	v("inverno com peixes faz regeneração", fazenda.motivo_para_nao_fazer("regeneracao") == "")
	v("fazer regeneração gasta os peixes", fazenda.fazer_pocao("regeneracao") == "" and fazenda.quantidade_pocoes("regeneracao") == 1 and fazenda.quantidade_peixes("truta") == 0 and fazenda.quantidade_peixes("tainha") == 0)
	v("peixes da outra receita ficam", fazenda.quantidade_peixes("linguado") == 2 and fazenda.motivo_para_nao_fazer("precisao") == "")
	v("no inverno a força de verão fica fora de época", fazenda.motivo_para_nao_fazer("forca") == "SO NO VERAO")
	# Efeitos dos novos tipos
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva = 12.0
	change_scene_to_file("res://cenas/cenario.tscn")
	await q(25)
	var jogador: Node2D = current_scene.get_node("Jogador")
	var efeitos: Node = jogador.efeitos_pocao
	jogador.hp_atual = 10
	efeitos.ativos["regeneracao"] = {"pocao": "regeneracao", "restante": 15.0, "duracao": 15.0, "valor": 0.02}
	var antes: int = jogador.hp_atual
	efeitos._process(1.0); efeitos._process(1.0); efeitos._process(1.0)
	var esperado := roundi(3.0 * 0.02 * jogador.estatisticas.hp_maximo)
	v("regeneração cura por segundo", jogador.hp_atual - antes >= esperado - 1 and jogador.hp_atual - antes <= esperado + 1, "curou %d (esperava ~%d)" % [jogador.hp_atual - antes, esperado])
	efeitos._process(20.0)
	v("regeneração acaba depois do tempo", not efeitos.esta_ativo("regeneracao"))
	efeitos.ativos["critico"] = {"pocao": "precisao", "restante": 30.0, "duracao": 30.0, "valor": 0.2}
	var est = jogador.estatisticas
	var criticos := 0
	var total := 4000
	for i in total:
		if est.calcular_dano_golpe(efeitos.bonus("critico")).critico: criticos += 1
	var sem := 0
	for i in total:
		if est.calcular_dano_golpe(0.0).critico: sem += 1
	v("precisão aumenta a chance de crítico em cerca de 20 pontos", float(criticos - sem) / total > 0.14 and float(criticos - sem) / total < 0.26, "com %d, sem %d de %d" % [criticos, sem, total])
	print("FALHAS: ", falhas); quit(falhas)
