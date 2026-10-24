extends SceneTree
# Save isolado: oito poções nas quatro estações, ingredientes disponíveis, consumo e transição sem perda.

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
	var Plantas := load("res://codigo/dados/plantas.gd")
	var Peixes := load("res://codigo/pesca/peixes.gd")
	for estacao in 4:
		cal.dia = 1 + cal.DIAS_POR_ESTACAO * estacao
		for id in Pocoes.ORDEM:
			inv.limpar()
			var formula: Dictionary = Pocoes.receita_da_estacao(id,estacao)
			v("falta ingrediente: %s / %d" % [id,estacao], fazenda.motivo_para_nao_fazer(id) == fazenda.MSG_FALTA_INGREDIENTE)
			for planta in formula.receita:
				v("planta disponível: %s / %d" % [planta,estacao], int(Plantas.PLANTAS[planta].estacao) == estacao)
				inv.adicionar_coletavel("colheita",planta,int(formula.receita[planta]))
			for peixe in formula.peixes:
				var epocas: Array = Peixes.DADOS[peixe].estacoes
				v("peixe disponível: %s / %d" % [peixe,estacao], epocas.is_empty() or estacao in epocas)
				inv.adicionar_peixe(peixe,0,int(formula.peixes[peixe]))
			v("prepara %s / %d" % [id,estacao], fazenda.fazer_pocao(id) == "" and fazenda.quantidade_pocoes(id) == 1)
			for planta in formula.receita:
				v("consumo exato %s" % planta, fazenda.quantidade_colhida(planta) == 0)
			for peixe in formula.peixes:
				v("consumo exato %s" % peixe, fazenda.quantidade_peixes(peixe) == 0)
			v("não fabrica sem os ingredientes novamente",fazenda.fazer_pocao(id) == fazenda.MSG_FALTA_INGREDIENTE and fazenda.quantidade_pocoes(id) == 1)
	# A virada da estação muda a receita sem apagar o estoque de poções/colheita.
	inv.limpar();cal.dia=1
	inv.adicionar_coletavel("colheita","cenoura",2);inv.adicionar_coletavel("colheita","morango",1)
	cal.dia=1+cal.DIAS_POR_ESTACAO
	var antes_receita: Array=inv.fotografar_mochila()
	v("troca de estação recusa receita antiga sem gastar",fazenda.fazer_pocao("cura") == fazenda.MSG_FALTA_INGREDIENTE and inv.fotografar_mochila() == antes_receita)
	inv.adicionar_coletavel("colheita","milho",2);inv.adicionar_coletavel("colheita","girassol",1)
	v("cura disponível no verão",fazenda.fazer_pocao("cura") == "" and fazenda.quantidade_pocoes("cura") == 1)
	v("colheita da primavera preservada",fazenda.quantidade_colhida("cenoura") == 2 and fazenda.quantidade_colhida("morango") == 1)
	cal.dia=1+cal.DIAS_POR_ESTACAO*3
	inv.adicionar_peixe("sardinha",0,2);inv.adicionar_peixe("carpa",0,1)
	v("cura disponível no inverno e mesma pilha",fazenda.fazer_pocao("cura") == "" and fazenda.quantidade_pocoes("cura") == 2)
	v("ids inválidos rejeitados",fazenda.fazer_pocao("invalida") == "POCAO INVALIDA" and Pocoes.receita_da_estacao("cura",4).is_empty())
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
