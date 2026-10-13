extends Node

# Sem class_name: o nome "InventarioJogador" é o do autoload e o global colidiria
const DadosItemScript := preload("res://Codigos/Modelos/dados_item.gd")
const Equipamentos := preload("res://Codigos/DadosLocais/Equipamentos.gd")

signal mochila_alterada
signal equipamento_alterado(slot: String)
signal item_alterado(item)
## A mochila ganhou (ou perdeu, no novo jogo) linhas: `capacidade` casas usáveis agora
signal capacidade_alterada(capacidade: int)

## Casas da mochila no começo (3 linhas de 5)
const TAMANHO_MOCHILA := 15
## Cada linha extra (5 casas) é liberada ao vencer esta onda pela primeira vez (Progresso.maior_onda_vencida, permanente: não se perde na
## morte). A tela do inventário mostra a próxima linha bloqueada, com um cadeado e o requisito; quando a grade não cabe mais, ela rola.
## O intervalo entre os requisitos cresce 10 a cada linha (10, 30, 60, 100...)
const ONDAS_LINHA_EXTRA := [10, 30, 60, 100, 150, 210, 280]
## Casas que a mochila pode chegar a ter (a base mais todas as linhas extras: 15 + 5 x 7)
const TAMANHO_MAXIMO := 50
## Colunas da grade da mochila (a grade da tela do inventário tem as mesmas). A primeira linha é a barra de baixo da tela, como a do Stardew Valley
const COLUNAS_MOCHILA := 5
## O que a barra de baixo mostra e troca: arma e escudo
const CATEGORIAS_DA_BARRA := ["arma", "escudo"]
const SLOTS := ["arma", "escudo", "secundaria", "cabeca", "corpo", "luvas", "botas"]
const DEFINICOES_INICIAIS := [
	{"tipo": "espada_basica", "categoria": "arma", "duas_maos": false, "equipado": false},
	{"tipo": "lanca_basica", "categoria": "arma", "duas_maos": true, "equipado": false},
	{"tipo": "escudo_basico", "categoria": "escudo", "duas_maos": false, "equipado": false},
	{"tipo": "aljava_basica", "categoria": "secundaria", "duas_maos": false, "equipado": true},
	{"tipo": "cabeca_basica", "categoria": "cabeca", "duas_maos": false, "equipado": true},
	{"tipo": "armadura_basica", "categoria": "corpo", "duas_maos": false, "equipado": true},
	{"tipo": "luvas_basicas", "categoria": "luvas", "duas_maos": false, "equipado": true},
	{"tipo": "botas_basicas", "categoria": "botas", "duas_maos": false, "equipado": true},
]

var mochila: Array = []
var equipados: Dictionary = {}
## A arma (e o escudo) em uso continua "ocupando" a casa da mochila de onde saiu, para a barra de baixo mostrá-la no lugar dela, como o item na
## mão do Stardew: {"arma": índice da casa, "escudo": índice} (-1 = sem casa). A casa fica vazia no modelo, mas reservada: nada novo entra
## nela (ver _primeira_livre) e quem passa a usar outro item devolve o anterior para ela
var celulas_da_mao: Dictionary = {"arma": -1, "escudo": -1}
## Linhas extras já liberadas (ver ONDAS_LINHA_EXTRA)
var linhas_extras: int = 0

var _sincronizando: bool = false
var _pendente_mochila: bool = false
var _pendentes_slots: Array[String] = []
var _pendentes_itens: Array = []

func _init() -> void:
	_limpar()

func _ready() -> void:
	# o Progresso é um autoload carregado depois deste: liga no quadro seguinte
	_ligar_progresso.call_deferred()

func _ligar_progresso() -> void:
	var progresso := get_node_or_null("/root/Progresso")
	if progresso == null:
		return
	progresso.onda_vencida_alterada.connect(_ao_onda_vencida)
	_ao_onda_vencida(int(progresso.get("maior_onda_vencida")))

func _ao_onda_vencida(onda: int) -> void:
	definir_linhas_extras(linhas_para_onda(onda))

## Quantas linhas extras quem já venceu a onda `onda_vencida` tem
static func linhas_para_onda(onda_vencida: int) -> int:
	var linhas := 0
	for onda in ONDAS_LINHA_EXTRA:
		if onda_vencida >= onda:
			linhas += 1
	return linhas

func definir_linhas_extras(linhas: int) -> void:
	linhas = clampi(linhas, 0, ONDAS_LINHA_EXTRA.size())
	if linhas == linhas_extras:
		return
	linhas_extras = linhas
	capacidade_alterada.emit(capacidade())
	_avisar_mochila()

