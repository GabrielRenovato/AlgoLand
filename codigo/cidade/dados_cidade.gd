extends RefCounted

const EstadosClima := preload("res://codigo/dados/estados_clima.gd")
const InteriorCasa := preload("res://codigo/cidade/interior_casa.gd")

## Cadastro da vila: lugares, moradores, agendas e pedidos. Horários seguem a Iluminacao.
const NOME := "VILA DAS FLORES"
static var _layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://codigo/cidade/layout_vila.json"))
static var PREDIOS: Dictionary = _montar_predios()

static func _montar_predios() -> Dictionary:
	var predios := {}
	for id in _layout["predios"]:
		var dados: Dictionary = _layout["predios"][id].duplicate()
		dados["base"] = Vector2(dados["base"][0], dados["base"][1])
		predios[id] = dados
	return predios

static func ponto(chave: String) -> Vector2:
	var coordenadas: Array = _layout[chave]
	return Vector2(coordenadas[0], coordenadas[1])

static func caminho_sprite(id: String) -> String:
	return "res://assets/npcs/cidade/%s.png" % MORADORES[id]["folha"]

static var _sprites: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/npcs/cidade/manifesto.json"))

static func geometria_sprite(id: String) -> Dictionary:
	return _sprites[MORADORES[id]["folha"]]

