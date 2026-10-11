extends Node

# Familia define qual conjunto de animacoes a arma usa (espada = uma mao, lanca = duas maos)
const FAMILIAS := {
	"espada_basica": "espada",
	"espada_gemea": "espada",
	"machado": "espada",
	"maca": "espada",
	"arco_curvo": "arco",
	"arco_curto": "arco",
	"arco_longo": "arco",
	"lanca_basica": "lanca",
	"escudo_basico": "escudo",
}
const NIVEIS_ONDA := [0, 4, 8, 14, 22]
const NIVEIS_CUSTO := [0, 200, 500, 1000, 2000]
# Armas compradas na loja. Espadas: sprites em CharacterSprites/Arms/<id>/base_N.png e ataque_N.png.
# Arcos: sprites em CharacterSprites/Arco/arcos/<codigo>_N_p2.png (parado/andando) e _p3.png (disparo);
# "tempo_disparo" multiplica a duração da animação de disparo (menor = mais rápido)
const ARMAS_LOJA := {
	"espada_gemea": {"nome": "Espada Gêmea", "dano": [9, 13, 20, 30, 43], "preco": 400},
	"machado": {"nome": "Machado", "dano": [10, 15, 22, 33, 47], "preco": 600},
	"maca": {"nome": "Maça", "dano": [9, 14, 21, 31, 45], "preco": 500},
	"arco_curto": {"nome": "Arco Curto", "codigo": "bo02", "duas_maos": true, "tempo_disparo": 0.5, "dano": [10, 15, 22, 33, 47], "preco": 500},
	"arco_curvo": {"nome": "Arco Curvo", "codigo": "bo01", "duas_maos": true, "tempo_disparo": 0.65, "dano": [14, 20, 30, 44, 62], "preco": 700},
	"arco_longo": {"nome": "Arco Longo", "codigo": "bo03", "duas_maos": true, "tempo_disparo": 0.8, "dano": [18, 26, 38, 56, 78], "preco": 900},
}

var armas = {
	# ==========================
	# 1) ARMAS JA EXISTENTES
	# ==========================

	"espada_basica": {
		"nome": "Espada Básica",
		"niveis": {
			1: {
				"textura": preload("res://CharacterSprites/Arms/swords/Sword_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/swords/Attack/slash_1.png"),
				"onda_necessaria": 0,
				"dano": 8,
				"custo": 0
			},
			2: {
				"textura": preload("res://CharacterSprites/Arms/swords/swords_upgraded/2/Sword_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/swords/Attack/swords_upgraded/slash_1/2/slash_1.png"),
				"onda_necessaria": 4,
				"dano": 12,
				"custo": 200
			},
			3: {
				"textura": preload("res://CharacterSprites/Arms/swords/swords_upgraded/3/Sword_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/swords/Attack/swords_upgraded/slash_1/3/slash_1.png"),
				"onda_necessaria": 8,
				"dano": 18,
				"custo": 500
			},
			4: {
				"textura": preload("res://CharacterSprites/Arms/swords/swords_upgraded/4/Sword_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/swords/Attack/swords_upgraded/slash_1/4/slash_1.png"),
				"onda_necessaria": 14,
				"dano": 28,
				"custo": 1000
			},
			5: {
				"textura": preload("res://CharacterSprites/Arms/swords/swords_upgraded/5/Sword_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/swords/Attack/swords_upgraded/slash_1/5/slash_1.png"),
				"onda_necessaria": 22,
				"dano": 40,
				"custo": 2000
			}
		}
	},

	"escudo_basico": {
		"nome": "Escudo Básico",
		"niveis": {
			1: {
				"textura": preload("res://CharacterSprites/Arms/shields/shield_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/shields/attack/slash_1.png"),
				"onda_necessaria": 0,
				"bonus_vitalidade": 2,
				"bonus_defesa": 4,
				"custo": 0
			},
			2: {
				"textura": preload("res://CharacterSprites/Arms/shields/shields_upgraded/2/shield_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/shields/attack/shields_upgraded/slash_1/2/slash_1.png"),
				"onda_necessaria": 4,
				"bonus_vitalidade": 4,
				"bonus_defesa": 8,
				"custo": 150
			},
			3: {
				"textura": preload("res://CharacterSprites/Arms/shields/shields_upgraded/3/shield_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/shields/attack/shields_upgraded/slash_1/3/slash_1.png"),
				"onda_necessaria": 8,
				"bonus_vitalidade": 6,
				"bonus_defesa": 13,
				"custo": 400
			},
			4: {
				"textura": preload("res://CharacterSprites/Arms/shields/shields_upgraded/4/shield_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/shields/attack/shields_upgraded/slash_1/4/slash_1.png"),
				"onda_necessaria": 14,
				"bonus_vitalidade": 9,
				"bonus_defesa": 19,
				"custo": 800
			},
			5: {
				"textura": preload("res://CharacterSprites/Arms/shields/shields_upgraded/5/shield_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/shields/attack/shields_upgraded/slash_1/5/slash_1.png"),
				"onda_necessaria": 22,
				"bonus_vitalidade": 12,
				"bonus_defesa": 26,
				"custo": 1600
			}
		}
	},

	"lanca_basica": {
		"nome": "Lança Básica",
		"niveis": {
			1: {
				"textura": preload("res://CharacterSprites/Arms/spears/spear_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/spears/Attack/slash_1.png"),
				"onda_necessaria": 0,
				"dano": 11,
				"custo": 0
			},
			2: {
				"textura": preload("res://CharacterSprites/Arms/spears/spears_upgraded/2/spear_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/spears/Attack/spears_upgraded/slash_1/2/slash_1.png"),
				"onda_necessaria": 4,
				"dano": 16,
				"custo": 200
			},
			3: {
				"textura": preload("res://CharacterSprites/Arms/spears/spears_upgraded/3/spear_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/spears/Attack/spears_upgraded/slash_1/3/slash_1.png"),
				"onda_necessaria": 8,
				"dano": 24,
				"custo": 500
			},
			4: {
				"textura": preload("res://CharacterSprites/Arms/spears/spears_upgraded/4/spear_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/spears/Attack/spears_upgraded/slash_1/4/slash_1.png"),
				"onda_necessaria": 14,
				"dano": 37,
				"custo": 1000
			},
			5: {
				"textura": preload("res://CharacterSprites/Arms/spears/spears_upgraded/5/spear_1.png"),
				"textura_ataque": preload("res://CharacterSprites/Arms/spears/Attack/spears_upgraded/slash_1/5/slash_1.png"),
				"onda_necessaria": 22,
				"dano": 52,
				"custo": 2000
			}
		}
	}
}

