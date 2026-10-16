extends Node

const FATOR_PRECO_RECOMPRA: float = 1.2

var itens: Dictionary = {
	"item_1": {
		"nome": "Furia Afiada",
		"icone": "res://assets/ui/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 85.png",
		"preco": 120,
		"preco_base": 120,
		"descricao": "Adiciona 3 de forca (+3 de dano por golpe)",
		"efeitos": {
			"forca": 3
		}
	},
	"item_2": {
		"nome": "Sede de Sangue",
		"icone": "res://assets/ui/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 93.png",
		"preco": 250,
		"preco_base": 250,
		"descricao": "Ganha 5% de roubo de vida sobre o dano causado",
		"efeitos": {
			"roubo_vida": 5
		}
	},
	"item_3": {
		"nome": "Passo do Relampago",
		"icone": "res://assets/ui/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 80.png",
		"preco": 150,
		"preco_base": 150,
		"descricao": "Adiciona 6 de agilidade (+9 de velocidade)",
		"efeitos": {
			"agilidade": 6
		}
	},
	"item_4": {
		"nome": "Bastiao Inquebravel",
		"icone": "res://assets/ui/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 76.png",
		"preco": 180,
		"preco_base": 180,
		"descricao": "Ganha 6 de defesa (reduz dano em %)",
		"efeitos": {
			"defesa": 6
		}
	},
	"item_5": {
		"nome": "Coracao Robusto",
		"icone": "res://assets/ui/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 70.png",
		"preco": 120,
		"preco_base": 120,
		"descricao": "+4 de vitalidade (+24 de HP maximo)",
		"efeitos": {
			"vitalidade": 4
		}
	},
	"item_6": {
		"nome": "Olho do Falcao",
		"icone": "res://assets/ui/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 79.png",
		"preco": 200,
		"preco_base": 200,
		"descricao": "+5 de sorte (+5% de critico, +0,1x dano critico)",
		"efeitos": {
			"sorte": 5
		}
	}
}

func obter_dados_item(id_item: String) -> Dictionary:
	if itens.has(id_item):
		return itens[id_item]
	return {}

func definir_dados_item(id_item: String, dados_item: Dictionary) -> void:
	itens[id_item] = dados_item

# Versao mais robusta com validacao
func definir_dados_item_seguro(id_item: String, nome: String, icone: String, preco: int, descricao: String, efeitos: Dictionary) -> void:
	itens[id_item] = {
		"nome": nome,
		"icone": icone,
		"preco": preco,
		"preco_base": preco,
		"descricao": descricao,
		"efeitos": efeitos
	}

## Preço do totem para este jogador: o base x 1,2 a cada cópia que ELE já comprou nesta partida (no cooperativo cada um
## tem o seu; a lista itens_comprados do jogador zera quando a partida acaba)
func preco_para(id_item: String, jogador: Node) -> int:
	var dados: Dictionary = itens.get(id_item, {})
	if dados.is_empty():
		return 0
	var base: int = int(dados.get("preco_base", dados.get("preco", 0)))
	var copias := 0
	if jogador != null:
		for comprado in jogador.itens_comprados:
			if comprado.get("nome", "") == dados.get("nome", "-"):
				copias += 1
	return int(round(base * pow(FATOR_PRECO_RECOMPRA, copias)))

## Compra um totem (melhoria da partida) para `jogador`: gasta o ouro dele e aplica os efeitos nele.
## false se o item não existe ou falta ouro
func comprar(id_item: String, jogador: Node) -> bool:
	var dados: Dictionary = itens.get(id_item, {})
	if jogador == null or dados.is_empty():
		return false
	var preco := preco_para(id_item, jogador)
	if not DadosJogo.gastar_de(jogador, preco):
		return false
	jogador.aplicar_efeitos_item(dados)
	jogador.itens_comprados.append(dados.duplicate())
	return true

## O preço agora sai das compras de cada jogador (preco_para); fica só por compatibilidade
func resetar_precos() -> void:
	pass
