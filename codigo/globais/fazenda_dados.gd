extends Node

## Estado e regras do plantio (autoload "Fazenda"). Não desenha nada: quem mostra o solo e as plantas é o
## codigo/logica/plantio.gd (na cena da fazenda); este autoload vale em qualquer cena, então dormir na casa (ou o
## PASSAR DIA do painel de debug) também faz as plantas crescerem.
##
## - Solo: só dentro da AREA_PLANTIO (em tiles de 16 px do terreno da fazenda). Enxada: terra -> arado (no inverno o
##   chão está congelado). Regador: arado -> molhado. Semente: só no arado, só na estação da planta.
## - Dia: ao dormir (Calendario.dia_passou) a planta regada avança 1 dia, as regas zeram e o clima do dia seguinte é
##   sorteado pela tabela da estação (Clima.SORTEIO_POR_ESTACAO); se chover, o solo arado amanhece todo molhado.
## - Troca de estação (Calendario.estacao_mudou, que vem antes de dia_passou): a planta fora da estação murcha
##   (resto seco, removido com a enxada).
## - Ferramentas (enxada, regador, mão) e sementes são itens da mochila (InventarioJogador), a mesma da arena: a barra de baixo é a
##   primeira linha dela. As sementes empilham (uma casa por planta) e não se compram: caem dos inimigos da arena
##   (codigo/logica/semente_drop.gd chama dar_sementes). A ferramenta ativa é escolhida na barra (teclas 1 a 5, toque) ou com Q/E.
## - Colheita vai para a bolsa de colheita (contador por planta, não usa a mochila de equipamentos) e o caldeirão a
##   transforma em poções (receitas em codigo/dados/pocoes.gd); as poções são bebidas na arena pelo cinto do HUD.
## - Nada daqui se perde ao morrer na arena (o reset roguelite só leva ouro e equipamento): a fazenda é progressão. As sementes
##   da mochila também ficam (InventarioJogador.guardar_para_nova_partida).
## - Salva em user://fazenda.json (solo, plantas, colheita, poções e clima do dia); o "novo jogo" apaga. Saves antigos
##   guardavam as sementes aqui: migrar_sementes_antigas() as passa para a mochila.
## Estações: 0 primavera, 1 verão, 2 outono, 3 inverno (mesmos índices do Calendario).

signal solo_alterado(celula: Vector2i)
## O solo mudou de uma vez (dormir, carregar, apagar, debug): quem desenha refaz tudo
signal solo_recarregado
## Sementes, colheita ou poções mudaram (drop, plantio, colheita, caldeirão, poção bebida)
signal bolsas_alteradas
signal ferramenta_alterada(ferramenta: String)
signal clima_do_dia_mudou(estado: int)
## Entulho apareceu ou saiu de uma célula da área de plantio (Vector2i(-1, -1) = vários de uma vez)
signal entulho_alterado(celula: Vector2i)
## Ação aplicada com sucesso: permite acompanhar lições sem contar tentativas inválidas.
signal acao_realizada(acao: String, celula: Vector2i)
## O regador gastou ou encheu (agua_regador)
signal agua_regador_alterada(quantidade: int)

const ClimaScript := preload("res://codigo/cenario/clima.gd")
const Pocoes := preload("res://codigo/dados/pocoes.gd")
const Plantas := preload("res://codigo/dados/plantas.gd")

const CAMINHO_SAVE := "user://fazenda.json"
## Lado do tile do terreno (px)
const LADO := 16
## Área de plantio em tiles (x, y, largura, altura): a terra de cenas/terreno_fazenda.tscn
## (PLANTIO em ferramentas/fazenda/gerar_fazenda.py; um teste confere que as duas coincidem)
const AREA_PLANTIO := Rect2i(6, 21, 32, 16)

const FERRAMENTAS_FIXAS: Array[String] = ["enxada", "regador"]
const PREFIXO_SEMENTE := Plantas.PREFIXO_SEMENTE
## Ação de fazenda_jogador.gd (animação) de cada ferramenta
const ACAO_DA_FERRAMENTA := {"enxada": "enxada", "regador": "regar", "machadinha": "machado", "picareta": "picareta"}
## Dias até o que foi cortado ou quebrado no mapa voltar (codigo/logica/extracao_fazenda.gd)
const RECRESCER := {"arvore": 5, "arbusto": 3, "pedra": 3}

