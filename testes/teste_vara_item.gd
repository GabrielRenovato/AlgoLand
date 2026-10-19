extends SceneTree

## A vara de pesca é item da mochila de cada jogador: aparece nos saves antigos, muda de nível/cor com o refinamento,
## sobrevive à troca de partida e não vai para o baú. Saves isolados obrigatórios.

var falhas := 0

func _initialize() -> void:
	_rodar()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func varas_em(inventario: Node) -> Array:
	return inventario.mochila.filter(func(i): return i != null and i.categoria == "vara")

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	var varas = load("res://codigo/pesca/varas.gd")
	var icones = load("res://codigo/ui/icones_itens.gd")
	var fazenda: Node = root.get_node("Fazenda")
	var inv: Node = root.get_node("InventarioJogador")
	var inv2: Node = root.get_node("InventarioJogador2")
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	fazenda.varas_pesca = {}

	# --- Save antigo (sem vara) ganha a vara ao carregar ---
	inv.limpar()
	inv.criar_itens_iniciais()
	for i in inv.mochila.size():
		if inv.mochila[i] != null and inv.mochila[i].categoria == "vara":
			inv.mochila[i] = null
	verificar("sem vara antes", varas_em(inv).is_empty())
	inv.salvar()
	inv.carregar()
	verificar("carregar repõe a vara gratuita",varas_em(inv).size()==1)
	inv.carregar()
	verificar("carregar de novo nao duplica", varas_em(inv).size() == 1)
	var vara = varas_em(inv)[0]
	verificar("nasce no nivel 1 comum", vara.nivel == 1 and vara.raridade == "comum" and vara.nome() == "VARA DE PESCA")

	# --- Refinar muda nivel, cor da casa e icone ---
	inv.adicionar_coletavel("material", "pedra_vara", 20)
	var corpo := CharacterBody2D.new()  # sem "eh_p2": conta como o jogador 1
	var cores_vistas := {}
	for nv in range(2, 6):
		verificar("melhorar para NV %d" % nv, varas.melhorar(corpo))
		var item = varas_em(inv)[0]
		verificar("item NV %d, raridade %s" % [nv, item.raridade], item.nivel == nv and item.raridade == ["comum", "incomum", "raro", "epico", "lendario"][nv - 1])
		cores_vistas[nv] = icones.icone_vara(nv).get_image().get_data()
	verificar("icones de cada nivel sao diferentes", cores_vistas[2] != cores_vistas[3] and cores_vistas[3] != cores_vistas[4] and cores_vistas[4] != cores_vistas[5])
	verificar("icone NV5 difere do NV1", icones.icone_vara(1).get_image().get_data() != cores_vistas[5])
	verificar("varas.melhorar nao cria segunda", varas_em(inv).size() == 1)

	# --- Save e carga mantem o nivel ---
	inv.salvar()
	fazenda.salvar()
	inv.carregar()
	fazenda.carregar()
	verificar("nivel sobrevive ao save", varas_em(inv).size() == 1 and varas_em(inv)[0].nivel == 5)

	# --- Nova partida (kit inicial) mantem a mesma vara ---
	var guardado: Dictionary = inv.guardar_para_nova_partida()
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.restaurar_da_partida_anterior(guardado)
	verificar("nova partida: uma vara so, no nivel 5", varas_em(inv).size() == 1 and varas_em(inv)[0].nivel == 5)

	# --- Jogador 2 tem a sua, no nivel dele ---
	inv2.limpar()
	inv2.criar_itens_iniciais()
	verificar("vara inicial do P2 começa no nível 1", varas_em(inv2).size() == 1 and varas_em(inv2)[0].nivel == 1)
	corpo.free()
	print("FALHAS: ", falhas)
	quit(1 if falhas else 0)
