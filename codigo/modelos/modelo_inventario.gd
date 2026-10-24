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
## Só a arma selecionada reserva uma casa na barra; escudo e aljava ficam nos seus slots.
const CATEGORIAS_DA_BARRA := ["arma"]
const SLOTS := ["arma", "escudo", "secundaria", "cabeca", "corpo", "luvas", "botas"]
## Espada, escudo e ferramentas são iniciais; os demais equipamentos exigem receita e forja.
const DEFINICOES_INICIAIS := [
	{"tipo": "espada_basica", "categoria": "arma", "duas_maos": false, "equipado": false},
	{"tipo": "escudo_basico", "categoria": "escudo", "duas_maos": false, "equipado": false},
	{"tipo": "enxada", "categoria": "ferramenta", "duas_maos": false, "equipado": false},
	{"tipo": "regador", "categoria": "ferramenta", "duas_maos": false, "equipado": false},
	{"tipo": "machadinha", "categoria": "ferramenta", "duas_maos": false, "equipado": false},
	{"tipo": "picareta", "categoria": "ferramenta", "duas_maos": false, "equipado": false},
]

## Moeda especial de forja (cai dos chefes): 1 por nível de peça de conjunto na bigorna. Vale só nesta partida, como o equipamento
signal moedas_forja_alteradas(quantidade: int)
var moedas_forja: int:
	get:
		return quantidade_tipo("material:moeda_forja")
	set(valor):
		var atual := quantidade_tipo("material:moeda_forja")
		if valor > atual:
			adicionar_coletavel("material","moeda_forja",valor-atual)
		elif valor < atual:
			gastar_tipo("material:moeda_forja",atual-maxi(0,valor))
var _rng_ascensao := RandomNumberGenerator.new()

var mochila: Array = []
var equipados: Dictionary = {}
## A arma selecionada ocupa uma casa da mochila/barra. O item é guardado em
## equipados["arma"] para compatibilidade com combate e saves; item_na_celula o expõe
## na casa original. Escudo e aljava equipados não reservam casas.
## A vara de pesca está na mão (escolhida na barra de baixo): só assim dá para pescar. Não é salvo: ao entrar no jogo a mão é a arma.
## Equipar uma arma tira a vara da mão
var vara_na_mao := false

func definir_vara_na_mao(valor: bool) -> void:
	if vara_na_mao == valor:
		return
	vara_na_mao = valor
	equipamento_alterado.emit("arma")

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

## Sobrevivem à morte: peças de conjunto, sementes, peixes, materiais, receitas,
## colheitas e poções, além das ferramentas e da vara. Tudo permanece em slots reais.
func guardar_para_nova_partida() -> Dictionary:
	var pecas: Array = []
	for slot in SLOTS:
		var item = equipados[slot]
		if item != null and Conjuntos.de_tipo(item.tipo) != null:
			pecas.append({"item": item, "equipado": true})
	for item in mochila:
		if item != null and (Conjuntos.de_tipo(item.tipo) != null or item.categoria in ["ferramenta","semente","peixe","vara","material","receita","colheita","pocao","produto","comida"]):
			pecas.append({"item": item, "equipado": false})
	return {"pecas": pecas, "moedas_forja": moedas_forja}

## Devolve o que guardar_para_nova_partida separou, depois do kit inicial: as peças voltam aos mesmos slots
func restaurar_da_partida_anterior(guardado: Dictionary) -> void:
	_sincronizando = true
	# Restaura os itens reais antes dos presentes da próxima partida. Uma mochila
	# cheia não pode perder materiais para dar lugar ao kit ou às armas liberadas.
	mochila.fill(null)
	var pecas_na_mochila: int = guardado.get("pecas", []).filter(func(p): return not p["equipado"]).size()
	celulas_da_mao = {"arma": 0, "escudo": -1} if pecas_na_mochila < capacidade() else {"arma": -1, "escudo": -1}
	armas_permanentes_entregues.clear()
	for registro in guardado.get("pecas", []):
		if registro["equipado"]:
			equipados[registro["item"].categoria] = registro["item"]
			continue
		var casa := _primeira_livre()
		if casa == -1:
			break
		# A vara guardada vale mais que a recém-criada pelo kit inicial (que ainda estava no nível certo, mas é outro item)
		if registro["item"].categoria == "vara":
			for i in mochila.size():
				if mochila[i] != null and mochila[i].categoria == "vara":
					mochila[i] = null
		mochila[casa] = registro["item"]
	sincronizar_vara()
	_sincronizando = false
	entregar_armas_liberadas()
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
		if item != null and (item.categoria == "ferramenta" or item.categoria == "semente" or item.tipo == "produto:feno"):
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
		if buscar_por_tipo(tipo) == null:
			var casa := _primeira_livre()
			if casa != -1: mochila[casa] = DadosItemScript.de_fazenda(tipo)


