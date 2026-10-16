extends SceneTree

const ScriptItem := preload("res://codigo/modelos/dados_item.gd")
var ScriptModelo: GDScript

var _falhas: int = 0

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use uma cópia com save isolado AlgoLand testes.")
		quit(1)
		return
	await process_frame
	ScriptModelo = load("res://codigo/modelos/modelo_inventario.gd")
	_testar_adicionar()
	_testar_mover_com_troca()
	_testar_equipar_move_anterior()
	_testar_casas_da_mao()
	_testar_linhas_extras()
	_testar_lanca_tira_escudo()
	_testar_desequipar()
	_testar_mochila_cheia()
	_testar_dict()
	_testar_sinais()
	_testar_itens_iniciais()
	_testar_arco_exige_aljava()
	quit(_falhas)

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _item(tipo: String, categoria: String, duas_maos: bool = false):
	var item = ScriptItem.new()
	item.id = StringName(tipo)
	item.tipo = tipo
	item.categoria = categoria
	item.duas_maos = duas_maos
	return item

func _modelo():
	return ScriptModelo.new()

func _testar_adicionar() -> void:
	var modelo = _modelo()
	var a = _item("espada_basica", "arma")
	var b = _item("escudo_basico", "escudo")
	_verificar("adicionar primeira livre", modelo.adicionar(a) == 0 and modelo.adicionar(b) == 1, "indices inesperados")
	modelo.mochila[0] = null
	var c = _item("botas_basicas", "botas")
	_verificar("adicionar reaproveita celula vazia", modelo.adicionar(c) == 0, "indice %d" % modelo.indice_de(c))
	modelo.free()

func _testar_mover_com_troca() -> void:
	var modelo = _modelo()
	var a = _item("espada_basica", "arma")
	var b = _item("escudo_basico", "escudo")
	modelo.adicionar(a)
	modelo.adicionar(b)
	modelo.mover_para_mochila(a, 1)
	_verificar("mover com troca", modelo.indice_de(a) == 1 and modelo.indice_de(b) == 0, "a=%d b=%d" % [modelo.indice_de(a), modelo.indice_de(b)])
	modelo.mover_para_mochila(a, 7)
	_verificar("mover para celula vazia", modelo.indice_de(a) == 7 and modelo.mochila[1] == null, "a=%d" % modelo.indice_de(a))
	modelo.equipar(b)
	modelo.mover_para_mochila(b, 7)
	_verificar("mover equipado para celula ocupada", modelo.indice_de(b) == 7 and modelo.slot_de(a) == "" and modelo.indice_de(a) == 0, "a=%d b=%d" % [modelo.indice_de(a), modelo.indice_de(b)])
	modelo.free()

func _testar_equipar_move_anterior() -> void:
	var modelo = _modelo()
	var espada = _item("espada_basica", "arma")
	var outra = _item("espada_forte", "arma")
	modelo.adicionar(_item("botas_basicas", "botas"))
	modelo.adicionar(espada)
	modelo.adicionar(outra)
	modelo.equipar(espada)
	var celula_livre: int = modelo.indice_de(espada)
	_verificar("equipar tira da mochila", modelo.slot_de(espada) == "arma" and celula_livre == -1, "slot=%s" % modelo.slot_de(espada))
	_verificar("a arma em uso ocupa a casa de onde saiu (casa 1 reservada e vazia no modelo)", modelo.celulas_da_mao["arma"] == 1 and modelo.mochila[1] == null and modelo.casa_reservada(1) and modelo.item_na_celula(1) == espada, str(modelo.celulas_da_mao))
	_verificar("nada novo entra na casa reservada", modelo.adicionar(_item("botas_basicas", "botas")) == 3, "foi para %d" % modelo.indice_de(modelo.mochila[3]) if modelo.mochila[3] != null else "casa 3 vazia")
	modelo.equipar(outra)
	_verificar("equipar outra arma devolve a anterior a casa que ela ocupava na mao", modelo.indice_de(espada) == 1 and modelo.slot_de(outra) == "arma", "indice=%d" % modelo.indice_de(espada))
	_verificar("a casa da mao passa a ser a de onde a nova veio", modelo.celulas_da_mao["arma"] == 2 and modelo.item_na_celula(2) == outra and modelo.mochila[2] == null, str(modelo.celulas_da_mao))
	# outro item caiu na casa da mao (2) por fora: a anterior fica na casa da nova (1)
	modelo.mochila[2] = _item("botas_basicas", "botas")
	var terceira = _item("espada_forte", "arma")
	modelo.mochila[1] = null
	modelo.mochila[1] = terceira
	modelo.equipar(terceira)
	_verificar("casa da mao ocupada por outro item: troca simples (a anterior fica onde a nova estava)", modelo.slot_de(terceira) == "arma" and modelo.indice_de(outra) == 1 and modelo.celulas_da_mao["arma"] == -1, "outra em %d, mao %s" % [modelo.indice_de(outra), str(modelo.celulas_da_mao)])
	modelo.free()

