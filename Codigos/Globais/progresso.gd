extends Node

## Progresso permanente entre partidas (roguelite): Brasas, melhorias, moradores do acampamento e recorde.
## As estatísticas da partida atual ficam aqui só até a morte; ao cair, encerrar_partida() converte
## o desempenho em Brasas. Salva em user://progresso.json.

signal brasas_alteradas(brasas: int)
signal melhorias_alteradas
signal morador_contratado(id: String)
signal checkpoint_alterado(onda: int)

const CAMINHO_SAVE := "user://progresso.json"
const NIVEL_MAXIMO := 5
const CUSTOS_MELHORIA := [10, 20, 35, 55, 80]
# Brasas por onda concluída, por chefe e por estágio bônus
const BRASAS_POR_ONDA := 2
const BRASAS_POR_CHEFE := 15
const BRASAS_POR_BONUS := 5
const FATOR_BARDO := 0.25
# Ouro de compensação da Mística: por onda do checkpoint escolhido
const OURO_POR_ONDA_CHECKPOINT := 30
# Fração da vida com que a Curandeira revive o jogador
const VIDA_REVIVER := 0.5
const INVULNERABILIDADE_REVIVER := 2.0

# por_nivel: fração (vigor, forca, couraca, folego, saque) ou ouro (bolsa) somado a cada nível
const ORDEM_MELHORIAS := ["vigor", "forca", "couraca", "folego", "bolsa", "saque"]
const MELHORIAS := {
	"vigor": {"nome": "VIGOR", "descricao": "+8% VIDA MAXIMA", "por_nivel": 0.08},
	"forca": {"nome": "FORCA", "descricao": "+6% DANO", "por_nivel": 0.06},
	"couraca": {"nome": "COURACA", "descricao": "+4% REDUCAO DE DANO", "por_nivel": 0.04},
	"folego": {"nome": "FOLEGO", "descricao": "+10% ESTAMINA MAXIMA", "por_nivel": 0.10},
	"bolsa": {"nome": "BOLSA", "descricao": "+40 OURO INICIAL", "por_nivel": 40.0},
	"saque": {"nome": "SAQUE", "descricao": "+10% OURO POR ABATE", "por_nivel": 0.10},
}

const ORDEM_MORADORES := ["curandeira", "bardo", "mistica"]
const MORADORES := {
	"curandeira": {"nome": "CURANDEIRA", "descricao": "REVIVE 1 VEZ POR PARTIDA", "custo": 40},
	"bardo": {"nome": "BARDO", "descricao": "+25% DE BRASAS", "custo": 25},
	"mistica": {"nome": "MISTICA", "descricao": "COMECA NO CHECKPOINT", "custo": 50},
}

# --- Dados permanentes ---
var brasas: int = 0
var recorde_onda: int = 0
var melhorias: Dictionary = {}
var moradores: Dictionary = {}
## Onda do maior chefe já derrotado (10, 20...); 0 se nenhum
var checkpoint_max: int = 0

# --- Partida atual ---
var partida_ativa: bool = false
var onda_maxima: int = 0
var ondas_concluidas: int = 0
var abates: int = 0
var ouro_ganho: int = 0
var chefes: int = 0
var bonus_concluidos: int = 0
var reviveu_na_partida: bool = false
## Onda em que a próxima partida começa (escolhida na Mística); 1 = início normal
var onda_inicial: int = 1
## Ouro de compensação já concedido pelo checkpoint escolhido
var ouro_compensacao: int = 0
## true depois que a primeira onda da partida começou: a Mística não aceita mais mudanças
var onda_comecou: bool = false
var ultimo_resultado: Dictionary = {}

var caminho_save: String = CAMINHO_SAVE
var _ondas_de_chefe_contadas: Dictionary = {}

func _ready() -> void:
	carregar()

# --- Partida ---