## A vara inicial é um item da mochila de cada jogador. O
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
	adicionar_coletavel("material", "moeda_forja", quantidade)
	moedas_forja_alteradas.emit(moedas_forja)

func gastar_moeda_forja(quantidade: int = 1) -> bool:
	if moedas_forja < quantidade:
		return false
	gastar_tipo("material:moeda_forja", quantidade)
	moedas_forja_alteradas.emit(moedas_forja)
	return true

func _limpar() -> void:
	armas_permanentes_entregues.clear()
	mochila.clear()
	mochila.resize(TAMANHO_MAXIMO)
	mochila.fill(null)
	equipados.clear()
	for slot in SLOTS:
		equipados[slot] = null
	celulas_da_mao = {"arma": -1, "escudo": -1}

func adicionar(item) -> int:
	return receber(item)

func quantidade_tipo(tipo: String) -> int:
	var total := 0
	for item in mochila:
		if item != null and item.tipo == tipo:
			total += item.quantidade
	return total

func pode_receber(item: DadosItem) -> bool:
	if item == null:
		return false
	if item.empilhavel():
		for pilha in mochila:
			if pilha != null and pilha.tipo == item.tipo and pilha.qualidade == item.qualidade:
				return true
	return _primeira_livre() >= 0

func adicionar_coletavel(categoria: String, id: String, quantidade := 1) -> bool:
	if quantidade <= 0:
		return false
	return receber(DadosItemScript.de_coletavel(categoria,id,quantidade)) >= 0

func fotografar_mochila() -> Array:
	return mochila.map(func(item): return item.para_dict() if item != null else null)

func restaurar_mochila(fotografia: Array) -> void:
	for i in mochila.size():
		mochila[i] = DadosItemScript.de_dict(fotografia[i]) if i < fotografia.size() and fotografia[i] is Dictionary else null
	_avisar_mochila()

func receber_materiais(ganhos: Dictionary) -> bool:
	var antes := fotografar_mochila()
	for id in ganhos:
		if not preload("res://codigo/dados/forja_armas.gd").MATERIAIS.has(id) or int(ganhos[id]) <= 0 or not adicionar_coletavel("material",id,int(ganhos[id])):
			restaurar_mochila(antes)
			return false
	if not salvar():
		restaurar_mochila(antes)
		return false
	return true

func usar_receita(item: DadosItem) -> String:
	if item == null or item.categoria != "receita" or indice_de(item) < 0:
		return "RECEITA NAO ESTA NA MOCHILA"
	return get_node("/root/Progresso").aprender_receita(item.conteudo(), self)

func usar_comida(item: DadosItem) -> String:
	if item == null or item.categoria != "comida" or indice_de(item)<0:
		return "COMIDA NAO ESTA NA MOCHILA"
	return get_node("/root/Progresso").comer_da_mochila(item,self)

func gastar_tipo(tipo: String, quantidade: int) -> bool:
	if quantidade <= 0 or quantidade_tipo(tipo) < quantidade:
		return false
	var restante := quantidade
	for i in capacidade():
		var item = mochila[i]
		if item == null or item.tipo != tipo:
			continue
		var retirar := mini(restante,item.quantidade)
		item.quantidade -= retirar
		restante -= retirar
		if item.quantidade == 0:
			mochila[i] = null
		else:
			_avisar_item(item)
		if restante == 0:
			break
	_avisar_mochila()
	return true

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
	var casa_arma: int = celulas_da_mao.get("arma", -1)
	if slot_origem == "arma" and casa_arma >= 0:
		if indice == casa_arma:
			return true
		mochila[casa_arma] = mochila[indice]
		mochila[indice] = null
		celulas_da_mao["arma"] = indice
		_avisar_mochila()
		return true
	if indice == casa_arma and equipados.get("arma") != null:
		if indice_origem < 0:
			return false
		mochila[indice_origem] = null
		mochila[indice] = item
		celulas_da_mao["arma"] = indice_origem
		_avisar_mochila()
		return true
	var ocupante = mochila[indice]
	# quem põe algo numa casa reservada pela mão tira a reserva (o item em uso fica sem casa na barra)
	for categoria in CATEGORIAS_DA_BARRA:
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
	# Arco exige aljava equipada: sem ela não tem de onde tirar as flechas
	if item.categoria == "arma" and Equipamentos.familia_de(item.tipo) == "arco" and equipados["secundaria"] == null:
		return false
	return true

