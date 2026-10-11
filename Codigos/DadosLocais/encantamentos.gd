extends RefCounted

const NIVEL_MAXIMO := 3
const CUSTO_POR_NIVEL := 120
# Só armas de ataque: o escudo não acerta inimigos
const TIPOS_ENCANTAVEIS: Array[String] = ["espada_basica", "espada_gemea", "machado", "maca", "arco_curto", "arco_curvo", "arco_longo", "lanca_basica"]

const TIPOS := {
	"fogo": {"nome": "FOGO", "cor": Color(1.0, 0.55, 0.2)},
	"gelo": {"nome": "GELO", "cor": Color(0.55, 0.85, 1.0)},
	"raio": {"nome": "RAIO", "cor": Color(1.0, 0.95, 0.4)},
	"vampirico": {"nome": "VAMPIRICO", "cor": Color(0.9, 0.25, 0.35)},
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
		"vampirico":
			return {"roubo": 0.04 * nivel}
	return {}

static func descricao(tipo: String, nivel: int) -> String:
	var e := efeito(tipo, nivel)
	match tipo:
		"fogo":
			return "QUEIMA %d POR 0,5S DURANTE 3S" % e["dano_tick"]
		"gelo":
			return "DEIXA %d%% MAIS LENTO POR 2S" % roundi(e["lentidao"] * 100)
		"raio":
			return "SALTA %d%% DO DANO PARA 1 INIMIGO" % roundi(e["fracao_dano"] * 100)
		"vampirico":
			return "ROUBA %d%% DO DANO COMO VIDA" % roundi(e["roubo"] * 100)
	return ""