## Casas usáveis da mochila agora
func capacidade() -> int:
	return TAMANHO_MOCHILA + COLUNAS_MOCHILA * linhas_extras

## Onda que libera a próxima linha (-1 se já liberou todas)
func onda_da_proxima_linha() -> int:
	return ONDAS_LINHA_EXTRA[linhas_extras] if linhas_extras < ONDAS_LINHA_EXTRA.size() else -1

func limpar() -> void:
	_limpar()
	_avisar_mochila()
	for slot in SLOTS:
		_avisar_slot(slot)

func _limpar() -> void:
	mochila.clear()
	mochila.resize(TAMANHO_MAXIMO)
	mochila.fill(null)
	equipados.clear()
	for slot in SLOTS:
		equipados[slot] = null
	celulas_da_mao = {"arma": -1, "escudo": -1}

func adicionar(item) -> int:
	var indice := _primeira_livre()
	if indice == -1:
		return -1
	mochila[indice] = item
	_avisar_mochila()
	return indice

func indice_de(item) -> int:
	return mochila.find(item)

func slot_de(item) -> String:
	for slot in SLOTS:
		if equipados[slot] == item:
			return slot
	return ""

func mover_para_mochila(item, indice: int) -> bool:
	if item == null or indice < 0 or indice >= capacidade():
		return false
	var slot_origem := slot_de(item)
	var indice_origem := indice_de(item)
	if slot_origem == "" and indice_origem == -1:
		return false
	if _aljava_obrigatoria(slot_origem):
		return false
	if indice_origem == indice:
		return true
	var ocupante = mochila[indice]
	# quem põe algo numa casa reservada pela mão tira a reserva (o item em uso fica sem casa na barra)
	for categoria in celulas_da_mao:
		if celulas_da_mao[categoria] == indice:
			celulas_da_mao[categoria] = -1
	if slot_origem != "":
		equipados[slot_origem] = null
		if celulas_da_mao.has(slot_origem):
			celulas_da_mao[slot_origem] = -1
		mochila[indice] = item
		if ocupante != null:
			var destino := _primeira_livre()
			if destino == -1:
				equipados[slot_origem] = item
				mochila[indice] = ocupante
				return false
			mochila[destino] = ocupante
		_avisar_slot(slot_origem)
	else:
		mochila[indice_origem] = ocupante
		mochila[indice] = item
	_avisar_mochila()
	return true

func pode_equipar(item) -> bool:
	if item == null or not equipados.has(item.categoria):
		return false
	if item.categoria == "escudo":
		var arma = equipados["arma"]
		if arma != null and arma.duas_maos:
			return false
	# Arco exige aljava equipada: sem ela não tem de onde tirar as flechas
	if item.categoria == "arma" and Equipamentos.familia_de(item.tipo) == "arco" and equipados["secundaria"] == null:
		return false
	return true

# Enquanto o arco estiver equipado a aljava é obrigatória, então ela não pode ser retirada
func _aljava_obrigatoria(slot: String) -> bool:
	if slot != "secundaria":
		return false
	var arma = equipados["arma"]
	return arma != null and Equipamentos.familia_de(arma.tipo) == "arco"

## Troca as quatro peças de uma vez. As peças anteriores ficam na mochila;
## se não couberem, nenhuma alteração ou sinal é emitido.
func equipar_conjunto_armadura(pecas: Dictionary) -> bool:
	var slots := ["cabeca", "corpo", "luvas", "botas"]
	if pecas.size() != slots.size():
		return false
	var nova_mochila := mochila.duplicate()
	for slot in slots:
		var item = pecas.get(slot)
		if item == null or item.categoria != slot or not pode_equipar(item):
			return false
		var indice := nova_mochila.find(item)
		if indice >= 0:
			nova_mochila[indice] = null
	for slot in slots:
		var anterior = equipados[slot]
		if anterior == null or anterior == pecas[slot]:
			continue
		var destino := -1
		for i in capacidade():
			if nova_mochila[i] == null and not casa_reservada(i):
				destino = i
				break
		if destino < 0:
			return false
		nova_mochila[destino] = anterior
	var sincronizando_antes := _sincronizando
	_sincronizando = true
	mochila = nova_mochila
	for slot in slots:
		if equipados[slot] != pecas[slot]:
			equipados[slot] = pecas[slot]
			_avisar_slot(slot)
	_avisar_mochila()
	_sincronizando = sincronizando_antes
	if not _sincronizando:
		_emitir_pendentes()
	return true

