extends Node

## Poções bebidas pelo jogador (filho "EfeitosPocao" do Jogador, criado no _ready dele). Guarda a poção escolhida no
## cinto, bebe (gasta do estoque da Fazenda) e conta o tempo dos efeitos. Quem aplica cada efeito é o Jogador,
## perguntando bonus(efeito):
##   "forca"      -> dano do golpe x (1 + valor)
##   "pedra"      -> redução de dano recebido + valor
##   "velocidade" -> velocidade de andar x (1 + valor)
##   "folego"     -> regeneração de estamina x (1 + valor), sem a espera depois de gastar
##   "vampiro"    -> fração do dano do golpe que volta como vida
##   "cura"       -> instantânea: o Jogador cura valor x vida máxima na hora
## Beber de novo um efeito que já está ativo renova o tempo (não soma). Morrer ou sair da arena limpa tudo.

const Pocoes := preload("res://Codigos/DadosLocais/pocoes.gd")

## Intervalo mínimo entre dois goles (evita gastar duas poções num toque duplo)
const ESPERA_ENTRE_GOLES := 0.6

const MSG_SEM_POCAO := "SEM POCOES"
const MSG_VIDA_CHEIA := "VIDA CHEIA"
const MSG_ESPERE := "ESPERE"

## O cinto trocou de poção (escolha do jogador ou a escolhida acabou)
signal selecao_alterada(id: String)
## Um efeito começou, foi renovado ou acabou
signal efeitos_alterados
## A poção foi bebida (o HUD mostra o nome)
signal pocao_bebida(id: String)

## efeito -> {"pocao": id, "restante": s, "duracao": s, "valor": float}
var ativos: Dictionary = {}
## Poção escolhida no cinto ("" = nenhuma no estoque)
var selecionada: String = ""

var _espera := 0.0

func _ready() -> void:
	Fazenda.bolsas_alteradas.connect(_validar_selecao)
	_validar_selecao()

func _process(delta: float) -> void:
	_espera = maxf(_espera - delta, 0.0)
	if ativos.is_empty():
		return
	var acabou := false
	for efeito in ativos.keys():
		ativos[efeito]["restante"] = float(ativos[efeito]["restante"]) - delta
		if float(ativos[efeito]["restante"]) <= 0.0:
			ativos.erase(efeito)
			acabou = true
	if acabou:
		efeitos_alterados.emit()

## Soma do efeito ativo (0 = nenhum)
func bonus(efeito: String) -> float:
	return float(ativos[efeito]["valor"]) if ativos.has(efeito) else 0.0

func esta_ativo(efeito: String) -> bool:
	return ativos.has(efeito)

## Segundos que faltam do efeito (0 = não ativo)
func restante(efeito: String) -> float:
	return float(ativos[efeito]["restante"]) if ativos.has(efeito) else 0.0

## Passa para a poção seguinte (+1) ou anterior (-1) entre as que o jogador tem, dando a volta
func trocar(passo: int) -> void:
	var lista := Fazenda.pocoes_que_tem()
	if lista.is_empty():
		_definir_selecao("")
		return
	var i := lista.find(selecionada)
	_definir_selecao(lista[posmod((i if i >= 0 else 0) + (passo if i >= 0 else 0), lista.size())])

## Bebe a poção escolhida no cinto. Devolve "" se bebeu, ou o motivo
func beber_selecionada() -> String:
	return beber(selecionada)

## Bebe a poção `id`: gasta 1 do estoque, aplica o efeito e avisa. Devolve "" se bebeu, ou o motivo
func beber(id: String) -> String:
	if id == "" or Fazenda.quantidade_pocoes(id) <= 0:
		return MSG_SEM_POCAO
	if _espera > 0.0:
		return MSG_ESPERE
	var dados := Pocoes.dados(id)
	var jogador := get_parent()
	var efeito := String(dados["efeito"])
	# Cura com a vida cheia gastaria a poção à toa
	if efeito == "cura" and jogador != null and "hp_atual" in jogador and jogador.hp_atual >= jogador.estatisticas.hp_maximo:
		return MSG_VIDA_CHEIA
	Fazenda.gastar_pocao(id)
	_espera = ESPERA_ENTRE_GOLES
	if float(dados["duracao"]) > 0.0:
		ativos[efeito] = {"pocao": id, "restante": float(dados["duracao"]), "duracao": float(dados["duracao"]),
				"valor": float(dados["valor"])}
		efeitos_alterados.emit()
	elif efeito == "cura" and jogador != null and jogador.has_method("curar"):
		jogador.curar(roundi(jogador.estatisticas.hp_maximo * float(dados["valor"])))
	Sons.tocar("beber", 0.05)
	pocao_bebida.emit(id)
	return ""

## Morte, troca de cena, nova partida: os efeitos acabam na hora
func limpar() -> void:
	if ativos.is_empty():
		return
	ativos.clear()
	efeitos_alterados.emit()

func _definir_selecao(id: String) -> void:
	selecionada = id
	selecao_alterada.emit(id)

# A escolhida acabou (ou ainda não há escolha): passa para a primeira que ainda tem
func _validar_selecao() -> void:
	if selecionada != "" and Fazenda.quantidade_pocoes(selecionada) > 0:
		return   # só a quantidade mudou: o cinto se redesenha pelo próprio Fazenda.bolsas_alteradas
	var lista := Fazenda.pocoes_que_tem()
	_definir_selecao(lista[0] if not lista.is_empty() else "")