## Motivos de recusa (texto do aviso na tela; a fonte do jogo não tem acentos)
const MSG_FORA := "FORA DA AREA DE PLANTIO"
const MSG_CONGELADO := "O SOLO ESTA CONGELADO"
const MSG_JA_ARADO := "JA ESTA ARADO"
const MSG_TEM_PLANTA := "TEM UMA PLANTA AQUI"
const MSG_ARAR_ANTES := "ARE O SOLO ANTES"
const MSG_JA_MOLHADO := "JA ESTA MOLHADO"
const MSG_REGADOR_VAZIO := "REGADOR VAZIO: ENCHA NO LAGO"
const MSG_REGADOR_CHEIO := "O REGADOR JA ESTA CHEIO"
## Regas por regador cheio; enche no laguinho da fazenda (lago_fazenda.gd), como no Harvest Moon
const REGADOR_CAPACIDADE := 20
const MSG_SEM_SEMENTE := "SEM SEMENTES"
const MSG_FORA_ESTACAO := "NAO E A ESTACAO DESTA SEMENTE"
const MSG_NADA_COLHER := "NADA PARA COLHER"
const MSG_MURCHA := "MURCHOU: USE A ENXADA"
const MSG_NAO_PRONTA := "AINDA NAO ESTA PRONTA"
const MSG_FALTA_INGREDIENTE := "FALTAM INGREDIENTES"
const MSG_SEM_TEMPO := "NAO DA TEMPO ATE O FIM DA ESTACAO"
const MSG_ENTULHO := {"pedra": "PEDRA NO CAMINHO: USE A PICARETA", "arbusto": "ARBUSTO NO CAMINHO: USE A MACHADINHA",
	"arvoreta": "ARVORE NO CAMINHO: USE A MACHADINHA", "mato": "MATO: ARRANQUE COM A ENXADA"}
## Entulho da área de plantio (como no Stardew): mato, pedras, arbustos e arvoretas nascem nos canteiros livres e
## atrapalham o plantio. A primeira visita espalha ENTULHO_INICIAL; cada noite nascem mais ENTULHO_POR_NOITE, até o teto.
## A enxada arranca o mato; a picareta quebra a pedra; a machadinha corta o arbusto e a arvoreta (extracao_fazenda.gd)
const ENTULHO_INICIAL := 60
const ENTULHO_POR_NOITE := 4
const ENTULHO_MAXIMO := 90
const PESOS_ENTULHO := {"mato": 35, "pedra": 30, "arbusto": 20, "arvoreta": 15}

## Dados das plantas: ficam em codigo/dados/plantas.gd (os nomes antigos continuam valendo aqui)
const TIRAS := Plantas.TIRAS
const FOLHA_ICONES := Plantas.FOLHA_ICONES
const PLANTAS := Plantas.PLANTAS
const COR_RARIDADE := Plantas.COR_RARIDADE
const NOME_RARIDADE := Plantas.NOME_RARIDADE
const ORDEM_PLANTAS := Plantas.ORDEM_PLANTAS
const SEMENTES_GRATIS_DEBUG := 5

