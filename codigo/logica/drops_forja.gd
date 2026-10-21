extends RefCounted

const Receitas := preload("res://codigo/dados/forja_armas.gd")
const Item := preload("res://codigo/modelos/dados_item.gd")
const Drop := preload("res://codigo/logica/equipamento_drop.gd")

static func soltar_material(id: String, quantidade: int, onde: Vector2, pai: Node) -> Node2D:
	return Drop.soltar_item(Item.de_coletavel("material",id,quantidade),onde,pai,RandomNumberGenerator.new())

static func receita_pendente(onda: int, arvore: SceneTree) -> String:
	for tipo in Receitas.receitas_ativas():
		if tipo in Receitas.INICIAIS_LIVRES: continue
		if onda < Receitas.onda_receita(tipo) or Progresso.receita_liberada(tipo):
			continue
		var id: String = "receita:"+tipo
		if InventarioJogador.quantidade_tipo(id) > 0 or (Saves.eh_coop() and InventarioJogador2.quantidade_tipo(id)>0):
			continue
		if BauCasa.itens.any(func(item): return item != null and item.tipo == id):
			continue
		if Saque.itens.any(func(item): return item != null and item.tipo == id):
			continue
		if arvore.get_nodes_in_group("equipamento_drop").any(func(drop): return is_instance_valid(drop) and drop.item.tipo == id and not drop._pego):
			continue
		return tipo
	return ""

## Após vencer o sorteio de drop, cria um projeto elegível ainda não aprendido/guardado.
## Coletar o pergaminho nunca aprende a receita: o jogador precisa usá-lo na mochila.
static func soltar_receita(onda: int, onde: Vector2, pai: Node) -> Node2D:
	var tipo := receita_pendente(onda,pai.get_tree())
	if tipo.is_empty():
		return null
	return Drop.soltar_item(Item.de_coletavel("receita",tipo),onde,pai,RandomNumberGenerator.new())