var armaduras = {
	"armadura_cabeca": {
		"nome": "Elmo",
		"niveis": {
			1: {
				"textura": preload("res://CharacterSprites/Armors/1/head.png"),
				"onda_necessaria": 0,
				"bonus_vitalidade": 2,
				"bonus_defesa": 2
			},
			2: {
				"textura": preload("res://CharacterSprites/Armors/2/head.png"),
				"onda_necessaria": 4,
				"bonus_vitalidade": 3,
				"bonus_defesa": 4
			},
			3: {
				"textura": preload("res://CharacterSprites/Armors/3/head.png"),
				"onda_necessaria": 8,
				"bonus_vitalidade": 5,
				"bonus_defesa": 7
			},
			4: {
				"textura": preload("res://CharacterSprites/Armors/4/head.png"),
				"onda_necessaria": 14,
				"bonus_vitalidade": 7,
				"bonus_defesa": 10
			},
			5: {
				"textura": preload("res://CharacterSprites/Armors/5/head.png"),
				"onda_necessaria": 22,
				"bonus_vitalidade": 9,
				"bonus_defesa": 14
			}
		}
	},
	"armadura_corpo": {
		"nome": "Peitoral",
		"niveis": {
			1: {
				"textura": preload("res://CharacterSprites/Armors/1/armor.png"),
				"onda_necessaria": 0,
				"bonus_vitalidade": 3,
				"bonus_defesa": 3
			},
			2: {
				"textura": preload("res://CharacterSprites/Armors/2/armor.png"),
				"onda_necessaria": 4,
				"bonus_vitalidade": 5,
				"bonus_defesa": 6
			},
			3: {
				"textura": preload("res://CharacterSprites/Armors/3/armor.png"),
				"onda_necessaria": 8,
				"bonus_vitalidade": 8,
				"bonus_defesa": 10
			},
			4: {
				"textura": preload("res://CharacterSprites/Armors/4/armor.png"),
				"onda_necessaria": 14,
				"bonus_vitalidade": 11,
				"bonus_defesa": 15
			},
			5: {
				"textura": preload("res://CharacterSprites/Armors/5/armor.png"),
				"onda_necessaria": 22,
				"bonus_vitalidade": 15,
				"bonus_defesa": 20
			}
		}
	},
	"armadura_luvas": {
		"nome": "Manoplas",
		"niveis": {
			1: {
				"textura": preload("res://CharacterSprites/Armors/1/gloves.png"),
				"onda_necessaria": 0,
				"bonus_vitalidade": 1,
				"bonus_defesa": 1
			},
			2: {
				"textura": preload("res://CharacterSprites/Armors/2/gloves.png"),
				"onda_necessaria": 4,
				"bonus_vitalidade": 2,
				"bonus_defesa": 2
			},
			3: {
				"textura": preload("res://CharacterSprites/Armors/3/gloves.png"),
				"onda_necessaria": 8,
				"bonus_vitalidade": 3,
				"bonus_defesa": 3
			},
			4: {
				"textura": preload("res://CharacterSprites/Armors/4/gloves.png"),
				"onda_necessaria": 14,
				"bonus_vitalidade": 4,
				"bonus_defesa": 5
			},
			5: {
				"textura": preload("res://CharacterSprites/Armors/5/gloves.png"),
				"onda_necessaria": 22,
				"bonus_vitalidade": 6,
				"bonus_defesa": 7
			}
		}
	},
	"armadura_botas": {
		"nome": "Botas",
		"niveis": {
			1: {
				"textura": preload("res://CharacterSprites/Armors/1/boots.png"),
				"onda_necessaria": 0,
				"bonus_vitalidade": 1,
				"bonus_defesa": 1
			},
			2: {
				"textura": preload("res://CharacterSprites/Armors/2/boots.png"),
				"onda_necessaria": 4,
				"bonus_vitalidade": 3,
				"bonus_defesa": 2
			},
			3: {
				"textura": preload("res://CharacterSprites/Armors/3/boots.png"),
				"onda_necessaria": 8,
				"bonus_vitalidade": 4,
				"bonus_defesa": 4
			},
			4: {
				"textura": preload("res://CharacterSprites/Armors/4/boots.png"),
				"onda_necessaria": 14,
				"bonus_vitalidade": 6,
				"bonus_defesa": 6
			},
			5: {
				"textura": preload("res://CharacterSprites/Armors/5/boots.png"),
				"onda_necessaria": 22,
				"bonus_vitalidade": 8,
				"bonus_defesa": 9
			}
		}
	}
}

