extends Node

signal onda_iniciada(onda: int)
signal onda_completada(onda: int)
signal jogo_ganho()
signal sinal_ondas_paradas
signal inimigos_alterados(vivos: int, total: int)
## Evento da onda que começou (ou {} quando terminou): o HUD mostra o indicador
signal evento_alterado(evento: Dictionary)

@export var onda_inicial: int = 1
## Balanceamento (tabela: testes/tabela_balanceamento.gd). Depois da morte roguelite o jogador volta ao kit inicial,
## então as primeiras ondas são menores e crescem mais devagar; o ouro dá para a bigorna: espada nv 2 na onda 4 (200)
## e nv 3 na onda 8 (500)
@export var max_inimigos: int = 4
@export var intervalo_onda: float = 15.0
@export var max_ondas: int = 1000
@export var aumento_deteccao_por_onda: float = 0.2
@export var inimigos_extra_por_onda: int = 2
@export var recompensa_ouro_base: int = 25
@export var recompensa_ouro_por_onda: int = 13
@export var moedas_por_inimigo_base: int = 3
## A cada N ondas o ouro por abate sobe 1 moeda
@export var ondas_por_moeda_extra: float = 4.0
## Crescimento da vida e do dano dos inimigos por onda: suave nas ONDAS_INICIAIS primeiras (kit inicial) e mais firme depois
@export var ondas_iniciais: int = 5
@export var vida_por_onda_inicial: float = 0.08
@export var dano_por_onda_inicial: float = 0.04
@export var vida_por_onda: float = 0.18
@export var dano_por_onda: float = 0.10
@onready var comerciante = $"../../Merchant"
## A cada N ondas vem o chefe (10, 20, 30...); 0 desliga
@export var intervalo_chefe: int = 10
## Sem escolta por padrão: as ondas de chefe também ficam com uma única espécie.
@export var escolta_chefe: int = 0
const CENA_CHEFE := preload("res://cenas/inimigos/golem.tscn")
## altura_coroa = altura do alto da cabeça em coordenadas locais (a coroa dourada fica ali)
## Rodízio de chefes: onda 10 minotauro, 20 rei slime, 30 caranguejo, 40 cogumelo, 50 dragão.
## Sem "escala" é o golem, que tem o comportamento próprio; os demais usam Inimigo-base.tornar_chefe
## (a vida e o dano ainda sobem pelos multiplicadores por onda, então cada ciclo é mais difícil).
## mult_vida dimensionado para uma luta de uns 30 a 60 s com o equipamento esperado na onda (ver a tabela)
const CHEFES: Array[Dictionary] = [
	{"id": "minotauro", "nome": "MINOTAURO", "cena": preload("res://cenas/inimigos/minotauro.tscn"), "mult_vida": 2.0},
	{"id": "rei_slime", "nome": "REI SLIME", "cena": preload("res://cenas/inimigos/slime.tscn"),
		"escala": 2.8, "mult_vida": 16.0, "mult_dano": 1.4, "habilidade": "rei_slime", "altura_coroa": 11.5},
	{"id": "caranguejo", "nome": "CARANGUEJO COLOSSAL", "cena": preload("res://cenas/inimigos/caranguejo.tscn"),
		"escala": 2.4, "mult_vida": 11.0, "mult_dano": 1.5, "habilidade": "caranguejo", "altura_coroa": 12.5},
	{"id": "cogumelo", "nome": "COGUMELO ANCIAO", "cena": preload("res://cenas/inimigos/cogumelo.tscn"),
		"escala": 2.4, "mult_vida": 12.5, "mult_dano": 1.4, "habilidade": "cogumelo", "altura_coroa": 10.0},
	{"id": "dragao_vermelho", "nome": "DRAGAO VERMELHO", "cena": preload("res://cenas/inimigos/dragao_vermelho.tscn"), "mult_vida": 2.3},
]
## Eventos de onda: sorteados a partir da onda 4, nunca na onda do chefe nem no estágio bônus.
## Chaves de efeito (1.0 = sem mudança): velocidade, dano, vida, qtde (inimigos), mutante (chance), ouro.
## "tom" escurece/tinge a tela (NEBLINA). "nao_no_inverno" tira o evento do sorteio no inverno (TEMPESTADE: chuva forte
## e raios em volta; o clima.gd escurece a tela e o raio.gd cuida do dano)
const EVENTOS: Array[Dictionary] = [
	{"id": "lua_sangue", "nome": "LUA DE SANGUE", "resumo": "INIMIGOS FEROZES", "cor": Color(1.0, 0.4, 0.38),
		"velocidade": 1.25, "dano": 1.25, "ouro": 1.5},
	{"id": "chuva_ouro", "nome": "CHUVA DE OURO", "resumo": "OURO X2", "cor": Color(1.0, 0.85, 0.3),
		"ouro": 2.0},
	{"id": "horda", "nome": "HORDA", "resumo": "MAIS INIMIGOS", "cor": Color(1.0, 0.65, 0.3),
		"qtde": 1.6, "vida": 0.65},
	{"id": "elite", "nome": "ELITE", "resumo": "MAIS MUTANTES", "cor": Color(0.75, 0.7, 1.0),
		"mutante": 3.0, "ouro": 1.25},
	{"id": "neblina", "nome": "NEBLINA", "resumo": "VISAO REDUZIDA", "cor": Color(0.7, 0.82, 0.95),
		"ouro": 1.3, "tom": Color(0.52, 0.58, 0.7)},
	{"id": "tempestade", "nome": "TEMPESTADE", "resumo": "RAIOS NO CAMPO", "cor": Color(0.55, 0.72, 1.0),
		"ouro": 1.4, "nao_no_inverno": true},
]
## Índice da estação em que o evento "nao_no_inverno" não sorteia (a estação vem do Calendario)
const ESTACAO_INVERNO: int = 3
const ONDA_MINIMA_EVENTO: int = 4
const CHANCE_EVENTO: float = 0.25
const DURACAO_TOM_EVENTO: float = 1.5
## Estágio bônus: só mímicos, fora da sequência de ondas (não avança o número da onda) e com bem mais ouro
const CENA_MIMICO := preload("res://cenas/inimigos/mimico.tscn")
@export var chance_onda_bonus: float = 0.15
@export var onda_minima_bonus: int = 3
@export var mimicos_bonus_base: int = 8
@export var mult_ouro_abate_bonus: int = 5
@export var mult_ouro_final_bonus: int = 3
## Chance de a onda (a partir da ONDA_MINIMA_EVENTO, fora chefe e bônus) trazer um evento
@export var chance_evento: float = CHANCE_EVENTO
const MAX_MIMICOS_BONUS: int = 20
const MAX_INIMIGOS_POR_ONDA: int = 60
const MAX_INIMIGOS_ATIVOS: int = 25

