extends RefCounted

const NIVEL_MAXIMO := 3
const CUSTO_POR_NIVEL := 120
# Só armas de ataque corpo a corpo: o escudo não acerta inimigos e o arco ficava fácil demais com efeito à distância (25/10/2026)
const TIPOS_ENCANTAVEIS: Array[String] = ["montante_ferro","montante_sentinela","montante_geada","montante_trovao","montante_astral","espada_basica", "espada_gemea", "machado", "maca", "lanca_basica"]

## O antigo "vampirico" (roubo de vida) saiu por ser forte demais; armas salvas com ele viram "eletrico" (dados_item.gd)
const TIPOS := {
	"fogo": {"nome": "AFIACAO", "cor": Color("cfaa78")},
	"gelo": {"nome": "BALANCEAMENTO", "cor": Color("abb9bd")},
	"raio": {"nome": "CONTRAPESO", "cor": Color("d3ba80")},
	"eletrico": {"nome": "PONTA REFORCADA", "cor": Color("c5bfb3")},
}

static func custo(proximo_nivel: int) -> int:
	return CUSTO_POR_NIVEL * proximo_nivel

static func cor(tipo: String) -> Color:
	return TIPOS.get(tipo, {}).get("cor", Color.WHITE)

static func nome(tipo: String) -> String:
	return TIPOS.get(tipo, {}).get("nome", "")

# Valores por nível; usados no combate e nos textos do painel
static func efeito(tipo: String, nivel: int) -> Dictionary:
	match tipo:
		"fogo":
			return {"dano_tick": 1 + nivel, "intervalo": 0.5, "duracao": 3.0}
		"gelo":
			return {"lentidao": 0.15 + 0.1 * nivel, "duracao": 2.0}
		"raio":
			return {"fracao_dano": 0.25 + 0.15 * nivel, "alcance": 70.0}
		"eletrico":
			# Choque extra no próprio alvo e chance de paralisar (chefes não paralisam: atordoar() os ignora)
			return {"fracao_dano": 0.1 + 0.1 * nivel, "chance_paralisia": 0.1 + 0.05 * nivel, "paralisia": 0.6}
	return {}

static func descricao(tipo: String, nivel: int) -> String:
	match tipo:
		"fogo":
			return "+%d%% DANO FISICO" % (4 * clampi(nivel,1,3))
		"gelo":
			return "-%d%% CONSUMO DE FOLEGO" % (3 * clampi(nivel,1,3))
		"raio":
			return "+%d%% EMPURRAO" % (10 * clampi(nivel,1,3))
		"eletrico":
			return "+%d%% DANO NA RESPOSTA APOS APARO" % (8 * clampi(nivel,1,3))
	return ""

static func modificadores(item: Resource) -> Dictionary:
	if item == null or not item.tipo in TIPOS_ENCANTAVEIS: return {}
	var n := clampi(int(item.nivel_encantamento),0,3)
	match item.encantamento:
		"fogo": return {"dano":0.04 * n}
		"gelo": return {"folego":0.03 * n}
		"raio": return {"empurrao":0.10 * n}
		"eletrico": return {"resposta":0.08 * n}
	return {}