func _init() -> void:
	for id in ARMAS_LOJA:
		armas[id] = _montar_arma_loja(id)

func _montar_arma_loja(id: String) -> Dictionary:
	var definicao: Dictionary = ARMAS_LOJA[id]
	var niveis := {}
	var eh_arco: bool = definicao.has("codigo")
	for i in 5:
		var caminho_base := "res://CharacterSprites/Arms/%s/base_%d.png" % [id, i + 1]
		var caminho_ataque := "res://CharacterSprites/Arms/%s/ataque_%d.png" % [id, i + 1]
		if eh_arco:
			caminho_base = "res://CharacterSprites/Arco/arcos/%s_%d_p2.png" % [definicao["codigo"], i + 1]
			caminho_ataque = "res://CharacterSprites/Arco/arcos/%s_%d_p3.png" % [definicao["codigo"], i + 1]
		var textura_carregando: Texture2D = null
		if eh_arco:
			textura_carregando = load("res://CharacterSprites/Arco/carregando/arco_%s_%d.png" % [definicao["codigo"], i + 1])
		niveis[i + 1] = {
			"textura_carregando": textura_carregando,
			"textura": load(caminho_base),
			"textura_ataque": load(caminho_ataque),
			"onda_necessaria": NIVEIS_ONDA[i],
			"dano": definicao["dano"][i],
			"custo": NIVEIS_CUSTO[i],
		}
	return {"nome": definicao["nome"], "niveis": niveis, "tempo_disparo": definicao.get("tempo_disparo", 1.0)}

static func familia_de(tipo: String) -> String:
	return FAMILIAS.get(tipo, "")

func obter_dados_nivel_arma(id_arma: String, nivel: int) -> Dictionary:
	if not armas.has(id_arma):
		return {}

	var arma = armas[id_arma]
	if not arma["niveis"].has(nivel):
		return {}

	return arma["niveis"][nivel]

func obter_dados_nivel_armadura(id_armadura: String, nivel: int) -> Dictionary:
	if not armaduras.has(id_armadura):
		return {}
	var armadura = armaduras[id_armadura]
	if not armadura["niveis"].has(nivel):
		return {}
	return armadura["niveis"][nivel]
