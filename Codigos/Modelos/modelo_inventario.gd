extends Node

# Sem class_name: o nome "InventarioJogador" é o do autoload e o global colidiria
const DadosItemScript := preload("res://Codigos/Modelos/dados_item.gd")
const Equipamentos := preload("res://Codigos/DadosLocais/Equipamentos.gd")

signal mochila_alterada
signal equipamento_alterado(slot: String)
signal item_alterado(item)

const TAMANHO_MOCHILA := 15
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

var _sincronizando: bool = false
var _pendente_mochila: bool = false
var _pendentes_slots: Array[String] = []
var _pendentes_itens: Array = []

func _init() -> void:
	_limpar()

func limpar() -> void:
	_limpar()
	_avisar_mochila()
	for slot in SLOTS:
		_avisar_slot(slot)

func _limpar() -> void:
	mochila.clear()
	mochila.resize(TAMANHO_MOCHILA)
	mochila.fill(null)
	equipados.clear()
	for slot in SLOTS:
		equipados[slot] = null

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
	if item == null or indice < 0 or indice >= TAMANHO_MOCHILA:
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
	if slot_origem != "":
		equipados[slot_origem] = null
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
	mochila[celula] = anterior
	equipados[slot] = item
	if escudo_deslocado != null:
		equipados["escudo"] = null
		mochila[_primeira_livre()] = escudo_deslocado
		_avisar_slot("escudo")
	_avisar_slot(slot)
	_avisar_mochila()
	return true

func desequipar(slot: String, indice: int = -1) -> bool:
	var item = equipados.get(slot)
	if item == null:
		return false
	if _aljava_obrigatoria(slot):
		return false
	if indice == -1:
		indice = _primeira_livre()
	if indice < 0 or indice >= TAMANHO_MOCHILA or mochila[indice] != null:
		return false
	equipados[slot] = null
	mochila[indice] = item
	_avisar_slot(slot)
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
	arquivo.store_string(JSON.stringify({"mochila": dados_mochila, "equipados": dados_equipados}, "\t"))
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
		for i in mini(dados_mochila.size(), TAMANHO_MOCHILA):
			if dados_mochila[i] is Dictionary:
				mochila[i] = DadosItemScript.de_dict(dados_mochila[i])
	var dados_equipados = dados.get("equipados", {})
	if dados_equipados is Dictionary:
		for slot in SLOTS:
			if dados_equipados.get(slot) is Dictionary:
				equipados[slot] = DadosItemScript.de_dict(dados_equipados[slot])
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

func _primeira_livre() -> int:
	return mochila.find(null)

func buscar_por_tipo(tipo: String):
	for item in mochila:
		if item != null and item.tipo == tipo:
			return item
	for slot in SLOTS:
		var item = equipados[slot]
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
