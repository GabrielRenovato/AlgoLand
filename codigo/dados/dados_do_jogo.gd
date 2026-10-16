extends Node

var moedas: int = 0
## Cooperativo: a carteira do jogador 2 (cada um com o seu ouro). Recompensas da onda caem nas duas; compras e vendas
## mexem só na de quem fez (moedas_de / adicionar_de / gastar_de)
var moedas_p2: int = 0

func _ready() -> void:
	# Atualiza a UI de moedas (caso já exista)
	atualizar_ui_moedas()

## Recompensa da onda (abate, fim de onda, chefe): no cooperativo os dois jogadores recebem
func adicionar_moedas(quantidade: int) -> void:
	moedas += quantidade
	if Cooperativo.com_dois():
		moedas_p2 += quantidade
	if quantidade > 0:
		Sons.tocar("moeda", 0.05)
	Progresso.registrar_ouro(quantidade)
	atualizar_ui_moedas()

func gastar_moedas(quantidade: int) -> bool:
	# Retorna true/false se a compra foi possível
	if moedas >= quantidade:
		moedas -= quantidade
		atualizar_ui_moedas()
		return true
	return false

# Novo jogo: só o ouro inicial da melhoria "bolsa" (o progresso acabou de ser apagado, então começa em 0)
func resetar_moedas() -> void:
	moedas = Progresso.ouro_inicial()
	moedas_p2 = moedas
	atualizar_ui_moedas()

static func _eh_p2(jogador: Node) -> bool:
	return jogador != null and bool(jogador.get("eh_p2"))

func moedas_de(jogador: Node) -> int:
	return moedas_p2 if _eh_p2(jogador) else moedas

## Ouro só de um jogador (venda dele, saque dele)
func adicionar_de(jogador: Node, quantidade: int) -> void:
	if _eh_p2(jogador):
		moedas_p2 += quantidade
		if quantidade > 0:
			Sons.tocar("moeda", 0.05)
		atualizar_ui_moedas()
	else:
		moedas += quantidade
		if quantidade > 0:
			Sons.tocar("moeda", 0.05)
		Progresso.registrar_ouro(quantidade)
		atualizar_ui_moedas()

func gastar_de(jogador: Node, quantidade: int) -> bool:
	if moedas_de(jogador) < quantidade:
		return false
	if _eh_p2(jogador):
		moedas_p2 -= quantidade
	else:
		moedas -= quantidade
	atualizar_ui_moedas()
	return true

## Começo de partida: a bolsa inicial (melhoria "bolsa") para os dois
func definir_ouro_inicial() -> void:
	moedas = Progresso.ouro_inicial()
	moedas_p2 = moedas
	atualizar_ui_moedas()

func atualizar_ui_moedas() -> void:
	get_tree().call_group("hud_p1", "atualizar_moedas", moedas)
	get_tree().call_group("hud_p2", "atualizar_moedas", moedas_p2)
