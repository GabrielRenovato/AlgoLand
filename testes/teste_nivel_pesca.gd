extends SceneTree

const Habilidade := preload("res://codigo/pesca/progressao_pesca.gd")
const Peixes := preload("res://codigo/pesca/peixes.gd")
const Pedidos := preload("res://codigo/pesca/desafios_pesca.gd")
var falhas := 0

func _initialize() -> void:
	_rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	var fazenda: Node = root.get_node("Fazenda")
	fazenda._zerar()
	var inventario: Node = root.get_node("InventarioJogador")
	inventario.limpar()
	# Os testes de integração usam os donos reais; aqui validamos o estado salvo de ambos.
	verificar("habilidade nova começa no nível 1", Habilidade.nivel() == 1)
	var limites := true
	for nv in range(2, 100):
		var limiar := Habilidade.xp_para_nivel(nv)
		limites = limites and Habilidade.nivel_da_xp(limiar) == nv and Habilidade.nivel_da_xp(limiar - 1) == nv - 1
	verificar("98 limites de XP exatos", limites)
	verificar("nível limitado entre 1 e 99", Habilidade.nivel_da_xp(-50) == 1 and Habilidade.nivel_da_xp(99999999) == 99)
	var base := Habilidade.experiencia_peixe("sardinha")
	verificar("perfeita dá 50% extra e qualidade soma bônus", Habilidade.experiencia_peixe("sardinha", true) == roundi(base * 1.5) and Habilidade.experiencia_peixe("sardinha", true, 3) > Habilidade.experiencia_peixe("sardinha", true))
	verificar("pedras não dão XP", Habilidade.experiencia_peixe("pedra_vara") == 0)
	fazenda.pescar("sardinha")
	verificar("captura recebida dá XP", Habilidade.xp() == base)
	var antes := Habilidade.xp()
	fazenda.pescar("inexistente")
	verificar("captura inválida não dá XP", Habilidade.xp() == antes)
	var mochila_antes: Array = inventario.mochila.duplicate()
	var quantidade_antes: int = inventario.mochila[0].quantidade
	inventario.mochila[0].quantidade = 9999
	for i in inventario.mochila.size(): inventario.mochila[i] = inventario.mochila[0]
	verificar("mochila cheia não concede XP nem peixe", not fazenda.pescar("carpa") and Habilidade.xp() == antes and not fazenda.peixes_pescados.has("carpa"))
	inventario.mochila = mochila_antes
	inventario.mochila[0].quantidade = quantidade_antes
	fazenda.vender_peixes()
	verificar("vender preserva habilidade", Habilidade.xp() == antes)
	fazenda.pesca_xp = {"p1": Habilidade.xp_para_nivel(50), "p2": Habilidade.xp_para_nivel(80)}
	fazenda.salvar()
	fazenda.carregar()
	verificar("XP individual de P1 e P2 persiste", Habilidade.nivel() == 50 and Habilidade.nivel_da_xp(int(fazenda.pesca_xp["p2"])) == 80)
	var pedido: Array = fazenda.pedidos_pesca()
	fazenda.pesca_xp["p1"] = Habilidade.xp_para_nivel(99)
	verificar("subir de nível mantém a encomenda do dia", fazenda.pedidos_pesca() == pedido)
	fazenda.pescar("sardinha", true)
	verificar("XP para de crescer no nível 99", Habilidade.xp() == Habilidade.xp_para_nivel(99))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261025
	var sorteios := true
	var encomendas := true
	for nv in [1, 5, 10, 20, 25, 35, 40, 50, 60, 80, 90, 99]:
		for estacao in 4:
			for ambiente in ["mar", "rio"]:
				for i in 100:
					var id := Peixes.sortear(ambiente, estacao, rng, nv)
					sorteios = sorteios and Peixes.existe(id) and Peixes.nivel_pesca(id) <= nv and Peixes.catalogo()[id]["ambiente"] == ambiente
					var epocas: Array = Peixes.DADOS[id]["estacoes"]
					sorteios = sorteios and (epocas.is_empty() or epocas.has(estacao))
			for dia in range(1, 31):
				for p in Pedidos.pedidos_do_dia(dia, estacao, nv):
					encomendas = encomendas and Peixes.nivel_pesca(p["peixe"]) <= nv
	verificar("9600 sorteios respeitam nível, água e estação", sorteios)
	verificar("encomendas não exigem peixes bloqueados", encomendas)
	verificar("seis espécies novas e duas recompensas no 99", Peixes.DADOS.size() == 54 and Peixes.nivel_pesca("imperador_abissal") == 99 and Peixes.nivel_pesca("carpa_celestial") == 99)
	var texturas := true
	for id in ["peixe_leao", "acara_disco", "peixe_mandarim", "aruana_prateada", "imperador_abissal", "carpa_celestial"]:
		var icone := Peixes.icone(id)
		texturas = texturas and icone != null and icone.get_size() == Vector2(16, 16)
	verificar("ícones novos carregam em 16 por 16", texturas)
	# Simular save legado sem o campo de XP e conferir migração única.
	fazenda.salvar()
	var legado: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fazenda.caminho_save))
	legado.erase("pesca_xp")
	legado["pesca_capturas_jogador"] = {"p1": 40, "p2": 20}
	var arquivo := FileAccess.open(fazenda.caminho_save, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(legado))
	arquivo.close()
	fazenda.carregar()
	verificar("save antigo recebe crédito por jogador", int(fazenda.pesca_xp["p1"]) == 2400 and int(fazenda.pesca_xp["p2"]) == 1200)
	fazenda.salvar()
	fazenda.carregar()
	verificar("migração não repete XP", Habilidade.xp() == 2400)
	fazenda._zerar()
	verificar("novo mundo zera habilidade", Habilidade.nivel() == 1 and fazenda.pesca_xp.is_empty())
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