var onda_atual: int = 1
var inimigos_vivos: int = 0
var total_inimigos_onda: int = 0
var gerador
var ondas_paradas: bool = false

var multiplicador_vida_inimigo: float = 1.0
var multiplicador_dano_inimigo: float = 1.0

var onda_em_andamento: bool = false
## Fração de ouro do "saque" que ainda não completou 1 moeda inteira
var _resto_saque: float = 0.0
## Vale para a onda em andamento (ou a que acabou de terminar, até a próxima começar)
var onda_bonus: bool = false
var _bonus_na_onda_anterior: bool = false
## Evento da onda em andamento ({} = nenhum); vale até a onda terminar
var evento_atual: Dictionary = {}
var _id_evento_anterior: String = ""
var _rng := RandomNumberGenerator.new()
var _avanco_debug_em_andamento := false

@onready var jogador = get_node("/root/cenario/Jogador")
func _ready() -> void:
	add_to_group("gerenciador_ondas")
	_rng.randomize()
	# Voltando da fazenda (Transicao): a partida em andamento continua. Lido antes do await, que atravessa
	# alguns quadros da troca de cena
	var voltando: bool = Transicao.retornando and Transicao.estado.has("onda_atual")
	await get_tree().create_timer(0.0).timeout
	onda_atual = onda_inicial
	gerador = get_tree().get_root().get_node("/root/cenario/enemySpawner")
	if voltando:
		# Mesma onda de antes e nada de reiniciar a partida, o ouro nem o checkpoint (ficam no Progresso e no DadosJogo)
		onda_atual = int(Transicao.estado["onda_atual"])
		if not Progresso.partida_ativa:
			Progresso.iniciar_partida()
		get_tree().call_group("hud", "atualizar_rotulo_onda", onda_atual)
		return
	# Uma partida nova começa junto com a cena de jogo (a morte inicia outra, ver Jogador.reiniciar_para_nova_partida)
	Progresso.iniciar_partida()
	if DadosJogo.moedas == 0:
		DadosJogo.moedas = Progresso.ouro_inicial()
		DadosJogo.atualizar_ui_moedas()

