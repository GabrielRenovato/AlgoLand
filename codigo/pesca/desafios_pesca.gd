extends RefCounted

## Metas únicas por mundo. A coleção usa o histórico: vender ou cozinhar não apaga descobertas.
const Peixes := preload("res://codigo/pesca/peixes.gd")
static var DESAFIOS := _montar_desafios()
const BASE := {
	"primeira_captura": {"nome":"PRIMEIRA CAPTURA", "campo":"total", "meta":1, "brasas":10},
	"pescador": {"nome":"PESCADOR PERSISTENTE", "campo":"total", "meta":20, "brasas":50},
	"mira_firme": {"nome":"3 CAPTURAS SO COM OTIMOS", "campo":"perfeitas", "meta":3, "brasas":45},
	"raridades": {"nome":"3 PEIXES RAROS OU EPICOS", "campo":"raros", "meta":3, "brasas":60},
	"fornecedor": {"nome":"5 ENCOMENDAS DO CAIS", "campo":"pedidos", "meta":5, "brasas":50},
}
const COLECAO := {
	"colecao_54": {"nome":"COLECAO COMPLETA: 54 ESPECIES", "campo":"especies", "meta":54, "brasas":1600},
	"colecao_24": {"nome":"NATURALISTA: 24 ESPECIES", "campo":"especies", "meta":24, "brasas":300},
	"colecao_36": {"nome":"ESPECIALISTA: 36 ESPECIES", "campo":"especies", "meta":36, "brasas":500},
	"colecao_48": {"nome":"COLECIONADOR: 48 ESPECIES", "campo":"especies", "meta":48, "brasas":1000},
	"colecao_3": {"nome":"CONHECEDOR: 3 ESPECIES", "campo":"especies", "meta":3, "brasas":25},
	"colecao_6": {"nome":"EXPLORADOR: 6 ESPECIES", "campo":"especies", "meta":6, "brasas":60},
	"colecao_12": {"nome":"MESTRE: 12 ESPECIES", "campo":"especies", "meta":12, "brasas":180},
}

static func dados(id: String) -> Dictionary:
	return DESAFIOS.get(id,COLECAO.get(id,{}))

static func progresso(id: String, historico: Dictionary, perfeitas: int, pedidos: int) -> int:
	if dados(id).has("peixe"):
		return int(historico.get(dados(id)["peixe"],0))
	match dados(id).get("campo", ""):
		"especies": return historico.size()
		"perfeitas": return perfeitas
		"pedidos": return pedidos
	var total := 0
	for peixe in historico:
		if dados(id).get("campo", "") == "raros" and not Peixes.raridade(peixe) in ["raro","epico"]:
			continue
		total += int(historico[peixe])
	return total

## Duas encomendas por dia do jogo; só espécies disponíveis na estação, sem sortear de novo ao abrir.
static func pedidos_do_dia(dia: int, estacao: int, habilidade := 99, nivel_vara := 5) -> Array[Dictionary]:
	var pedidos: Array[Dictionary] = []
	for ambiente in ["mar","rio"]:
		var candidatos: Array[String] = []
		for id in Peixes.DADOS:
			if Peixes.nivel_pesca(id) > clampi(habilidade,1,99): continue
			if int(Peixes.DADOS[id].get("nivel_vara",1)) > clampi(nivel_vara,1,5): continue
			var dados_peixe: Dictionary = Peixes.DADOS[id]
			if Peixes.catalogo()[id]["ambiente"] != ambiente:
				continue
			if not dados_peixe["estacoes"].is_empty() and not dados_peixe["estacoes"].has(estacao):
				continue
			candidatos.append(id)
		if candidatos.is_empty(): continue
		var peixe := candidatos[(maxi(1,dia)-1)%candidatos.size()]
		var quantidade := 2 if Peixes.raridade(peixe) in ["comum","incomum"] else 1
		pedidos.append({"id":"%d_%s" % [dia,ambiente], "peixe":peixe, "quantidade":quantidade,
			"brasas":Peixes.brasas(peixe)*quantidade*3})
	return pedidos

static func _montar_desafios() -> Dictionary:
	var resultado := BASE.duplicate(true)
	for meta in [50,100,250,500,1000]:
		resultado["capturas_%d" % meta] = {"nome":"%d CAPTURAS" % meta,"campo":"total","meta":meta,"brasas":meta}
	for meta in [10,25,50]:
		resultado["perfeitas_%d" % meta] = {"nome":"%d PESCARIAS PERFEITAS" % meta,"campo":"perfeitas","meta":meta,"brasas":meta*10}
	for peixe in Peixes.DADOS:
		resultado["especie_"+peixe] = {"nome":"PESCAR 5 "+Peixes.nome(peixe),"peixe":peixe,"meta":5,"brasas":Peixes.brasas(peixe)*10}
	return resultado
