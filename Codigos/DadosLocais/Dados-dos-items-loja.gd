extends Node

const FATOR_PRECO_RECOMPRA: float = 1.2

var itens: Dictionary = {
	"item_1": {
		"nome": "Fúria Afiada",
		"icone": "res://UI/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 85.png",
		"preco": 120,
		"preco_base": 120,
		"descricao": "Adiciona 3 de força (+3 de dano por golpe)",
		"efeitos": {
			"forca": 3
		}
	},
	"item_2": {
		"nome": "Sede de Sangue",
		"icone": "res://UI/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 93.png",
		"preco": 250,
		"preco_base": 250,
		"descricao": "Ganha 5% de roubo de vida sobre o dano causado",
		"efeitos": {
			"roubo_vida": 5
		}
	},
	"item_3": {
		"nome": "Passo do Relâmpago",
		"icone": "res://UI/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 80.png",
		"preco": 150,
		"preco_base": 150,
		"descricao": "Adiciona 6 de agilidade (+9 de velocidade)",
		"efeitos": {
			"agilidade": 6
		}
	},
	"item_4": {
		"nome": "Bastião Inquebrável",
		"icone": "res://UI/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 76.png",
		"preco": 180,
		"preco_base": 180,
		"descricao": "Ganha 6 de defesa (reduz dano em %)",
		"efeitos": {
			"defesa": 6
		}
	},
	"item_5": {
		"nome": "Coração Robusto",
		"icone": "res://UI/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 70.png",
		"preco": 120,
		"preco_base": 120,
		"descricao": "+4 de vitalidade (+24 de HP máximo)",
		"efeitos": {
			"vitalidade": 4
		}
	},
	"item_6": {
		"nome": "Olho do Falcão",
		"icone": "res://UI/craftpix-net-629015-100-skill-icons-pack-for-rpg/PNG/skill icon 79.png",
		"preco": 200,
		"preco_base": 200,
		"descricao": "+5 de sorte (+5% de crítico, +0,1x dano crítico)",
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

# Versão mais robusta com validação
func definir_dados_item_seguro(id_item: String, nome: String, icone: String, preco: int, descricao: String, efeitos: Dictionary) -> void:
	itens[id_item] = {
		"nome": nome,
		"icone": icone,
		"preco": preco,
		"preco_base": preco,
		"descricao": descricao,
		"efeitos": efeitos
	}

func resetar_precos() -> void:
	for id_item in itens.keys():
		itens[id_item]["preco"] = itens[id_item].get("preco_base", itens[id_item]["preco"])