## Células com solo arado: Vector2i -> {"molhado": bool, "planta": String, "dias": int, "murcha": bool}
var solo: Dictionary = {}
## Sementes de saves antigos (antes de virarem itens da mochila), à espera de migrar_sementes_antigas()
var _sementes_antigas: Dictionary = {}
## id da planta -> quantidade
var colheita: Dictionary = {}
## Peixes pescados e ainda não vendidos ao Nilo {id: quantidade}, e quantos já foram pescados no total (catálogo do Nilo)
var peixes: Dictionary = {}
var peixes_pescados: Dictionary = {}
var varas_pesca: Dictionary = {}
var pedras_vara: Dictionary = {}
var pesca_capturas_jogador: Dictionary = {}
var pesca_ultima_pedra: Dictionary = {}
var pesca_perfeitas := 0
var pesca_recompensas: Dictionary = {}
var pesca_pedidos_entregues: Dictionary = {}
## id da poção (Pocoes.POCOES) -> quantidade
var pocoes: Dictionary = {}
## Entulho na área de plantio: Vector2i -> "mato", "pedra", "arbusto" ou "arvoreta"
var entulho: Dictionary = {}
## Se a primeira leva de entulho já foi espalhada (fazenda nova começa cheia de mato e pedra)
var entulho_iniciado := false
## Árvores e pedras derrubadas no mapa: chave do recurso -> {"dia": dia em que caiu, "tipo": "arvore"/"arbusto"/"pedra",
## "toco": a árvore caiu mas o toco ainda está lá}
var removidos: Dictionary = {}
## Estado de clima.gd do dia (-1 = ainda não sorteado: vale o padrão da estação)
var clima_hoje: int = -1
var ferramenta: String = "enxada"
## Cooperativo: o jogador 2 escolhe a própria ferramenta, da mochila dele (InventarioJogador2)
var ferramenta_p2: String = "enxada"
var agua_regador: int = REGADOR_CAPACIDADE
var caminho_save: String = CAMINHO_SAVE
var rng := RandomNumberGenerator.new()

var _salvamento_agendado := false

func _ready() -> void:
	rng.randomize()
	carregar()
	# Sementes e ferramentas moram na mochila: qualquer mudança nela pode tirar a ferramenta ativa da lista
	InventarioJogador.mochila_alterada.connect(_ao_bolsa_alterada)
	InventarioJogador.item_alterado.connect(func(_item) -> void: _ao_bolsa_alterada())
	InventarioJogador2.mochila_alterada.connect(_ao_bolsa_alterada)
	InventarioJogador2.item_alterado.connect(func(_item) -> void: _ao_bolsa_alterada())
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
	return Plantas.plantas_da_estacao(estacao)

## Texto do tempo de crescimento: "3 DIAS"
static func texto_crescimento(id: String) -> String:
	return Plantas.texto_crescimento(id)

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

func quantidade_sementes(id: String, lado := 1) -> int:
	return mochila_do_lado(lado).quantidade_sementes(id)

func mochila_do_lado(lado: int) -> Node:
	return InventarioJogador2 if lado == 2 else InventarioJogador

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
func avaliar(acao: String, celula: Vector2i, semente := "", lado := 1) -> String:
	if not dentro_da_area(celula):
		return MSG_FORA
	if entulho.has(celula):
		return "" if acao == "enxada" and entulho[celula] == "mato" else String(MSG_ENTULHO[entulho[celula]])
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
			if esta_molhado(celula):
				return MSG_JA_MOLHADO
			return MSG_REGADOR_VAZIO if agua_regador <= 0 else ""
		"plantar":
			if not solo.has(celula):
				return MSG_ARAR_ANTES
			if planta_em(celula) != "":
				return MSG_TEM_PLANTA
			if semente == "" or quantidade_sementes(semente, lado) <= 0:
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
func aplicar(acao: String, celula: Vector2i, semente := "", lado := 1) -> String:
	var motivo := avaliar(acao, celula, semente, lado)
	if motivo != "":
		return motivo
	match acao:
		"enxada":
			# Mato: o golpe só arranca (o canteiro fica livre para arar no próximo)
			if entulho.get(celula, "") == "mato":
				remover_entulho(celula)
				return ""
			if solo.has(celula):
				solo[celula]["planta"] = ""   # tira o resto seco
				solo[celula]["dias"] = 0
				solo[celula]["murcha"] = false
			else:
				solo[celula] = {"molhado": false, "planta": "", "dias": 0, "murcha": false}
		"regar":
			solo[celula]["molhado"] = true
			agua_regador = maxi(agua_regador - 1, 0)
			agua_regador_alterada.emit(agua_regador)
		"plantar":
			solo[celula]["planta"] = semente
			solo[celula]["dias"] = 0
			solo[celula]["murcha"] = false
			mochila_do_lado(lado).gastar_semente(semente)
			mochila_do_lado(lado).salvar()
		"colher":
			var id := planta_em(celula)
			colheita[id] = quantidade_colhida(id) + 1
			solo[celula]["planta"] = ""
			solo[celula]["dias"] = 0
			_ao_bolsa_alterada()
	solo_alterado.emit(celula)
	acao_realizada.emit(acao, celula)
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
	if entulho_iniciado:
		espalhar_entulho(ENTULHO_POR_NOITE)
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

