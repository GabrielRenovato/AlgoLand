extends RefCounted

## Especialidades fazem parte do modelo da arma, não somam atributos permanentes.
const DESCRICOES := {
	"montante_ferro":"RITMO: ULTIMO GOLPE DO COMBO CAUSA +25% DANO",
	"montante_sentinela":"RITMO: ULTIMO GOLPE DO COMBO CAUSA +25% DANO",
	"montante_geada":"RITMO: ULTIMO GOLPE DO COMBO CAUSA +25% DANO",
	"montante_trovao":"RITMO: ULTIMO GOLPE DO COMBO CAUSA +25% DANO",
	"montante_astral":"RITMO: ULTIMO GOLPE DO COMBO CAUSA +25% DANO",

	"espada_basica":"CONTRAGOLPE: APOS APARO PERFEITO, PROXIMO GOLPE +50% (3S)",
	"espada_gemea":"RITMO: ULTIMO GOLPE DO COMBO CAUSA +25% DANO",
	"machado":"ABERTURA: PRIMEIRO GOLPE DO COMBO CAUSA +25% DANO",
	"maca":"IMPACTO: +50% EMPURRAO; ULTIMO GOLPE DO COMBO ATORDOA POR 0,35S",
	"lanca_basica":"PONTA: +25% DANO AO ACERTAR A MAIS DE 32 PX",
	"arco_curto":"REFLEXO: +20% DANO ATE 90 PX",
	"arco_curvo":"PRECISAO: +20% DANO ENTRE 90 E 180 PX",
	"arco_longo":"LONGO ALCANCE: +15% DANO A PARTIR DE 160 PX",
}

static func efeito(tipo: String, combo: int, distancia: float, contra: bool = false) -> Dictionary:
	var resultado := {"dano":1.0, "empurrao":1.0, "atordoar":0.0}
	if preload("res://codigo/dados/armas_montantes.gd").MODELOS.has(tipo): tipo = "espada_gemea"
	match tipo:
		"espada_basica":
			if contra: resultado.dano = 1.5
		"espada_gemea":
			if combo == 3: resultado.dano = 1.25
		"machado":
			if combo == 1: resultado.dano = 1.25
		"maca":
			resultado.empurrao = 1.5
			if combo == 3: resultado.atordoar = 0.35
		"lanca_basica":
			if distancia > 32.0: resultado.dano = 1.25
		"arco_curto":
			if distancia <= 90.0: resultado.dano = 1.20
		"arco_curvo":
			if distancia > 90.0 and distancia <= 180.0: resultado.dano = 1.20
		"arco_longo":
			if distancia >= 160.0: resultado.dano = 1.15
	return resultado
