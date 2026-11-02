extends RefCounted
## Maestria de combate independe do modelo do item e do conjunto de animações.
const FAMILIAS := ["espada", "montante", "lanca", "machado", "maca", "arco", "escudo"]
static var _cache: Dictionary = {}
const NOMES := {"espada":"ESPADA", "montante":"DUAS MAOS", "lanca":"LANCA", "machado":"MACHADO", "maca":"MACA", "arco":"ARCO", "escudo":"ESCUDO"}
const MARCOS := [3, 10, 20, 40, 60, 100]
const PONTOS := [3, 8, 10, 15, 20, 30, 40, 50, 60, 75, 90, 100]
const RAMOS := {
	"espada":["DUELISTA", "VANGUARDA", "GUARDIAO"],
	"montante":["ALCANCE", "RUPTURA", "SENTINELA"],
	"lanca":["PONTA", "CONTROLE", "VIGILIA"],
	"machado":["CACADOR", "LENHADOR DE GUERRA", "RESISTENCIA"],
	"maca":["PRECISAO", "DEMOLIDOR", "BASTIAO"],
	"arco":["ATIRADOR", "PRESSAO", "BATEDOR"],
	"escudo":["MOBILIDADE", "RESPOSTA", "FORTALEZA"]}
const TECNICAS := {
	"espada":["CORTE DE AVANCO", "CORTE PESADO", "RESPOSTA FIRME"],
	"montante":["PASSO E CORTE", "CORTE DE RUPTURA", "CORTE DE CONTENCAO"],
	"lanca":["ESTOCADA LONGA", "VARREDURA", "ESTOCADA DE RESPOSTA"],
	"machado":["CORTE DE APROXIMACAO", "GOLPE DO LENHADOR", "CORTE DE RESPOSTA"],
	"maca":["PASSO E IMPACTO", "GOLPE DEMOLIDOR", "IMPACTO DE RESPOSTA"],
	"arco":["TIRO PREPARADO", "DISPARO POTENTE", "TIRO EM RECUO"],
	"escudo":["AVANCO PROTEGIDO", "ESCUDADA FORTE", "RESPOSTA DO BASTIAO"]}
const FINALIZADORES := {
	"espada":["CORTE DE RETORNO", "CORTE ROMPEDOR", "CORTE DE COBERTURA"],
	"montante":["CORTE DE ALCANCE", "RUPTURA FINAL", "CORTE DA SENTINELA"],
	"lanca":["PONTA FINAL", "VARREDURA FINAL", "PONTA DA VIGILIA"],
	"machado":["CORTE DO CACADOR", "CUNHA DE GUERRA", "CORTE FIRME"],
	"maca":["IMPACTO PRECISO", "IMPACTO DEVASTADOR", "IMPACTO DO BASTIAO"],
	"arco":["FLECHA PRECISA", "FLECHA DE IMPACTO", "FLECHA DE COBERTURA"],
	"escudo":["ESCUDADA EM AVANCO", "ESCUDADA ROMPEDORA", "ESCUDADA DE COBERTURA"]}

static func familia(tipo: String) -> String:
	if tipo.begins_with("montante_") or tipo == "espada_gemea": return "montante"
	if tipo.begins_with("arco_"): return "arco"
	if tipo.begins_with("escudo_"): return "escudo"
	if tipo.begins_with("lanca_"): return "lanca"
	return {"espada_basica":"espada", "machado":"machado", "maca":"maca"}.get(tipo, "")

static func xp_para_nivel(nivel: int) -> int:
	var n := clampi(nivel, 0, 100)
	return roundi(30.0 * n + 5.0 * n * n + 0.15 * n * n * n)

static func nivel(xp: int) -> int:
	var baixo := 0
	var alto := 100
	while baixo < alto:
		var meio := (baixo + alto + 1) / 2
		if xp_para_nivel(meio) <= xp: baixo = meio
		else: alto = meio - 1
	return baixo

static func pontos(n: int) -> int:
	return PONTOS.filter(func(m): return m <= n).size()