## Sementes que caíram de um inimigo (ou de graça, no debug): vão para a pilha da planta na mochila. false se não couberam
## (mochila cheia e ainda sem pilha daquela planta)
func dar_sementes(id: String, quantidade := 1) -> bool:
	if not PLANTAS.has(id) or quantidade <= 0:
		return false
	if not InventarioJogador.adicionar_sementes(id, quantidade):
		return false
	InventarioJogador.salvar()
	return true

## Saves de antes das sementes virarem itens: passa as que estavam guardadas na fazenda para a mochila (chamado quando o
## inventário do jogador já foi carregado). O que não couber fica guardado para a próxima vez
func migrar_sementes_antigas() -> void:
	if _sementes_antigas.is_empty():
		return
	for id in _sementes_antigas.keys():
		if InventarioJogador.adicionar_sementes(id, int(_sementes_antigas[id])):
			_sementes_antigas.erase(id)
	InventarioJogador.salvar()
	salvar()

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

# --- Refeições do Caio e venda de colheita para a Lia (ligação fazenda -> arena, 2026-10-16) -------------------

const Refeicoes := preload("res://codigo/dados/refeicoes.gd")
const Peixes := preload("res://codigo/pesca/peixes.gd")
const DesafiosPesca := preload("res://codigo/pesca/desafios_pesca.gd")
## Brasas por unidade de colheita vendida à Lia: um pouco mais que o preço da semente (loja_sementes.gd), então
## plantar sempre compensa e a horta ajuda nas melhorias permanentes mesmo de quem cai cedo na arena
const BRASAS_POR_COLHEITA := {"comum": 3, "incomum": 5, "raro": 6, "epico": 9}

func motivo_para_nao_cozinhar(id: String, quem: Node = null) -> String:
	if Refeicoes.dados(id).is_empty():
		return "PRATO INVALIDO"
	if Progresso.refeicao != "":
		return "VOCE JA COMEU: " + String(Refeicoes.dados(Progresso.refeicao)["nome"])
	var receita: Dictionary = Refeicoes.dados(id)["receita"]
	for planta in receita:
		if quantidade_colhida(planta) < int(receita[planta]):
			return MSG_FALTA_INGREDIENTE
	for peixe in Refeicoes.dados(id).get("peixes",{}):
		if quantidade_peixes(peixe,quem) < int(Refeicoes.dados(id)["peixes"][peixe]):
			return MSG_FALTA_INGREDIENTE
	return ""

## O Caio cozinha: gasta a colheita e o prato vale a próxima partida (Progresso.comer). "" = comeu
func cozinhar(id: String, quem: Node = null) -> String:
	var motivo := motivo_para_nao_cozinhar(id,quem)
	if motivo != "":
		return motivo
	var receita: Dictionary = Refeicoes.dados(id)["receita"]
	for planta in receita:
		colheita[planta] = quantidade_colhida(planta) - int(receita[planta])
		if colheita[planta] <= 0:
			colheita.erase(planta)
	for peixe in Refeicoes.dados(id).get("peixes",{}):
		gastar_peixes(peixe,int(Refeicoes.dados(id)["peixes"][peixe]),quem)
	Progresso.comer(id)
	_ao_bolsa_alterada()
	_agendar_salvamento()
	return ""

static func brasas_por_colheita(planta: String) -> int:
	return int(BRASAS_POR_COLHEITA.get(String(Plantas.PLANTAS.get(planta, {}).get("raridade", "comum")), 3))

## Vende `quantidade` (0 = tudo) da colheita `planta` para a Lia. Devolve as Brasas recebidas
func vender_colheita(planta: String, quantidade := 0) -> int:
	var tem := quantidade_colhida(planta)
	var vende := tem if quantidade <= 0 else mini(quantidade, tem)
	if vende <= 0:
		return 0
	colheita[planta] = tem - vende
	if colheita[planta] <= 0:
		colheita.erase(planta)
	var ganho := vende * brasas_por_colheita(planta)
	Progresso.brasas += ganho
	Progresso.salvar()
	Progresso.brasas_alteradas.emit(Progresso.brasas)
	_ao_bolsa_alterada()
	_agendar_salvamento()
	return ganho

