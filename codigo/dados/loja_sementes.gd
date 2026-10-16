extends RefCounted

const Plantas := preload("res://codigo/dados/plantas.gd")
const PRECOS := {"comum": 2, "incomum": 3, "raro": 4, "epico": 6, "lendario": 8}

static func preco(planta: String) -> int:
	return int(PRECOS.get(Plantas.PLANTAS.get(planta, {}).get("raridade", "comum"), 2))

## Valida estação e capacidade antes de cobrar; a semente pertence ao comprador, as Brasas à partida.
static func comprar(planta: String, inventario: Node, progresso: Node, estacao: int) -> String:
	if not planta in Plantas.plantas_da_estacao(estacao):
		return "SEMENTE FORA DA ESTACAO"
	var custo := preco(planta)
	if progresso.brasas < custo:
		return "BRASAS INSUFICIENTES"
	if not inventario.adicionar_sementes(planta, 1):
		return "MOCHILA CHEIA"
	progresso.brasas -= custo
	inventario.salvar()
	progresso.salvar()
	progresso.brasas_alteradas.emit(progresso.brasas)
	return ""