func iniciar_partida() -> void:
	partida_ativa = true
	onda_maxima = 0
	ondas_concluidas = 0
	abates = 0
	ouro_ganho = 0
	chefes = 0
	bonus_concluidos = 0
	reviveu_na_partida = false
	onda_inicial = 1
	ouro_compensacao = 0
	onda_comecou = false
	_ondas_de_chefe_contadas.clear()

func registrar_abate() -> void:
	if partida_ativa:
		abates += 1

func registrar_ouro(quantidade: int) -> void:
	if partida_ativa and quantidade > 0:
		ouro_ganho += quantidade

func registrar_onda_iniciada(onda: int) -> void:
	if not partida_ativa:
		return
	onda_comecou = true
	onda_maxima = maxi(onda_maxima, onda)

func registrar_onda_concluida(onda: int, chefe: bool, bonus: bool) -> void:
	if not partida_ativa:
		return
	onda_maxima = maxi(onda_maxima, onda)
	if bonus:
		bonus_concluidos += 1
	else:
		ondas_concluidas += 1
	if chefe:
		registrar_chefe(onda)

## Chamado na morte do chefe e na conclusão da onda dele; conta uma vez só por onda
func registrar_chefe(onda: int) -> void:
	if not partida_ativa or _ondas_de_chefe_contadas.has(onda):
		return
	_ondas_de_chefe_contadas[onda] = true
	chefes += 1
	if onda > checkpoint_max:
		checkpoint_max = onda
		salvar()

func calcular_brasas_base() -> int:
	return BRASAS_POR_ONDA * ondas_concluidas + BRASAS_POR_CHEFE * chefes + BRASAS_POR_BONUS * bonus_concluidos

## Fecha a partida: converte o desempenho em Brasas, atualiza o recorde e salva. Chamar duas vezes devolve o mesmo resultado
func encerrar_partida() -> Dictionary:
	if not partida_ativa:
		return ultimo_resultado
	partida_ativa = false
	var base := calcular_brasas_base()
	var total := base
	if tem_morador("bardo"):
		total = roundi(base * (1.0 + FATOR_BARDO))
	var novo_recorde := onda_maxima > recorde_onda
	if novo_recorde:
		recorde_onda = onda_maxima
	brasas += total
	ultimo_resultado = {
		"onda": onda_maxima,
		"ondas_concluidas": ondas_concluidas,
		"abates": abates,
		"ouro": ouro_ganho,
		"chefes": chefes,
		"bonus": bonus_concluidos,
		"brasas_base": base,
		"brasas_bardo": total - base,
		"brasas": total,
		"novo_recorde": novo_recorde,
		"recorde": recorde_onda,
	}
	salvar()
	brasas_alteradas.emit(brasas)
	return ultimo_resultado

# --- Melhorias ---

func nivel(id: String) -> int:
	return clampi(int(melhorias.get(id, 0)), 0, NIVEL_MAXIMO)

## Custo do próximo nível; -1 se já está no máximo ou o id não existe
func custo_proximo(id: String) -> int:
	if not MELHORIAS.has(id) or nivel(id) >= NIVEL_MAXIMO:
		return -1
	return CUSTOS_MELHORIA[nivel(id)]

func pode_comprar_melhoria(id: String) -> bool:
	var custo := custo_proximo(id)
	return custo != -1 and brasas >= custo

func comprar_melhoria(id: String) -> bool:
	if not pode_comprar_melhoria(id):
		return false
	brasas -= custo_proximo(id)
	melhorias[id] = nivel(id) + 1
	salvar()
	brasas_alteradas.emit(brasas)
	melhorias_alteradas.emit()
	return true

## Efeito total da melhoria no nível atual (fração para as porcentagens, ouro para a bolsa)
func bonus(id: String) -> float:
	if not MELHORIAS.has(id):
		return 0.0
	return float(MELHORIAS[id]["por_nivel"]) * nivel(id)

func ouro_inicial() -> int:
	return roundi(bonus("bolsa"))

# --- Moradores ---

func tem_morador(id: String) -> bool:
	return bool(moradores.get(id, false))