func _ao_bolsa_alterada() -> void:
	_validar_ferramenta()
	bolsas_alteradas.emit()

# --- Entulho da área de plantio ----------------------------------------------------------------------------

## A primeira leva (fazenda nova ou save de antes do entulho)
func iniciar_entulho() -> void:
	if entulho_iniciado:
		return
	entulho_iniciado = true
	espalhar_entulho(ENTULHO_INICIAL)

## Espalha até `quantidade` entulhos em canteiros sem solo arado, respeitando o teto. No inverno não nasce mato
func espalhar_entulho(quantidade: int) -> void:
	var livres: Array[Vector2i] = []
	for y in range(AREA_PLANTIO.position.y, AREA_PLANTIO.end.y):
		for x in range(AREA_PLANTIO.position.x, AREA_PLANTIO.end.x):
			var celula := Vector2i(x, y)
			if not solo.has(celula) and not entulho.has(celula):
				livres.append(celula)
	var total := 0
	for peso in PESOS_ENTULHO.values():
		total += int(peso)
	var novos := 0
	while novos < quantidade and not livres.is_empty() and entulho.size() < ENTULHO_MAXIMO:
		var celula: Vector2i = livres.pop_at(rng.randi() % livres.size())
		var sorteio := rng.randi() % total
		var tipo := "mato"
		for chave in PESOS_ENTULHO:
			sorteio -= int(PESOS_ENTULHO[chave])
			if sorteio < 0:
				tipo = chave
				break
		if tipo == "mato" and Calendario.estacao() == 3:
			tipo = "pedra"
		entulho[celula] = tipo
		novos += 1
	if novos > 0:
		entulho_alterado.emit(Vector2i(-1, -1))
		_agendar_salvamento()

func remover_entulho(celula: Vector2i) -> void:
	if entulho.erase(celula):
		entulho_alterado.emit(celula)
		_agendar_salvamento()

# --- Árvores e pedras do mapa ---------------------------------------------------------------------------

## O recurso do mapa ainda está derrubado? (volta depois de RECRESCER dias)
func recurso_removido(chave: String) -> bool:
	if not removidos.has(chave):
		return false
	var item: Dictionary = removidos[chave]
	if Calendario.dia - int(item["dia"]) >= int(RECRESCER.get(item["tipo"], 3)):
		removidos.erase(chave)
		_agendar_salvamento()
		return false
	return true

func remover_recurso(chave: String, tipo: String, toco := false) -> void:
	removidos[chave] = {"dia": Calendario.dia, "tipo": tipo, "toco": toco}
	_agendar_salvamento()

## A árvore caída ainda tem o toco? (o toco sai com mais golpes de machadinha; a árvore volta inteira depois)
func tem_toco(chave: String) -> bool:
	return recurso_removido(chave) and bool(removidos[chave].get("toco", false))

func arrancar_toco(chave: String) -> void:
	if removidos.has(chave):
		removidos[chave]["toco"] = false
		_agendar_salvamento()

# --- Ferramenta ativa --------------------------------------------------------------------------------------

## Ferramentas e sementes da estação que estão na mochila, na ordem das casas ("enxada", "regador", "semente:<id>").
## Semente de outra estação fica guardada na mochila, mas não entra (não dá para plantar)
## Lado 1 = jogador 1, lado 2 = jogador 2 do cooperativo (cada um tem ferramenta e mochila próprias)
static func lado_de(jogador: Node) -> int:
	return 2 if jogador != null and bool(jogador.get("eh_p2")) else 1

func ferramenta_de(lado := 1) -> String:
	return ferramenta_p2 if lado == 2 else ferramenta

func ferramentas(lado := 1) -> Array[String]:
	var lista: Array[String] = []
	var estacao := Calendario.estacao()
	for item in mochila_do_lado(lado).itens_de_fazenda():
		if item.tipo == "mao":
			continue
		if item.categoria == "semente" and int(PLANTAS.get(item.planta(), {}).get("estacao", -1)) != estacao:
			continue
		if not lista.has(item.tipo):
			lista.append(item.tipo)
	return lista

func definir_ferramenta(nova: String, lado := 1) -> void:
	if nova == ferramenta_de(lado) or not ferramentas(lado).has(nova):
		return
	_guardar_ferramenta(nova, lado)