static var MORADORES := {
	"mercador": {"folha": "tomas", "nome": "TOMAS", "oficio": "Comerciante", "casa": "venda", "textura": "merchant", "servico": "mercante", "cor": Color.WHITE,
		"fala": "A venda abastece quem cuida da terra e quem enfrenta a floresta.",
		"rotina": [[6, "cidade", ponto("mercador_abertura"), "Abrindo a venda"], [8, "venda", InteriorCasa.ponto("venda", "trabalho"), "Atendendo na venda"], [17, "cidade", ponto("mercador_praca"), "Conversando na praca"], [20, "venda", InteriorCasa.ponto("venda", "trabalho"), "Guardando as mercadorias"]]},
	"curandeira": {"folha": "rosa", "nome": "DONA ROSA", "oficio": "Curandeira", "casa": "enfermaria", "textura": "old woman", "servico": "cura", "cor": Color.WHITE,
		"fala": "Descanse antes de voltar a lutar. Uma vila tambem se cuida com pequenos gestos.",
		"rotina": [[6, "cidade", ponto("rosa_jardim"), "Cuidando do jardim"], [8, "enfermaria", InteriorCasa.ponto("enfermaria", "trabalho"), "Atendendo na enfermaria"], [18, "cidade", ponto("rosa_praca"), "Passeando na praca"], [19, "enfermaria", InteriorCasa.ponto("enfermaria", "trabalho"), "Preparando os remedios"]]},
	"bardo": {"folha": "caio", "nome": "CAIO", "oficio": "Musico", "casa": "pousada", "textura": "bard", "servico": "", "cor": Color.WHITE,
		"fala": "Cada aventura merece uma cancao. Volte para me contar a sua!",
		"rotina": [[6, "pousada", InteriorCasa.ponto("pousada", "passeio"), "Tomando cafe"], [10, "cidade", ponto("bardo_coreto"), "Tocando no coreto"], [18, "pousada", InteriorCasa.ponto("pousada", "balcao"), "Atendendo no balcao da taverna"]]},
	"mistica": {"folha": "estela", "nome": "ESTELA", "oficio": "Mistica", "casa": "mistica", "textura": "mystic", "servico": "mistica", "cor": Color.WHITE,
		"fala": "As estacoes mudam, mas o que voce aprendeu na floresta continua com voce.",
		"rotina": [[6, "mistica", InteriorCasa.ponto("mistica", "trabalho"), "Consultando os mapas"]]},
	"lia": {"folha": "lia", "nome": "LIA", "oficio": "Cuida da comunidade", "casa": "sede", "textura": "old woman", "servico": "acampamento", "cor": Color.WHITE,
		"fala": "Bem-vindo a Vila das Flores! A fazenda fica a oeste e a trilha da arena a leste. Os pedidos estao no mural.",
		"rotina": [[6, "sede", InteriorCasa.ponto("sede", "trabalho"), "Organizando os pedidos"], [9, "cidade", ponto("lia_praca"), "Recebendo os visitantes"], [15, "sede", InteriorCasa.ponto("sede", "trabalho"), "Cuidando da comunidade"], [19, "pousada", InteriorCasa.ponto_inverno(1), "Jantando com os vizinhos"]]},
	"bento": {"folha": "bento", "nome": "BENTO", "oficio": "Agricultor", "casa": "casa_bento", "textura": "merchant", "servico": "", "cor": Color.WHITE,
		"fala": "Plante o que combina com a estacao e regue todo dia. No inverno, prepare a terra para a primavera.",
		"rotina": [[6, "cidade", ponto("bento_horta"), "Cuidando da horta"], [12, "cidade", ponto("bento_praca"), "Descansando na praca"], [16, "casa_bento", InteriorCasa.ponto("casa_bento", "trabalho"), "Separando as sementes"], [19, "pousada", InteriorCasa.ponto_inverno(3), "Jantando na pousada"], [22, "casa_bento", InteriorCasa.ponto("casa_bento", "trabalho"), "Descansando em casa"]]},
	"nilo": {"folha":"nilo", "nome":"NILO", "oficio":"Pescador e artesao de varas", "casa":"palafita", "textura":"merchant", "servico":"vara_pesca", "cor":Color.WHITE,
		"fala":"Eu cuido da sua vara. Traga as pedras de refinamento que encontrar pescando.", "rotina":[]},
	"ferreiro": {"folha": "ivo", "nome": "IVO", "oficio": "Ferreiro", "casa": "forja", "textura": "merchant", "servico": "forja", "cor": Color.WHITE,
		"fala": "Na arena voce aprende o desenho. A terra fornece o material. Eu junto as duas coisas.",
		"rotina": [[6, "forja", InteriorCasa.ponto("forja", "passeio"), "Afiando as ferramentas"], [8, "forja", InteriorCasa.ponto("forja", "trabalho"), "Trabalhando na forja"]]},
	"osvaldo": {"folha":"osvaldo","nome":"OSVALDO","oficio":"Carpinteiro, 65 anos","idade":65,"casa":"carpintaria","textura":"merchant","servico":"carpinteiro","cor":Color.WHITE,"fala":"Traga madeira e pedra. Construo e amplio o abrigo das suas aves.","rotina":[]},
	"helena": {"folha":"helena","nome":"HELENA","oficio":"Bordadeira e contadora de historias, 55 anos","idade":55,"condicao":"ELA","cadeira_de_rodas":true,"casa":"carpintaria","textura":"old woman","servico":"","cor":Color.WHITE,"fala":"Clara me ajuda no dia a dia. Agora me conte de voce: como anda sua fazenda?","rotina":[]},
	"clara": {"folha":"clara","nome":"CLARA","oficio":"Artesa, 30 anos; ajuda nos cuidados da mae","idade":30,"casa":"carpintaria","textura":"merchant","servico":"","cor":Color.WHITE,"fala":"Divido meu tempo entre minhas encomendas e os cuidados da minha mae, Helena.","rotina":[]},

}
const FALAS_ESTACAO := [
	"A primavera enche os jardins de flores. E tempo de recomecar.",
	"O verao traz tardes longas. Procure a sombra da praca.",
	"No outono, as folhas cobrem os caminhos e a colheita chega a mesa.",
	"O inverno pede cafe quente e conversa dentro de casa.",
]
static var MISSOES := _montar_missoes()
const MISSOES_BASE := {
	"boas_vindas": {"nome": "OS ROSTOS DA VILA", "dono": "lia", "texto": "\"Esta casa de pedra e a sede da vigilia. Faz tempo que ninguem assume o posto do vigia, a sua fazenda.\" A Lia quer que voce se apresente a Tomas, Dona Rosa, Caio, Estela e Bento: cada um guarda uma parte do que mantem o selo da praca de pe.", "tipo": "conversas", "alvos": ["mercador", "curandeira", "bardo", "mistica", "bento"], "brasas": 10},
	"passeio": {"nome": "AS PORTAS DA VIGILIA", "dono": "lia", "texto": "\"Venda, enfermaria, pousada e a casa da Estela: eram os pontos de apoio dos vigias.\" A Lia pede que voce entre nos quatro e veja o que ainda funciona.", "tipo": "visitas", "alvos": ["venda", "enfermaria", "pousada", "mistica"], "brasas": 10},
	"horta": {"nome": "RAIZES DO BENTO", "dono": "bento", "texto": "\"Minha avo dizia que o selo nao gosta de terra morta.\" O Bento quer provar 3 colheitas da estacao da sua horta; ele jura que o solo da fazenda ainda lembra da mao do antigo vigia. No inverno, qualquer colheita serve.", "tipo": "colheita", "quantidade": 3, "brasas": 15},
	"remedios": {"nome": "ERVAS PARA QUEM VOLTA", "dono": "curandeira", "texto": "\"Quem volta da fenda traz frio nos ossos, querido. So erva fresca resolve.\" A Dona Rosa precisa de 2 colheitas para encher as prateleiras da enfermaria antes da proxima leva de feridos.", "tipo": "colheita", "quantidade": 2, "brasas": 15},
	"cancao": {"nome": "O REFRAO DA FENDA", "dono": "bardo", "texto": "\"Todo mundo canta os vigias que partiram. Ninguem canta quem voltou.\" O Caio quer uma cancao nova, e o refrao e a sua historia: depois de aceitar, venca 3 andares na fenda e volte para contar.", "tipo": "ondas", "quantidade": 3, "brasas": 20},
	"caminhos": {"nome": "ONDE AS ESTRELAS SE APAGAM", "dono": "mistica", "texto": "\"As estrelas se apagam sempre no mesmo ponto da fenda: o decimo andar.\" A Estela pede que voce derrote o guardiao do andar 10 e volte para contar o que viu do outro lado.", "tipo": "chefe", "quantidade": 10, "brasas": 25},
}

