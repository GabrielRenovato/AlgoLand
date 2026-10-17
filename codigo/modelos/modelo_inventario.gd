extends Node

# Sem class_name: o nome "InventarioJogador" é o do autoload e o global colidiria
const Varas := preload("res://codigo/pesca/varas.gd")
const DadosItemScript := preload("res://codigo/modelos/dados_item.gd")
const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")

signal mochila_alterada
signal equipamento_alterado(slot: String)
signal item_alterado(item)
## A mochila ganhou (ou perdeu, no novo jogo) linhas: `capacidade` casas usáveis agora
signal capacidade_alterada(capacidade: int)

## Casas da mochila no começo (3 linhas de 8)
const TAMANHO_MOCHILA := 24
## Cada linha extra (8 casas) é liberada ao vencer esta onda pela primeira vez (Progresso.maior_onda_vencida, permanente: não se perde na
## morte). A tela do inventário mostra a próxima linha bloqueada, com um cadeado e o requisito; quando a grade não cabe mais, ela rola.
## O intervalo entre os requisitos cresce 10 a cada linha (10, 30, 60, 100...)
const ONDAS_LINHA_EXTRA := [10, 30, 60, 100, 150, 210, 280]
## Casas que a mochila pode chegar a ter (a base mais todas as linhas extras: 24 + 8 x 7)
const TAMANHO_MAXIMO := 80
## Colunas da grade da mochila (a grade da tela do inventário tem as mesmas). A primeira linha é a barra de baixo da tela, como a do Stardew Valley
const COLUNAS_MOCHILA := 8
## O que a barra de baixo mostra e troca: arma e escudo
const CATEGORIAS_DA_BARRA := ["arma", "escudo"]
const SLOTS := ["arma", "escudo", "secundaria", "cabeca", "corpo", "luvas", "botas"]
## Ordem = casas da mochila: a primeira linha (a barra de baixo, igual na arena e na fazenda) já vem com espada, escudo, enxada, regador e lança
const DEFINICOES_INICIAIS := [
	{"tipo": "espada_basica", "categoria": "arma", "duas_maos": false, "equipado": false},
	{"tipo": "escudo_basico", "categoria": "escudo", "duas_maos": false, "equipado": false},
	{"tipo": "enxada", "categoria": "ferramenta", "duas_maos": false, "equipado": false},
	{"tipo": "regador", "categoria": "ferramenta", "duas_maos": false, "equipado": false},
	{"tipo": "lanca_basica", "categoria": "arma", "duas_maos": true, "equipado": false},
	{"tipo": "aljava_basica", "categoria": "secundaria", "duas_maos": false, "equipado": true},
	{"tipo": "cabeca_basica", "categoria": "cabeca", "duas_maos": false, "equipado": true},
	{"tipo": "armadura_basica", "categoria": "corpo", "duas_maos": false, "equipado": true},
	{"tipo": "luvas_basicas", "categoria": "luvas", "duas_maos": false, "equipado": true},
	{"tipo": "botas_basicas", "categoria": "botas", "duas_maos": false, "equipado": true},
	{"tipo": "machadinha", "categoria": "ferramenta", "duas_maos": false, "equipado": false},
	{"tipo": "picareta", "categoria": "ferramenta", "duas_maos": false, "equipado": false},
]

## Moeda especial de forja (cai dos chefes): 1 por nível de peça de conjunto na bigorna. Vale só nesta partida, como o equipamento
signal moedas_forja_alteradas(quantidade: int)
var moedas_forja: int = 0
var _rng_ascensao := RandomNumberGenerator.new()

var mochila: Array = []
var equipados: Dictionary = {}
## A arma (e o escudo) em uso continua "ocupando" a casa da mochila de onde saiu, para a barra de baixo mostrá-la no lugar dela, como o item na
## mão do Stardew: {"arma": índice da casa, "escudo": índice} (-1 = sem casa). A casa fica vazia no modelo, mas reservada: nada novo entra
## nela (ver _primeira_livre) e quem passa a usar outro item devolve o anterior para ela
var celulas_da_mao: Dictionary = {"arma": -1, "escudo": -1}
## Linhas extras já liberadas (ver ONDAS_LINHA_EXTRA)
var linhas_extras: int = 0
var armas_permanentes_entregues: Array[String] = []

var _sincronizando: bool = false
var _pendente_mochila: bool = false
var _pendentes_slots: Array[String] = []
var _pendentes_itens: Array = []

func _init() -> void:
	_rng_ascensao.randomize()
	_limpar()