## O escudo permanece equipado com duas mãos, mas só funciona junto de arma compatível.
func escudo_ativo() -> bool:
	var arma = equipados.get("arma")
	return equipados.get("escudo") != null and arma != null and Equipamentos.familia_de(arma.tipo) == "espada" and not arma.duas_maos and not vara_na_mao

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
	if item != null and item == equipados.get("arma"):
		definir_vara_na_mao(false)
		return true
	var celula := indice_de(item)
	if celula == -1 or not pode_equipar(item):
		return false
	var slot: String = item.categoria
	if slot == "arma":
		definir_vara_na_mao(false)
	var anterior = equipados[slot]
	mochila[celula] = null
	_trocar_equipado(slot, item, anterior, celula)
	_avisar_slot(slot)
	_avisar_mochila()
	return true

## Põe `item` no slot e decide onde fica o `anterior`. Arma: o anterior volta à casa que o item novo deixou de vez (a que ele ocupava
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
	if item.empilhavel():
		for pilha in mochila:
			if pilha != null and pilha != item and pilha.tipo == item.tipo and pilha.qualidade == item.qualidade:
				pilha.quantidade += item.quantidade
				_avisar_item(pilha)
				_avisar_mochila()
				return mochila.find(pilha)
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

## Exclusão persistente de uma pilha da mochila. Em falha de escrita, conserva o item.
func excluir_item(item) -> bool:
	var indice := mochila.find(item)
	if item == null or indice == -1:
		return false
	mochila[indice] = null
	if not salvar():
		mochila[indice] = item
		return false
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

## A vara de pesca não conta: ela é criada na mochila logo ao abrir o jogo (Fazenda.carregar -> Varas), antes do save ser lido. Se contasse, o
## jogo acharia que já tem inventário, nunca leria o inventario.json e o próximo salvamento apagaria todos os itens
func esta_vazio() -> bool:
	for item in mochila:
		if item != null and item.categoria != "vara":
			return false
	for slot in SLOTS:
		if equipados[slot] != null:
			return false
	return true

# O kit inicial entrega espada, escudo e ferramentas.
func criar_itens_iniciais(para_introducao := false) -> void:
	_sincronizando = true
	for definicao in DEFINICOES_INICIAIS:
		if not definicao["tipo"] in preload("res://codigo/dados/forja_armas.gd").INICIAIS_LIVRES:
			continue
		if para_introducao and not definicao["categoria"] in ["cabeca", "corpo", "luvas", "botas"]:
			continue
		var item = _criar_item(definicao)
		if definicao["equipado"]:
			equipados[item.categoria] = item
			_avisar_slot(item.categoria)
		else:
			mochila[_primeira_livre()] = item
			_avisar_mochila()
	# Começa com espada selecionada na barra e escudo no slot, liberando sua casa.
	for tipo in ["espada_basica", "escudo_basico"]:
		equipar(buscar_por_tipo(tipo))
	_sincronizando = false
	_emitir_pendentes()
	if not para_introducao:
		entregar_armas_liberadas()
		sincronizar_vara()

## Arquivo deste inventário (Saves troca entre o mundo solo e o cooperativo; o do jogador 2 é outro)
var caminho_save := "user://inventario.json"

func dados_save() -> Dictionary:
	var dados_equipados: Dictionary = {}
	for slot in SLOTS:
		var item = equipados[slot]
		dados_equipados[slot] = item.para_dict() if item != null else null
	return {"mochila": fotografar_mochila(), "equipados": dados_equipados, "mao": celulas_da_mao,
		"armas_permanentes_entregues": armas_permanentes_entregues}

static func gravar_dados(caminho: String, dados: Dictionary) -> bool:
	var arquivo := FileAccess.open(caminho + ".tmp", FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho + ".tmp"), ProjectSettings.globalize_path(caminho)) == OK