func _guardar_ferramenta(nova: String, lado: int) -> void:
	if lado == 2:
		ferramenta_p2 = nova
	else:
		ferramenta = nova
	ferramenta_alterada.emit(nova)

## Passa para a ferramenta seguinte (+1) ou anterior (-1), dando a volta
func trocar_ferramenta(passo: int, lado := 1) -> void:
	var lista := ferramentas(lado)
	if lista.is_empty():
		return
	var indice := lista.find(ferramenta_de(lado))
	if indice < 0:
		indice = 0
	definir_ferramenta(lista[posmod(indice + passo, lista.size())], lado)

## Id da semente se a ferramenta ativa for uma semente, senão ""
func semente_da_ferramenta(lado := 1) -> String:
	var atual := ferramenta_de(lado)
	return atual.trim_prefix(PREFIXO_SEMENTE) if atual.begins_with(PREFIXO_SEMENTE) else ""

## Ação de fazenda_jogador.gd da ferramenta ativa ("" sem nenhuma ferramenta na mochila)
func acao_da_ferramenta(lado := 1) -> String:
	if semente_da_ferramenta(lado) != "":
		return "plantar"
	return String(ACAO_DA_FERRAMENTA.get(ferramenta_de(lado), ""))

# A semente que acabou (ou a estação que virou, ou a ferramenta que saiu da mochila) tira a ferramenta da lista: cai no
# regador, o passo seguinte natural depois de plantar; sem ele, na primeira que houver. Sem ferramenta antes (mochila
# recriada), começa na primeira da barra
func _validar_ferramenta() -> void:
	for lado in [1, 2]:
		var atual := ferramenta_de(lado)
		var lista := ferramentas(lado)
		if lista.has(atual):
			continue
		var nova := ""
		if not lista.is_empty():
			nova = "regador" if atual != "" and lista.has("regador") else lista[0]
		if nova != atual:
			_guardar_ferramenta(nova, lado)

# --- Depuração (painel F3) ---------------------------------------------------------------------------------

## Sementes de graça de toda a estação atual
func dar_sementes_debug(quantidade := SEMENTES_GRATIS_DEBUG) -> void:
	for id in plantas_da_estacao(Calendario.estacao()):
		dar_sementes(id, quantidade)

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

func _tabela_entulho() -> Dictionary:
	var tabela := {}
	for celula in entulho:
		tabela["%d,%d" % [celula.x, celula.y]] = entulho[celula]
	return tabela

# --- Pesca (minigame copiado do SeasonsFarm, 2026-10-17): o peixe vai para a bolsa e pode ser vendido ao Tomas ------

func mochila_pesca(quem: Node = null) -> Node:
	return InventarioJogador2 if quem != null and EventosJogo.eh_do_p2(quem) else InventarioJogador

func quantidade_peixes(id: String, quem: Node = null) -> int:
	migrar_peixes_antigos()
	return mochila_pesca(quem).quantidade_peixes(id)

func total_de_peixes(quem: Node = null) -> int:
	migrar_peixes_antigos()
	return mochila_pesca(quem).quantidade_peixes()

func pescar(id: String, perfeita := false, quem: Node = null, qualidade := 0) -> bool:
	if not Peixes.existe(id) or not mochila_pesca(quem).adicionar_peixe(id,qualidade):
		return false
	peixes_pescados[id] = int(peixes_pescados.get(id,0))+1
	if perfeita: pesca_perfeitas += 1
	mochila_pesca(quem).salvar()
	_ao_bolsa_alterada()
	_agendar_salvamento()
	return true

func gastar_peixes(id: String, quantidade: int, quem: Node = null) -> bool:
	migrar_peixes_antigos()
	if not mochila_pesca(quem).gastar_peixes(id,quantidade): return false
	mochila_pesca(quem).salvar()
	return true

func valor_dos_peixes(id := "", quem: Node = null) -> int:
	migrar_peixes_antigos()
	var total := 0
	var qualidade := preload("res://codigo/pesca/qualidade_peixe.gd")
	for item in mochila_pesca(quem).mochila:
		if item != null and item.categoria == "peixe" and (id=="" or item.peixe()==id):
			total += item.quantidade*qualidade.valor(Peixes.brasas(item.peixe()),item.qualidade)
	return total