func _ready() -> void:
	# O mesmo roteiro serve ao inventário do jogador 2 (cooperativo), com outro arquivo
	if name == "InventarioJogador2":
		caminho_save = "user://inventario_p2.json"
	# o Progresso é um autoload carregado depois deste: liga no quadro seguinte
	_ligar_progresso.call_deferred()

func _ligar_progresso() -> void:
	var progresso := get_node_or_null("/root/Progresso")
	if progresso == null:
		return
	progresso.onda_vencida_alterada.connect(_ao_onda_vencida)
	_ao_onda_vencida(int(progresso.get("maior_onda_vencida")))
	progresso.armas_liberadas_alteradas.connect(entregar_armas_liberadas)

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

## O que sobrevive à morte: as peças de conjunto (equipadas ou na mochila, com nível e afixos), as sementes (progresso da fazenda) e as
## moedas de forja. As ferramentas não precisam: fazem parte do kit inicial
func guardar_para_nova_partida() -> Dictionary:
	var pecas: Array = []
	for slot in SLOTS:
		var item = equipados[slot]
		if item != null and Conjuntos.de_tipo(item.tipo) != null:
			pecas.append({"item": item, "equipado": true})
	for item in mochila:
		if item != null and (Conjuntos.de_tipo(item.tipo) != null or item.categoria in ["semente","peixe","vara"]):
			pecas.append({"item": item, "equipado": false})
	return {"pecas": pecas, "moedas_forja": moedas_forja}

## Devolve o que guardar_para_nova_partida separou, depois do kit inicial: as peças voltam aos mesmos slots
func restaurar_da_partida_anterior(guardado: Dictionary) -> void:
	_sincronizando = true
	moedas_forja = int(guardado.get("moedas_forja", 0))
	for registro in guardado.get("pecas", []):
		var casa := _primeira_livre()
		if casa == -1:
			break
		# A vara guardada vale mais que a recém-criada pelo kit inicial (que ainda estava no nível certo, mas é outro item)
		if registro["item"].categoria == "vara":
			for i in mochila.size():
				if mochila[i] != null and mochila[i].categoria == "vara":
					mochila[i] = null
		mochila[casa] = registro["item"]
		if registro["equipado"]:
			equipar(registro["item"])
	_sincronizando = false
	moedas_forja_alteradas.emit(moedas_forja)
	_avisar_mochila()
	for slot in SLOTS:
		_avisar_slot(slot)
	_emitir_pendentes()

# --- Fazenda: ferramentas e sementes na mochila ------------------------------------------------------------------

## Sementes da planta `planta` em todas as casas (uma pilha por planta)
func quantidade_sementes(planta: String) -> int:
	var pilha = _pilha_de_semente(planta)
	return int(pilha.quantidade) if pilha != null else 0

## Soma à pilha da planta ou abre uma casa nova. false se a mochila está cheia e ainda não há pilha dela
func adicionar_sementes(planta: String, quantos: int = 1) -> bool:
	if quantos <= 0:
		return false
	var pilha = _pilha_de_semente(planta)
	if pilha != null:
		pilha.quantidade += quantos
		_avisar_item(pilha)
		return true
	var casa := _primeira_livre()
	if casa == -1:
		return false
	mochila[casa] = DadosItemScript.de_fazenda(DadosItemScript.Plantas.PREFIXO_SEMENTE + planta, quantos)
	_avisar_mochila()
	return true

## Gasta uma semente (plantou); a casa esvazia quando a pilha acaba. false se não tinha
func gastar_semente(planta: String) -> bool:
	var pilha = _pilha_de_semente(planta)
	if pilha == null:
		return false
	pilha.quantidade -= 1
	if pilha.quantidade <= 0:
		mochila[mochila.find(pilha)] = null
		_avisar_mochila()
	else:
		_avisar_item(pilha)
	return true

## Ferramentas e sementes da mochila, na ordem das casas (a ordem da barra de baixo e do Q/E na fazenda)
func itens_de_fazenda() -> Array:
	var lista: Array = []
	for item in mochila:
		if item != null and (item.categoria == "ferramenta" or item.categoria == "semente"):
			lista.append(item)
	return lista

func _pilha_de_semente(planta: String):
	var tipo := DadosItemScript.Plantas.PREFIXO_SEMENTE + planta
	for item in mochila:
		if item != null and item.categoria == "semente" and item.tipo == tipo:
			return item
	return null