func salvar(caminho: String = "") -> bool:
	if caminho == "":
		caminho = caminho_save
	var dados := dados_save()
	var progresso := get_node_or_null("/root/Progresso") if is_inside_tree() else null
	if progresso != null and progresso.mochila_pendente.get("caminho", "") == caminho:
		progresso.mochila_pendente["dados"] = dados
		if not progresso.salvar():
			return false
	return gravar_dados(caminho, dados)

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
	moedas_forja_alteradas.emit(moedas_forja)
	for tipo in dados.get("armas_permanentes_entregues", []):
		if Equipamentos.ARMAS_ADICIONAIS.has(tipo) and not tipo in armas_permanentes_entregues:
			armas_permanentes_entregues.append(tipo)
	_migrar_aljava()
	_migrar_ferramentas()
	_garantir_armas_basicas()
	sincronizar_vara()
	_avisar_mochila()
	for slot in SLOTS:
		_avisar_slot(slot)
	return true

## Save antigo (ou gravado no meio do prólogo) pode vir sem nenhuma arma ou escudo: fora do prólogo, quem não tem NENHUMA arma
## (ou nenhum escudo) ganha a básica, já na mão. Quem tem qualquer arma/escudo, mesmo trocado ou melhorado, não recebe nada
func _garantir_armas_basicas() -> void:
	if Introducao.ativa():
		return
	for par in [["arma", "espada_basica"], ["escudo", "escudo_basico"]]:
		var tem: bool = equipados.get(par[0]) != null
		for item in mochila:
			if item != null and item.categoria == par[0]:
				tem = true
				break
		var casa := _primeira_livre()
		if tem or casa == -1:
			continue
		for definicao in DEFINICOES_INICIAIS:
			if definicao["tipo"] == par[1]:
				var novo = _criar_item(definicao)
				mochila[casa] = novo
				equipar(novo)
				break

# Saves anteriores à aljava (ou que a perderam) ficam sem ela e o arco não equipa: reequipa a que estiver na mochila
# sem conceder outra: a aljava precisa ter sido fabricada.
func _migrar_aljava() -> void:
	if equipados["secundaria"] != null:
		return
	for i in mochila.size():
		var item = mochila[i]
		if item != null and item.categoria == "secundaria":
			equipados["secundaria"] = item
			mochila[i] = null
			return
	# Sem concessão automática: a aljava precisa ter sido fabricada no Ivo.

## Primeira casa vazia (das liberadas) que não é reservada pela mão
func _primeira_livre() -> int:
	for i in capacidade():
		if mochila[i] == null and not casa_reservada(i):
			return i
	return -1

## Cabe mais um item na mochila?
func tem_espaco() -> bool:
	return _primeira_livre() != -1

## Casa ocupada pela arma selecionada (vazia internamente, visível na barra).
func casa_reservada(i: int) -> bool:
	for categoria in CATEGORIAS_DA_BARRA:
		if celulas_da_mao[categoria] == i and equipados.get(categoria) != null:
			return true
	return false

## Item da casa da mochila/barra, incluindo a arma selecionada.
func item_na_celula(i: int):
	if i < 0 or i >= TAMANHO_MAXIMO:
		return null
	if mochila[i] != null:
		return mochila[i]
	for categoria in CATEGORIAS_DA_BARRA:
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
	var forja = preload("res://codigo/dados/forja_armas.gd")
	if forja.RECEITAS.has(tipo):
		return adicionar(forja.criar_item(tipo)) != -1
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
		moedas_forja_alteradas.emit(moedas_forja)

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
		moedas_forja_alteradas.emit(moedas_forja)
	for slot in slots:
		equipamento_alterado.emit(slot)
	for item in itens:
		item_alterado.emit(item)

## Uma cópia comum por arma e por partida; não permite retirar e vender infinitamente.
func entregar_armas_liberadas(forcar := false) -> void:
	if not is_inside_tree() or (esta_vazio() and not forcar):
		return
	var progresso := get_node_or_null("/root/Progresso")
	var introducao := get_node_or_null("/root/Introducao")
	if progresso == null or progresso._carregando or (introducao != null and introducao.ativa()):
		return
	var mudou := false
	for tipo in preload("res://codigo/dados/forja_armas.gd").RECEITAS:
		if tipo in preload("res://codigo/dados/forja_armas.gd").INICIAIS_LIVRES: continue
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
