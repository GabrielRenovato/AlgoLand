extends RefCounted
## Contagens acumuladas de golpes/disparos, agrupadas por id; sem eventos individuais no servidor.
const ARMAS := {
	"arco_curto":"arco","arco_curvo":"arco","arco_longo":"arco",
	"espada_basica":"espada","espada_gemea":"espada_dupla","lanca_basica":"lanca",
	"maca":"espada","machado":"machado"}
const LIMITE := 1000000000

static func validar(valor: Variant) -> String:
	if valor is String and preload("res://codigo/dados/armas_montantes.gd").MODELOS.has(valor): return "espada_gemea"
	return valor if valor is String and ARMAS.has(valor) else ""

static func normalizar(valor: Variant) -> Dictionary:
	var resultado := {}
	if not valor is Dictionary: return resultado
	for id: String in ARMAS:
		var n = valor.get(id)
		if (n is int or n is float) and is_finite(float(n)) and float(n)>0:
			resultado[id] = int(clampf(float(n),0,LIMITE))
	return resultado

static func favorita(contagens: Dictionary) -> String:
	var melhor := ""
	var usos := 0
	for id: String in ARMAS:
		var n := int(contagens.get(id,0))
		# ARMAS está em ordem alfabética, igual ao desempate do servidor.
		if n>usos:
			melhor = id
			usos = n
	return melhor

static func mesclar(a: Dictionary, b: Variant) -> Dictionary:
	var resultado := normalizar(a)
	for id: String in normalizar(b): resultado[id] = maxi(int(resultado.get(id,0)),int(b[id]))
	return normalizar(resultado)
