extends RefCounted

## Primeiro arco com conclusão; usa o diário e o save da vila, inclusive em mundos antigos.
const ORDEM := ["limiar_vigilia", "limiar_raizes", "limiar_ecos", "limiar_selo"]
const MISSOES := {
	"limiar_vigilia": {"nome":"LIMIAR I - A PRIMEIRA VIGILIA", "dono":"lia", "tipo":"chefe", "quantidade":1, "brasas":10, "receita":"lanca_basica",
		"texto":"O selo da praca esta enfraquecendo. Derrote o guardiao do primeiro andar e conte a Lia. Recompensa extra: projeto da lanca para fabricar no Ivo."},
	"limiar_raizes": {"nome":"LIMIAR II - RAIZES QUE SUSTENTAM", "dono":"bento", "tipo":"colheita", "quantidade":2, "brasas":15, "receita":"aljava_basica", "anterior":"limiar_vigilia",
		"texto":"Bento precisa de duas colheitas da estacao para preparar as raizes do novo selo. Cultive sua horta e entregue a ele. Recompensa extra: projeto da aljava."},
	"limiar_ecos": {"nome":"LIMIAR III - O ECO NAS RUINAS", "dono":"ferreiro", "tipo":"chefe", "quantidade":6, "brasas":20, "receita":"armadura_basica", "anterior":"limiar_raizes",
		"texto":"Ivo reconheceu o metal que prende o Limiar. Venca o guardiao do andar 6 e volte a forja. Recompensa extra: projeto da armadura."},
	"limiar_selo": {"nome":"LIMIAR IV - A LUZ DA VILA", "dono":"mistica", "tipo":"chefe", "quantidade":10, "brasas":40, "anterior":"limiar_ecos",
		"texto":"Estela encontrou o ultimo vinculo. Derrote o guardiao do andar 10 e volte para restaurar o selo da praca. A fonte passara a recuperar 30 de energia por dia, para cada jogador."},
}

static func disponivel(id: String, cidade: Node) -> bool:
	if not MISSOES.has(id): return true
	var anterior: String = MISSOES[id].get("anterior", "")
	return anterior == "" or (cidade != null and cidade.missoes.get(anterior,{}).get("estado", "") == "concluida")

static func concluida(cidade: Node) -> bool:
	return cidade != null and cidade.missoes.get("limiar_selo",{}).get("estado", "") == "concluida"

static func objetivo(cidade: Node) -> String:
	for id in ORDEM:
		if cidade.missoes.get(id,{}).get("estado", "") != "concluida":
			return MISSOES[id].nome + "\n" + MISSOES[id].texto
	return "O SELO FOI RESTAURADO\nA fonte da praca recupera 30 de energia por dia. A fenda continua aberta para novas expedicoes."

## Uma fonte para HUD, diário e marcadores; os itens são consultados na mochila de quem lê.
static func rastreio(cidade: Node, quem: Node = null) -> Dictionary:
	for id in ORDEM:
		var estado: String = cidade.missoes.get(id,{}).get("estado","")
		if estado == "concluida": continue
		var dados: Dictionary = MISSOES[id]
		var nomes := {"lia":"LIA", "bento":"BENTO", "ferreiro":"IVO", "mistica":"ESTELA"}
		var nome: String = nomes[dados.dono]
		var fase := "aceitar"
		var texto := "Fale com %s na vila" % nome
		var alvo: String = dados.dono
		# Só a etapa "derrote o guardião do andar N" tem a ver com a fenda; falar com a vila ou colher na horta não tem
		var nos_andares := false
		if estado == "aceita":
			var progresso: Vector2i = cidade.progresso_missao(id,quem)
			if progresso.x >= progresso.y:
				fase = "entregar"
				texto = "Volte a %s para entregar" % nome
			else:
				fase = "cumprir"
				alvo = ""
				texto = "Fazenda: colheitas da estacao %d/2" % progresso.x if dados.tipo == "colheita" else "Fenda: derrote o guardiao do andar %d" % dados.quantidade
				nos_andares = dados.tipo == "chefe"
		return {"id":id,"fase":fase,"texto":texto,"alvo":alvo,"dono":dados.dono,"titulo":dados.nome,"andares":nos_andares}
	return {"id":"","fase":"concluida","texto":"Selo restaurado! Use a fonte da vila.","alvo":"","dono":"","titulo":"LIMIAR CONCLUIDO","andares":false}

const ENTREGAS := {
	"limiar_vigilia":"Voce voltou. Entao ainda temos tempo. Aprendi com o antigo guarda a desenhar esta lanca: leve o projeto ao Ivo. Agora procure Bento; o selo precisa de raizes vivas.",
	"limiar_raizes":"Essas raizes nasceram aqui. E isso que faltava ao selo: algo que queira ficar. O projeto da aljava e seu. Ivo espera noticias das ruinas do sexto andar.",
	"limiar_ecos":"O eco nas ruinas confirmou: a pedra da praca e o Limiar estao ligados. Este projeto de armadura vai ajudar. Procure Estela depois de vencer o decimo guardiao.",
	"limiar_selo":"Esta ouvindo? A praca voltou a respirar. Voce nao fechou todos os caminhos, mas deu a esta vila um futuro. A fonte agora recupera sua energia uma vez por dia. Quando quiser partir de novo, estaremos aqui."
}