# Saves de antes das ferramentas virarem itens: devolve as que faltam (na primeira casa livre)
func _migrar_ferramentas() -> void:
	# Coleta virou comando próprio: libera somente a casa do item antigo, sem mover os demais.
	for i in mochila.size():
		if mochila[i] != null and mochila[i].categoria == "ferramenta" and mochila[i].tipo == "mao":
			mochila[i] = null
	if Introducao.ativa():
		return
	for tipo in DadosItemScript.FERRAMENTAS:
		var tem := false
		for item in mochila:
			if item != null and item.tipo == tipo:
				tem = true
				break
		var casa := _primeira_livre()
		if not tem and casa != -1:
			mochila[casa] = DadosItemScript.de_fazenda(tipo)

## A vara de pesca é um item da mochila de cada jogador, criado a partir deste patch nos saves que ainda não têm uma. O
## nível/raridade dela seguem o refinamento (Varas). `nivel_vara` < 1 usa o do jogador deste inventário.
func sincronizar_vara(nivel_vara: int = 0) -> void:
	if Introducao.ativa():
		return
	var nivel_atual: int = nivel_vara if nivel_vara >= 1 else Varas.nivel_do_inventario(self)
	for item in mochila:
		if item != null and item.categoria == "vara":
			if item.nivel != nivel_atual:
				item.aplicar_nivel_vara(nivel_atual)
				_avisar_item(item)
			return
	var casa := _primeira_livre()
	if casa != -1:
		mochila[casa] = DadosItemScript.de_vara(nivel_atual)
		_avisar_mochila()

func adicionar_moedas_forja(quantidade: int = 1) -> void:
	moedas_forja = maxi(moedas_forja + quantidade, 0)
	moedas_forja_alteradas.emit(moedas_forja)

func gastar_moeda_forja(quantidade: int = 1) -> bool:
	if moedas_forja < quantidade:
		return false
	moedas_forja -= quantidade
	moedas_forja_alteradas.emit(moedas_forja)
	return true

func _limpar() -> void:
	armas_permanentes_entregues.clear()
	moedas_forja = 0
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
## Item que vem de fora da mochila (o baú da casa): vai para a casa `indice` se ela estiver livre, senão para a primeira
## livre. Semente junta na pilha da mesma planta. Devolve a casa usada ou -1 (mochila cheia)
func receber(item, indice: int = -1) -> int:
	if item == null:
		return -1
	if item.categoria == "peixe":
		for pilha in mochila:
			if pilha != null and pilha.categoria == "peixe" and pilha.tipo == item.tipo and pilha.qualidade == item.qualidade:
				pilha.quantidade += item.quantidade
				_avisar_item(pilha)
				_avisar_mochila()
				return mochila.find(pilha)
	if item.categoria == "semente":
		var pilha = _pilha_de_semente(item.tipo.trim_prefix(DadosItemScript.Plantas.PREFIXO_SEMENTE))
		if pilha != null:
			pilha.quantidade += item.quantidade
			_avisar_item(pilha)
			return mochila.find(pilha)
	if indice < 0 or indice >= capacidade() or mochila[indice] != null or casa_reservada(indice):
		indice = _primeira_livre()
	if indice == -1:
		return -1
	mochila[indice] = item
	_avisar_mochila()
	return indice

func remover_da_mochila(item) -> bool:
	var indice := mochila.find(item)
	if indice == -1:
		return false
	mochila[indice] = null
	_avisar_mochila()
	return true

func subir_nivel(item) -> void:
	# Peça de conjunto no nível 5: a bigorna sobe a raridade (e soma um bônus) em vez do nível; lendária já está no máximo
	if Conjuntos.de_tipo(item.tipo) != null and item.nivel >= Conjuntos.NIVEL_ASCENSAO:
		if not Conjuntos.ascender(item, _rng_ascensao):
			return
	else:
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
func criar_itens_iniciais(para_introducao := false) -> void:
	_sincronizando = true
	for definicao in DEFINICOES_INICIAIS:
		if para_introducao and not definicao["categoria"] in ["cabeca", "corpo", "luvas", "botas"]:
			continue
		var item = _criar_item(definicao)
		if definicao["equipado"]:
			equipados[item.categoria] = item
			_avisar_slot(item.categoria)
		else:
			mochila[_primeira_livre()] = item
			_avisar_mochila()
	# Já começa com espada e escudo na mão (cada um fica ligado à casa da barra de onde saiu)
	for tipo in ["espada_basica", "escudo_basico"]:
		equipar(buscar_por_tipo(tipo))
	_sincronizando = false
	_emitir_pendentes()
	if not para_introducao:
		entregar_armas_liberadas()
		sincronizar_vara()

## Arquivo deste inventário (Saves troca entre o mundo solo e o cooperativo; o do jogador 2 é outro)
var caminho_save := "user://inventario.json"