func _testar_linhas_extras() -> void:
	var modelo = _modelo()
	_verificar("mochila comeca com 24 casas e a proxima linha libera na onda 10", modelo.capacidade() == 24 and modelo.onda_da_proxima_linha() == 10, "%d %d" % [modelo.capacidade(), modelo.onda_da_proxima_linha()])
	_verificar("linhas por onda vencida: 9->0, 10->1, 29->1, 30->2, 60->3, 100->4, 280->7, 999->7", modelo.linhas_para_onda(9) == 0 and modelo.linhas_para_onda(10) == 1 and modelo.linhas_para_onda(29) == 1
			and modelo.linhas_para_onda(30) == 2 and modelo.linhas_para_onda(60) == 3 and modelo.linhas_para_onda(100) == 4 and modelo.linhas_para_onda(280) == 7 and modelo.linhas_para_onda(999) == 7, "")
	_verificar("o tamanho maximo e a base mais todas as linhas extras", modelo.TAMANHO_MAXIMO == modelo.TAMANHO_MOCHILA + modelo.COLUNAS_MOCHILA * modelo.ONDAS_LINHA_EXTRA.size(), "")
	for _i in modelo.TAMANHO_MOCHILA:
		modelo.adicionar(_item("botas_basicas", "botas"))
	_verificar("com 24 casas cheias nao cabe mais nada", not modelo.tem_espaco() and modelo.adicionar(_item("botas_basicas", "botas")) == -1, "")
	_verificar("nao da para mover para uma casa ainda bloqueada", not modelo.mover_para_mochila(modelo.mochila[0], 27), "")
	var avisos := [0]
	modelo.capacidade_alterada.connect(func(_c): avisos[0] += 1)
	modelo.definir_linhas_extras(1)
	_verificar("vencer a onda 10 libera mais 8 casas (32) e avisa", modelo.capacidade() == 32 and avisos[0] == 1 and modelo.onda_da_proxima_linha() == 30, "%d" % modelo.capacidade())
	_verificar("o item novo vai para a linha liberada", modelo.adicionar(_item("botas_basicas", "botas")) == 24, "")
	modelo.definir_linhas_extras(modelo.ONDAS_LINHA_EXTRA.size())
	_verificar("todas as linhas: 80 casas e nenhuma proxima", modelo.capacidade() == 80 and modelo.onda_da_proxima_linha() == -1, "")
	modelo.salvar("user://teste_inventario_linhas.json")
	var outro = _modelo()
	outro.definir_linhas_extras(outro.ONDAS_LINHA_EXTRA.size())
	outro.carregar("user://teste_inventario_linhas.json")
	_verificar("salvar e carregar mantem os itens das linhas extras", outro.mochila[15] != null, "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_inventario_linhas.json"))
	outro.free()
	modelo.free()