static func nos(f: String) -> Array[Dictionary]:
	if _cache.has(f): return _cache[f]
	var resultado: Array[Dictionary] = []
	if not f in FAMILIAS: return resultado
	for ramo in 3:
		for degrau in 6:
			var id := "%s_%d_%d" % [f, ramo, degrau]
			var nome: String = ["PASSO ECONOMICO", "IMPACTO FIRME", "GUARDA EFICIENTE"][ramo]
			var texto: String = ["Esquiva gasta 8% menos folego.", "Golpes empurram 12% mais.", "Bloqueios gastam 8% menos folego."][ramo]
			var efeito: String = ["esquiva", "empurrao", "guarda"][ramo]
			var valor: float = [0.08, 0.12, 0.08][ramo]
			var tipo := "passiva"
			match degrau:
				1:
					nome = TECNICAS[f][ramo]; tipo = "tecnica"; efeito = ""; valor = 0
					texto = perfil(f, ramo).descricao
				2:
					nome = ["LEITURA DE ABERTURA", "PRESSAO CONTINUA", "RESPOSTA DISCIPLINADA"][ramo]
					efeito = ["apos_esquiva", "fim_combo", "apos_guarda"][ramo]; valor = 0.10
					texto = ["+10% dano no primeiro acerto apos esquivar.", "+10% dano no ultimo golpe do combo.", "+10% dano no primeiro acerto apos bloquear."][ramo]
				3:
					nome = FINALIZADORES[f][ramo]; tipo = "finalizador"; efeito = ""; valor = 0
					texto = ("Substitui a escudada apos aparar por " if f == "escudo" else "Finaliza o combo com ") + ["alcance maior e avanco curto.", "impacto forte e recuperacao mais lenta.", "golpe firme com recuperacao mais curta."][ramo]
				4:
					nome = ["ECONOMIA DE MOVIMENTO", "RITMO DE COMBATE", "GUARDA SOLIDA"][ramo]
					efeito = ["custo_tecnica", "regeneracao", "reducao_bloqueio"][ramo]; valor = [0.10, 0.08, 0.05][ramo]
					texto = ["Tecnicas gastam 10% menos folego.", "Regenera folego 8% mais rapido.", "Bloqueio reduz mais 5% do dano recebido."][ramo]
				5:
					nome = "DOMINIO: " + RAMOS[f][ramo]; efeito = "dominio_%d" % ramo; valor = 0.15
					texto = "Tecnica e finalizador deste caminho causam 15% mais dano."
			resultado.append({"id":id, "familia":f, "ramo":ramo, "degrau":degrau, "nome":nome, "descricao":texto, "nivel":MARCOS[degrau], "tipo":tipo, "efeito":efeito, "valor":valor, "requisito":"%s_%d_%d" % [f, ramo, degrau - 1] if degrau > 0 else ""})
	_cache[f] = resultado
	return resultado

static func no(id: String) -> Dictionary:
	for f in FAMILIAS:
		if not id.begins_with(f + "_"): continue
		for dado in nos(f):
			if dado.id == id: return dado
	return {}

static func perfil(f: String, ramo: int) -> Dictionary:
	var r := clampi(ramo, 0, 2)
	var alcance: float = {"espada":44.0,"montante":56.0,"lanca":68.0,"machado":44.0,"maca":40.0,"escudo":38.0,"arco":280.0}.get(f, 44.0)
	return {"familia":f,"ramo":r,"dano":[1.25,1.65,1.35][r],"empurrao":[1.0,1.6,1.3][r],"alcance":alcance * [1.25,1.0,1.0][r],"cone":[0.70,0.05,0.40][r],"folego":[16.0,24.0,18.0][r],"preparo":[0.18,0.40,0.16][r],"duracao":[0.44,0.64,0.46][r],"recuperacao":[0.18,0.32,0.16][r],"avanco":[18.0,0.0,-12.0 if f == "arco" else 0.0][r],"descricao":["Avanco curto e golpe preciso. Custa 16 de folego.", "Prepara um golpe pesado. Custa 24 de folego.", "Resposta apos bloquear ou aparar. Custa 18 de folego."][r]}
