extends SceneTree

const ScriptItem := preload("res://Codigos/Modelos/dados_item.gd")
const ScriptModelo := preload("res://Codigos/Modelos/modelo_inventario.gd")

var _falhas: int = 0

func _initialize() -> void:
	_testar_adicionar()
	_testar_mover_com_troca()
	_testar_equipar_move_anterior()
	_testar_lanca_tira_escudo()
	_testar_desequipar()
	_testar_mochila_cheia()
	_testar_dict()
	_testar_sinais()
	_testar_itens_iniciais()
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
	modelo.equipar(outra)
	_verificar("equipar arma move a anterior para a celula liberada", modelo.indice_de(espada) == 2 and modelo.slot_de(outra) == "arma", "indice=%d" % modelo.indice_de(espada))
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
	modelo.adicionar(espada)
	modelo.equipar(espada)
	for _i in modelo.TAMANHO_MOCHILA:
		modelo.adicionar(_item("botas_basicas", "botas"))
	_verificar("desequipar com mochila cheia", not modelo.desequipar("arma") and modelo.slot_de(espada) == "arma", "desequipou")
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
	_verificar("criar_itens_iniciais cria 7 itens", total == 7 and not modelo.esta_vazio(), "total=%d" % total)
	var armas_na_mochila: bool = modelo.mochila[0].tipo == "espada_basica" and modelo.mochila[1].tipo == "lanca_basica" and modelo.mochila[2].tipo == "escudo_basico" and modelo.mochila[3] == null
	_verificar("armas e escudo comecam na mochila", armas_na_mochila and modelo.equipados["arma"] == null and modelo.equipados["escudo"] == null, "mochila[0]=%s" % str(modelo.mochila[0]))
	var armaduras_equipadas: bool = modelo.equipados["cabeca"].tipo == "cabeca_basica" and modelo.equipados["corpo"].tipo == "armadura_basica" and modelo.equipados["luvas"].tipo == "luvas_basicas" and modelo.equipados["botas"].tipo == "botas_basicas"
	_verificar("armaduras comecam equipadas", armaduras_equipadas, "armaduras fora do lugar")
	_verificar("criar_itens_iniciais emite cada sinal uma vez", contagem["mochila"] == 1 and contagem["slots"] == 4 and contagem["itens"] == 0, str(contagem))
	var lanca = modelo.buscar_por_tipo("lanca_basica")
	_verificar("buscar_por_tipo acha na mochila e equipado", lanca != null and lanca.nivel == 1 and modelo.buscar_por_tipo("botas_basicas") != null and modelo.buscar_por_tipo("inexistente") == null, "busca falhou")
	modelo.subir_nivel(lanca)
	_verificar("nivel lido pelo tipo apos subir_nivel", modelo.buscar_por_tipo("lanca_basica").nivel == 2, "nivel=%d" % modelo.buscar_por_tipo("lanca_basica").nivel)
	modelo.free()