## Vida de cada morador fora da rotina de trabalho (pedido de 2026-10-15):
## - dorme das HORA_DORMIR às 6h na cama dele (casa e índice da cama em interiores.json; a Lia dorme na pousada, a sede
##   não tem quarto), com a animação de dormir de morador_cidade.gd;
## - folga num dia fixo da semana (0 = segunda; a semana tem 7 dias): acorda em casa e das 8h até dormir anda pela
##   cidade; depois de fechar o comércio também passeia pela cidade até dormir (ver passeio);
## - o serviço (loja, cura, sementes...) só abre no horário comercial e fora da folga (ver servico_fechado);
## - em dia de trabalho, antes de abrir, quem tem comércio fica em casa (não anda pela cidade).
const HORA_DORMIR := 22.0
const CAMAS := {"mercador": ["venda", 0], "curandeira": ["enfermaria", 0], "bardo": ["pousada", 0], "lia": ["pousada", 1],
	"mistica": ["mistica", 0], "bento": ["casa_bento", 0], "ferreiro": ["forja", 0]}
const FOLGAS := {"mercador": 6, "curandeira": 2, "bardo": 0, "mistica": 4, "lia": 5, "bento": 3, "ferreiro": 2}
## [abre, fecha] do serviço de cada um
## A loja só fica aberta enquanto o dono está nela (a rotina de trabalho cobre esse horário)
const HORARIOS := {"nilo":[8,17],"osvaldo":[8,17],"mercador": [8, 17], "curandeira": [8, 18], "mistica": [8, 18], "lia": [6, 19], "bento": [6, 19], "ferreiro": [8, 18]}

## Taverna noturna; o intervalo atravessa a meia-noite. A porta abre todos os dias.
const HORARIO_TAVERNA := [18, 2]

## Caio (bardo) não senta: na festa ele continua atendendo as mesas do balcão (o banco de frente para o Bento fica
## livre para o jogador)
const LUGARES_FESTA := {
	"mercador": Vector2(184, 185), "curandeira": Vector2(184, 239),
	"lia": Vector2(264, 185), "mistica": Vector2(264, 239),
	"bento": Vector2(400, 185),
	"ferreiro": Vector2(400, 257),
}
const COSTAS_FESTA := ["curandeira", "mistica"]
const DUPLAS_FESTA := [["mercador", "curandeira"], ["lia", "mistica"]]

