extends Node

## Saque da partida (autoload Saque, pedido de 2026-10-16): o equipamento que cai na arena e não cabe na mochila vai
## para esta sacola temporária, mostrada na aba SAQUE da janela entre as ondas. Lá o jogador leva o que quiser para a
## mochila (arrastando ou confirmando), vende um por um ou vende tudo. A sacola só existe durante a partida: voltar
## para a cidade vende o que sobrou; morrer perde.
##
## Venda automática (filtro): itens até a raridade escolhida nem ocupam espaço; viram ouro na hora em que são pegos.
##
## Balanço: dentro da partida a venda paga pouco, pela onda e pela raridade, e não pelo tipo e nível do item
## (preco_na_partida). Assim um drop ajuda, mas nunca vale mais que lutar a onda (ver os números no comentário dela).

signal alterado

const CAPACIDADE := 12
const CAMINHO_OPCOES := "user://opcoes.cfg"
## Filtro da venda automática: índice em FILTROS; cada um vende sozinho as raridades da lista
const FILTROS := [
	{"nome": "NADA", "raridades": []},
	{"nome": "COMUNS", "raridades": ["comum"]},
	{"nome": "ATE INCOMUNS", "raridades": ["comum", "incomum"]},
]

var itens: Array = []
var filtro := 0

func _ready() -> void:
	itens.resize(CAPACIDADE)
	var config := ConfigFile.new()
	if config.load(CAMINHO_OPCOES) == OK:
		filtro = clampi(int(config.get_value("saque", "filtro", 0)), 0, FILTROS.size() - 1)

# --- Preço ------------------------------------------------------------------------------------------------------

## O que um equipamento vale vendido durante a partida: (6 + 1,5 x onda) x multiplicador da raridade.
## Onda 10: comum 21, raro 34, lendário 63 (a onda 10 rende uns 276 de ouro entre abates e o bônus final).
## Onda 20: comum 36, lendário 108 (a onda rende uns 620)
static func preco_na_partida(raridade: String, onda: int) -> int:
	var Raridades := preload("res://codigo/dados/raridades.gd")
	return maxi(roundi((6.0 + 1.5 * float(maxi(onda, 1))) * Raridades.multiplicador_preco(raridade)), 1)

func onda_atual() -> int:
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	return int(gerenciador.onda_atual) if gerenciador != null else 1

func preco(item) -> int:
	return preco_na_partida(item.raridade, onda_atual())

# --- Filtro -------------------------------------------------------------------------------------------------------

func vende_sozinho(item) -> bool:
	return item != null and String(item.raridade) in FILTROS[filtro]["raridades"]

func trocar_filtro() -> void:
	filtro = (filtro + 1) % FILTROS.size()
	var config := ConfigFile.new()
	config.load(CAMINHO_OPCOES)
	config.set_value("saque", "filtro", filtro)
	config.save(CAMINHO_OPCOES)
	alterado.emit()

func nome_filtro() -> String:
	return FILTROS[filtro]["nome"]

# --- Sacola -------------------------------------------------------------------------------------------------------

func tem_espaco() -> bool:
	return itens.has(null)

func quantidade() -> int:
	return itens.filter(func(item) -> bool: return item != null).size()

func contem(item) -> bool:
	return item != null and itens.has(item)

## Item que caiu no chão e não coube na mochila. false se a sacola também está cheia
func adicionar(item) -> bool:
	var casa := itens.find(null)
	if casa == -1:
		return false
	itens[casa] = item
	alterado.emit()
	return true

## Da mochila para a sacola (abrir espaço na mochila durante a partida)
func guardar(item, casa: int = -1, quem: Node = null) -> bool:
	var mochila := _mochila_de(quem)
	if item == null or mochila.indice_de(item) == -1:
		return false
	if casa < 0 or casa >= CAPACIDADE or itens[casa] != null:
		casa = itens.find(null)
	if casa == -1:
		return false
	mochila.remover_da_mochila(item)
	mochila.salvar()
	itens[casa] = item
	alterado.emit()
	return true

## Da sacola para a mochila. false com a mochila cheia
func retirar(item, casa_mochila: int = -1, quem: Node = null) -> bool:
	var mochila := _mochila_de(quem)
	var indice := itens.find(item)
	if indice == -1:
		return false
	if mochila.receber(item, casa_mochila) == -1:
		return false
	itens[indice] = null
	mochila.salvar()
	alterado.emit()
	return true

func mover(item, casa: int) -> bool:
	var origem := itens.find(item)
	if origem == -1 or casa < 0 or casa >= CAPACIDADE:
		return false
	var ocupante = itens[casa]
	itens[casa] = item
	itens[origem] = ocupante
	alterado.emit()
	return true

## Vende um item da sacola (ou da mochila, arrastado para a casa de venda) pelo preço da partida. Devolve o ouro
func vender(item, quem: Node = null) -> int:
	if item == null:
		return 0
	var mochila := _mochila_de(quem)
	var indice := itens.find(item)
	if indice != -1:
		itens[indice] = null
	elif mochila.indice_de(item) != -1:
		mochila.remover_da_mochila(item)
		mochila.salvar()
	else:
		return 0
	var valor := preco(item)
	DadosJogo.adicionar_de(quem, valor)
	Sons.tocar("compra", 0.05)
	alterado.emit()
	return valor

func vender_tudo(quem: Node = null) -> int:
	var total := 0
	for item in itens.duplicate():
		if item != null:
			total += vender(item, quem)
	return total

## Fim da partida: voltar para a cidade vende o que sobrou; morrer perde
func encerrar(vender_o_resto: bool) -> int:
	var total := vender_tudo() if vender_o_resto else 0
	itens.clear()
	itens.resize(CAPACIDADE)
	alterado.emit()
	return total

## Mochila de quem mexe (cooperativo: cada jogador tem a sua); null = a do jogador 1
static func _mochila_de(quem: Node) -> Node:
	return quem.inventario if quem != null and quem.get("inventario") != null else InventarioJogador

