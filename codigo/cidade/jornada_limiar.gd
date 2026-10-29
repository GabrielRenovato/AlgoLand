extends RefCounted

## Primeiro arco com conclusão; usa o diário e o save da vila, inclusive em mundos antigos.
const ORDEM := ["limiar_vigilia", "limiar_raizes", "limiar_ecos", "limiar_selo"]
const MISSOES := {
	"limiar_vigilia": {"nome":"LIMIAR I - A PRIMEIRA VIGILIA", "dono":"lia", "tipo":"chefe", "quantidade":1, "brasas":10, "receita":"lanca_basica",
		"texto":"O selo da praca esta enfraquecendo e a fenda ja responde a quem anda por ela. Lia guarda as chaves da vigilia, mas nao pode descer. Derrote o guardiao do primeiro andar, o eco de um antigo vigia, e conte a ela. Recompensa extra: projeto da lanca para fabricar no Ivo."},
	"limiar_raizes": {"nome":"LIMIAR II - RAIZES QUE SUSTENTAM", "dono":"bento", "tipo":"colheita", "quantidade":2, "brasas":15, "receita":"aljava_basica", "anterior":"limiar_vigilia",
		"texto":"Bento herdou da avo sementes que crescem sobre o selo e prendem a pedra da praca. Ele precisa de duas colheitas da estacao para replantar as raizes. Cultive sua horta e entregue a ele. Recompensa extra: projeto da aljava."},
	"limiar_ecos": {"nome":"LIMIAR III - O ECO NAS RUINAS", "dono":"ferreiro", "tipo":"chefe", "quantidade":6, "brasas":20, "receita":"armadura_basica", "anterior":"limiar_raizes",
		"texto":"Ivo reconheceu o metal que prende o Limiar: e o mesmo das armas dos primeiros vigias. Venca o guardiao do andar 6, onde esse metal sangra pelas ruinas, e volte a forja. Recompensa extra: projeto da armadura."},
	"limiar_selo": {"nome":"LIMIAR IV - A ULTIMA VIGILIA", "dono":"mistica", "tipo":"ondas", "quantidade":3, "brasas":40, "anterior":"limiar_ecos",
		"texto":"Estela leu nas estrelas a ultima ronda: o selo precisa que alguem desca, volte, e prove que e possivel voltar. Depois de aceitar, venca 3 andares da fenda e volte para conversar. Recompensa extra: recuperar 30 de energia por dia na praca."},
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
				if dados.tipo == "ondas":
					texto = "Fenda: venca %d andares (%d/%d)" % [dados.quantidade,progresso.x,progresso.y]
				nos_andares = dados.tipo in ["chefe","ondas"]
		return {"id":id,"fase":fase,"texto":texto,"alvo":alvo,"dono":dados.dono,"titulo":dados.nome,"andares":nos_andares}
	return {"id":"","fase":"concluida","texto":"Selo restaurado! Use a fonte da vila.","alvo":"","dono":"","titulo":"LIMIAR CONCLUIDO","andares":false}

const ENTREGAS := {
	"boas_vindas":"Entao ja conhece a vila inteira. Cada um deles carrega um pedaco do selo, mesmo sem saber. Cuide deles e a vila cuida de voce.",
	"passeio":"As portas continuam abrindo. Isso ja e mais do que eu esperava ver depois de tantos anos. Obrigada por olhar com tanto cuidado.",
	"horta":"Hum. A terra respondeu a sua mao do mesmo jeito que respondia a do antigo vigia. Minha avo teria sorrido.",
	"remedios":"Ervas frescas, direto da fazenda do vigia. As prateleiras nao ficavam tao cheias desde antes da fenda, querido.",
	"cancao":"Isso! Esse e o refrao que faltava: nao a partida, o retorno. Vou cantar seu nome em toda mesa da taverna.",
	"caminhos":"Entao e verdade: ha algo do outro lado do decimo andar. Anotei tudo no meu caderno de estrelas. A fenda ainda tem muito a dizer.",
	"limiar_vigilia":"Voce voltou. Entao ainda temos tempo. O guardiao era um vigia, nao um monstro, e mesmo assim voce o deixou descansar. Aprendi a desenhar esta lanca com ele: leve o projeto ao Ivo. Agora procure Bento; o selo precisa de raizes vivas.",
	"limiar_raizes":"Essas raizes nasceram aqui, e e isso que faltava ao selo: algo que queira ficar. O projeto da aljava e seu. Ivo espera noticias das ruinas do sexto andar.",
	"limiar_ecos":"O eco nas ruinas confirmou: a pedra da praca e o Limiar sao o mesmo metal, forjado pelos primeiros vigias. Este projeto de armadura vai ajudar. Procure Estela para organizar a ultima ronda da vila.",
	"limiar_selo":"Esta ouvindo? A praca voltou a respirar. Voce nao fechou todos os caminhos, mas provou que e possivel voltar, e isso mantem o selo de pe. A fonte agora recupera sua energia uma vez por dia. Quando quiser partir de novo, estaremos aqui."
}
