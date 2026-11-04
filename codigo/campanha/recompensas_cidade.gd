extends RefCounted
## Prêmios das missões secundárias da vila. A economia da campanha usa só ouro por enquanto:
## sem Brasas e sem moeda de forja, só ouro, materiais, poções e receitas.
const Forja := preload("res://codigo/dados/forja_armas.gd")
const PREMIOS := {
	"pesca_primeiras_fisgadas": {"ouro": 30},
	"pesca_carpas_da_vila": {"ouro": 50},
	"ferro_que_ainda_serve": {"ouro": 40, "materiais": {"ferro": 3, "madeira": 2}, "receita": "luvas_basicas"},
	"quem_ficou_para_tras": {"ouro": 25, "materiais": {"fibra": 4}, "pocoes": {"cura": 2}},
	"antes_de_sair_outra_vez": {"ouro": 60},
	"moinho_vazao": {"ouro": 100, "materiais": {"ferro": 3, "madeira": 3}, "pocoes": {"cura": 1}},
	"defesa_da_vila": {"ouro": 80, "materiais": {"ferro": 2, "madeira": 4}},
}

static func tem(missao: String) -> bool:
	return PREMIOS.has(missao)

## Linha curta para o aviso de missão concluída.
static func texto(missao: String) -> String:
	var premio: Dictionary = PREMIOS.get(missao, {})
	var partes: Array[String] = []
	if premio.has("ouro"):
		partes.append("%d de ouro" % premio.ouro)
	for id in premio.get("materiais", {}):
		partes.append("%d %s" % [premio.materiais[id], str(Forja.MATERIAIS[id].nome).capitalize()])
	for id in premio.get("pocoes", {}):
		partes.append("%d poção de cura" % premio.pocoes[id])
	if premio.has("receita"):
		partes.append("receita de %s" % str(premio.receita).replace("_", " "))
	return ", ".join(partes)

## Entrega tudo ou nada: se algo não couber na mochila, restaura a mochila e não paga ouro.
static func entregar(jogador: Node, missao: String) -> bool:
	if not PREMIOS.has(missao):
		return false
	var premio: Dictionary = PREMIOS[missao]
	var mochila = jogador.inventario
	var antes: Array = mochila.fotografar_mochila()
	var ok := true
	if premio.has("materiais"):
		ok = mochila.receber_materiais(premio.materiais)
	if ok:
		for id in premio.get("pocoes", {}):
			ok = ok and mochila.adicionar_coletavel("pocao", id, int(premio.pocoes[id]))
	if ok and premio.has("receita") and Forja.RECEITAS.has(premio.receita):
		ok = mochila.adicionar_coletavel("receita", premio.receita)
	if not ok or not mochila.salvar():
		mochila.restaurar_mochila(antes)
		return false
	if premio.has("ouro"):
		jogador.adicionar_moedas(int(premio.ouro))
	return true
