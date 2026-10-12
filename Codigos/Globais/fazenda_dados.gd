extends Node

## Estado e regras do plantio (autoload "Fazenda"). Não desenha nada: quem mostra o solo e as plantas é o
## Codigos/Logicas/plantio.gd (na cena da fazenda); este autoload vale em qualquer cena, então dormir na casa (ou o
## PASSAR DIA do painel de debug) também faz as plantas crescerem.
##
## - Solo: só dentro da AREA_PLANTIO (em tiles de 16 px do terreno da fazenda). Enxada: terra -> arado (no inverno o
##   chão está congelado). Regador: arado -> molhado. Semente: só no arado, só na estação da planta.
## - Dia: ao dormir (Calendario.dia_passou) a planta regada avança 1 dia, as regas zeram e o clima do dia seguinte é
##   sorteado pela tabela da estação (Clima.SORTEIO_POR_ESTACAO); se chover, o solo arado amanhece todo molhado.
## - Troca de estação (Calendario.estacao_mudou, que vem antes de dia_passou): a planta fora da estação murcha
##   (resto seco, removido com a enxada).
## - Sementes não se compram: caem dos inimigos da arena (Codigos/Logicas/semente_drop.gd chama dar_sementes).
## - Colheita vai para a bolsa de colheita (contador por planta, não usa a mochila de equipamentos) e o caldeirão a
##   transforma em poções (receitas em Codigos/DadosLocais/pocoes.gd); as poções são bebidas na arena pelo cinto do HUD.
## - Nada daqui se perde ao morrer na arena (o reset roguelite só leva ouro e equipamento): a fazenda é progressão.
## - Salva em user://fazenda.json (solo, plantas, sementes, colheita, poções e clima do dia); o "novo jogo" apaga.
## Estações: 0 primavera, 1 verão, 2 outono, 3 inverno (mesmos índices do Calendario).

signal solo_alterado(celula: Vector2i)
## O solo mudou de uma vez (dormir, carregar, apagar, debug): quem desenha refaz tudo
signal solo_recarregado
## Sementes, colheita ou poções mudaram (drop, plantio, colheita, caldeirão, poção bebida)
signal bolsas_alteradas
signal ferramenta_alterada(ferramenta: String)
signal clima_do_dia_mudou(estado: int)

const ClimaScript := preload("res://Codigos/Design/clima.gd")
const Pocoes := preload("res://Codigos/DadosLocais/pocoes.gd")

const CAMINHO_SAVE := "user://fazenda.json"
## Lado do tile do terreno (px)
const LADO := 16
## Área de plantio em tiles (x, y, largura, altura): a terra de cenas/terreno_fazenda.tscn
## (PLANTIO em ferramentas/fazenda/gerar_fazenda.py; um teste confere que as duas coincidem)
const AREA_PLANTIO := Rect2i(17, 22, 15, 9)

const FERRAMENTAS_FIXAS: Array[String] = ["enxada", "regador", "mao"]
const PREFIXO_SEMENTE := "semente:"
## Ação de fazenda_jogador.gd (animação) de cada ferramenta
const ACAO_DA_FERRAMENTA := {"enxada": "enxada", "regador": "regar", "mao": "colher"}

## Motivos de recusa (texto do aviso na tela; a fonte do jogo não tem acentos)
const MSG_FORA := "FORA DA AREA DE PLANTIO"
const MSG_CONGELADO := "O SOLO ESTA CONGELADO"
const MSG_JA_ARADO := "JA ESTA ARADO"
const MSG_TEM_PLANTA := "TEM UMA PLANTA AQUI"
const MSG_ARAR_ANTES := "ARE O SOLO ANTES"
const MSG_JA_MOLHADO := "JA ESTA MOLHADO"
const MSG_SEM_SEMENTE := "SEM SEMENTES"
const MSG_FORA_ESTACAO := "NAO E A ESTACAO DESTA SEMENTE"
const MSG_NADA_COLHER := "NADA PARA COLHER"
const MSG_MURCHA := "MURCHOU: USE A ENXADA"
const MSG_NAO_PRONTA := "AINDA NAO ESTA PRONTA"
const MSG_FALTA_INGREDIENTE := "FALTAM INGREDIENTES"
const MSG_SEM_TEMPO := "NAO DA TEMPO ATE O FIM DA ESTACAO"

const TIRAS := "res://Tiles/Farm RPG/Crops/"
const FOLHA_ICONES := "res://Tiles/Farm RPG/Crops/All Crops.png"