## Cardápio da taverna (fica em cima de cada mesa): o jogador pede sentado à mesa ou falando com o Caio, paga em
## Brasas e o Caio leva até ele; os moradores pedem pelo mesmo cardápio. cura = fração da vida máxima
const CARDAPIO := {
	"pao": {"nome": "PAO DA CASA", "preco": 1, "cura": 0.15, "pedido": "pao com manteiga"},
	"cha": {"nome": "CHA DE ERVAS", "preco": 1, "cura": 0.1, "pedido": "um cha de ervas bem quente"},
	"sopa": {"nome": "SOPA DE LEGUMES", "preco": 2, "cura": 0.35, "pedido": "uma sopa de legumes"},
	"caldo": {"nome": "CALDO DE FEIJAO", "preco": 2, "cura": 0.35, "pedido": "um caldo de feijao"},
	"ensopado": {"nome": "ENSOPADO DO CAIO", "preco": 4, "cura": 1.0, "pedido": "o ensopado da casa"},
}
## O que cada morador costuma pedir (ids do CARDAPIO), em rodízio
const PEDIDOS_MORADORES := {
	"mercador": ["pao", "sopa"],
	"curandeira": ["sopa", "cha"],
	"mistica": ["cha", "caldo"],
	"lia": ["sopa", "pao"],
	"bento": ["caldo", "ensopado"],
	"ferreiro": ["ensopado", "cha"],
}
const SAIDAS_FESTA := {"curandeira": 0.5, "bento": 0.7, "mercador": 0.9, "lia": 1.0, "mistica": 1.15, "bardo": 1.3, "ferreiro": 1.1}

## Cartas sem remetente que o pombo-correio traz (agenda_vila.gd): no domingo de manhã e, sem pedidos a entregar, em
## qualquer manhã. Vêm na ordem, uma vez cada; "brasas" > 0 é um presentinho dentro do envelope. Sem acentos (fonte).
const CARTAS_MISTERIOSAS := [
	{"id": "misterio_1", "texto": "Se esta lendo isto, a fazenda aceitou voce. Ela costumava ser mais exigente. - V.", "brasas": 0},
	{"id": "misterio_2", "texto": "O selo da praca nao e de pedra. E feito de coisas que alguem quis proteger: uma horta, uma cancao, uma porta aberta.", "brasas": 0},
	{"id": "misterio_3", "texto": "Nao desconfie do pombo. Ele atravessou a fenda uma vez e voltou sem asas novas, so com o habito de sempre chegar. Deixei algo no envelope.", "brasas": 3},
	{"id": "misterio_4", "texto": "Os guardioes dos andares foram vigias como eu. Esqueceram o caminho de volta. Quando um deles cair, repare: ele costuma agradecer.", "brasas": 0},
	{"id": "misterio_5", "texto": "Ha um fundo falso na gaveta da forja do Ivo. Nao conte que eu te falei. Deixei um agrado aqui dentro.", "brasas": 5},
	{"id": "misterio_6", "texto": "A fenda nao e um monstro. E uma porta que ninguem fechou direito, e portas cansam de esperar.", "brasas": 0},
	{"id": "misterio_7", "texto": "A Estela le as estrelas e erra por modestia. O decimo andar e onde elas de fato se apagam. Va com calma.", "brasas": 0},
	{"id": "misterio_8", "texto": "Esta e a ultima carta que consigo mandar. O resto da historia agora e sua, e da vila. Obrigado por sempre voltar. - V.", "brasas": 10},
]

## Eventos da vila anunciados no banner do HUD (agenda_vila.gd): de manhã o convite, na hora o começo.
## "dia_semana": 0 = segunda; "inicio"/"fim" em horas (fim < inicio = passa da meia-noite). Textos sem acentos (fonte).
const EVENTOS := {
	"festa_sabado": {"dia_semana": 5, "inicio": 18.0, "fim": 2.0,
		"convite": "HOJE TEM FESTA NA TAVERNA", "detalhe_convite": "A PARTIR DAS 18H",
		"comecou": "A FESTA NA TAVERNA COMECOU!", "detalhe_comecou": "OS VIZINHOS TE ESPERAM LA"},
}

static func festa_sabado(hora: float, dia_semana: int) -> bool:
	return (dia_semana == 5 and (hora >= 18.0 or hora < 2.0)) or (dia_semana == 6 and hora < 2.0)

static func taverna_aberta(hora: float, dia_semana: int = -1) -> bool:
	return hora >= HORARIO_TAVERNA[0] or hora < HORARIO_TAVERNA[1]

