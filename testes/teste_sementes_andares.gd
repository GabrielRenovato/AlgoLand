extends SceneTree

var falhas := 0

class GuardiaoTeste extends Node2D:
	var eh_chefe := true
	var eh_mutante := false

func _initialize() -> void:
	rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	var sementes = load("res://codigo/logica/semente_drop.gd")
	var rng := RandomNumberGenerator.new()
	# Comparar amostras repetíveis, incluindo os bônus dos mutantes e dos guardiões.
	for mutante in [false, true]:
		var antigo := 0
		var atual := 0
		for modo in [false, true]:
			rng.seed = 70419
			for i in 100000:
				var quantidade: int = sementes.sortear(0, mutante, false, rng, modo).size()
				if modo: atual += quantidade
				else: antigo += quantidade
		verificar("sementes de mobs reduzidas em cerca de 75%%, mutante=%s (%d -> %d)" % [mutante, antigo, atual], atual > antigo * 0.20 and atual < antigo * 0.30)
	var respeita_estacoes := true
	var minimo := 99
	var total := 0
	rng.seed = 70419
	for estacao in 4:
		for i in 2000:
			var resultado: Array = sementes.sortear(estacao, false, true, rng, true)
			if estacao == 3:
				respeita_estacoes = respeita_estacoes and resultado.is_empty()
			else:
				minimo = mini(minimo, resultado.size())
				total += resultado.size()
				for planta in resultado:
					respeita_estacoes = respeita_estacoes and int(root.get_node("Fazenda").PLANTAS[planta].estacao) == estacao
	verificar("guardião garante uma semente e média fica abaixo de 1,2", minimo == 1 and total / 6000.0 < 1.2)
	verificar("sementes seguem a estação; inverno não solta nem a garantida", respeita_estacoes)
	# Exercitar a entrada real usada pelo gerador de encontros, sem carregar mapas ou gravar inventário.
	root.get_node("Introducao").pular_prologo()
	root.get_node("Calendario").dia = 1
	var pai := Node2D.new()
	root.add_child(pai)
	var gerente := Node.new()
	root.add_child(gerente)
	gerente.add_to_group("gerenciador_andar")
	var gerador = load("res://codigo/fendas/gerador_encontros.gd").new()
	gerador.principal = pai
	gerador.gerenciador_ondas = gerente
	var guardiao := GuardiaoTeste.new()
	for semente_rng in range(100):
		rng.seed = semente_rng
		if sementes.sortear(0, false, true, rng, true).size() == 1:
			gerador._rng_sementes.seed = semente_rng
			break
	gerador._soltar_sementes(guardiao)
	verificar("gerador de encontros aplica a tabela reduzida ao guardião", pai.get_child_count() == 1)
	guardiao.free()
	gerador.free()
	pai.queue_free()
	gerente.queue_free()
	await process_frame
	print("Sementes nos andares: %d falhas" % falhas)
	quit(1 if falhas else 0)