func contratar(id: String) -> bool:
	if not MORADORES.has(id) or tem_morador(id):
		return false
	var custo: int = MORADORES[id]["custo"]
	if brasas < custo:
		return false
	brasas -= custo
	moradores[id] = true
	salvar()
	brasas_alteradas.emit(brasas)
	morador_contratado.emit(id)
	return true

## Curandeira: gasta o reviver da partida. Retorna false se não há curandeira ou já foi usado
func usar_reviver() -> bool:
	if not partida_ativa or not tem_morador("curandeira") or reviveu_na_partida:
		return false
	reviveu_na_partida = true
	return true

# --- Checkpoint (Mística) ---

## Ondas em que dá para começar: a 1 e a seguinte a cada chefe já derrotado (11, 21...)
func checkpoints_disponiveis(intervalo_chefe: int = 10) -> Array[int]:
	var lista: Array[int] = [1]
	if intervalo_chefe <= 0:
		return lista
	var onda_chefe := intervalo_chefe
	while onda_chefe <= checkpoint_max:
		lista.append(onda_chefe + 1)
		onda_chefe += intervalo_chefe
	return lista

## Ouro de compensação de começar na onda dada (0 na onda 1)
func ouro_checkpoint(onda: int) -> int:
	return OURO_POR_ONDA_CHECKPOINT * onda if onda > 1 else 0

func pode_escolher_checkpoint() -> bool:
	return partida_ativa and tem_morador("mistica") and not onda_comecou

## Define a onda inicial da partida. Retorna a diferença de ouro a aplicar (compensação nova menos a já
## concedida); 0 se a escolha for inválida ou nada mudar. Quem chama soma o ouro e ajusta o gerenciador
func definir_checkpoint(onda: int, intervalo_chefe: int = 10) -> int:
	if not pode_escolher_checkpoint() or not checkpoints_disponiveis(intervalo_chefe).has(onda):
		return 0
	var nova_compensacao := ouro_checkpoint(onda)
	var diferenca := nova_compensacao - ouro_compensacao
	onda_inicial = onda
	ouro_compensacao = nova_compensacao
	checkpoint_alterado.emit(onda)
	return diferenca

# --- Salvar / carregar ---

func salvar() -> bool:
	var arquivo := FileAccess.open(caminho_save, FileAccess.WRITE)
	if arquivo == null:
		return false
	var dados := {
		"brasas": brasas,
		"recorde_onda": recorde_onda,
		"melhorias": melhorias,
		"moradores": moradores,
		"checkpoint_max": checkpoint_max,
	}
	arquivo.store_string(JSON.stringify(dados, "\t"))
	return true

func carregar() -> bool:
	_zerar_dados()
	if not FileAccess.file_exists(caminho_save):
		return false
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho_save))
	if not dados is Dictionary:
		return false
	brasas = maxi(int(dados.get("brasas", 0)), 0)
	recorde_onda = maxi(int(dados.get("recorde_onda", 0)), 0)
	checkpoint_max = maxi(int(dados.get("checkpoint_max", 0)), 0)
	var dados_melhorias = dados.get("melhorias", {})
	if dados_melhorias is Dictionary:
		for id in dados_melhorias:
			if MELHORIAS.has(id):
				melhorias[id] = clampi(int(dados_melhorias[id]), 0, NIVEL_MAXIMO)
	var dados_moradores = dados.get("moradores", {})
	if dados_moradores is Dictionary:
		for id in dados_moradores:
			if MORADORES.has(id):
				moradores[id] = bool(dados_moradores[id])
	brasas_alteradas.emit(brasas)
	melhorias_alteradas.emit()
	return true

## Novo jogo: apaga o arquivo e zera tudo na memória
func apagar() -> void:
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_save))
	_zerar_dados()
	partida_ativa = false
	brasas_alteradas.emit(brasas)
	melhorias_alteradas.emit()

func _zerar_dados() -> void:
	brasas = 0
	recorde_onda = 0
	checkpoint_max = 0
	melhorias = {}
	moradores = {}