func _testar_casas_da_mao() -> void:
	var modelo = _modelo()
	var espada = _item("espada_basica", "arma")
	var escudo = _item("escudo_basico", "escudo")
	modelo.adicionar(espada)
	modelo.adicionar(escudo)
	modelo.equipar(espada)
	modelo.equipar(escudo)
	_verificar("escudo em uso tambem ocupa a casa dele", modelo.celulas_da_mao["escudo"] == 1 and modelo.item_na_celula(1) == escudo and modelo.item_na_celula(0) == espada, str(modelo.celulas_da_mao))
	_verificar("tem_espaco ignora as casas da mao", modelo.tem_espaco() and modelo._primeira_livre() == 2, "livre=%d" % modelo._primeira_livre())
	modelo.desequipar("arma")
	_verificar("desequipar volta para a casa da mao", modelo.indice_de(espada) == 0 and modelo.celulas_da_mao["arma"] == -1, "indice=%d" % modelo.indice_de(espada))
	# salvar e carregar mantem a casa da mao
	modelo.equipar(espada)
	modelo.salvar("user://teste_inventario_mao.json")
	var outro = _modelo()
	outro.carregar("user://teste_inventario_mao.json")
	_verificar("salvar e carregar mantem as casas da mao", outro.celulas_da_mao["arma"] == 0 and outro.celulas_da_mao["escudo"] == 1 and outro.item_na_celula(0) != null and outro.item_na_celula(0).tipo == "espada_basica", str(outro.celulas_da_mao))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_inventario_mao.json"))
	outro.free()
	# mover algo para a casa reservada tira a reserva
	var bota = _item("botas_basicas", "botas")
	modelo.adicionar(bota)
	modelo.mover_para_mochila(bota, 0)
	_verificar("pôr um item na casa da mao tira a reserva da arma (ela fica sem casa na barra)", modelo.celulas_da_mao["arma"] == -1 and modelo.indice_de(bota) == 0, str(modelo.celulas_da_mao))
	modelo.free()

func _testar_lanca_tira_escudo() -> void:
	var modelo = _modelo()
	var escudo = _item("escudo_basico", "escudo")
	var lanca = _item("lanca_basica", "arma", true)
	modelo.adicionar(escudo)
	modelo.adicionar(lanca)
	modelo.equipar(escudo)
	_verificar("escudo equipa sem lanca", modelo.slot_de(escudo) == "escudo", "slot=%s" % modelo.slot_de(escudo))
	modelo.equipar(lanca)
	_verificar("lanca tira o escudo para a mochila", modelo.slot_de(lanca) == "arma" and modelo.slot_de(escudo) == "" and modelo.indice_de(escudo) != -1, "escudo em %d" % modelo.indice_de(escudo))
	_verificar("pode_equipar escudo false com lanca", not modelo.pode_equipar(escudo), "permitiu")
	_verificar("equipar escudo recusado com lanca", not modelo.equipar(escudo) and modelo.slot_de(escudo) == "", "equipou")
	modelo.free()

func _testar_desequipar() -> void:
	var modelo = _modelo()
	var espada = _item("espada_basica", "arma")
	var luvas = _item("luvas_basicas", "luvas")
	modelo.adicionar(espada)
	modelo.adicionar(luvas)
	modelo.equipar(espada)
	modelo.equipar(luvas)
	_verificar("desequipar para celula especifica", modelo.desequipar("arma", 9) and modelo.indice_de(espada) == 9, "indice=%d" % modelo.indice_de(espada))
	_verificar("desequipar celula ocupada falha", not modelo.desequipar("luvas", 9) and modelo.slot_de(luvas) == "luvas", "aceitou")
	_verificar("desequipar para primeira livre", modelo.desequipar("luvas") and modelo.indice_de(luvas) == 0, "indice=%d" % modelo.indice_de(luvas))
	_verificar("desequipar slot vazio", not modelo.desequipar("botas"), "retornou true")
	modelo.free()