func iniciar_onda(ignorar_checkpoint: bool = false) -> void:
	ondas_paradas = false
	if jogador.estaMorto:
		onda_atual = 1
		jogador.estaMorto = false
	if ondas_paradas:
		return
	# Checkpoint da Mística: vale só até a primeira onda da partida começar
	if not ignorar_checkpoint and not Progresso.onda_comecou and Progresso.onda_inicial > 1:
		onda_atual = Progresso.onda_inicial
	if onda_atual > max_ondas:
		emit_signal("jogo_ganho")
		return
	comerciante.visible = false
	onda_em_andamento = true
	var chefe := eh_onda_chefe(onda_atual)
	onda_bonus = _sortear_onda_bonus(chefe)
	_bonus_na_onda_anterior = onda_bonus
	_definir_evento(sortear_evento(onda_atual, chefe, onda_bonus, _id_evento_anterior, _rng, chance_evento,
			Calendario.estacao()))
	if onda_bonus:
		inimigos_vivos = mini(mimicos_bonus_base + onda_atual / 2, MAX_MIMICOS_BONUS)
	elif chefe:
		inimigos_vivos = 1 + escolta_chefe
	else:
		inimigos_vivos = quantidade_inimigos_onda(onda_atual)
	total_inimigos_onda = inimigos_vivos
	multiplicador_vida_inimigo = mult_vida_onda(onda_atual)
	multiplicador_dano_inimigo = mult_dano_onda(onda_atual)
	Progresso.registrar_onda_iniciada(onda_atual)
	emit_signal("onda_iniciada", onda_atual)
	# Na onda do chefe quem soa é a entrada dele (ver Inimigo-base._iniciar_chefe)
	if not chefe:
		Sons.tocar("onda_inicio", 0.0)
	atualizar_ui()
	if onda_bonus:
		gerador.spawnar_inimigos(inimigos_vivos, multiplicador_vida_inimigo, multiplicador_dano_inimigo, CENA_MIMICO)
	elif chefe:
		var dados_chefe := chefe_da_onda(onda_atual)
		var config: Dictionary = {}
		if dados_chefe.has("escala"):
			config = {"nome": dados_chefe["nome"], "escala": dados_chefe["escala"], "mult_vida": dados_chefe["mult_vida"],
				"mult_dano": dados_chefe.get("mult_dano", 1.0), "habilidade": dados_chefe.get("habilidade", ""),
				"altura_coroa": dados_chefe.get("altura_coroa", -1.0)}
		# O golem não passa por tornar_chefe: o mult_vida dele entra junto com o multiplicador da onda
		var mult_vida_chefe := multiplicador_vida_inimigo if dados_chefe.has("escala") else multiplicador_vida_inimigo * float(dados_chefe.get("mult_vida", 1.0))
		gerador.spawnar_inimigos(1, mult_vida_chefe, multiplicador_dano_inimigo, dados_chefe["cena"], config)
		if escolta_chefe > 0:
			gerador.spawnar_inimigos(escolta_chefe, multiplicador_vida_inimigo, multiplicador_dano_inimigo)
	else:
		gerador.spawnar_inimigos(inimigos_vivos, multiplicador_vida_inimigo, multiplicador_dano_inimigo)