## Cama do morador: {"local", "base" (pé da cama, centro), "altura"} ou vazio se não tem
static func cama(id: String) -> Dictionary:
	if not CAMAS.has(id):
		return {}
	var casa: String = CAMAS[id][0]
	var camas: Array = InteriorCasa.dados()["casas"][casa]["itens"].filter(func(item): return item["p"] == "cama")
	if camas.is_empty():
		return {}
	var item: Dictionary = camas[mini(int(CAMAS[id][1]), camas.size() - 1)]
	return {"local": casa, "base": Vector2(item["x"], item["y"]), "altura": float(item["usado"][3])}

## Pontos iniciais do tempo livre. Os afazeres e próximos destinos são escolhidos por passeio_morador.gd;
## no inverno os moradores procuram a pousada.
const LUGARES_PASSEIO := ["praca", "mercador_praca", "rosa_jardim", "bardo_coreto", "estela_flores", "lia_praca", "bento_praca", "poco", "coreto"]

static func passeio(id: String, hora: float, estacao: int, atividade: String) -> Dictionary:
	var indice := MORADORES.keys().find(id)
	if estacao == 3:
		return {"local": "pousada", "ponto": InteriorCasa.ponto_inverno(indice), "atividade": "Aquecendo-se na pousada"}
	var lugar: String = LUGARES_PASSEIO[(indice * 2) % LUGARES_PASSEIO.size()]
	return {"local": "cidade", "ponto": ponto(lugar) + Vector2((indice % 3 - 1) * 14, 0), "atividade": atividade, "livre": true}

static func de_folga(id: String, dia_semana: int) -> bool:
	return int(FOLGAS.get(id, -1)) == dia_semana

## O serviço do morador está aberto agora? Devolve "" se sim, ou o motivo para o botão ("FOLGA HOJE", "ABRE AS 8H")
static func servico_fechado(id: String, hora: float, dia_semana: int) -> String:
	if not HORARIOS.has(id):
		return ""
	if de_folga(id, dia_semana):
		return "FOLGA HOJE"
	var horario: Array = HORARIOS[id]
	if hora < float(horario[0]):
		return "ABRE AS %dH" % int(horario[0])
	if hora >= float(horario[1]):
		return "FECHOU AS %dH" % int(horario[1])
	return ""

## A bigorna permite consultar receitas; fabricar e retirar exigem o ferreiro atendendo.
static func atendimento_forja(cena: Node, dia_semana: int) -> String:
	if cena == null or cena.get("local") != "forja":
		return "FABRICACAO SOMENTE NA FORJA"
	var fechado := servico_fechado("ferreiro", cena.hora_atual(), dia_semana)
	if fechado != "":
		return fechado
	var moradores: Dictionary = cena.get("moradores") if cena.get("moradores") != null else {}
	var ivo: Node2D = moradores.get("ferreiro")
	if not is_instance_valid(ivo) or not ivo.visible or ivo.dormindo or ivo._saindo or ivo.agenda.get("local", "") != "forja":
		return "AGUARDE IVO CHEGAR A OFICINA"
	return ""