func equipar(item) -> bool:
	var celula := indice_de(item)
	if celula == -1 or not pode_equipar(item):
		return false
	var slot: String = item.categoria
	var anterior = equipados[slot]
	var escudo_deslocado = null
	if item.duas_maos and equipados["escudo"] != null:
		escudo_deslocado = equipados["escudo"]
	if escudo_deslocado != null and anterior != null and _primeira_livre() == -1:
		return false
	mochila[celula] = null
	_trocar_equipado(slot, item, anterior, celula)
	if escudo_deslocado != null:
		equipados["escudo"] = null
		var casa_escudo: int = celulas_da_mao["escudo"]
		celulas_da_mao["escudo"] = -1
		# o escudo volta para a casa em que estava (se ainda estiver livre); senão, para a primeira livre
		var destino := casa_escudo if casa_escudo >= 0 and mochila[casa_escudo] == null else _primeira_livre()
		mochila[destino] = escudo_deslocado
		_avisar_slot("escudo")
	_avisar_slot(slot)
	_avisar_mochila()
	return true

## Põe `item` no slot e decide onde fica o `anterior`. Arma e escudo: o anterior volta à casa que o item novo deixou de vez (a que ele ocupava
## na mão) e o item novo passa a ocupar a casa de onde veio; sem casa livre assim, o anterior ocupa a casa do novo (troca simples)
func _trocar_equipado(slot: String, item, anterior, celula: int) -> void:
	equipados[slot] = item
	if not slot in CATEGORIAS_DA_BARRA:
		mochila[celula] = anterior
		return
	var casa_anterior: int = celulas_da_mao[slot]
	if anterior != null and casa_anterior >= 0 and casa_anterior != celula and mochila[casa_anterior] == null:
		mochila[casa_anterior] = anterior
		celulas_da_mao[slot] = celula
	elif anterior != null:
		mochila[celula] = anterior
		celulas_da_mao[slot] = -1
	else:
		celulas_da_mao[slot] = celula

func desequipar(slot: String, indice: int = -1) -> bool:
	var item = equipados.get(slot)
	if item == null:
		return false
	if _aljava_obrigatoria(slot):
		return false
	if indice == -1:
		# volta para a casa que ocupava na mão, se ainda estiver livre
		var casa: int = celulas_da_mao.get(slot, -1)
		indice = casa if casa >= 0 and mochila[casa] == null else _primeira_livre()
	if indice < 0 or indice >= capacidade() or mochila[indice] != null:
		return false
	equipados[slot] = null
	if celulas_da_mao.has(slot):
		celulas_da_mao[slot] = -1
	mochila[indice] = item
	_avisar_slot(slot)
	_avisar_mochila()
	return true

## Tira o item da mochila (venda). Devolve false se ele não está lá (equipado não se vende)
func remover_da_mochila(item) -> bool:
	var indice := mochila.find(item)
	if indice == -1:
		return false
	mochila[indice] = null
	_avisar_mochila()
	return true

func subir_nivel(item) -> void:
	item.nivel += 1
	_avisar_item(item)

# Um encantamento por item: outro tipo substitui o atual e volta ao nível 1
func encantar(item, tipo: String) -> void:
	if item.encantamento == tipo:
		item.nivel_encantamento += 1
	else:
		item.encantamento = tipo
		item.nivel_encantamento = 1
	_avisar_item(item)

func esta_vazio() -> bool:
	for item in mochila:
		if item != null:
			return false
	for slot in SLOTS:
		if equipados[slot] != null:
			return false
	return true

# Armas e escudo começam na mochila; as peças de armadura já vêm equipadas
func criar_itens_iniciais() -> void:
	_sincronizando = true
	for definicao in DEFINICOES_INICIAIS:
		var item = _criar_item(definicao)
		if definicao["equipado"]:
			equipados[item.categoria] = item
			_avisar_slot(item.categoria)
		else:
			mochila[_primeira_livre()] = item
			_avisar_mochila()
	_sincronizando = false
	_emitir_pendentes()

func salvar(caminho: String = "user://inventario.json") -> bool:
	var dados_mochila: Array = []
	for item in mochila:
		dados_mochila.append(item.para_dict() if item != null else null)
	var dados_equipados: Dictionary = {}
	for slot in SLOTS:
		var item = equipados[slot]
		dados_equipados[slot] = item.para_dict() if item != null else null
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify({"mochila": dados_mochila, "equipados": dados_equipados, "mao": celulas_da_mao}, "\t"))
	return true