## Multiplicadores de vida/dano dos inimigos na onda (a onda 1 é 1.0); o spawner aplica sobre os valores das cenas
func mult_vida_onda(onda: int) -> float:
	return 1.0 + _crescimento(onda, vida_por_onda_inicial, vida_por_onda)

func mult_dano_onda(onda: int) -> float:
	return 1.0 + _crescimento(onda, dano_por_onda_inicial, dano_por_onda)

# Soma dos passos entre a onda 1 e a atual: os (ondas_iniciais - 1) primeiros valem `inicial`, os demais `normal`
func _crescimento(onda: int, inicial: float, normal: float) -> float:
	var passos := maxi(onda - 1, 0)
	var passos_iniciais := mini(passos, maxi(ondas_iniciais - 1, 0))
	return inicial * passos_iniciais + normal * (passos - passos_iniciais)

## Ouro de cada abate (antes de evento e do "saque") e o prêmio por terminar a onda (antes do evento)
func ouro_por_abate(onda: int) -> int:
	return moedas_por_inimigo_base + int(onda / ondas_por_moeda_extra)

func ouro_fim_onda(onda: int) -> int:
	return recompensa_ouro_base + recompensa_ouro_por_onda * onda

## Inimigos de uma onda comum; o evento HORDA aumenta a quantidade (sempre dentro do limite)
func quantidade_inimigos_onda(onda: int) -> int:
	var base: int = mini(max_inimigos + inimigos_extra_por_onda * (onda - 1), MAX_INIMIGOS_POR_ONDA)
	return mini(roundi(base * mult_evento("qtde")), MAX_INIMIGOS_POR_ONDA)

## Chefe da onda no rodízio (10, 20, 30, 40, 50...). Dicionário de CHEFES
func chefe_da_onda(onda: int) -> Dictionary:
	var posicao := (maxi(onda / maxi(intervalo_chefe, 1), 1) - 1) % CHEFES.size()
	return CHEFES[posicao]

## Sorteio puro (sem estado do gerenciador, para poder ser testado): devolve um item de EVENTOS ou {}.
## Nunca antes de ONDA_MINIMA_EVENTO, nunca em onda de chefe ou bônus, nunca o mesmo evento da onda anterior
## e, no inverno (estacao 3), nunca os eventos "nao_no_inverno" (a TEMPESTADE)
static func sortear_evento(onda: int, eh_chefe: bool, eh_bonus: bool, id_anterior: String, rng: RandomNumberGenerator, chance: float = CHANCE_EVENTO, estacao: int = 0) -> Dictionary:
	if eh_chefe or eh_bonus or onda < ONDA_MINIMA_EVENTO:
		return {}
	# Chance 100% não depende do sorteio (randf pode devolver exatamente 1.0)
	if chance < 1.0 and rng.randf() >= chance:
		return {}
	var candidatos: Array[Dictionary] = []
	for evento in EVENTOS:
		if evento["id"] == id_anterior:
			continue
		if estacao == ESTACAO_INVERNO and evento.get("nao_no_inverno", false):
			continue
		candidatos.append(evento)
	return candidatos[rng.randi() % candidatos.size()]

## Modificador do evento atual para a chave (1.0 quando não há evento ou a chave não se aplica)
func mult_evento(chave: String) -> float:
	return float(evento_atual.get(chave, 1.0))

func _definir_evento(evento: Dictionary) -> void:
	evento_atual = evento
	_id_evento_anterior = String(evento.get("id", ""))
	_aplicar_tom_evento(evento.get("tom", Color.WHITE))
	evento_alterado.emit(evento_atual)

# O fim da onda (ou parar_ondas) devolve a tela ao normal; o ciclo do dia e a estação seguem por baixo
func _encerrar_evento() -> void:
	if evento_atual.is_empty():
		return
	evento_atual = {}
	_aplicar_tom_evento(Color.WHITE)
	evento_alterado.emit(evento_atual)

func _aplicar_tom_evento(tom: Color) -> void:
	if is_inside_tree():
		get_tree().call_group("iluminacao", "definir_tom_evento", tom, DURACAO_TOM_EVENTO)

