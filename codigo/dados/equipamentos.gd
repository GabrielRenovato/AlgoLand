extends Node

const Raridades := preload("res://codigo/dados/raridades.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const ARMADURAS_ITENS := {"cabeca_basica": "armadura_cabeca", "armadura_basica": "armadura_corpo", "luvas_basicas": "armadura_luvas", "botas_basicas": "armadura_botas"}

# Familia define qual conjunto de animacoes a arma usa (espada = uma mao, lanca = duas maos)
const Montantes := preload("res://codigo/dados/armas_montantes.gd")
const FAMILIAS := {
	"montante_ferro": "espada",
	"montante_sentinela": "espada",
	"montante_geada": "espada",
	"montante_trovao": "espada",
	"montante_astral": "espada",

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
## Moedas de forja gastas por nível de peça de conjunto na bigorna (ver InventarioJogador.moedas_forja)
const MOEDAS_FORJA_POR_NIVEL := 1
## Ouro de cada ascensão de raridade da peça de conjunto no nível 5: comum>incomum, incomum>raro, raro>épico, épico>lendário
const CUSTOS_ASCENSAO := [2500, 3500, 5000, 7000]
# Armas e ícones Raven.
# "tempo_disparo" multiplica a duração da animação de disparo (menor = mais rápido). "flechas" e "abertura_graus": quantas flechas saem de
# uma vez e o ângulo entre elas (o arco longo atira 3 e é o mais lento). Arco curto em 0,65 (0,70 s por flecha) desde 25/10/2026:
# atirar de longe sem risco rendia demais. Com a força inicial (5) o dano por segundo de um nível 1 fica em
# uns 30 (curto), 40 (curvo) e 63 (longo, se as 3 acertam): quanto mais caro o arco, mais ele rende.
const ARMAS_ADICIONAIS := {
	"montante_ferro": Montantes.MODELOS.montante_ferro,
	"montante_sentinela": Montantes.MODELOS.montante_sentinela,
	"montante_geada": Montantes.MODELOS.montante_geada,
	"montante_trovao": Montantes.MODELOS.montante_trovao,
	"montante_astral": Montantes.MODELOS.montante_astral,

	"espada_gemea": {"nome": "Espada de Duas Mãos", "duas_maos": true, "dano": [9, 13, 20, 30, 43], "preco": 400},
	"machado": {"nome": "Machado", "duas_maos": true, "dano": [10, 15, 22, 33, 47], "preco": 600},
	"maca": {"nome": "Maça", "dano": [9, 14, 21, 31, 45], "preco": 500},
	"arco_curto": {"nome": "Arco", "codigo": "bo02", "duas_maos": true, "tempo_disparo": 0.65, "dano": [10, 15, 22, 33, 47], "preco": 500},
	"arco_curvo": {"nome": "Arco Curvo", "codigo": "bo01", "duas_maos": true, "tempo_disparo": 0.6, "dano": [19, 27, 40, 58, 81], "preco": 700},
	"arco_longo": {"nome": "Arco Longo", "codigo": "bo03", "duas_maos": true, "tempo_disparo": 1.1, "flechas": 3, "abertura_graus": 11.0, "dano": [18, 26, 38, 56, 78], "preco": 900},
}

var armas = {
	# ==========================
	# 1) ARMAS JA EXISTENTES
	# ==========================

	"espada_basica": {
		"nome": "Espada Básica",
		"niveis": {
			1: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/espada_basica.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/espada_basica.png"),
				"onda_necessaria": 0,
				"dano": 8,
				"custo": 0
			},
			2: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/espada_basica.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/espada_basica.png"),
				"onda_necessaria": 4,
				"dano": 12,
				"custo": 200
			},
			3: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/espada_basica.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/espada_basica.png"),
				"onda_necessaria": 8,
				"dano": 18,
				"custo": 500
			},
			4: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/espada_basica.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/espada_basica.png"),
				"onda_necessaria": 14,
				"dano": 28,
				"custo": 1000
			},
			5: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/espada_basica.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/espada_basica.png"),
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
				"textura": preload("res://assets/personagens/raven_fantasy/icones/escudo_basico.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/escudo_basico.png"),
				"onda_necessaria": 0,
				"bonus_vitalidade": 2,
				"bonus_defesa": 4,
				"custo": 0
			},
			2: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/escudo_basico.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/escudo_basico.png"),
				"onda_necessaria": 4,
				"bonus_vitalidade": 4,
				"bonus_defesa": 8,
				"custo": 150
			},
			3: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/escudo_basico.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/escudo_basico.png"),
				"onda_necessaria": 8,
				"bonus_vitalidade": 6,
				"bonus_defesa": 13,
				"custo": 400
			},
			4: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/escudo_basico.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/escudo_basico.png"),
				"onda_necessaria": 14,
				"bonus_vitalidade": 9,
				"bonus_defesa": 19,
				"custo": 800
			},
			5: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/escudo_basico.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/escudo_basico.png"),
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
				"textura": preload("res://assets/personagens/raven_fantasy/icones/lanca_basica.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/lanca_basica.png"),
				"onda_necessaria": 0,
				"dano": 11,
				"custo": 0
			},
			2: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/lanca_basica.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/lanca_basica.png"),
				"onda_necessaria": 4,
				"dano": 16,
				"custo": 200
			},
			3: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/lanca_basica.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/lanca_basica.png"),
				"onda_necessaria": 8,
				"dano": 24,
				"custo": 500
			},
			4: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/lanca_basica.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/lanca_basica.png"),
				"onda_necessaria": 14,
				"dano": 37,
				"custo": 1000
			},
			5: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/lanca_basica.png"),
				"textura_ataque": preload("res://assets/personagens/raven_fantasy/icones/lanca_basica.png"),
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
				"textura": preload("res://assets/personagens/raven_fantasy/icones/cabeca_basica.png"),
				"onda_necessaria": 0,
				"bonus_vitalidade": 2,
				"bonus_defesa": 2
			},
			2: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/cabeca_basica.png"),
				"onda_necessaria": 4,
				"bonus_vitalidade": 3,
				"bonus_defesa": 4
			},
			3: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/cabeca_basica.png"),
				"onda_necessaria": 8,
				"bonus_vitalidade": 5,
				"bonus_defesa": 7
			},
			4: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/cabeca_basica.png"),
				"onda_necessaria": 14,
				"bonus_vitalidade": 7,
				"bonus_defesa": 10
			},
			5: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/cabeca_basica.png"),
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
				"textura": preload("res://assets/personagens/raven_fantasy/icones/armadura_basica.png"),
				"onda_necessaria": 0,
				"bonus_vitalidade": 3,
				"bonus_defesa": 3
			},
			2: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/armadura_basica.png"),
				"onda_necessaria": 4,
				"bonus_vitalidade": 5,
				"bonus_defesa": 6
			},
			3: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/armadura_basica.png"),
				"onda_necessaria": 8,
				"bonus_vitalidade": 8,
				"bonus_defesa": 10
			},
			4: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/armadura_basica.png"),
				"onda_necessaria": 14,
				"bonus_vitalidade": 11,
				"bonus_defesa": 15
			},
			5: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/armadura_basica.png"),
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
				"textura": preload("res://assets/personagens/raven_fantasy/icones/luvas_basicas.png"),
				"onda_necessaria": 0,
				"bonus_vitalidade": 1,
				"bonus_defesa": 1
			},
			2: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/luvas_basicas.png"),
				"onda_necessaria": 4,
				"bonus_vitalidade": 2,
				"bonus_defesa": 2
			},
			3: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/luvas_basicas.png"),
				"onda_necessaria": 8,
				"bonus_vitalidade": 3,
				"bonus_defesa": 3
			},
			4: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/luvas_basicas.png"),
				"onda_necessaria": 14,
				"bonus_vitalidade": 4,
				"bonus_defesa": 5
			},
			5: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/luvas_basicas.png"),
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
				"textura": preload("res://assets/personagens/raven_fantasy/icones/botas_basicas.png"),
				"onda_necessaria": 0,
				"bonus_vitalidade": 1,
				"bonus_defesa": 1
			},
			2: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/botas_basicas.png"),
				"onda_necessaria": 4,
				"bonus_vitalidade": 3,
				"bonus_defesa": 2
			},
			3: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/botas_basicas.png"),
				"onda_necessaria": 8,
				"bonus_vitalidade": 4,
				"bonus_defesa": 4
			},
			4: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/botas_basicas.png"),
				"onda_necessaria": 14,
				"bonus_vitalidade": 6,
				"bonus_defesa": 6
			},
			5: {
				"textura": preload("res://assets/personagens/raven_fantasy/icones/botas_basicas.png"),
				"onda_necessaria": 22,
				"bonus_vitalidade": 8,
				"bonus_defesa": 9
			}
		}
	}
}

