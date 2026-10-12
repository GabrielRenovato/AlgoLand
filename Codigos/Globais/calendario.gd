extends Node

## Calendário de dias do jogo (fazenda e arena juntas). Cada estação dura DIAS_POR_ESTACAO dias e só dormir na
## cama da casa passa o dia (a arena e as ondas não mexem nele). A morte na arena NÃO volta o calendário.
## Salva em user://calendario.json (arquivo próprio, separado do progresso roguelite).
## Estações: 0 primavera, 1 verão, 2 outono, 3 inverno (mesmos índices de Codigos/Design/estacoes.gd).

signal dia_passou(dia: int)
signal estacao_mudou(estacao: int)

const CAMINHO_SAVE := "user://calendario.json"
const DIAS_POR_ESTACAO := 7
const ESTACOES_POR_ANO := 4
## Texto do HUD (a fonte do jogo não tem acentos)
const NOMES: Array[String] = ["PRIMAVERA", "VERAO", "OUTONO", "INVERNO"]

## Dia corrido desde o começo do jogo (1 = primeiro dia da primavera do ano 1)
var dia: int = 1
var caminho_save: String = CAMINHO_SAVE

func _ready() -> void:
	carregar()

# --- Consultas ---------------------------------------------------------------------------------------------

## Estação (0..3) de um dia corrido; sem argumento, a do dia atual
@warning_ignore("integer_division")
func estacao(dia_consultado: int = -1) -> int:
	var d := dia if dia_consultado < 1 else dia_consultado
	return ((d - 1) / DIAS_POR_ESTACAO) % ESTACOES_POR_ANO

## Ano (1..) de um dia corrido; sem argumento, o do dia atual
@warning_ignore("integer_division")
func ano(dia_consultado: int = -1) -> int:
	var d := dia if dia_consultado < 1 else dia_consultado
	return (d - 1) / (DIAS_POR_ESTACAO * ESTACOES_POR_ANO) + 1

## Dia dentro da estação (1..DIAS_POR_ESTACAO)
func dia_na_estacao() -> int:
	return (dia - 1) % DIAS_POR_ESTACAO + 1

func nome_estacao() -> String:
	return NOMES[estacao()]

## "PRIMAVERA - DIA 3" (o HUD)
func texto_data() -> String:
	return "%s - DIA %d" % [nome_estacao(), dia_na_estacao()]

# --- Passagem do tempo -------------------------------------------------------------------------------------

## Dormir: avança um dia e salva. Se a estação virou, avisa antes de avisar o dia (quem cultiva murcha o que
## saiu de estação e depois cresce o resto)
func dormir() -> void:
	var estacao_anterior := estacao()
	dia += 1
	salvar()
	if estacao() != estacao_anterior:
		estacao_mudou.emit(estacao())
	dia_passou.emit(dia)

# --- Salvar / carregar -------------------------------------------------------------------------------------

func salvar() -> bool:
	var arquivo := FileAccess.open(caminho_save, FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify({"dia": dia}, "\t"))
	return true

func carregar() -> bool:
	dia = 1
	if not FileAccess.file_exists(caminho_save):
		return false
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho_save))
	if not dados is Dictionary:
		return false
	dia = maxi(int(dados.get("dia", 1)), 1)
	return true

## Novo jogo: apaga o arquivo e volta ao dia 1 (sem emitir sinais: quem está na tela de título não reage)
func apagar() -> void:
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_save))
	dia = 1