# Nunca na onda do chefe nem duas vezes seguidas
func _sortear_onda_bonus(chefe: bool) -> bool:
	if chefe or _bonus_na_onda_anterior or onda_atual < onda_minima_bonus:
		return false
	return randf() < chance_onda_bonus

func eh_onda_chefe(onda: int) -> bool:
	return intervalo_chefe > 0 and onda % intervalo_chefe == 0

func atualizar_ui() -> void:
	inimigos_alterados.emit(inimigos_vivos, total_inimigos_onda)

func inimigo_morreu() -> void:
	var moedas := ouro_por_abate(onda_atual)
	DadosJogo.adicionar_moedas(_aplicar_saque(float(moedas * mult_ouro_abate_bonus if onda_bonus else moedas) * mult_evento("ouro")))
	Progresso.registrar_abate()
	_descontar_inimigo()

# Melhoria "saque": +10% de ouro por nível. A parte fracionária acumula para as moedas inteiras não se perderem no arredondamento
func _aplicar_saque(moedas: float) -> int:
	var total := moedas * (1.0 + Progresso.bonus("saque")) + _resto_saque
	var inteiro := int(total)
	_resto_saque = total - inteiro
	return inteiro

# Spawn que falhou: encerra a onda sem dar moedas de abate
func descontar_inimigo_nao_spawnado() -> void:
	_descontar_inimigo()

func _descontar_inimigo() -> void:
	inimigos_vivos -= 1
	atualizar_ui()
	if inimigos_vivos <= 0:
		var recompensa = ouro_fim_onda(onda_atual)
		DadosJogo.adicionar_moedas(roundi(float(recompensa * mult_ouro_final_bonus if onda_bonus else recompensa) * mult_evento("ouro")))
		comerciante.visible = true
		get_tree().call_group("tela_mercante", "atualizar_exibicao_moedas")
		onda_em_andamento = false
		Progresso.registrar_onda_concluida(onda_atual, eh_onda_chefe(onda_atual) and not onda_bonus, onda_bonus)
		emit_signal("onda_completada", onda_atual)
		Sons.tocar("onda_fim", 0.0)
		# Saquinhos de semente que ficaram no chão voam até o jogador
		get_tree().call_group("semente_drop", "atrair")
		# Equipamento no chão também (mochila cheia: é vendido na hora)
		get_tree().call_group("equipamento_drop", "atrair")
		_encerrar_evento()
		# O bônus é um estágio extra: a próxima onda é a mesma que ficou esperando
		if not onda_bonus:
			onda_atual += 1

## Mística: muda a onda em que a partida começa (antes da primeira onda)
func definir_onda_inicial(onda: int) -> void:
	if onda_em_andamento:
		return
	onda_atual = onda
	get_tree().call_group("hud", "atualizar_rotulo_onda", onda)

## F3: troca de onda sem premiar os inimigos descartados nem concluir a onda pulada.
func avancar_onda_debug(quantidade: int = 1) -> void:
	if not OS.is_debug_build() or _avanco_debug_em_andamento or get_tree().paused or jogador.estaMorto or quantidade <= 0:
		return
	_avanco_debug_em_andamento = true
	var destino := mini(onda_atual + quantidade, max_ondas)
	parar_ondas()
	# Deixa sair da árvore os inimigos antigos, inclusive chefes e seus ataques pendentes.
	await get_tree().process_frame
	if not jogador.estaMorto:
		onda_atual = destino
		iniciar_onda(true)
	_avanco_debug_em_andamento = false

func parar_ondas() -> void:
	ondas_paradas = true
	if is_instance_valid(gerador) and gerador.has_method("cancelar_spawns"):
		gerador.cancelar_spawns()
	emit_signal("sinal_ondas_paradas")
	comerciante.visible = true
	var lista_inimigos = get_tree().get_nodes_in_group("enemy")
	for inimigo in lista_inimigos:
		inimigo.queue_free()
	onda_atual = 1
	inimigos_vivos = 0
	onda_em_andamento = false
	onda_bonus = false
	_bonus_na_onda_anterior = false
	_id_evento_anterior = ""
	_encerrar_evento()