func vender_peixes(id := "", quem: Node = null) -> int:
	var ganho := valor_dos_peixes(id,quem)
	if ganho<=0: return 0
	var inventario := mochila_pesca(quem)
	for i in inventario.mochila.size():
		var item = inventario.mochila[i]
		if item != null and item.categoria == "peixe" and (id=="" or item.peixe()==id): inventario.mochila[i]=null
	inventario._avisar_mochila()
	inventario.salvar()
	Progresso.brasas += ganho
	Progresso.salvar()
	Progresso.brasas_alteradas.emit(Progresso.brasas)
	_ao_bolsa_alterada()
	_agendar_salvamento()
	return ganho

var _migrando_peixes := false
func migrar_peixes_antigos() -> void:
	if peixes.is_empty() or _migrando_peixes: return
	_migrando_peixes = true
	var mudou := false
	for id in peixes.keys():
		if InventarioJogador.adicionar_peixe(id,0,int(peixes[id])):
			peixes.erase(id)
			mudou = true
	if mudou:
		InventarioJogador.salvar()
		salvar()
	_migrando_peixes = false

func pedidos_pesca() -> Array[Dictionary]:
	return DesafiosPesca.pedidos_do_dia(Calendario.dia,Calendario.estacao())

func progresso_desafio_pesca(id: String) -> int:
	return DesafiosPesca.progresso(id,peixes_pescados,pesca_perfeitas,pesca_pedidos_entregues.size())

func resgatar_desafio_pesca(id: String) -> int:
	var dados := DesafiosPesca.dados(id)
	if dados.is_empty() or pesca_recompensas.has(id) or progresso_desafio_pesca(id) < int(dados["meta"]):
		return 0
	pesca_recompensas[id] = true
	return _recompensar_pesca(int(dados["brasas"]))

func entregar_pedido_pesca(id: String) -> int:
	if pesca_pedidos_entregues.has(id):
		return 0
	for pedido in pedidos_pesca():
		if pedido["id"] != id:
			continue
		var peixe: String = pedido["peixe"]
		if quantidade_peixes(peixe) < int(pedido["quantidade"]):
			return 0
		gastar_peixes(peixe,int(pedido["quantidade"]))
		pesca_pedidos_entregues[id] = true
		return _recompensar_pesca(int(pedido["brasas"]))
	return 0

func _recompensar_pesca(brasas: int) -> int:
	Progresso.brasas += brasas
	# Marca a entrega/resgate antes de permitir outra interação.
	salvar()
	Progresso.salvar()
	Progresso.brasas_alteradas.emit(Progresso.brasas)
	_ao_bolsa_alterada()
	return brasas

