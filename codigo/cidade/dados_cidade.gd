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
}
const FALAS_ESTACAO := [
	"A primavera enche os jardins de flores. E tempo de recomecar.",
	"O verao traz tardes longas. Procure a sombra da praca.",
	"No outono, as folhas cobrem os caminhos e a colheita chega a mesa.",
	"O inverno pede cafe quente e conversa dentro de casa.",
]
static var MISSOES := _montar_missoes()
const MISSOES_BASE := {
	"boas_vindas": {"nome": "CONHECA SEUS VIZINHOS", "dono": "lia", "texto": "\"Uma vila so e vila quando todo mundo se conhece.\" A Lia quer que voce se apresente a Tomas, Dona Rosa, Caio, Estela e Bento.", "tipo": "conversas", "alvos": ["mercador", "curandeira", "bardo", "mistica", "bento"], "brasas": 10},
	"passeio": {"nome": "PORTAS ABERTAS", "dono": "lia", "texto": "\"Cada porta daqui guarda uma ajuda.\" A Lia pede que voce entre na venda, na enfermaria, na pousada e na casa da mistica.", "tipo": "visitas", "alvos": ["venda", "enfermaria", "pousada", "mistica"], "brasas": 10},
	"horta": {"nome": "DA HORTA PARA A MESA", "dono": "bento", "texto": "\"Terra boa a gente conhece pelo que ela da.\" O Bento quer provar 3 colheitas da estacao da sua horta. No inverno, qualquer colheita serve.", "tipo": "colheita", "quantidade": 3, "brasas": 15},
	"remedios": {"nome": "UM CUIDADO PARA A VILA", "dono": "curandeira", "texto": "\"Remedio bom comeca no canteiro, querido.\" A Dona Rosa precisa de 2 colheitas para encher as prateleiras da enfermaria.", "tipo": "colheita", "quantidade": 2, "brasas": 15},
	"cancao": {"nome": "UMA HISTORIA PARA CANTAR", "dono": "bardo", "texto": "\"Me falta o refrao, e o refrao e voce!\" O Caio quer uma cancao nova: depois de aceitar, venca 3 ondas na arena e volte para contar.", "tipo": "ondas", "quantidade": 3, "brasas": 20},
	"caminhos": {"nome": "CAMINHOS DA FLORESTA", "dono": "mistica", "texto": "\"As estrelas apontam para algo grande na arena.\" A Estela pede que voce derrote o primeiro chefe e volte para conversar.", "tipo": "chefe", "quantidade": 10, "brasas": 25},
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
	"mistica": ["mistica", 0], "bento": ["casa_bento", 0]}
const FOLGAS := {"mercador": 6, "curandeira": 2, "bardo": 0, "mistica": 4, "lia": 5, "bento": 3}
## [abre, fecha] do serviço de cada um
## A loja só fica aberta enquanto o dono está nela (a rotina de trabalho cobre esse horário)
const HORARIOS := {"nilo":[8,17],"mercador": [8, 17], "curandeira": [8, 18], "mistica": [8, 18], "lia": [6, 19], "bento": [6, 19]}

## Taverna noturna; o intervalo atravessa a meia-noite. A porta abre todos os dias.
const HORARIO_TAVERNA := [18, 2]

## Caio (bardo) não senta: na festa ele continua atendendo as mesas do balcão (o banco de frente para o Bento fica
## livre para o jogador)
const LUGARES_FESTA := {
	"mercador": Vector2(184, 185), "curandeira": Vector2(184, 239),
	"lia": Vector2(264, 185), "mistica": Vector2(264, 239),
	"bento": Vector2(400, 185),
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
}
const SAIDAS_FESTA := {"curandeira": 0.5, "bento": 0.7, "mercador": 0.9, "lia": 1.0, "mistica": 1.15, "bardo": 1.3}