func carregar(caminho: String = "user://inventario.json") -> bool:
	if not FileAccess.file_exists(caminho):
		return false
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not dados is Dictionary:
		return false
	_limpar()
	var dados_mochila = dados.get("mochila", [])
	if dados_mochila is Array:
		for i in mini(dados_mochila.size(), TAMANHO_MAXIMO):
			if dados_mochila[i] is Dictionary:
				mochila[i] = DadosItemScript.de_dict(dados_mochila[i])
	var dados_equipados = dados.get("equipados", {})
	if dados_equipados is Dictionary:
		for slot in SLOTS:
			if dados_equipados.get(slot) is Dictionary:
				equipados[slot] = DadosItemScript.de_dict(dados_equipados[slot])
	# Casas da mão: só valem se a casa existe, está vazia e o slot tem item (saves antigos não têm "mao": ficam sem casa)
	var mao = dados.get("mao", {})
	if mao is Dictionary:
		for categoria in CATEGORIAS_DA_BARRA:
			var casa := int(mao.get(categoria, -1))
			if casa >= 0 and casa < TAMANHO_MAXIMO and mochila[casa] == null and equipados[categoria] != null:
				celulas_da_mao[categoria] = casa
	_migrar_aljava()
	_avisar_mochila()
	for slot in SLOTS:
		_avisar_slot(slot)
	return true

# Saves anteriores à aljava podem ter um arco equipado sem ela; concede uma para não travar o personagem
func _migrar_aljava() -> void:
	var arma = equipados["arma"]
	if arma != null and Equipamentos.familia_de(arma.tipo) == "arco" and equipados["secundaria"] == null:
		equipados["secundaria"] = _criar_item({"tipo": "aljava_basica", "categoria": "secundaria", "duas_maos": false})

## Primeira casa vazia (das liberadas) que não é reservada pela mão
func _primeira_livre() -> int:
	for i in capacidade():
		if mochila[i] == null and not casa_reservada(i):
			return i
	return -1

## Cabe mais um item na mochila?
func tem_espaco() -> bool:
	return _primeira_livre() != -1

## A casa é a que a arma ou o escudo em uso ocupam na mão (vazia no modelo)
func casa_reservada(i: int) -> bool:
	for categoria in celulas_da_mao:
		if celulas_da_mao[categoria] == i and equipados.get(categoria) != null:
			return true
	return false

## O que a casa mostra na barra de baixo: o item da mochila ou, se for a casa da mão, a arma/escudo em uso
func item_na_celula(i: int):
	if i < 0 or i >= TAMANHO_MAXIMO:
		return null
	if mochila[i] != null:
		return mochila[i]
	for categoria in celulas_da_mao:
		if celulas_da_mao[categoria] == i and equipados.get(categoria) != null:
			return equipados[categoria]
	return null

## A casa que o item em uso ocupa na mão (-1 se não está em uso ou não tem casa)
func casa_da_mao(item) -> int:
	var slot := slot_de(item)
	return celulas_da_mao.get(slot, -1) if slot != "" else -1

## Primeiro item do tipo: o equipado, se houver (com duas armas do mesmo tipo e raridades diferentes, é o que o corpo está usando), depois a mochila
func buscar_por_tipo(tipo: String):
	for slot in SLOTS:
		var item = equipados[slot]
		if item != null and item.tipo == tipo:
			return item
	for item in mochila:
		if item != null and item.tipo == tipo:
			return item
	return null

# Armas compradas na loja: vão para a mochila
func adicionar_arma_nova(tipo: String) -> bool:
	var duas_maos: bool = Equipamentos.ARMAS_LOJA.get(tipo, {}).get("duas_maos", false)
	return adicionar(_criar_item({"tipo": tipo, "categoria": "arma", "duas_maos": duas_maos})) != -1

func _criar_item(definicao: Dictionary):
	var item = DadosItemScript.new()
	item.id = StringName(definicao["tipo"])
	item.tipo = definicao["tipo"]
	item.categoria = definicao["categoria"]
	item.duas_maos = definicao["duas_maos"]
	return item

func _avisar_mochila() -> void:
	if _sincronizando:
		_pendente_mochila = true
	else:
		mochila_alterada.emit()

func _avisar_slot(slot: String) -> void:
	if _sincronizando:
		if not _pendentes_slots.has(slot):
			_pendentes_slots.append(slot)
	else:
		equipamento_alterado.emit(slot)

func _avisar_item(item) -> void:
	if _sincronizando:
		if not _pendentes_itens.has(item):
			_pendentes_itens.append(item)
	else:
		item_alterado.emit(item)

func _emitir_pendentes() -> void:
	var slots := _pendentes_slots.duplicate()
	var itens := _pendentes_itens.duplicate()
	var mochila_mudou := _pendente_mochila
	_pendentes_slots.clear()
	_pendentes_itens.clear()
	_pendente_mochila = false
	if mochila_mudou:
		mochila_alterada.emit()
	for slot in slots:
		equipamento_alterado.emit(slot)
	for item in itens:
		item_alterado.emit(item)