func _init() -> void:
	for id in ARMAS_ADICIONAIS:
		armas[id] = _montar_arma_adicional(id)

func _montar_arma_adicional(id: String) -> Dictionary:
	var definicao: Dictionary = ARMAS_ADICIONAIS[id]
	var niveis := {}
	var eh_arco: bool = definicao.has("codigo")
	for i in 5:
		var caminho_base := "res://assets/personagens/raven_fantasy/icones/%s.png" % id
		var caminho_ataque := caminho_base
		var textura_carregando: Texture2D = load(caminho_base) if eh_arco else null

		niveis[i + 1] = {
			"textura_carregando": textura_carregando,
			"textura": load(caminho_base),
			"textura_ataque": load(caminho_ataque),
			"onda_necessaria": NIVEIS_ONDA[i],
			"dano": definicao["dano"][i],
			"custo": NIVEIS_CUSTO[i],
		}
	return {"nome": definicao["nome"], "niveis": niveis, "tempo_disparo": definicao.get("tempo_disparo", 1.0),
			"flechas": definicao.get("flechas", 1), "abertura_graus": definicao.get("abertura_graus", 0.0)}

static func familia_de(tipo: String) -> String:
	return FAMILIAS.get(tipo, "")

## Preço de loja das armas que não se compram (o kit inicial); serve de base para vender
const PRECO_BASICOS := {"espada_basica": 150, "lanca_basica": 250, "escudo_basico": 300}
## Armas e escudo que podem cair dos inimigos (equipamento com raridade)
const TIPOS_DROP: Array[String] = ["montante_ferro","montante_sentinela","montante_geada","montante_trovao","montante_astral","espada_basica", "espada_gemea", "machado", "maca", "lanca_basica", "arco_curto", "arco_curvo", "arco_longo", "escudo_basico"]
## Quanto do que o item custou (preço de loja + melhorias na bigorna) o mercador paga, antes do multiplicador da raridade
const FRACAO_VENDA := 0.3