func salvar() -> bool:
	var tabela := {}
	for celula in solo:
		var dados: Dictionary = solo[celula]
		tabela["%d,%d" % [celula.x, celula.y]] = {"molhado": dados["molhado"], "planta": dados["planta"],
				"dias": dados["dias"], "murcha": dados["murcha"]}
	var arquivo := FileAccess.open(caminho_save, FileAccess.WRITE)
	if arquivo == null:
		return false
	# "sementes" só guarda o que ainda não migrou para a mochila (saves antigos)
	arquivo.store_string(JSON.stringify({"versao": 3, "solo": tabela, "sementes": _sementes_antigas, "colheita": colheita, "peixes": peixes, "peixes_pescados": peixes_pescados,
			"varas_pesca": varas_pesca, "pedras_vara": pedras_vara, "pesca_capturas_jogador":pesca_capturas_jogador, "pesca_ultima_pedra":pesca_ultima_pedra, "pesca_perfeitas": pesca_perfeitas, "pesca_recompensas": pesca_recompensas, "pesca_pedidos_entregues": pesca_pedidos_entregues,
			"pocoes": pocoes, "clima_hoje": clima_hoje, "removidos": removidos,
			"entulho": _tabela_entulho(), "entulho_iniciado": entulho_iniciado, "agua_regador": agua_regador}, "\t"))
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
	_sementes_antigas = _ler_contagens(dados.get("sementes", {}), PLANTAS)
	colheita = _ler_contagens(dados.get("colheita", {}), PLANTAS)
	peixes = _ler_contagens(dados.get("peixes", {}), Peixes.DADOS)
	peixes_pescados = _ler_contagens(dados.get("peixes_pescados", {}), Peixes.DADOS)
	for campo in ["varas_pesca","pedras_vara"]:
		var lido = dados.get(campo,{})
		if lido is Dictionary:
			for chave in ["p1","p2"]:
				if campo == "varas_pesca":
					varas_pesca[chave] = clampi(int(lido.get(chave,1)),1,5)
				else:
					pedras_vara[chave] = maxi(0,int(lido.get(chave,0)))
	pesca_perfeitas = maxi(0,int(dados.get("pesca_perfeitas",0)))
	for campo in ["pesca_capturas_jogador","pesca_ultima_pedra"]:
		var lido = dados.get(campo,{})
		if lido is Dictionary:
			for chave in ["p1","p2"]:
				get(campo)[chave] = maxi(-1 if campo == "pesca_ultima_pedra" else 0,int(lido.get(chave,-1 if campo == "pesca_ultima_pedra" else 0)))
	var recompensas = dados.get("pesca_recompensas",{})
	if recompensas is Dictionary:
		for id in recompensas:
			if recompensas[id] == true and not DesafiosPesca.dados(id).is_empty():
				pesca_recompensas[id] = true
	var pedidos_entregues = dados.get("pesca_pedidos_entregues",{})
	if pedidos_entregues is Dictionary:
		for id in pedidos_entregues:
			var partes := String(id).split("_")
			if pedidos_entregues[id] == true and partes.size() == 2 and partes[0].is_valid_int() and int(partes[0]) > 0 and partes[1] in ["mar","rio"]:
				pesca_pedidos_entregues[id] = true
	pocoes = _ler_contagens(dados.get("pocoes", {}), Pocoes.POCOES)
	clima_hoje = clampi(int(dados.get("clima_hoje", -1)), -1, ClimaScript.Estado.NEVE_FORTE)
	var tabela_entulho = dados.get("entulho", {})
	if tabela_entulho is Dictionary:
		for chave in tabela_entulho:
			var partes := String(chave).split(",")
			if partes.size() == 2 and partes[0].is_valid_int() and partes[1].is_valid_int() and PESOS_ENTULHO.has(String(tabela_entulho[chave])):
				var celula := Vector2i(int(partes[0]), int(partes[1]))
				if dentro_da_area(celula) and not solo.has(celula):
					entulho[celula] = String(tabela_entulho[chave])
	entulho_iniciado = bool(dados.get("entulho_iniciado", false))
	agua_regador = clampi(int(dados.get("agua_regador", REGADOR_CAPACIDADE)), 0, REGADOR_CAPACIDADE)
	var bruto = dados.get("removidos", {})
	if bruto is Dictionary:
		for chave in bruto:
			var item = bruto[chave]
			if item is Dictionary and RECRESCER.has(String(item.get("tipo", ""))):
				removidos[String(chave)] = {"dia": int(item.get("dia", 0)), "tipo": String(item["tipo"]), "toco": bool(item.get("toco", false))}
	# A vara na mochila segue o nível que acabou de ser lido
	preload("res://codigo/pesca/varas.gd").sincronizar_itens()
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
	_sementes_antigas = {}
	colheita = {}
	peixes = {}
	peixes_pescados = {}
	varas_pesca = {}
	pedras_vara = {}
	pesca_capturas_jogador = {}
	pesca_ultima_pedra = {}
	pesca_perfeitas = 0
	pesca_recompensas = {}
	pesca_pedidos_entregues = {}
	pocoes = {}
	removidos = {}
	entulho = {}
	entulho_iniciado = false
	clima_hoje = -1
	ferramenta = "enxada"
	agua_regador = REGADOR_CAPACIDADE

## Encheu no lago
func encher_regador() -> void:
	agua_regador = REGADOR_CAPACIDADE
	agua_regador_alterada.emit(agua_regador)
	_agendar_salvamento()

## Novo jogo: apaga o arquivo e esvazia a fazenda (sem sinais: quem está na tela de título não reage)
func apagar() -> void:
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_save))
	_zerar()
