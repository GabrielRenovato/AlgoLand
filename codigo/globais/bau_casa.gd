extends Node

## Baú da casa da fazenda (autoload BauCasa): guarda itens fora da mochila, salvos em user://bau.json.
## Começa pequeno (CAPACIDADE_INICIAL casas). Tudo da mochila pode ir para o baú, menos o que está na mão
## (arma e escudo em uso não têm casa na mochila). Sementes da mesma planta se juntam numa pilha, como na mochila.

const DadosItemScript := preload("res://codigo/modelos/dados_item.gd")
const CAMINHO := "user://bau.json"
const CAPACIDADE_INICIAL := 8

signal alterado

var capacidade := CAPACIDADE_INICIAL
var itens: Array = []
var caminho_save := CAMINHO

func _ready() -> void:
	_limpar()
	carregar()

func _limpar() -> void:
	capacidade = CAPACIDADE_INICIAL
	itens.clear()
	itens.resize(capacidade)

func contem(item) -> bool:
	return item != null and itens.has(item)

## Guardar uma arma não torna seus aprimoramentos temporários permanentes.
## O baú preserva a cópia; o modelo recomeça comum, nível 1, como o kit da mochila.
func reiniciar_equipamento_da_partida() -> void:
	var mudou := false
	for item in itens:
		if item == null or item.categoria not in ["arma", "escudo"]:
			continue
		if preload("res://codigo/dados/conjuntos_armadura.gd").de_tipo(item.tipo) != null:
			continue
		item.nivel = 1
		item.raridade = "comum"
		item.encantamento = ""
		item.nivel_encantamento = 0
		item.afixos.clear()
		mudou = true
	if mudou:
		salvar()
		alterado.emit()

## Guarda um item da mochila. `casa` = onde soltou (ocupada ou -1: a primeira livre). false se não coube
func guardar(item, casa: int = -1, quem: Node = null) -> bool:
	var mochila := _mochila_de(quem)
	if item == null or mochila.indice_de(item) == -1:
		return false
	var destino := _destino(item, casa)
	if destino == -1:
		return false
	mochila.remover_da_mochila(item)
	if itens[destino] != null:
		itens[destino].quantidade += item.quantidade
	else:
		itens[destino] = item
	_gravar()
	return true

## Devolve um item do baú para a mochila (na casa `casa_mochila` se estiver livre). false com a mochila cheia
func retirar(item, casa_mochila: int = -1, quem: Node = null) -> bool:
	var mochila := _mochila_de(quem)
	var indice := itens.find(item)
	if indice == -1:
		return false
	if mochila.receber(item, casa_mochila) == -1:
		return false
	itens[indice] = null
	mochila.salvar()
	_gravar()
	return true

## Troca um item de casa dentro do baú
func mover(item, casa: int) -> bool:
	var origem := itens.find(item)
	if origem == -1 or casa < 0 or casa >= capacidade:
		return false
	var ocupante = itens[casa]
	itens[casa] = item
	itens[origem] = ocupante
	_gravar()
	return true

func _destino(item, casa: int) -> int:
	if item.empilhavel():
		for i in capacidade:
			if itens[i] != null and itens[i].categoria == item.categoria and itens[i].tipo == item.tipo and itens[i].qualidade == item.qualidade:
				return i
	if casa >= 0 and casa < capacidade and itens[casa] == null:
		return casa
	return itens.find(null)

func _gravar() -> void:
	salvar()
	InventarioJogador.salvar()
	if Saves.eh_coop():
		InventarioJogador2.salvar()
	alterado.emit()

func salvar() -> bool:
	var lista: Array = []
	for item in itens:
		lista.append(item.para_dict() if item != null else null)
	var arquivo := FileAccess.open(caminho_save, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify({"versao": 1, "capacidade": capacidade, "itens": lista}))
	arquivo.close()
	return true

func carregar() -> bool:
	_limpar()
	if not FileAccess.file_exists(caminho_save):
		return false
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho_save))
	if not dados is Dictionary:
		return false
	capacidade = maxi(int(dados.get("capacidade", CAPACIDADE_INICIAL)), CAPACIDADE_INICIAL)
	itens.resize(capacidade)
	var lista = dados.get("itens", [])
	if lista is Array:
		for i in mini(lista.size(), capacidade):
			if lista[i] is Dictionary:
				itens[i] = DadosItemScript.de_dict(lista[i])
	alterado.emit()
	return true

## Novo jogo: baú vazio e pequeno de novo
func apagar() -> void:
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_save))
	_limpar()
	alterado.emit()

## Mochila de quem mexe (cooperativo: cada jogador tem a sua); null = a do jogador 1
static func _mochila_de(quem: Node) -> Node:
	return quem.inventario if quem != null and quem.get("inventario") != null else InventarioJogador