func _testar_mochila_cheia() -> void:
	var modelo = _modelo()
	for _i in modelo.TAMANHO_MOCHILA:
		modelo.adicionar(_item("botas_basicas", "botas"))
	_verificar("adicionar com mochila cheia", modelo.adicionar(_item("espada_basica", "arma")) == -1, "nao retornou -1")
	modelo.free()
	modelo = _modelo()
	var espada = _item("espada_basica", "arma")
	var luvas = _item("luvas_basicas", "luvas")
	modelo.adicionar(espada)
	modelo.adicionar(luvas)
	modelo.equipar(espada)
	modelo.equipar(luvas)
	for _i in modelo.TAMANHO_MOCHILA:
		modelo.adicionar(_item("botas_basicas", "botas"))
	_verificar("mochila cheia: so cabe o que tem casa reservada (a arma em uso)", not modelo.tem_espaco() and modelo.casa_reservada(0), "")
	_verificar("desequipar com mochila cheia (armadura, sem casa da mao)", not modelo.desequipar("luvas") and modelo.slot_de(luvas) == "luvas", "desequipou")
	_verificar("a arma em uso sempre pode voltar a casa dela, mesmo com a mochila cheia", modelo.desequipar("arma") and modelo.indice_de(espada) == 0, "nao voltou")
	modelo.free()

func _testar_dict() -> void:
	var item = _item("lanca_basica", "arma", true)
	item.nivel = 4
	item.raridade = "raro"
	var copia = ScriptItem.de_dict(item.para_dict())
	var igual: bool = copia.id == item.id and copia.tipo == item.tipo and copia.categoria == item.categoria and copia.nivel == 4 and copia.raridade == "raro" and copia.duas_maos
	_verificar("para_dict/de_dict ida e volta", igual, str(copia.para_dict()))
	_verificar("nome e cor da raridade", item.nome() == "LANCA" and item.cor_raridade() == Color(0.3, 0.55, 1.0), item.nome())

	var modelo = _modelo()
	var espada = _item("espada_basica", "arma")
	espada.nivel = 3
	modelo.adicionar(_item("botas_basicas", "botas"))
	modelo.adicionar(espada)
	modelo.equipar(espada)
	var caminho := "user://teste_inventario.json"
	var salvou: bool = modelo.salvar(caminho)
	var outro = _modelo()
	var carregou: bool = outro.carregar(caminho)
	var equipada = outro.equipados["arma"]
	_verificar("salvar e carregar ida e volta", salvou and carregou and equipada != null and equipada.nivel == 3 and outro.mochila[0] != null and outro.mochila[0].tipo == "botas_basicas" and outro.mochila[1] == null, "salvou=%s carregou=%s" % [salvou, carregou])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	modelo.free()
	outro.free()

func _testar_sinais() -> void:
	var modelo = _modelo()
	var contagem := {"mochila": 0, "slots": [], "itens": 0}
	modelo.mochila_alterada.connect(func() -> void: contagem["mochila"] += 1)
	modelo.equipamento_alterado.connect(func(slot: String) -> void: contagem["slots"].append(slot))
	modelo.item_alterado.connect(func(_item_alterado) -> void: contagem["itens"] += 1)
	var espada = _item("espada_basica", "arma")
	modelo.adicionar(espada)
	_verificar("sinal mochila_alterada ao adicionar", contagem["mochila"] == 1, str(contagem["mochila"]))
	modelo.equipar(espada)
	_verificar("sinal equipamento_alterado ao equipar", contagem["slots"] == ["arma"] and contagem["mochila"] == 2, str(contagem))
	modelo.subir_nivel(espada)
	_verificar("sinal item_alterado ao subir nivel", contagem["itens"] == 1 and espada.nivel == 2, str(contagem))
	modelo.free()