func salvar(caminho: String = "") -> bool:
	if caminho == "":
		caminho = caminho_save
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
	arquivo.store_string(JSON.stringify({"mochila": dados_mochila, "equipados": dados_equipados, "mao": celulas_da_mao, "moedas_forja": moedas_forja, "armas_permanentes_entregues": armas_permanentes_entregues}, "\t"))
	return true

func carregar(caminho: String = "") -> bool:
	if caminho == "":
		caminho = caminho_save
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
	moedas_forja = maxi(int(dados.get("moedas_forja", 0)), 0)
	moedas_forja_alteradas.emit(moedas_forja)
	for tipo in dados.get("armas_permanentes_entregues", []):
		if Equipamentos.ARMAS_ADICIONAIS.has(tipo) and not tipo in armas_permanentes_entregues:
			armas_permanentes_entregues.append(tipo)
	_migrar_aljava()
	_migrar_ferramentas()
	sincronizar_vara()
	_avisar_mochila()
	for slot in SLOTS:
		_avisar_slot(slot)
	return true

# Saves anteriores à aljava (ou que a perderam) ficam sem ela e o arco não equipa: reequipa a que estiver na mochila
# ou concede uma básica, tenha o arco na mão ou não
func _migrar_aljava() -> void:
	if equipados["secundaria"] != null:
		return
	for i in mochila.size():
		var item = mochila[i]
		if item != null and item.categoria == "secundaria":
			equipados["secundaria"] = item
			mochila[i] = null
			return
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

# Armas recém-liberadas: vão para a mochila no nível 1.
func adicionar_arma_nova(tipo: String) -> bool:
	var duas_maos: bool = Equipamentos.ARMAS_ADICIONAIS.get(tipo, {}).get("duas_maos", false)
	return adicionar(_criar_item({"tipo": tipo, "categoria": "arma", "duas_maos": duas_maos})) != -1

func _criar_item(definicao: Dictionary):
	if definicao["categoria"] == "ferramenta":
		return DadosItemScript.de_fazenda(definicao["tipo"])
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

## Uma cópia comum por arma e por partida; não permite retirar e vender infinitamente.
func entregar_armas_liberadas() -> void:
	if not is_inside_tree() or esta_vazio():
		return
	var progresso := get_node_or_null("/root/Progresso")
	var introducao := get_node_or_null("/root/Introducao")
	if progresso == null or progresso._carregando or (introducao != null and introducao.ativa()):
		return
	var mudou := false
	for tipo in Equipamentos.ARMAS_ADICIONAIS:
		if not progresso.arma_liberada(tipo) or tipo in armas_permanentes_entregues:
			continue
		if buscar_por_tipo(tipo) == null and not adicionar_arma_nova(tipo):
			continue
		armas_permanentes_entregues.append(tipo)
		mudou = true
	if mudou:
		salvar()

## Encerramento voluntário usa a mesma seleção de itens permanentes da morte.
## Conjuntos, sementes e moedas de forja ficam; equipamento temporário volta ao kit inicial.
func reiniciar_equipamento_da_partida() -> void:
	var guardado := guardar_para_nova_partida()
	limpar()
	criar_itens_iniciais()
	restaurar_da_partida_anterior(guardado)
	salvar()

## Espécies e qualidades diferentes ocupam pilhas independentes.
func adicionar_peixe(especie: String, qualidade := 0, quantos := 1) -> bool:
	if not preload("res://codigo/pesca/peixes.gd").existe(especie) or quantos<=0: return false
	for item in mochila:
		if item != null and item.categoria == "peixe" and item.peixe()==especie and item.qualidade==qualidade:
			item.quantidade += quantos
			_avisar_item(item)
			_avisar_mochila()
			return true
	return adicionar(DadosItemScript.de_peixe(especie,qualidade,quantos))>=0

func quantidade_peixes(especie := "") -> int:
	var total := 0
	for item in mochila:
		if item != null and item.categoria == "peixe" and (especie=="" or item.peixe()==especie): total += item.quantidade
	return total

func gastar_peixes(especie: String, quantos: int) -> bool:
	if quantos<0 or quantidade_peixes(especie)<quantos: return false
	# Receitas e cartas consomem primeiro a qualidade menor.
	for qualidade in 4:
		for i in mochila.size():
			var item = mochila[i]
			if item == null or item.categoria != "peixe" or item.peixe()!=especie or item.qualidade!=qualidade: continue
			var tirar := mini(quantos,item.quantidade)
			item.quantidade -= tirar
			quantos -= tirar
			if item.quantidade==0: mochila[i]=null
			else: _avisar_item(item)
			if quantos==0:
				_avisar_mochila()
				return true
	return true