## Maior nível de arma que a onda já libera na bigorna (NIVEIS_ONDA): é até onde um drop pode vir evoluído
static func nivel_liberado(onda: int) -> int:
	var nivel := 1
	for k in NIVEIS_ONDA.size():
		if onda >= NIVEIS_ONDA[k]:
			nivel = k + 1
	return nivel

static func preco_base(tipo: String) -> int:
	var conjunto := Conjuntos.de_tipo(tipo)
	if conjunto != null:
		return conjunto.PRECO_BASE
	if ARMAS_ADICIONAIS.has(tipo):
		return int(ARMAS_ADICIONAIS[tipo]["preco"])
	return int(PRECO_BASICOS.get(tipo, 100))

## O que o mercador paga por um equipamento: o investimento (preço de loja + o custo de cada melhoria até o nível dele) x fração x multiplicador
## da raridade. Assim vender nunca rende mais que comprar e melhorar de novo, e a raridade é o que faz valer a pena guardar ou vender
static func preco_venda(tipo: String, raridade: String, nivel: int) -> int:
	var investimento := preco_base(tipo)
	for k in range(1, clampi(nivel, 1, NIVEIS_CUSTO.size())):
		investimento += NIVEIS_CUSTO[k]
	return maxi(roundi(investimento * FRACAO_VENDA * Raridades.multiplicador_preco(raridade)), 1)

func obter_dados_nivel_arma(id_arma: String, nivel: int) -> Dictionary:
	if not armas.has(id_arma):
		return {}

	var arma = armas[id_arma]
	if not arma["niveis"].has(nivel):
		return {}

	return arma["niveis"][nivel]

## Custo do próximo passo de uma peça de conjunto na bigorna. Até o nível 5: ouro e onda como nas armas, mais 1 moeda de forja.
## No nível 5: ascensão de raridade (CUSTOS_ASCENSAO pelo degrau, 1 moeda de forja), com "ascensao" e "raridade_nova". Vazio no lendário nível 5
static func dados_melhoria_conjunto(nivel: int, raridade: String = "comum") -> Dictionary:
	if nivel >= 1 and nivel < NIVEIS_CUSTO.size():
		return {"custo": NIVEIS_CUSTO[nivel], "onda_necessaria": NIVEIS_ONDA[nivel], "moedas_forja": MOEDAS_FORJA_POR_NIVEL}
	var degrau := Raridades.indice(raridade)
	if nivel < NIVEIS_CUSTO.size() or degrau >= CUSTOS_ASCENSAO.size():
		return {}
	return {"custo": CUSTOS_ASCENSAO[degrau], "onda_necessaria": NIVEIS_ONDA[NIVEIS_ONDA.size() - 1], "moedas_forja": MOEDAS_FORJA_POR_NIVEL,
			"ascensao": true, "raridade_nova": Raridades.ORDEM[degrau + 1]}

func obter_dados_nivel_armadura(id_armadura: String, nivel: int) -> Dictionary:
	var conjunto := Conjuntos.de_tipo(id_armadura)
	if conjunto != null:
		return conjunto.dados(id_armadura, nivel)
	id_armadura = ARMADURAS_ITENS.get(id_armadura, id_armadura)
	if not armaduras.has(id_armadura):
		return {}
	var armadura = armaduras[id_armadura]
	if not armadura["niveis"].has(nivel):
		return {}
	return armadura["niveis"][nivel]