## Plantas: estação, dias regados até a colheita (um item por colheita), raridade da semente (a chance de cair dos
## inimigos, em semente_drop.gd: as plantas das melhores poções são as mais raras), a tira do
## Farm RPG (quadros de 16x16, ou 16x32 se "alta"), os quadros da tira em ordem de crescimento (a semente na terra
## até a planta madura) e as células do "All Crops.png" (coluna, linha) do saco de semente e do item colhido.
## Uma estação tem 7 dias: quem demora mais de 7 - (dia da estação em que foi plantada) dias murcha antes de amadurecer.
const PLANTAS := {
	"cenoura": {"nome": "CENOURA", "estacao": 0, "dias": 3, "raridade": "comum",
		"tira": "Spring/Carrot.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(0, 6), "item": Vector2i(2, 6)},
	"batata": {"nome": "BATATA", "estacao": 0, "dias": 4, "raridade": "comum",
		"tira": "Spring/Potato.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(0, 4), "item": Vector2i(2, 4)},
	"couve_flor": {"nome": "COUVE-FLOR", "estacao": 0, "dias": 5, "raridade": "incomum",
		"tira": "Spring/Cauliflower.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(0, 10), "item": Vector2i(2, 10)},
	"morango": {"nome": "MORANGO", "estacao": 0, "dias": 6, "raridade": "incomum",
		"tira": "Spring/Strawberry.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(0, 2), "item": Vector2i(2, 2)},
	"girassol": {"nome": "GIRASSOL", "estacao": 1, "dias": 3, "raridade": "comum",
		"tira": "Summer/Sunflower.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": true, "saco": Vector2i(9, 5), "item": Vector2i(11, 5)},
	"tomate": {"nome": "TOMATE", "estacao": 1, "dias": 4, "raridade": "raro",
		"tira": "Summer/Tomato.png", "quadros": [0, 1, 2, 3, 4, 6], "alta": false, "saco": Vector2i(9, 4), "item": Vector2i(11, 4)},
	"milho": {"nome": "MILHO", "estacao": 1, "dias": 5, "raridade": "incomum",
		"tira": "Fall/Corn.png", "quadros": [0, 1, 2, 3, 4, 5, 7], "alta": true, "saco": Vector2i(18, 4), "item": Vector2i(20, 4)},
	"melancia": {"nome": "MELANCIA", "estacao": 1, "dias": 6, "raridade": "epico",
		"tira": "Summer/Watermelon.png", "quadros": [0, 1, 2, 3, 4, 5, 7], "alta": false, "saco": Vector2i(9, 11), "item": Vector2i(11, 11)},
	"beterraba": {"nome": "BETERRABA", "estacao": 2, "dias": 3, "raridade": "comum",
		"tira": "Fall/Beetroot.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(18, 1), "item": Vector2i(20, 1)},
	"berinjela": {"nome": "BERINJELA", "estacao": 2, "dias": 4, "raridade": "epico",
		"tira": "Fall/Eggplant.png", "quadros": [0, 1, 2, 3, 4, 5], "alta": false, "saco": Vector2i(18, 5), "item": Vector2i(20, 5)},
	"abobora": {"nome": "ABOBORA", "estacao": 2, "dias": 5, "raridade": "incomum",
		"tira": "Fall/Pumpkin.png", "quadros": [0, 2, 3, 4, 5], "alta": false, "saco": Vector2i(18, 2), "item": Vector2i(20, 2)},
	"uva": {"nome": "UVA", "estacao": 2, "dias": 6, "raridade": "raro",
		"tira": "Fall/Grapes.png", "quadros": [0, 2, 3, 4, 5], "alta": true, "saco": Vector2i(18, 3), "item": Vector2i(20, 3)},
}
## Raridade da semente (chance de cair dos inimigos em Codigos/Logicas/semente_drop.gd): cor e nome, como nos MMORPGs
const COR_RARIDADE := {"comum": Color(0.92, 0.92, 0.88), "incomum": Color(0.45, 1, 0.4), "raro": Color(0.4, 0.68, 1),
	"epico": Color(0.82, 0.45, 1)}
const NOME_RARIDADE := {"comum": "COMUM", "incomum": "INCOMUM", "raro": "RARA", "epico": "EPICA"}
## Ordem de exibição (barra de ferramentas e listas)
const ORDEM_PLANTAS: Array[String] = ["cenoura", "batata", "couve_flor", "morango", "girassol", "tomate", "milho",
	"melancia", "beterraba", "berinjela", "abobora", "uva"]
const SEMENTES_GRATIS_DEBUG := 5

## Células com solo arado: Vector2i -> {"molhado": bool, "planta": String, "dias": int, "murcha": bool}
var solo: Dictionary = {}
## id da planta -> quantidade
var sementes: Dictionary = {}
var colheita: Dictionary = {}
## id da poção (Pocoes.POCOES) -> quantidade
var pocoes: Dictionary = {}
## Estado de clima.gd do dia (-1 = ainda não sorteado: vale o padrão da estação)
var clima_hoje: int = -1
var ferramenta: String = "enxada"
var caminho_save: String = CAMINHO_SAVE
var rng := RandomNumberGenerator.new()

var _salvamento_agendado := false

func _ready() -> void:
	rng.randomize()
	carregar()
	Calendario.estacao_mudou.connect(_ao_estacao_mudou)
	Calendario.dia_passou.connect(_ao_dia_passou)

# --- Consultas ---------------------------------------------------------------------------------------------

static func dentro_da_area(celula: Vector2i) -> bool:
	return AREA_PLANTIO.has_point(celula)

## Tile do terreno que contém um ponto em coordenadas do terreno
static func celula_do_ponto(ponto: Vector2) -> Vector2i:
	return Vector2i(floori(ponto.x / LADO), floori(ponto.y / LADO))

static func dados_da_planta(id: String) -> Dictionary:
	return PLANTAS.get(id, {})

## Ids das plantas de uma estação, na ordem de exibição
static func plantas_da_estacao(estacao: int) -> Array[String]:
	var lista: Array[String] = []
	for id in ORDEM_PLANTAS:
		if int(PLANTAS[id]["estacao"]) == estacao:
			lista.append(id)
	return lista

func esta_arado(celula: Vector2i) -> bool:
	return solo.has(celula)

func esta_molhado(celula: Vector2i) -> bool:
	return solo.has(celula) and bool(solo[celula]["molhado"])

func planta_em(celula: Vector2i) -> String:
	return String(solo[celula]["planta"]) if solo.has(celula) else ""

func esta_murcha(celula: Vector2i) -> bool:
	return solo.has(celula) and bool(solo[celula]["murcha"])

func dias_crescidos(celula: Vector2i) -> int:
	return int(solo[celula]["dias"]) if solo.has(celula) else 0

func esta_madura(celula: Vector2i) -> bool:
	var id := planta_em(celula)
	if id == "" or esta_murcha(celula):
		return false
	return dias_crescidos(celula) >= int(PLANTAS[id]["dias"])

## Quadro da tira a desenhar: 0 = semente na terra, o último = madura (os dias se repartem pelos quadros)
func quadro_da_planta(id: String, dias: int) -> int:
	var quadros: Array = PLANTAS[id]["quadros"]
	var total: int = PLANTAS[id]["dias"]
	if dias >= total:
		return int(quadros[quadros.size() - 1])
	return int(quadros[floori(float(dias) / float(total) * (quadros.size() - 1))])

func quantidade_sementes(id: String) -> int:
	return int(sementes.get(id, 0))

func quantidade_colhida(id: String) -> int:
	return int(colheita.get(id, 0))

func quantidade_pocoes(id: String) -> int:
	return int(pocoes.get(id, 0))

## Poções que o jogador tem, na ordem do cinto
func pocoes_que_tem() -> Array[String]:
	var lista: Array[String] = []
	for id in Pocoes.ORDEM:
		if quantidade_pocoes(id) > 0:
			lista.append(id)
	return lista

func total_de_itens_colhidos() -> int:
	var total := 0
	for id in colheita:
		total += int(colheita[id])
	return total

func celulas_com_planta() -> Array[Vector2i]:
	var lista: Array[Vector2i] = []
	for celula in solo:
		if String(solo[celula]["planta"]) != "":
			lista.append(celula)
	return lista

# --- Ações no solo -------------------------------------------------------------------------------------------

## Por que a ação não pode ser feita agora ("" = pode). acao: "enxada", "regar", "plantar" ou "colher";
## semente: id da planta (só "plantar")
func avaliar(acao: String, celula: Vector2i, semente := "") -> String:
	if not dentro_da_area(celula):
		return MSG_FORA
	match acao:
		"enxada":
			if solo.has(celula):
				if planta_em(celula) == "":
					return MSG_JA_ARADO
				return "" if esta_murcha(celula) else MSG_TEM_PLANTA
			return MSG_CONGELADO if Calendario.estacao() == 3 else ""
		"regar":
			if not solo.has(celula):
				return MSG_ARAR_ANTES
			return MSG_JA_MOLHADO if esta_molhado(celula) else ""
		"plantar":
			if not solo.has(celula):
				return MSG_ARAR_ANTES
			if planta_em(celula) != "":
				return MSG_TEM_PLANTA
			if semente == "" or quantidade_sementes(semente) <= 0:
				return MSG_SEM_SEMENTE
			if int(PLANTAS[semente]["estacao"]) != Calendario.estacao():
				return MSG_FORA_ESTACAO
			return ""
		"colher":
			if planta_em(celula) == "":
				return MSG_NADA_COLHER
			if esta_murcha(celula):
				return MSG_MURCHA
			return "" if esta_madura(celula) else MSG_NAO_PRONTA
	return "ACAO DESCONHECIDA"

## Faz a ação se ela for possível. Devolve "" se fez, ou o motivo da recusa
func aplicar(acao: String, celula: Vector2i, semente := "") -> String:
	var motivo := avaliar(acao, celula, semente)
	if motivo != "":
		return motivo
	match acao:
		"enxada":
			if solo.has(celula):
				solo[celula]["planta"] = ""   # tira o resto seco
				solo[celula]["dias"] = 0
				solo[celula]["murcha"] = false
			else:
				solo[celula] = {"molhado": false, "planta": "", "dias": 0, "murcha": false}
		"regar":
			solo[celula]["molhado"] = true
		"plantar":
			solo[celula]["planta"] = semente
			solo[celula]["dias"] = 0
			solo[celula]["murcha"] = false
			sementes[semente] = quantidade_sementes(semente) - 1
			if sementes[semente] <= 0:
				sementes.erase(semente)
			_ao_bolsa_alterada()
		"colher":
			var id := planta_em(celula)
			colheita[id] = quantidade_colhida(id) + 1
			solo[celula]["planta"] = ""
			solo[celula]["dias"] = 0
			_ao_bolsa_alterada()
	solo_alterado.emit(celula)
	_agendar_salvamento()
	return ""

## A planta cabe na estação? (aviso ao plantar: nasce, mas murcha antes de amadurecer). Dias que ainda restam
## na estação são as noites até a troca: a da noite do último dia já murcha a planta
func da_tempo_de_crescer(id: String) -> bool:
	return int(PLANTAS[id]["dias"]) <= Calendario.DIAS_POR_ESTACAO - Calendario.dia_na_estacao()

# --- Passagem do dia ---------------------------------------------------------------------------------------

## Planta fora da estação murcha (chamado antes de dia_passou pelo Calendario)
func _ao_estacao_mudou(estacao: int) -> void:
	_validar_ferramenta()   # as sementes da estação anterior saem da barra
	var mudou := false
	for celula in solo:
		var dados: Dictionary = solo[celula]
		if String(dados["planta"]) != "" and not dados["murcha"] and int(PLANTAS[dados["planta"]]["estacao"]) != estacao:
			dados["murcha"] = true
			mudou = true
	if mudou:
		solo_recarregado.emit()
		_agendar_salvamento()

func _ao_dia_passou(_dia: int) -> void:
	avancar_dia()

## Fim do dia: a planta regada cresce, as regas zeram e o clima do dia seguinte é sorteado (chuva molha tudo).
## `clima_amanha` força o clima (-1 sorteia pela estação atual do Calendario)
func avancar_dia(clima_amanha := -1) -> void:
	for celula in solo:
		var dados: Dictionary = solo[celula]
		if String(dados["planta"]) != "" and not dados["murcha"] and dados["molhado"]:
			dados["dias"] = mini(int(dados["dias"]) + 1, int(PLANTAS[dados["planta"]]["dias"]))
		dados["molhado"] = false
	clima_hoje = clima_amanha if clima_amanha >= 0 else ClimaScript.sortear_clima(Calendario.estacao(), rng)
	if ClimaScript.eh_chuva(clima_hoje):
		for celula in solo:
			solo[celula]["molhado"] = true
	salvar()
	solo_recarregado.emit()
	clima_do_dia_mudou.emit(clima_hoje)

## O clima do mundo mudou durante o dia (sorteio de uma onda, tempestade na arena; ver clima.gd): guarda e, se começou
## a chover, molha todo o solo arado — a chuva rega as plantas mesmo com o jogador longe da fazenda
func definir_clima_hoje(estado: int) -> void:
	if estado == clima_hoje:
		return
	clima_hoje = estado
	if ClimaScript.eh_chuva(estado):
		for celula in solo:
			solo[celula]["molhado"] = true
		solo_recarregado.emit()
	_agendar_salvamento()
	clima_do_dia_mudou.emit(estado)

# --- Sementes, caldeirão e poções --------------------------------------------------------------------------

## Sementes que caíram de um inimigo (ou de graça, no debug)
func dar_sementes(id: String, quantidade := 1) -> void:
	if not PLANTAS.has(id) or quantidade <= 0:
		return
	sementes[id] = quantidade_sementes(id) + quantidade
	_ao_bolsa_alterada()
	_agendar_salvamento()

## Por que a poção não pode ser feita agora ("" = pode)
func motivo_para_nao_fazer(id: String) -> String:
	if not Pocoes.POCOES.has(id):
		return "POCAO INVALIDA"
	var receita: Dictionary = Pocoes.POCOES[id]["receita"]
	for planta in receita:
		if quantidade_colhida(planta) < int(receita[planta]):
			return MSG_FALTA_INGREDIENTE
	return ""

## Gasta os ingredientes da bolsa de colheita e soma 1 poção. "" = fez
func fazer_pocao(id: String) -> String:
	var motivo := motivo_para_nao_fazer(id)
	if motivo != "":
		return motivo
	var receita: Dictionary = Pocoes.POCOES[id]["receita"]
	for planta in receita:
		colheita[planta] = quantidade_colhida(planta) - int(receita[planta])
		if colheita[planta] <= 0:
			colheita.erase(planta)
	pocoes[id] = quantidade_pocoes(id) + 1
	_ao_bolsa_alterada()
	_agendar_salvamento()
	return ""

## Tira 1 poção do estoque (bebida na arena). false = não tinha
func gastar_pocao(id: String) -> bool:
	if quantidade_pocoes(id) <= 0:
		return false
	pocoes[id] = quantidade_pocoes(id) - 1
	if pocoes[id] <= 0:
		pocoes.erase(id)
	_ao_bolsa_alterada()
	_agendar_salvamento()
	return true

func _ao_bolsa_alterada() -> void:
	_validar_ferramenta()
	bolsas_alteradas.emit()

# --- Ferramenta ativa --------------------------------------------------------------------------------------

## Enxada, regador, mão e uma entrada por semente da estação que o jogador tem (a barra do HUD)
func ferramentas() -> Array[String]:
	var lista: Array[String] = FERRAMENTAS_FIXAS.duplicate()
	for id in plantas_da_estacao(Calendario.estacao()):
		if quantidade_sementes(id) > 0:
			lista.append(PREFIXO_SEMENTE + id)
	return lista

func definir_ferramenta(nova: String) -> void:
	if nova == ferramenta or not ferramentas().has(nova):
		return
	ferramenta = nova
	ferramenta_alterada.emit(ferramenta)

## Passa para a ferramenta seguinte (+1) ou anterior (-1), dando a volta
func trocar_ferramenta(passo: int) -> void:
	var lista := ferramentas()
	var indice := lista.find(ferramenta)
	if indice < 0:
		indice = 0
	definir_ferramenta(lista[posmod(indice + passo, lista.size())])

## Id da semente se a ferramenta ativa for uma semente, senão ""
func semente_da_ferramenta() -> String:
	return ferramenta.trim_prefix(PREFIXO_SEMENTE) if ferramenta.begins_with(PREFIXO_SEMENTE) else ""

## Ação de fazenda_jogador.gd da ferramenta ativa
func acao_da_ferramenta() -> String:
	if semente_da_ferramenta() != "":
		return "plantar"
	return String(ACAO_DA_FERRAMENTA.get(ferramenta, "enxada"))

# A semente que acabou (ou a estação que virou) tira a ferramenta da lista: cai no regador, o passo seguinte
# natural depois de plantar
func _validar_ferramenta() -> void:
	if ferramentas().has(ferramenta):
		return
	ferramenta = "regador"
	ferramenta_alterada.emit(ferramenta)

# --- Depuração (painel F3) ---------------------------------------------------------------------------------

## Sementes de graça de toda a estação atual
func dar_sementes_debug(quantidade := SEMENTES_GRATIS_DEBUG) -> void:
	for id in plantas_da_estacao(Calendario.estacao()):
		sementes[id] = quantidade_sementes(id) + quantidade
	_ao_bolsa_alterada()
	_agendar_salvamento()

## Colheita de graça de todas as plantas (para testar o caldeirão em qualquer estação)
func dar_colheita_debug(quantidade := SEMENTES_GRATIS_DEBUG) -> void:
	for id in ORDEM_PLANTAS:
		colheita[id] = quantidade_colhida(id) + quantidade
	_ao_bolsa_alterada()
	_agendar_salvamento()

## Poções de graça de todos os tipos (para testar o cinto na arena)
func dar_pocoes_debug(quantidade := 3) -> void:
	for id in Pocoes.ORDEM:
		pocoes[id] = quantidade_pocoes(id) + quantidade
	_ao_bolsa_alterada()
	_agendar_salvamento()

## Faz as plantas vivas crescerem 1 dia sem regar
func crescer_um_dia_debug() -> void:
	for celula in solo:
		var dados: Dictionary = solo[celula]
		if String(dados["planta"]) != "" and not dados["murcha"]:
			dados["dias"] = mini(int(dados["dias"]) + 1, int(PLANTAS[dados["planta"]]["dias"]))
	solo_recarregado.emit()
	_agendar_salvamento()

func regar_tudo_debug() -> void:
	for celula in solo:
		solo[celula]["molhado"] = true
	solo_recarregado.emit()
	_agendar_salvamento()

# --- Salvar / carregar -------------------------------------------------------------------------------------

# Várias mudanças no mesmo quadro viram uma gravação só
func _agendar_salvamento() -> void:
	if _salvamento_agendado:
		return
	_salvamento_agendado = true
	_salvar_agendado.call_deferred()

func _salvar_agendado() -> void:
	_salvamento_agendado = false
	salvar()

func salvar() -> bool:
	var tabela := {}
	for celula in solo:
		var dados: Dictionary = solo[celula]
		tabela["%d,%d" % [celula.x, celula.y]] = {"molhado": dados["molhado"], "planta": dados["planta"],
				"dias": dados["dias"], "murcha": dados["murcha"]}
	var arquivo := FileAccess.open(caminho_save, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify({"versao": 2, "solo": tabela, "sementes": sementes, "colheita": colheita,
			"pocoes": pocoes, "clima_hoje": clima_hoje}, "\t"))
	return true

## Lê o arquivo (ausente ou inválido = fazenda vazia). Células, plantas e contagens inválidas são descartadas
func carregar() -> bool:
	_zerar()
	if not FileAccess.file_exists(caminho_save):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(caminho_save)) != OK or not json.data is Dictionary:
		return false   # arquivo corrompido: fazenda vazia (o parse com JSON.new nao imprime erro)
	var dados: Dictionary = json.data
	var tabela = dados.get("solo", {})
	if tabela is Dictionary:
		for chave in tabela:
			var partes := String(chave).split(",")
			if partes.size() != 2 or not partes[0].is_valid_int() or not partes[1].is_valid_int() or not tabela[chave] is Dictionary:
				continue
			var celula := Vector2i(int(partes[0]), int(partes[1]))
			if not dentro_da_area(celula):
				continue
			var item: Dictionary = tabela[chave]
			var planta := String(item.get("planta", ""))
			if planta != "" and not PLANTAS.has(planta):
				planta = ""
			solo[celula] = {"molhado": bool(item.get("molhado", false)), "planta": planta,
					"dias": clampi(int(item.get("dias", 0)), 0, int(PLANTAS[planta]["dias"]) if planta != "" else 0),
					"murcha": planta != "" and bool(item.get("murcha", false))}
	sementes = _ler_contagens(dados.get("sementes", {}), PLANTAS)
	colheita = _ler_contagens(dados.get("colheita", {}), PLANTAS)
	pocoes = _ler_contagens(dados.get("pocoes", {}), Pocoes.POCOES)
	clima_hoje = clampi(int(dados.get("clima_hoje", -1)), -1, ClimaScript.Estado.NEVE_FORTE)
	return true

## Contagens {id: n} do arquivo: só ids de `validos` e quantidades positivas
static func _ler_contagens(bruto, validos: Dictionary) -> Dictionary:
	var saida := {}
	if bruto is Dictionary:
		for id in bruto:
			if validos.has(id) and int(bruto[id]) > 0:
				saida[String(id)] = int(bruto[id])
	return saida

func _zerar() -> void:
	solo = {}
	sementes = {}
	colheita = {}
	pocoes = {}
	clima_hoje = -1
	ferramenta = "enxada"

## Novo jogo: apaga o arquivo e esvazia a fazenda (sem sinais: quem está na tela de título não reage)
func apagar() -> void:
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_save))
	_zerar()