func _testar_itens_iniciais() -> void:
	var modelo = _modelo()
	var contagem := {"mochila": 0, "slots": 0, "itens": 0}
	modelo.mochila_alterada.connect(func() -> void: contagem["mochila"] += 1)
	modelo.equipamento_alterado.connect(func(_slot: String) -> void: contagem["slots"] += 1)
	modelo.item_alterado.connect(func(_item_alterado) -> void: contagem["itens"] += 1)
	_verificar("modelo novo esta vazio", modelo.esta_vazio(), "tinha itens")
	modelo.criar_itens_iniciais()
	var total := 0
	for item in modelo.mochila:
		if item != null:
			total += 1
	for slot in modelo.SLOTS:
		if modelo.equipados[slot] != null:
			total += 1
	_verificar("criar_itens_iniciais cria 12 itens (com as quatro ferramentas e aljava)", total == 12 and not modelo.esta_vazio(), "total=%d" % total)
	# Kit inicial: espada e escudo já na mão, cada um reservando a casa da barra de onde saiu; a primeira linha segue com
	# enxada, regador e mão (a mesma barra serve à fazenda) e a lança fica na segunda linha
	var tipos_mochila: Array = []
	for i in 6:
		tipos_mochila.append(modelo.mochila[i].tipo if modelo.mochila[i] != null else "")
	var kit_na_mao: bool = modelo.equipados["arma"] != null and modelo.equipados["arma"].tipo == "espada_basica" and modelo.equipados["escudo"] != null \
			and modelo.equipados["escudo"].tipo == "escudo_basico" and tipos_mochila == ["", "", "enxada", "regador", "lanca_basica", "machadinha"] \
			and modelo.celulas_da_mao["arma"] == 0 and modelo.celulas_da_mao["escudo"] == 1 and modelo.mochila[2].categoria == "ferramenta"
	_verificar("espada e escudo equipados, enxada, regador, lança e machadinha nas casas previstas", kit_na_mao, "mochila=%s mao=%s" % [str(tipos_mochila), str(modelo.celulas_da_mao)])
	var armaduras_equipadas: bool = modelo.equipados["cabeca"].tipo == "cabeca_basica" and modelo.equipados["corpo"].tipo == "armadura_basica" and modelo.equipados["luvas"].tipo == "luvas_basicas" and modelo.equipados["botas"].tipo == "botas_basicas"
	_verificar("armaduras comecam equipadas", armaduras_equipadas, "armaduras fora do lugar")
	_verificar("aljava comeca equipada", modelo.equipados["secundaria"].tipo == "aljava_basica", "secundaria=%s" % str(modelo.equipados["secundaria"]))
	_verificar("criar_itens_iniciais emite cada sinal uma vez", contagem["mochila"] == 1 and contagem["slots"] == 7 and contagem["itens"] == 0, str(contagem))
	var lanca = modelo.buscar_por_tipo("lanca_basica")
	_verificar("buscar_por_tipo acha na mochila e equipado", lanca != null and lanca.nivel == 1 and modelo.buscar_por_tipo("botas_basicas") != null and modelo.buscar_por_tipo("inexistente") == null, "busca falhou")
	modelo.subir_nivel(lanca)
	_verificar("nivel lido pelo tipo apos subir_nivel", modelo.buscar_por_tipo("lanca_basica").nivel == 2, "nivel=%d" % modelo.buscar_por_tipo("lanca_basica").nivel)
	modelo.free()

func _testar_arco_exige_aljava() -> void:
	var modelo = _modelo()
	var arco = _item("arco_curto", "arma", true)
	var aljava = _item("aljava_basica", "secundaria")
	var espada = _item("espada_basica", "arma")
	modelo.adicionar(arco)
	modelo.adicionar(aljava)
	modelo.adicionar(espada)
	_verificar("arco nao pode ser equipado sem aljava", not modelo.pode_equipar(arco) and not modelo.equipar(arco), "equipou sem aljava")
	modelo.equipar(aljava)
	_verificar("arco equipa com aljava equipada", modelo.equipar(arco) and modelo.slot_de(arco) == "arma", "nao equipou")
	_verificar("aljava nao pode ser desequipada com arco equipado", not modelo.desequipar("secundaria") and modelo.slot_de(aljava) == "secundaria", "desequipou")
	_verificar("aljava nao pode ser movida para a mochila com arco equipado", not modelo.mover_para_mochila(aljava, 5) and modelo.slot_de(aljava) == "secundaria", "moveu")
	modelo.equipar(espada)
	_verificar("troca de arma libera a aljava", modelo.desequipar("secundaria") and modelo.slot_de(aljava) == "", "nao liberou")
	modelo.free()