## Cartas sem remetente que o pombo-correio traz (agenda_vila.gd): no domingo de manhã e, sem pedidos a entregar, em
## qualquer manhã. Vêm na ordem, uma vez cada; "brasas" > 0 é um presentinho dentro do envelope. Sem acentos (fonte).
const CARTAS_MISTERIOSAS := [
	{"id": "misterio_1", "texto": "Eu sei o que voce plantou no verao passado.", "brasas": 0},
	{"id": "misterio_2", "texto": "As estrelas da Estela mentem as tercas. Nas outras noites elas so exageram um pouco.", "brasas": 0},
	{"id": "misterio_3", "texto": "Nao confie no pombo. Ele diz que nao le as cartas, mas sempre chega sabendo do que se trata.", "brasas": 3},
	{"id": "misterio_4", "texto": "Alguem nesta vila nunca dorme de verdade. Repare em quem acorda primeiro.", "brasas": 0},
	{"id": "misterio_5", "texto": "Deixei um agrado dentro deste envelope. Nao conte ao Tomas, ele ia querer cobrar imposto.", "brasas": 5},
	{"id": "misterio_6", "texto": "A arena nao comecou com voce e nao vai terminar com voce. Mas desde que voce chegou ficou bem mais divertida.", "brasas": 0},
	{"id": "misterio_7", "texto": "O Caio esta compondo uma cancao sobre um heroi misterioso. Eu acho que e sobre mim. Ele acha que e sobre voce.", "brasas": 0},
	{"id": "misterio_8", "texto": "Esta e a ultima carta. Ou nao. Ate breve.", "brasas": 10},
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

static func agenda(id: String, hora: float, estacao: int, clima: int = -1, dia_semana: int = -1) -> Dictionary:
	if id == "nilo":
		return preload("res://codigo/pesca/rotina_nilo.gd").agenda(hora,clima)
	var dados: Dictionary = MORADORES[id]
	if festa_sabado(hora, dia_semana):
		if hora < 18.0 and hora >= float(SAIDAS_FESTA[id]):
			var leito_festa := cama(id)
			return {"local": leito_festa["local"], "ponto": leito_festa["base"] + Vector2(0, 12), "atividade": "Indo dormir depois da festa", "dormindo": true,
				"cama": leito_festa["base"], "altura_cama": leito_festa["altura"]}
		if id == "bardo":
			return {"local": "pousada", "ponto": InteriorCasa.ponto("pousada", "balcao"), "atividade": "Servindo os pedidos da festa", "festa": true}
		return {"local": "pousada", "ponto": LUGARES_FESTA[id], "atividade": "Festejando com os vizinhos na taverna", "festa": true}
	if id == "bardo" and taverna_aberta(hora, dia_semana):
		return {"local": "pousada", "ponto": InteriorCasa.ponto("pousada", "balcao"), "atividade": "Atendendo no balcao da taverna"}
	# Dormindo (o temporal não acorda ninguém)
	if hora >= HORA_DORMIR or hora < 6.0:
		var leito := cama(id)
		if not leito.is_empty():
			return {"local": leito["local"], "ponto": leito["base"] + Vector2(0, 12), "atividade": "Dormindo", "dormindo": true,
				"cama": leito["base"], "altura_cama": leito["altura"]}
	# Temporal tem prioridade sobre trabalho, encontros e o abrigo coletivo do inverno.
	if clima == EstadosClima.Estado.TEMPESTADE:
		return {"local": dados["casa"], "ponto": InteriorCasa.ponto(dados["casa"], "passeio"), "atividade": "Esperando o temporal passar em casa"}
	var praia := visita_praia(id, hora, estacao, clima, dia_semana)
	if not praia.is_empty():
		return praia
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
	var pontos := [Vector2(236, 220), Vector2(196, 232), Vector2(288, 240), Vector2(424, 224), Vector2(448, 190), Vector2(224, 260)]
	var deslocamento := Vector2(12, 8) if int(hora) % 4 >= 2 else Vector2.ZERO
	return {"local": "praia", "ponto": pontos[indice % pontos.size()] + deslocamento,
		"atividade": "Passeando na praia no dia de folga" if folga else "Olhando o mar depois do trabalho"}

## Encomendas sazonais do pombo, entregues aos moradores (Nilo só refina varas).
static func _montar_missoes() -> Dictionary:
	var peixes := preload("res://codigo/pesca/peixes.gd")
	var resultado := MISSOES_BASE.duplicate(true)
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
			resultado["carta_pesca_%d_%d" % [estacao,i]] = {"nome":"PESCA DE "+estacoes[estacao],"dono":moradores[i],"tipo":"peixe",
				"peixe":peixe,"estacao":estacao,"quantidade":quantidade,"brasas":peixes.brasas(peixe)*quantidade*3,
				"texto":"Pedido: %d peixes da especie %s.\nOnde: %s.\nEstacao: %s." % [quantidade,peixes.nome(peixe),"mar" if peixes.catalogo()[peixe]["ambiente"]=="mar" else "lago",estacoes[estacao]]}
	return resultado

static func missao_na_estacao(id: String, estacao: int) -> bool:
	return not MISSOES[id].has("estacao") or int(MISSOES[id]["estacao"]) == estacao