static func agenda(id: String, hora: float, estacao: int, clima: int = -1, dia_semana: int = -1) -> Dictionary:
	if id in ["osvaldo","helena","clara"]:
		return preload("res://codigo/cidade/familia_carpinteiro.gd").agenda(id,hora,estacao,clima)
	if id == "nilo":
		return preload("res://codigo/pesca/rotina_nilo.gd").agenda(hora,clima)
	var dados: Dictionary = MORADORES[id]
	if festa_sabado(hora, dia_semana):
		if hora < 18.0 and hora >= float(SAIDAS_FESTA[id]):
			var leito_festa := cama(id)
			return {"local": leito_festa["local"], "ponto": leito_festa["base"] + Vector2(0, 12), "atividade": "Indo dormir depois da festa", "dormindo": true,
				"cama": leito_festa["base"], "altura_cama": leito_festa["altura"]}
		if id == "bardo":
			var posto_festa:=preload("res://codigo/cidade/postos_comerciais.gd").agenda(id)
			posto_festa["atividade"]="Servindo os pedidos da festa"
			posto_festa["festa"]=true
			return posto_festa
		return {"local": "pousada", "ponto": LUGARES_FESTA[id], "atividade": "Festejando com os vizinhos na taverna", "festa": true}
	if id == "bardo" and taverna_aberta(hora, dia_semana):
		return preload("res://codigo/cidade/postos_comerciais.gd").agenda(id)
	# Dormindo (o temporal não acorda ninguém)
	if hora >= HORA_DORMIR or hora < 6.0:
		var leito := cama(id)
		if not leito.is_empty():
			return {"local": leito["local"], "ponto": leito["base"] + Vector2(0, 12), "atividade": "Dormindo", "dormindo": true,
				"cama": leito["base"], "altura_cama": leito["altura"]}
	# Temporal tem prioridade sobre trabalho, encontros e o abrigo coletivo do inverno.
	if clima == EstadosClima.Estado.TEMPESTADE:
		return {"local": dados["casa"], "ponto": InteriorCasa.ponto(dados["casa"], "passeio"), "atividade": "Esperando o temporal passar em casa"}
	# Durante o expediente aberto, o atendimento tem prioridade sobre passeios.
	# Bento não tem comércio: conserva a horta e sua rotina de agricultor.
	if preload("res://codigo/cidade/postos_comerciais.gd").POSTOS.has(id) and HORARIOS.has(id) and servico_fechado(id,hora,dia_semana)=="":
		return preload("res://codigo/cidade/postos_comerciais.gd").agenda(id)
	var praia := visita_praia(id, hora, estacao, clima, dia_semana)
	if not praia.is_empty():
		return praia
	# O ferreiro encerra o expediente, janta com a vila e volta à própria casa antes de dormir.
	if id == "ferreiro" and hora >= 18.0:
		if hora < 19.0:
			return passeio(id, hora, estacao, "Descansando depois da forja")
		if hora < 21.0:
			return {"local": "pousada", "ponto": LUGARES_FESTA[id], "atividade": "Jantando depois do expediente"}
		return {"local": "forja", "ponto": InteriorCasa.ponto("forja", "passeio"), "atividade": "Guardando as ferramentas e descansando"}
	# Folga: acorda sem pressa e passa o dia andando pela cidade até a hora de dormir
	if de_folga(id, dia_semana):
		if hora < 8.0:
			return {"local": dados["casa"], "ponto": InteriorCasa.ponto(dados["casa"], "passeio"), "atividade": "De folga em casa"}
		return passeio(id, hora, estacao, "Passeando no dia de folga")
	# Depois de fechar o comércio, anda pela cidade até a hora de dormir
	if HORARIOS.has(id) and hora >= float(HORARIOS[id][1]):
		return passeio(id, hora, estacao, "Passeando depois do trabalho")
	var entrada: Array = dados["rotina"][0]
	for faixa in dados["rotina"]:
		if hora >= float(faixa[0]):
			entrada = faixa
	if hora < 6.0:
		entrada = [0, dados["casa"], InteriorCasa.ponto(dados["casa"], "passeio"), "Descansando em casa"]
	# Dia de trabalho antes de abrir: quem tem comércio fica em casa se arrumando, sem passear pela cidade
	if HORARIOS.has(id) and hora < float(HORARIOS[id][0]) and entrada[1] == "cidade":
		return {"local": dados["casa"], "ponto": InteriorCasa.ponto(dados["casa"], "passeio"), "atividade": "Se arrumando para abrir"}
	# No frio, os encontros ao ar livre passam para a pousada, exceto a abertura da venda.
	if estacao == 3 and entrada[1] == "cidade" and id != "mercador":
		return {"local": "pousada", "ponto": InteriorCasa.ponto_inverno(MORADORES.keys().find(id)), "atividade": "Aquecendo-se na pousada"}
	return {"local": entrada[1], "ponto": entrada[2], "atividade": entrada[3], "livre": entrada[1] == "cidade"}

