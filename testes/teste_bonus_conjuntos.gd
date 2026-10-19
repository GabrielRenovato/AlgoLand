extends SceneTree

## Bônus por 2/4 e 4/4 peças, escala por nível, moeda de forja dos chefes e custo da bigorna. Saves somente na cópia isolada.
const Carrasco := preload("res://codigo/dados/conjunto_carrasco.gd")
const Rubro := preload("res://assets/personagens/conjuntos/cavaleiro_rubro/definicao.gd")
const Mordomo := preload("res://assets/personagens/conjuntos/cavalheiro/definicao.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
var _falhas := 0
var Drop: GDScript

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, passou: bool) -> void:
	print("OK " if passou else "FALHA ", nome)
	if not passou:
		_falhas += 1

func _equipados(conjunto: GDScript, pecas: int, nivel: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var resultado := {"cabeca": null, "corpo": null, "luvas": null, "botas": null}
	var slots := ["cabeca", "corpo", "luvas", "botas"]
	for i in pecas:
		for tipo in conjunto.TIPOS:
			if conjunto.TIPOS[tipo]["slot"] == slots[i]:
				var item: DadosItem = Drop.criar_item(rng, 1, false, false, "", tipo)
				item.nivel = nivel
				resultado[slots[i]] = item
	return resultado

func _rodar() -> void:
	await process_frame
	Drop = load("res://codigo/logica/equipamento_drop.gd")
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Use a cópia isolada AlgoLand testes Carrasco.")
		quit(1)
		return
	for conjunto in Conjuntos.CONJUNTOS:
		_verificar(conjunto.ID + ": comum e disponível desde a onda 1", conjunto.RARIDADE == "comum" and conjunto.ONDA_MINIMA == 1 and conjunto.chance_drop(1, false, true) > 0.0)
		var rng := RandomNumberGenerator.new()
		var item: DadosItem = Drop.criar_item(rng, 60, false, true, "", conjunto.TIPOS.keys()[0])
		_verificar(conjunto.ID + ": peça cai no nível 1 mesmo em onda alta", item.nivel == 1 and item.raridade == "comum")
	# Fatores: 0 / 1 peça = nada; 2 e 3 = metade; 4 = completo; nível 5 = 2x
	_verificar("1 peça não dá bônus", Conjuntos.fator(Carrasco, _equipados(Carrasco, 1, 1)) == 0.0)
	_verificar("2 peças dão metade", is_equal_approx(Conjuntos.fator(Carrasco, _equipados(Carrasco, 2, 1)), 0.5))
	_verificar("3 peças dão metade", is_equal_approx(Conjuntos.fator(Carrasco, _equipados(Carrasco, 3, 1)), 0.5))
	_verificar("4 peças dão o efeito completo", is_equal_approx(Conjuntos.fator(Carrasco, _equipados(Carrasco, 4, 1)), 1.0))
	_verificar("nível 5 dobra o efeito", is_equal_approx(Conjuntos.fator(Carrasco, _equipados(Carrasco, 4, 5)), 2.0))
	var misto := _equipados(Carrasco, 4, 5)
	misto["botas"].nivel = 2
	_verificar("o nível do conjunto é o da peça mais fraca", is_equal_approx(Conjuntos.fator(Carrasco, misto), 1.25))
	# Raio do Carrasco: chance 10% x fator
	_verificar("raio 2/4 usa 5%", Carrasco.pode_ativar(_equipados(Carrasco, 2, 1), 0.0, 0.049) and not Carrasco.pode_ativar(_equipados(Carrasco, 2, 1), 0.0, 0.051))
	_verificar("raio 4/4 nível 1 usa 10%", Carrasco.pode_ativar(_equipados(Carrasco, 4, 1), 0.0, 0.099) and not Carrasco.pode_ativar(_equipados(Carrasco, 4, 1), 0.0, 0.101))
	_verificar("raio 4/4 nível 5 usa 20%", Carrasco.pode_ativar(_equipados(Carrasco, 4, 5), 0.0, 0.199) and not Carrasco.pode_ativar(_equipados(Carrasco, 4, 5), 0.0, 0.201))
	_verificar("raio respeita a recarga", not Carrasco.pode_ativar(_equipados(Carrasco, 4, 5), 1.0, 0.0))
	_verificar("congelamento do Mordomo 2/4 usa 5%", Mordomo.pode_ativar(_equipados(Mordomo, 2, 1), 0.0, 0.049) and not Mordomo.pode_ativar(_equipados(Mordomo, 2, 1), 0.0, 0.051))
	# Rubro: status
	var rubro2 := Conjuntos.bonus_status(_equipados(Rubro, 2, 1))
	var rubro4 := Conjuntos.bonus_status(_equipados(Rubro, 4, 1))
	var rubro4_nv5 := Conjuntos.bonus_status(_equipados(Rubro, 4, 5))
	_verificar("Rubro 2/4 dá 5%", is_equal_approx(rubro2["defesa"], 0.05) and is_equal_approx(rubro2["vitalidade"], 0.05))
	_verificar("Rubro 4/4 dá 10%", is_equal_approx(rubro4["defesa"], 0.1))
	_verificar("Rubro 4/4 nível 5 dá 20%", is_equal_approx(rubro4_nv5["defesa"], 0.2) and is_equal_approx(rubro4_nv5["vitalidade"], 0.2))
	# Moeda de forja: só chefe, 5%
	var rng_moeda := RandomNumberGenerator.new()
	rng_moeda.seed = 77
	var chefe := 0
	var comum := 0
	for i in 20000:
		chefe += 1 if Drop.sortear_moeda_forja(rng_moeda, true) else 0
		comum += 1 if Drop.sortear_moeda_forja(rng_moeda, false) else 0
	_verificar("moeda de forja cai em ~5% dos chefes e nunca dos demais", chefe > 850 and chefe < 1150 and comum == 0)
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.adicionar_moedas_forja(2)
	_verificar("gastar moeda de forja", inv.gastar_moeda_forja() and inv.moedas_forja == 1)
	inv.salvar()
	inv.limpar()
	_verificar("limpar zera as moedas", inv.moedas_forja == 0)
	inv.carregar()
	_verificar("save guarda as moedas de forja", inv.moedas_forja == 1)
	_verificar("sem moeda não gasta", inv.gastar_moeda_forja() and not inv.gastar_moeda_forja() and inv.moedas_forja == 0)
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.salvar()
	# Peças só caem do chefe, por chance (nunca garantidas)
	var so_chefe := true
	var rng_mob := RandomNumberGenerator.new()
	rng_mob.seed = 5
	for i in 3000:
		var item_mob: DadosItem = Drop.criar_item(rng_mob, 50, i % 2 == 0, false)
		so_chefe = so_chefe and Conjuntos.de_tipo(item_mob.tipo) == null
	_verificar("mob normal e mutante nunca geram peça de conjunto", so_chefe)
	var pecas_chefe := 0
	for i in 2000:
		pecas_chefe += 1 if Conjuntos.de_tipo(Drop.criar_item(rng_mob, 50, false, true).tipo) != null else 0
	_verificar("chefe solta peça em ~30% dos equipamentos (10% por conjunto), não sempre", pecas_chefe > 480 and pecas_chefe < 720)
	# A cobertura gravada em cobertura/<pagina>.png tem de ser idêntica à calculada (a gravada evita ~200 ms de travada ao equipar)
	var Aparencia = load("res://codigo/dados/aparencia.gd")
	var coberturas_iguais := true
	for conjunto in Conjuntos.CONJUNTOS:
		for pagina in ["andar", "espada", "arco_p3"]:
			coberturas_iguais = coberturas_iguais and Aparencia._cobertura_das_pecas(pagina, conjunto.RAIZ_SPRITES) == Aparencia.calcular_cobertura(pagina, conjunto.RAIZ_SPRITES)
	_verificar("cobertura gravada igual à calculada nos três conjuntos", coberturas_iguais)
	# Morte: peças de conjunto (equipadas e na mochila, com nível) e moedas sobrevivem; o resto volta ao kit inicial
	inv.limpar()
	inv.criar_itens_iniciais()
	var rng_morte := RandomNumberGenerator.new()
	var elmo: DadosItem = Drop.criar_item(rng_morte, 1, false, false, "", "elmo_carrasco")
	elmo.nivel = 3
	var botas: DadosItem = Drop.criar_item(rng_morte, 1, false, false, "", "botas_cavalheiro")
	inv.adicionar(elmo)
	inv.adicionar(botas)
	inv.equipar(elmo)
	inv.adicionar_moedas_forja(4)
	var guardado: Dictionary = inv.guardar_para_nova_partida()
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.restaurar_da_partida_anterior(guardado)
	_verificar("morte: elmo equipado volta equipado e com o nível", inv.equipados["cabeca"] == elmo and elmo.nivel == 3)
	_verificar("morte: peça da mochila volta para a mochila", inv.mochila.has(botas) and inv.equipados["botas"] == null)
	_verificar("morte: moedas de forja ficam", inv.moedas_forja == 4)
	_verificar("morte: espada e escudo do kit continuam equipados", inv.equipados["arma"] != null and inv.equipados["escudo"] != null)
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.salvar()
	# Custo da bigorna: ouro como nas armas mais 1 moeda de forja; nível 5 é o máximo
	var custo := Equipamentos.dados_melhoria_conjunto(1)
	_verificar("nível 1 > 2 custa ouro e 1 moeda", custo["custo"] == Equipamentos.NIVEIS_CUSTO[1] and custo["moedas_forja"] == 1 and custo["onda_necessaria"] == Equipamentos.NIVEIS_ONDA[1])
	var ascensao := Equipamentos.dados_melhoria_conjunto(5, "comum")
	_verificar("nível 5 comum: próximo passo é a ascensão para incomum", ascensao.get("ascensao", false) and ascensao["raridade_nova"] == "incomum" and ascensao["moedas_forja"] == 1 and ascensao["custo"] == Equipamentos.CUSTOS_ASCENSAO[0])
	_verificar("lendário nível 5 é o máximo", Equipamentos.dados_melhoria_conjunto(5, "lendario").is_empty())
	print("Falhas: ", _falhas)
	quit(1 if _falhas > 0 else 0)