## Visitas no tempo livre: folga à tarde ou uma caminhada semanal depois do expediente.
## Trabalho, festa, sono e abrigo do temporal têm prioridade sobre a praia.
static func visita_praia(id: String, hora: float, estacao: int, clima: int, dia_semana: int) -> Dictionary:
	if estacao == 3 or clima not in [-1, EstadosClima.Estado.LIMPO, EstadosClima.Estado.NUBLADO]:
		return {}
	var indice := MORADORES.keys().find(id)
	var folga := de_folga(id, dia_semana) and hora >= 10 and hora < 16
	var depois := HORARIOS.has(id) and dia_semana == (indice + 2) % 7 and hora >= maxf(17, HORARIOS[id][1]) and hora < 19
	if not folga and not depois:
		return {}
	var lugares: Array = preload("res://codigo/cidade/perfis_rotina.gd").PERFIS[id]["praia"]
	var lugar: Array = lugares[posmod(dia_semana, lugares.size())]
	return {"local": "praia", "ponto": lugar[0], "atividade": lugar[1], "livre": true}

## Pedidos de pesca na voz de cada morador (%d = quantidade, %s = peixe, %s = onde). Sem acentos (fonte).
const PEDIDOS_PESCA := {
	"bardo": {"titulo": "PEIXE PARA A TAVERNA", "texto": "Preciso de %d %s do %s para o jantar da taverna. Dizem que quem come peixe de la sonha com a fenda, e eu quero colher o sonho em verso."},
	"curandeira": {"titulo": "CALDO DOS CONVALESCENTES", "texto": "Para o caldo de quem voltou ferido, preciso de %d %s do %s. Peixe fresco ajuda mais que erva, querido."},
	"bento": {"titulo": "ADUBO DE PEIXE", "texto": "Nao entendo de anzol, mas a horta pede adubo bom: %d %s do %s, se nao for incomodo."},
	"lia": {"titulo": "RANCHO DA VIGILIA", "texto": "A vigilia fica de estomago vazio nos turnos longos. Pode pescar %d %s no %s? O selo agradece."},
}
## Agradecimento de cada morador aos pedidos de pesca.
const AGRADECIMENTO_PESCA := {
	"bardo": "Que peixe! Ja ouco o refrao: \"da fenda ao prato, do prato ao verso\". Suas Brasas estao a caminho.",
	"curandeira": "Perfeito, querido. Esta noite alguem dorme sem febre por sua causa. Aqui esta a sua parte.",
	"bento": "Isso vai fazer a terra sorrir. Minha avo aprovaria. Pegue, e merecido.",
	"lia": "A ronda da noite jantara bem. Quem guarda a vila agradece. Aqui esta o combinado.",
}

## Encomendas sazonais do pombo, entregues aos moradores (Nilo só refina varas).
static func _montar_missoes() -> Dictionary:
	var peixes := preload("res://codigo/pesca/peixes.gd")
	var resultado: Dictionary = preload("res://codigo/cidade/jornada_limiar.gd").MISSOES.duplicate(true)
	resultado.merge(MISSOES_BASE)
	var estacoes := ["PRIMAVERA","VERAO","OUTONO","INVERNO"]
	var moradores := ["bardo","curandeira","bento","lia"]
	for estacao in 4:
		var candidatos: Array = peixes.DADOS.keys().filter(func(id):
			return peixes.DADOS[id]["estacoes"].has(estacao)
		)
		candidatos.sort_custom(func(a,b): return peixes.nivel_recomendado(a)<peixes.nivel_recomendado(b))
		for i in mini(4,candidatos.size()):
			var peixe: String = candidatos[i]
			var quantidade := 2 if peixes.nivel_recomendado(peixe)<=2 else 1
			var onde := "mar" if peixes.catalogo()[peixe]["ambiente"]=="mar" else "lago"
			resultado["carta_pesca_%d_%d" % [estacao,i]] = {"nome":PEDIDOS_PESCA[moradores[i]]["titulo"],"dono":moradores[i],"tipo":"peixe",
				"peixe":peixe,"estacao":estacao,"quantidade":quantidade,"brasas":peixes.brasas(peixe)*quantidade*3,
				"texto":PEDIDOS_PESCA[moradores[i]]["texto"] % [quantidade,peixes.nome(peixe),onde]+"\nEstacao: "+estacoes[estacao]+"."}
	return resultado

static func missao_na_estacao(id: String, estacao: int) -> bool:
	var cidade := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Cidade")
	if not preload("res://codigo/cidade/jornada_limiar.gd").disponivel(id, cidade): return false
	return not MISSOES[id].has("estacao") or int(MISSOES[id]["estacao"]) == estacao
